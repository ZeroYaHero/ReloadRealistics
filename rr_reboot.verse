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
    # cause_knock_xp_tag := class(reboot_verse_tag){}
    rift_sfx_tag := class(reboot_verse_tag){}

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
            Duration := 15.0
        rr_reboot_state:
            TimeToReboot := 5.0
            Duration := 30.0
        rr_reboot_state:
            TimeToReboot := 7.0
            Duration := 30.0
        rr_reboot_state:
            TimeToReboot := 12.0
            Duration := 60.0
            ShowTimer := true

rr_reboot_manager := class:

    RebootParameters : rr_reboot_parameters
    TeamWipeHUD : hud_message_device
    TeamWipeSFX : audio_player_device
    RebootTimerDevice : timer_device
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
    RiftSFX : audio_player_device

    var <private>CurrentRebootIndex<private> : int = 0
    var <private>CurrentRebootState<private> : ?rr_reboot_state = false
    var <private>RebootableParticipantStateMap<private> : [agent]logic = map{}
    var <private>LastPositionBeforeEliminated<private> : [agent]transform = map{}
    var <private>RebootsDisabled<private> : logic = false
    var <private>TeleporterIndex<private> : int = 0

    RebootsDisabledEvent : event() = event(){}
    RoundEndEvent : event() = event(){}
    TeamWipeEvent : event(int) = event(int){}

    EnableReboots<public>():void = 
        set RebootsDisabled = false
        set CurrentRebootIndex = 0
        set CurrentRebootState = option{RebootParameters.RebootStates[CurrentRebootIndex]}

    # Await Reboot States
    AwaitReboots<public>(Participants : []agent)<suspends>:void =
        set RebootableParticipantStateMap = Dict of for(Participant : Participants):
            spawn{AwaitEliminated(Participant)}
            HideHoldRebootHUD(Participant)
            TeamWipeHUD.Hide(Participant)
            (Participant, true)
        race:
            RoundEndEvent.Await()
            AwaitAllKnocked(Participants)
            ProcessRebootStates(Participants)

    # Stop Reboots
    DisableReboots<public>(?RoundEnding : logic = false):void =
        RebootsDisabledEvent.Signal()
        set RebootsDisabled = true
        set CurrentRebootState = false
        HoldToRebootTrigger.UnregisterAll()
        StatusTimerCenterHUD.Stop()
        StatusTimerCornerHUD.Stop()
        if(RoundEnding?):
            RoundEndEvent.Signal()
            DisabledHUD.Hide()
            TeamWipeHUD.Hide()
        else:
            DisabledHUD.Show()

    ProcessRebootStates(Participants : []agent)<suspends>:void = 
        for(RebootState : RebootParameters.RebootStates):
            set CurrentRebootState = option{RebootState}
            if(RebootState.ShowTimer?):
                spawn{StartRebootStatusTimer(Int[RebootState.Duration] or 0, Participants)}
            AwaitTimer(RebootState.Duration)
        DisableReboots()

    # Reboot Status Timer
    StartRebootStatusTimer(Duration : int, Participants : []agent)<suspends>:void =
        race:
            RoundEndEvent.Await()
            block:
                for(Participant : Participants):
                    StatusTimerCenterHUD.Start(Participant, Duration)
                if(Duration > 3):
                    AwaitTimer(3.0)
                    StatusTimerCenterHUD.Stop()
                    for(Participant : Participants):
                        StatusTimerCornerHUD.Start(Participant, Duration -3)
                    AwaitTimer(1.0 * Duration - 6.0)
                    StatusTimerCornerHUD.Stop()
                    for(Participant : Participants):
                        StatusTimerCenterHUD.Start(Participant, 3)

    AwaitEliminated<private>(InAgent : agent)<suspends>:void =
        race:
            RoundEndEvent.Await()
            block:
                GetMainDevicePlayspace().ParticipantRemovedEvent().AwaitPayloadEqual(InAgent)
                set RebootableParticipantStateMap = Dict of for:
                    RebootableParticipant -> State : RebootableParticipantStateMap
                    RebootableParticipant <> InAgent
                do:
                    (RebootableParticipant, State)
            if(FortCharacter := InAgent.GetFortCharacter[]):
                loop:
                    EliminationResult := FortCharacter.EliminatedEvent().Await()
                    if { set LastPositionBeforeEliminated[InAgent] = FortCharacter.GetTransform() }
                    HideHoldRebootHUD(InAgent)
                    if:
                        RebootableParticipantStateMap[InAgent]?
                        set RebootableParticipantStateMap[InAgent] = false
                    then:
                        if(IsRebootSafe[InAgent]):
                            if(not RebootsDisabled?):
                                QueueReboot(InAgent)
                            else:
                                break
                        else:
                            TeamWipe(InAgent, EliminationResult.EliminatingCharacter)
                            break

    AwaitAllKnocked<private>(Participants : []agent)<suspends>:void =
        loop:
            KnockedAgent := DBNODevice.AgentDownedEvent.Await()
            if(Participants.Find[KnockedAgent]):
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
                        HoldToRebootHUDNoAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
                    else:
                        HoldToRebootHUDNoAnim.Show(InAgent, EmptyMessage, ?DisplayTime:=0.0)
                    HoldToRebootTrigger.Register(InAgent)

                    HoldToRebootTrigger.PressedEvent.AwaitPayloadEqual(InAgent)
                    HideHoldRebootHUD(InAgent)

                    if(TimeToReboot := Int[CurrentRebootState?.TimeToReboot]):
                        HoldToRebootHUDAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
                    else:
                        HoldToRebootHUDAnim.Show(InAgent, EmptyMessage, ?DisplayTime:=0.0)

                    IsHeld := HoldToRebootTrigger.IsHoldingFor(InAgent, 1.0)

                    HideHoldRebootHUD(InAgent)
                    if(IsHeld?):
                        break
                true
        if:
            FortCharacter := InAgent.GetFortCharacter[]
            Result? and FortCharacter.IsDownButNotOut[]
        then:
            RepeatAttemptElimination(FortCharacter)

    IsRebootSafe<private>(InAgent : agent)<transacts><decides>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        TeamMatesAlive := for:
            TeamMate : TeamCollection._GetUpTeammates(InAgent)
            RebootableParticipantStateMap[TeamMate] # ! This verifies that the teammate was playing this round
        do:
            TeamMate
        TeamMatesAlive.Length >= RebootParameters.MinimumTeammatesAliveRequired

    QueueReboot<private>(InAgent : agent)<suspends>:void =
        Success := AwaitRebootCountdown(InAgent)
        if:
            Success?
            Print("Timer was Success")
            IsRebootSafe[InAgent]
            Print("Reboot is Safe")
            NextTeleporter := SkyDiveTeleporters[Mod[TeleporterIndex, 8]] 
        then:
            set TeleporterIndex += 1
            SkyReboot(InAgent, NextTeleporter)

    AwaitRebootCountdown<private>(InAgent : agent)<suspends>:logic =
        defer:
            RebootTimerDevice.Reset(InAgent)
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if(TimeToReboot := CurrentRebootState?.TimeToReboot):
            RebootTimerDevice.SetActiveDuration(TimeToReboot, InAgent)
            RebootTimerDevice.Start(InAgent)
            RebootTimerDevice.SetActiveDuration(TimeToReboot, InAgent)
            Print("Awaiting Timer and Time Skips")
            branch:
                AwaitTeamTimeSkips(InAgent)
            # RebootTimerDevice.SuccessEvent.AwaitPayloadEqual(option{InAgent})
            loop:
                MaybeSuccessAgent := RebootTimerDevice.SuccessEvent.Await()
                if(MaybeSuccessAgent? = InAgent):
                    break
            Print("Timer Finished")
            true
        else:
            Print("Failed to Get TimeToReboot")
            false

    AwaitTeamTimeSkips(InAgent : agent)<suspends>:void =
        sync:
            AwaitTeamKnocks(InAgent)
            AwaitTeamEliminations(InAgent)
            AwaitTeamTeamWipes(InAgent)

    AwaitTeamKnocks(InAgent : agent)<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseKnockEvent := GetTeamCauseKnockEvent[TeamIndex]
        then:
            loop:
                KnockResult := TeamCauseKnockEvent.Await()
                if(RebootableParticipantStateMap[KnockResult.Target]):
                    RebootTimerDevice.SetActiveDuration(RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)

    AwaitTeamEliminations(InAgent : agent)<suspends>:void = 
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseEliminationEvent := GetTeamCauseEliminationEvent[TeamIndex]
        then:
            loop:
                EliminationResult := TeamCauseEliminationEvent.Await()
                if(RebootableParticipantStateMap[EliminationResult.Target]): # If they are a valid member in this round
                    RebootTimerDevice.SetActiveDuration(RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)

    AwaitTeamTeamWipes(InAgent : agent)<suspends>:void = 
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if(TeamIndex := TeamCollection._GetTeamIndex[InAgent]):
            loop:
                TeamWipeIndex := TeamWipeEvent.Await()
                if(TeamWipeIndex = TeamIndex):
                    RebootTimerDevice.SetActiveDuration(RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)

    HideHoldRebootHUD(InAgent : agent):void =
        HoldToRebootTrigger.Unregister(InAgent)
        HoldToRebootHUDNoAnim.Hide(InAgent)
        HoldToRebootHUDAnim.Hide(InAgent)

    # Called when a team can no longer reboot as all team members are eliminated.
    TeamWipe<private>(InAgent : agent, MaybeEliminatingCharacter : ?fort_character):void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if(Eliminator := MaybeEliminatingCharacter?.GetAgent[]):
            TeamWipeHUD.Show(Eliminator)
            TeamWipeSFX.Play(Eliminator)
            AwardXP(Eliminator, rr_award.TeamWipe)
            UpTeammates := TeamCollection._GetUpTeammates(Eliminator)
            for(UpTeammate : UpTeammates):
                TeamWipeHUD.Show(UpTeammate)
                TeamWipeSFX.Play(UpTeammate)
                AwardXP(UpTeammate, rr_award.TeamWipe)
            if(TeamWiperIndex := TeamCollection._GetTeamIndex[Eliminator]):
                TeamWipeEvent.Signal(TeamWiperIndex)
        else:
            TeamWipeEvent.Signal(-1)

    SkyReboot<private>(InAgent : agent, InTeleporterDevice : teleporter_device)<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        UpTeamMates := TeamCollection._GetUpTeammates(InAgent)

        RebootTransform := if:
        # Spawn Above Teammate
            RandomUpTeamMate := UpTeamMates[GetRandomInt(0, UpTeamMates.Length - 1)]
            TeammateFortChar := RandomUpTeamMate.GetFortCharacter[]
        then:
            transform:
                Translation := TeammateFortChar.GetTransform().Translation.SetZ(RebootParameters.SkyZ)
                Rotation := TeammateFortChar.GetTransform().Rotation
                Scale := v3(1)
        # Spawn Above Last Recorded Position
        else if(LastTransform := LastPositionBeforeEliminated[InAgent]):
            transform:
                Translation := LastTransform.Translation.SetZ(RebootParameters.SkyZ)
                Rotation := LastTransform.Rotation
                Scale := v3(1)
        # Spawn Center to POI
        else if(CurrentPOI := GetCurrentPOI[]):
            transform:
                Translation := CurrentPOI.GetCenter().Translation.SetZ(RebootParameters.SkyZ)
                Rotation := IdentityRotation()
                Scale := v3(1)
        else:
            return
        
        spawn{RebootRift(RebootTransform, InTeleporterDevice)}
        RiftSFX.Play(InAgent)
        RespawnTask := InAgent.RespawnAt(RebootTransform)
        race:
            RespawnTask.Await()
            block:
                Sleep(0.2)
                Sleep(0.0)
                InTeleporterDevice.Teleport(InAgent)
        AwardXP(InAgent, rr_award.Rebooted)
        RebootMessageFeed.Activate(InAgent)
        HideHoldRebootHUD(InAgent)

        ItemGranter.GrantItem(InAgent)
        if { set RebootableParticipantStateMap[InAgent] = true }

    RebootRift<private>(InTransform : transform, InTeleporterDevice : teleporter_device)<suspends>:void =
        if { InTeleporterDevice.TeleportTo[InTransform] }
        SpawnResult := SpawnProp(RebootParameters.RebootRift, InTransform + v3(0,0,128))
        if(SpawnedProp := SpawnResult(0)?):
            Sleep(RebootParameters.RebootRiftLifetime)
            SpawnedProp.Dispose()

RebootTimeMessage<localizes>(SecondsToReboot : int):message = "{SecondsToReboot}s"