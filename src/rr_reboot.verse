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

rr_reboot_parameters<public> := class<concrete>:

    @editable       SkyZ<public> : float = 384.0 * 40
    @editable       KnockSkip<public> : float = 2.0
    @editable       EliminationSkip<public> : float = 4.0
    @editable       TeamWipeSkip<public> : float = 10.0
    @editable       MinimumTeammatesAliveRequired<public> : int = 1
    @editable       MaximumRebootBank<public> : int = 1
    @editable       RebootRiftLifetime<public> : float = 10.0
    RespawnDurations<public> : []tuple(float, float) = array{}

rr_reboot_manager := class:

    RebootParameters:rr_reboot_parameters
    TeamWipeHUD:hud_message_device
    TeamWipeSFX:audio_player_device
    RebootTimerDevice:timer_device
    StatusTimerCenterHUD:custom_hud_timer
    StatusTimerCornerHUD:custom_hud_timer
    EnabledHUD:hud_message_device
    DisabledHUD:hud_message_device
    ItemGranter:item_granter_device
    HoldToRebootTrigger:input_trigger_device
    HoldToRebootHUDNoAnim:hud_message_device
    HoldToRebootHUDAnim:hud_message_device
    RebootMessageFeed:elimination_feed_device
    SkyDiveTeleporters:[]teleporter_device
    RiftAsset:creative_prop_asset
    RiftSFX:audio_player_device
    DBNODevice:down_but_not_out_device

    var <private>CurrentRebootIndex<private>:int = 0
    var <private>CurrentRespawnDuration<private>:?tuple(float, float) = false
    var <private>RebootableParticipantStateMap<private>:[agent]logic = map{}
    var <private>LastPositionBeforeEliminated<private>:[agent]transform = map{}
    var <private>RebootsDisabled<private>:logic = false
    var <private>TeleporterIndex<private>:int = 0
    var <private>DefaultRebootLocation<private>:vector3 = vector3{}

    RebootsDisabledEvent<private>:event() = event(){}
    RoundEndEvent<private>:event() = event(){}
    TeamWipeEvent<public>:event(int) = event(int){}

    # Enable the Reboots
    EnableReboots<public>():void = 
        set RebootsDisabled = false
        set CurrentRebootIndex = 0
        set CurrentRespawnDuration = option{RebootParameters.RespawnDurations[CurrentRebootIndex]}

    # Set the Default Reboot Location
    SetDefaultRebootLocation<public>(InDefaultRebootLocation : vector3):void =
        set DefaultRebootLocation = InDefaultRebootLocation

    # Await Reboot States
    AwaitReboots<public>(Participants : []agent)<suspends>:void =
        EnabledHUD.Show()
        set RebootableParticipantStateMap = Dict of for(Participant : Participants):
            spawn{AwaitEliminated(Participant)}
            spawn{AwaitLeave(Participant)}
            HideHoldRebootHUD(Participant)
            TeamWipeHUD.Hide(Participant)
            (Participant, true)
        race:
            RoundEndEvent.Await()
            AwaitAllKnocked(Participants)
            ProcessRebootStates(Participants)

    # Process the Reboot States
    ProcessRebootStates<private>(Participants : []agent)<suspends>:void = 
        for(Index -> RespawnDuration : RebootParameters.RespawnDurations):
            set CurrentRespawnDuration = option{RespawnDuration}
            Print("Starting RebootState | Respawn: {RespawnDuration(0)}, Duration: {RespawnDuration(1)}")
            if(Index = RebootParameters.RespawnDurations.Length - 1):
                spawn{StartRebootStatusTimer(RespawnDuration(1), Participants)}
            AwaitTimer(RespawnDuration(1))
            Print("Ending RebootState | Respawn: {RespawnDuration(0)}, Duration: {RespawnDuration(1)}")
        DisableReboots()

    # Reboot Status Timer
    StartRebootStatusTimer<private>(Duration : float, Participants : []agent)<suspends>:void =
        race:
            RoundEndEvent.Await()
            block:
                EnabledHUD.Hide()
                for(Participant : Participants):
                    StatusTimerCenterHUD.Start(Participant, Duration)
                if(Duration > 3.0):
                    AwaitTimer(3.0)
                    StatusTimerCenterHUD.Stop()
                    for(Participant : Participants):
                        StatusTimerCornerHUD.Start(Participant, Duration -3.0)
                    AwaitTimer(1.0 * Duration - 6.0)
                    StatusTimerCornerHUD.Stop()
                    for(Participant : Participants):
                        StatusTimerCenterHUD.Start(Participant, 3.0)

    # Stop Reboots
    DisableReboots<public>(?RoundEnding : logic = false):void =
        RebootsDisabledEvent.Signal()
        set RebootsDisabled = true
        set CurrentRespawnDuration = false
        set DefaultRebootLocation = vector3{}
        HoldToRebootTrigger.UnregisterAll()
        EnabledHUD.Hide()
        StatusTimerCenterHUD.Stop()
        StatusTimerCornerHUD.Stop()
        if(RoundEnding?):
            RoundEndEvent.Signal()
            DisabledHUD.Hide()
            TeamWipeHUD.Hide()
        else:
            DisabledHUD.Show()

    # Await this Agent Elimination
    AwaitEliminated<private>(InAgent : agent)<suspends>:void =
        if(FortCharacter := InAgent.GetFortCharacter[]):
            race:
                RoundEndEvent.Await()
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
                                AttemptReboot(InAgent)
                            else:
                                break
                        else:
                            TeamWipe(InAgent, EliminationResult.EliminatingCharacter)
                            break

    # Await this Agent Leaving
    AwaitLeave<private>(InAgent : agent)<suspends>:void =
        GetMainDevicePlayspace().ParticipantRemovedEvent().AwaitPayloadEqual(InAgent)
        set RebootableParticipantStateMap = Dict of for:
            RebootableParticipant -> State : RebootableParticipantStateMap
            RebootableParticipant <> InAgent
        do:
            (RebootableParticipant, State)

    # Await all Participant Knocks
    AwaitAllKnocked<private>(Participants : []agent)<suspends>:void =
        loop:
            KnockedAgent := DBNODevice.AgentDownedEvent.Await()
            if(Participants.Find[KnockedAgent]):
                spawn{AwaitHoldToReboot(KnockedAgent)}

    # Await Hold To Reboot
    AwaitHoldToReboot<private>(InAgent : agent)<suspends>:void =
        defer:
            HideHoldRebootHUD(InAgent)
        if(FortCharacter := InAgent.GetFortCharacter[]):
            loop:

                # Await Elimination, Pressed, and Constantly Register/Show Hold To Reboot HUD
                race:
                    FortCharacter.EliminatedEvent().Await()
                    HoldToRebootTrigger.PressedEvent.AwaitPayloadEqual(InAgent)
                    LoopRegisterHoldRebootHUD(InAgent, FortCharacter)
                HideHoldRebootHUD(InAgent)

                # After any of these events, confirm if the player is down and show the animated HUD.
                if:
                    FortCharacter.IsDownButNotOut[]
                    RespawnDuration := CurrentRespawnDuration?
                    TimeToReboot := Int[RespawnDuration(0)]
                then:
                    HoldToRebootHUDAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
                else:
                    break

                # Confirm the player holds for the allocated time.
                IsHeld := HoldToRebootTrigger.IsHoldingFor(InAgent, 1.0)
                HideHoldRebootHUD(InAgent)

                if(IsHeld? and FortCharacter.IsDownButNotOut[]):
                    RepeatAttemptEliminate(FortCharacter)
                    break

    LoopRegisterHoldRebootHUD<private>(InAgent : agent, FortCharacter : fort_character)<suspends>:void =
        loop:
            if:
                FortCharacter.IsDownButNotOut[]
                RespawnDuration := CurrentRespawnDuration?
                TimeToReboot := Int[RespawnDuration(0)]
            then:
                HoldToRebootHUDNoAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
                HoldToRebootTrigger.Register(InAgent)
                AwaitServerTick()
            else:
                break

    # AwaitHeldForceReboot<private>(InAgent : agent)<suspends>:void =
    #     defer:
    #         HideHoldRebootHUD(InAgent)
    #     Result := race:
    #         block:
    #             RebootsDisabledEvent.Await()
    #             false
    #         if(FortCharacter := InAgent.GetFortCharacter[]):
    #             FortCharacter.EliminatedEvent().Await()
    #             false
    #         else:
    #             Sleep(-1.0)
    #             false
    #         block:
    #             loop:
    #                 if(TimeToReboot := Int[CurrentRebootState?.TimeToReboot]):
    #                     HoldToRebootHUDNoAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
    #                 else:
    #                     HoldToRebootHUDNoAnim.Show(InAgent, EmptyMessage, ?DisplayTime:=0.0)
    #                 HoldToRebootTrigger.Register(InAgent)

    #                 HoldToRebootTrigger.PressedEvent.AwaitPayloadEqual(InAgent)
    #                 HideHoldRebootHUD(InAgent)

    #                 if(TimeToReboot := Int[CurrentRebootState?.TimeToReboot]):
    #                     HoldToRebootHUDAnim.Show(InAgent, RebootTimeMessage(TimeToReboot), ?DisplayTime:=0.0)
    #                 else:
    #                     HoldToRebootHUDAnim.Show(InAgent, EmptyMessage, ?DisplayTime:=0.0)

    #                 IsHeld := HoldToRebootTrigger.IsHoldingFor(InAgent, 1.0)

    #                 HideHoldRebootHUD(InAgent)
    #                 if(IsHeld?):
    #                     break
    #             true
    #     if:
    #         FortCharacter := InAgent.GetFortCharacter[]
    #         Result? and FortCharacter.IsDownButNotOut[]
    #     then:
    #         RepeatAttemptEliminate(FortCharacter)

    # TODO: Have use with config reboot bank
    IsRebootSafe<private>(InAgent : agent)<transacts><decides>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        TeamMatesAlive := for:
            TeamMate : TeamCollection._GetUpTeammates[InAgent]
            RebootableParticipantStateMap[TeamMate]
        do:
            TeamMate
        TeamMatesAlive.Length >= RebootParameters.MinimumTeammatesAliveRequired

    AttemptReboot<private>(InAgent : agent)<suspends>:void =
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
        if:
            RespawnDuration := CurrentRespawnDuration?
            TimeToReboot := RespawnDuration(0)
        then:
            RebootTimerDevice.SetActiveDuration(TimeToReboot, InAgent)
            RebootTimerDevice.Start(InAgent)
            RebootTimerDevice.SetActiveDuration(TimeToReboot, InAgent)
            branch:
                AwaitTeamTimeSkips(InAgent)
            RebootTimerDevice.SuccessEvent.AwaitPayloadEqual(option{InAgent})
            true
        else:
            false

    AwaitTeamTimeSkips(InAgent : agent)<suspends>:void =
        sync:
            AwaitTeamKnocks(InAgent)
            AwaitTeamEliminations(InAgent)
            AwaitTeamTeamWipes(InAgent)

    AwaitTeamKnocks<private>(InAgent : agent)<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseKnockEvent := GetTeamCauseKnockEvent[TeamIndex]
        then:
            loop:
                KnockResult := TeamCauseKnockEvent.Await()
                if(RebootableParticipantStateMap[KnockResult.Target]):
                    RebootTimerDevice.SetActiveDuration(RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)

    AwaitTeamEliminations<private>(InAgent : agent)<suspends>:void = 
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseEliminationEvent := GetTeamCauseEliminationEvent[TeamIndex]
        then:
            loop:
                EliminationResult := TeamCauseEliminationEvent.Await()
                if(RebootableParticipantStateMap[EliminationResult.Target]): # If they are a valid member in this round
                    RebootTimerDevice.SetActiveDuration(RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)

    AwaitTeamTeamWipes<private>(InAgent : agent)<suspends>:void = 
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        if(TeamIndex := TeamCollection._GetTeamIndex[InAgent]):
            loop:
                TeamWipeIndex := TeamWipeEvent.Await()
                if(TeamWipeIndex = TeamIndex):
                    RebootTimerDevice.SetActiveDuration(RebootTimerDevice.GetActiveDuration(InAgent) - RebootParameters.KnockSkip, InAgent)

    HideHoldRebootHUD<private>(InAgent : agent):void =
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
            for(UpTeammate : TeamCollection._GetUpTeammates[Eliminator]):
                TeamWipeHUD.Show(UpTeammate)
                TeamWipeSFX.Play(UpTeammate)
                AwardXP(UpTeammate, rr_award.TeamWipe)
            if(TeamWiperIndex := TeamCollection._GetTeamIndex[Eliminator]):
                TeamWipeEvent.Signal(TeamWiperIndex)
        else:
            TeamWipeEvent.Signal(-1)

    SkyReboot<private>(InAgent : agent, InTeleporterDevice : teleporter_device)<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        RebootTransform := if:
        # Spawn Above Teammate
            UpTeammates := TeamCollection._GetUpTeammates[InAgent]
            RandomUpTeamMate := UpTeammates[GetRandomInt(0, UpTeammates.Length - 1)]
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
        else:
            transform:
                Translation := DefaultRebootLocation.SetZ(RebootParameters.SkyZ)
                Rotation := IdentityRotation()
                Scale := v3(1)

        spawn{RebootRift(RebootTransform, InTeleporterDevice)}
        RiftSFX.Play(InAgent)
        RespawnTask := InAgent.RespawnAt(RebootTransform)
        race:
            RespawnTask.Await()
            block:
                Sleep(0.2)
                AwaitServerTick()
                InTeleporterDevice.Teleport(InAgent)
        AwardXP(InAgent, rr_award.Rebooted)
        RebootMessageFeed.Activate(InAgent)
        HideHoldRebootHUD(InAgent)

        ItemGranter.GrantItem(InAgent)
        if { set RebootableParticipantStateMap[InAgent] = true }

    RebootRift<private>(InTransform : transform, InTeleporterDevice : teleporter_device)<suspends>:void =
        if { InTeleporterDevice.TeleportTo[InTransform] }
        SpawnResult := SpawnProp(RiftAsset, InTransform + v3(0,0,128))
        if(SpawnedProp := SpawnResult(0)?):
            Sleep(RebootParameters.RebootRiftLifetime)
            SpawnedProp.Dispose()

RebootTimeMessage<localizes>(SecondsToReboot : int):message = "{SecondsToReboot}s"