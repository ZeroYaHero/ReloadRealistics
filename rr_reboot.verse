using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/FortPlayerUtilities }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Concurrency }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Fortnite.com/Game }
using { /Verse.org/Random }

using { FN_Gameplay }

# TODO: Tab spacing should be consistent for all things (like editables). Same for spacing on classes.

reboot_verse_tag := class(tag){}
    reboot_respawn_tag := class(reboot_verse_tag){}
    reboot_status_timer_center_tag := class(reboot_verse_tag){}
    reboot_status_timer_corner_tag := class(reboot_verse_tag){}
    team_wipe_tag := class(reboot_verse_tag){}
    reboot_granted_item_tag := class(reboot_verse_tag){}
    reboot_skyzone_tag := class(reboot_verse_tag){}
    reboot_disabled_hud_tag := class(reboot_verse_tag){}
    hold_to_reboot_input_tag := class(reboot_verse_tag){}
    hold_to_reboot_hud_no_anim := class(reboot_verse_tag){}
    hold_to_reboot_hud_anim := class(reboot_verse_tag){}
    reboot_message_feed_tag := class(reboot_verse_tag){}

rr_reboot_state := class<concrete>:

    @editable       TimeToReboot : float = 5.0
    @editable       Duration : float = 30.0
    @editable       ShowTimer : logic = false

rr_reboot_parameters := class<concrete>:

    @editable       SkyZ : float = 384.0 * 40
    @editable       KnockSkip : float = 2.0
    @editable       EliminationSkip : float = 4.0
    @editable       TeamWipeSkip : float = 10.0
    @editable       MinimumTeammatesAliveRequired : int = 1
    @editable       MaximumRebootBank : int = 1
    @editable       RebootRift : creative_prop_asset = DefaultCreativePropAsset
    @editable       RebootMessageFeed : elimination_feed_device = elimination_feed_device{}
    @editable       RebootRiftLifetime : float = 10.0
    @editable       RebootStates : []rr_reboot_state = array:
        rr_reboot_state:
            TimeToReboot := 3.0
            Duration := 30.0
        rr_reboot_state:
            TimeToReboot := 5.0
            Duration := 30.0
        rr_reboot_state:
            TimeToReboot := 7.0
            Duration := 45.0
        rr_reboot_state:
            TimeToReboot := 15.0
            Duration := 60.0
            ShowTimer := true

rr_reboot_devices := struct:
    
    TeamWipeHUD : hud_message_device
    TeamWipeXP : accolades_device
    RebootTimerDevice : timer_device
    RebootXP : accolades_device
    StatusTimerCenterHUD : custom_hud_timer
    StatusTimerCornerHUD : custom_hud_timer
    DisabledHUD : hud_message_device
    ItemGranter : item_granter_device
    DBNODevice : down_but_not_out_device
    HoldToRebootTrigger : input_trigger_device
    HoldToRebootHUDNoAnim : hud_message_device
    HoldToRebootHUDAnim : hud_message_device
    RebootMessageFeed : elimination_feed_device
    SkyDiveTeleporters : []teleporter_device

rr_reboot_manager := class:

    RebootParameters : rr_reboot_parameters
    RebootDevices : rr_reboot_devices
    TeamPlayerManager : rr_team_and_player_manager

    var <private>CurrentRebootIndex<private> : int = 0
    var <private>CurrentRebootState<private> : ?rr_reboot_state = false
    var <private>PlayerAliveStateMap<private> : [agent]logic = map{}
    var <private>LastPositionBeforeEliminated<private> : [agent]transform = map{}
    var <private>RebootsDisabled<private> : logic = false
    var <private>TeleporterIndex<private> : int = 0

    RebootsDisabledEvent : event() = event(){}
    RoundEndEvent : event() = event(){}
    TeamWipeEvent : event(int) = event(int){}

    IsRebootSafe<private>(InAgent : agent)<transacts><decides>:void =
        TeamMatesAlive := for:
            TeamMate : TeamPlayerManager.GetUpTeamMates(InAgent)
            PlayerAliveStateMap[TeamMate] # ! This verifies that the teammate was playing this round
        do:
            TeamMate
        TeamMatesAlive.Length >= RebootParameters.MinimumTeammatesAliveRequired

    EnableReboots<public>(Participants : []agent):void = 
        set RebootsDisabled = false
        set CurrentRebootIndex = 0
        set CurrentRebootState = option{RebootParameters.RebootStates[CurrentRebootIndex]}

        spawn{AwaitKnocked()}
        set PlayerAliveStateMap = Dict of for(Participant : Participants):
            spawn{AwaitEliminated(Participant)}
            HideHoldRebootHUD(Participant)
            RebootDevices.TeamWipeHUD.Hide(Participant)
            (Participant, true)

    # Stop Reboots
    DisableReboots<public>(?RoundEnding : logic = false):void =
        RebootsDisabledEvent.Signal()
        set RebootsDisabled = true
        set CurrentRebootState = false
        RebootDevices.HoldToRebootTrigger.UnregisterAll()
        RebootDevices.StatusTimerCenterHUD.Stop()
        RebootDevices.StatusTimerCornerHUD.Stop()
        if(RoundEnding?):
            RoundEndEvent.Signal()
            RebootDevices.DisabledHUD.Hide()
            RebootDevices.TeamWipeHUD.Hide()
        else:
            RebootDevices.DisabledHUD.Show()

    # Await Reboot States
    AwaitReboots<public>()<suspends>:void =
        race:
            RoundEndEvent.Await()
            block:
                for(RebootState : RebootParameters.RebootStates):
                    set CurrentRebootState = option{RebootState}
                    if(RebootState.ShowTimer?):
                        spawn{StartRebootStatusTimer(Int[RebootState.Duration] or 0)}
                    Sleep(RebootState.Duration)
                DisableReboots()

    # Reboot Status Timer
    StartRebootStatusTimer(Duration : int)<suspends>:void =
        race:
            RoundEndEvent.Await()
            block:
                RebootDevices.StatusTimerCenterHUD.Start(Duration)
                if(Duration > 3):
                    Sleep(3.0)
                    RebootDevices.StatusTimerCenterHUD.Stop()
                    RebootDevices.StatusTimerCornerHUD.Start(Duration - 3)
                    Sleep(1.0 * Duration - 6.0)
                    RebootDevices.StatusTimerCornerHUD.Stop()
                    RebootDevices.StatusTimerCenterHUD.Start(3)

    AwaitEliminated<private>(InAgent : agent)<suspends>:void =
        if(FortCharacter := InAgent.GetFortChar[]):
            branch:
                loop:
                    ElimResult := FortCharacter.EliminatedEvent().Await()
                    HideHoldRebootHUD(InAgent)
                    if:
                        PlayerAliveStateMap[InAgent]?
                        set PlayerAliveStateMap[InAgent] = false
                    then:
                        if { set LastPositionBeforeEliminated[InAgent] = FortCharacter.GetTransform() }
                        QueueReboot(InAgent, ElimResult.EliminatingCharacter) # TODO: Check TeamWiped/IsRebootSafe here!
            RoundEndEvent.Await()

    AwaitKnocked<private>()<suspends>:void =
        race:
            RebootsDisabledEvent.Await()
            loop:
                KnockedAgent := RebootDevices.DBNODevice.AgentDownedEvent.Await()
                spawn{AwaitHeldForceReboot(KnockedAgent)}

    AwaitHeldForceReboot<private>(InAgent : agent)<suspends>:void =
        defer:
            HideHoldRebootHUD(InAgent)
        Result := race:
            block:
                RebootsDisabledEvent.Await()
                false
            if(FortCharacter := InAgent.GetFortCharacter[]):
                FortCharacter.EliminatedEvent().Await()
                false
            else:
                Sleep(-1.0)
                false
            block:
                loop:
                    if(TimeToReboot := Int[CurrentRebootState?.TimeToReboot]):
                        RebootDevices.HoldToRebootHUDNoAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
                    else:
                        RebootDevices.HoldToRebootHUDNoAnim.Show(InAgent, EmptyMessage, ?DisplayTime:=0.0)
                    RebootDevices.HoldToRebootTrigger.Register(InAgent)

                    RebootDevices.HoldToRebootTrigger.AwaitPressed(InAgent)
                    HideHoldRebootHUD(InAgent)

                    if(TimeToReboot := Int[CurrentRebootState?.TimeToReboot]):
                        RebootDevices.HoldToRebootHUDAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
                    else:
                        RebootDevices.HoldToRebootHUDAnim.Show(InAgent, EmptyMessage, ?DisplayTime:=0.0)

                    IsHeld := RebootDevices.HoldToRebootTrigger.IsHoldingFor(InAgent, 2.0)

                    HideHoldRebootHUD(InAgent)
                    if(IsHeld?):
                        break
                true

        if(Result?):
            InAgent.Eliminate()

    RebootTimeMessage<localizes>(SecondsToReboot : int):message = "{SecondsToReboot}s"

    # ?FIXME: What happens when this is called somehow after a disable
    QueueReboot<private>(InAgent : agent, MaybeEliminatingCharacter : ?fort_character)<suspends>:void =
        Print("Queued Reboot")
        if(not RebootsDisabled?):
            if(IsRebootSafe[InAgent]):
                Success := AwaitRebootCountdown(InAgent)
                if:
                    Success?
                    IsRebootSafe[InAgent]
                    NextTeleporter := RebootDevices.SkyDiveTeleporters[Mod[TeleporterIndex, 8]] 
                then:
                    set TeleporterIndex += 1
                    Print("Awaited the Reboot Countdown and Teammates are alive!")
                    SkyReboot(InAgent, NextTeleporter)
            else:
                Print("Reboot failed: No TeamMates Alive!")
                TeamWipe(InAgent, MaybeEliminatingCharacter)
        else:
            Print("Reboot failed: Disabled!")

    AwaitRebootCountdown<private>(InAgent : agent)<suspends>:logic =
        defer:
            RebootDevices.RebootTimerDevice.Reset(InAgent)
        if:
            TeamIndex := TeamPlayerManager.GetTeamIndex[InAgent]
            TeamCauseKnockEvent := GetTeamCauseKnockEvent[TeamIndex]
            TeamCauseEliminationEvent := GetTeamCauseEliminationEvent[TeamIndex]
            TimeToReboot := CurrentRebootState?.TimeToReboot
        then:
            RebootDevices.RebootTimerDevice.SetActiveDuration(TimeToReboot, InAgent)
            RebootDevices.RebootTimerDevice.Start(InAgent)
            RebootDevices.RebootTimerDevice.SetActiveDuration(TimeToReboot, InAgent)
            branch:
                TeamTimeSkips := sync:
                    loop:
                        KnockResult := TeamCauseKnockEvent.Await()
                        RebootDevices.RebootTimerDevice.SetActiveDuration(RebootDevices.RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)
                    loop:
                        EliminationResult := TeamCauseEliminationEvent.Await()
                        RebootDevices.RebootTimerDevice.SetActiveDuration(RebootDevices.RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.EliminationSkip, InAgent)
                    loop:
                        TeamWiperIndex := TeamWipeEvent.Await()
                        if(TeamWiperIndex = TeamIndex):
                            RebootDevices.RebootTimerDevice.SetActiveDuration(RebootDevices.RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.TeamWipeSkip, InAgent)
            Timer := loop:
                MaybeAgent := RebootDevices.RebootTimerDevice.SuccessEvent.Await()
                if(MaybeAgent? = InAgent):
                    break
            true
        else:
            false

    HideHoldRebootHUD(InAgent : agent):void =
        RebootDevices.HoldToRebootTrigger.Unregister(InAgent)
        RebootDevices.HoldToRebootHUDNoAnim.Hide(InAgent)
        RebootDevices.HoldToRebootHUDAnim.Hide(InAgent)

    # Called when a team can no longer reboot as all team members are eliminated.
    TeamWipe<private>(InAgent : agent, MaybeEliminatingCharacter : ?fort_character):void =
        if(Eliminator := MaybeEliminatingCharacter?.GetAgent[]):
            RebootDevices.TeamWipeHUD.Show(Eliminator)
            UpTeamMates := TeamPlayerManager.GetUpTeamMates(Eliminator)
            for(UpTeamMate : UpTeamMates):
                RebootDevices.TeamWipeHUD.Show(UpTeamMate)
            if(TeamWiperIndex := TeamPlayerManager.GetTeamIndex[Eliminator]):
                TeamWipeEvent.Signal(TeamWiperIndex)
        else:
            TeamWipeEvent.Signal(-1)

    SkyReboot<private>(InAgent : agent, InTeleporterDevice : teleporter_device)<suspends>:void =
        Sleep(0.0) # Allow another tick for cancellation
        UpTeamMates := TeamPlayerManager.GetUpTeamMates(InAgent)

        RebootTransform := if:
        # Spawn Above Teammate
            RandomUpTeamMate := UpTeamMates[GetRandomInt(0, UpTeamMates.Length - 1)]
            TeamMateFortChar := RandomUpTeamMate.GetFortChar[]
        then:
            transform:
                Translation := vector3:
                    X := TeamMateFortChar.GetTransform().Translation.X
                    Y := TeamMateFortChar.GetTransform().Translation.Y
                    Z := RebootParameters.SkyZ
                Rotation := TeamMateFortChar.GetTransform().Rotation
                Scale := v3(1)
        # Spawn Above Last Recorded Position
        else if(LastTransform := LastPositionBeforeEliminated[InAgent]):
            transform:
                Translation := vector3:
                    X := LastTransform.Translation.X
                    Y := LastTransform.Translation.Y
                    Z := RebootParameters.SkyZ
                Rotation := LastTransform.Rotation
                Scale := v3(1)
        # Spawn Center to POI
        else if(CurrentPOI := GetCurrentPOI[]):
            transform:
                Translation := CurrentPOI.GetCenter().Translation.SetZ(RebootParameters.SkyZ)
                Rotation := IdentityRotation()
                Scale := v3(1)
        # Fail
        else:
            return
        
        spawn{RebootRift(RebootTransform, InTeleporterDevice)}
        RespawnTask := Respawn(InAgent, RebootTransform)
        race:
            RespawnTask.Await()
            block:
                Sleep(0.2)
                Sleep(0.0)
                InTeleporterDevice.Teleport(InAgent)
        RebootDevices.RebootMessageFeed.Activate(InAgent)
        HideHoldRebootHUD(InAgent)

        RebootDevices.ItemGranter.GrantItem(InAgent)
        if { set PlayerAliveStateMap[InAgent] = true }

    RebootRift<private>(InTransform : transform, InTeleporterDevice : teleporter_device)<suspends>:void =
        if { InTeleporterDevice.TeleportTo[InTransform] }
        SpawnResult := SpawnProp(RebootParameters.RebootRift, InTransform + v3(0,0,128))
        if(SpawnedProp := SpawnResult(0)?):
            Sleep(RebootParameters.RebootRiftLifetime)
            SpawnedProp.Dispose()
