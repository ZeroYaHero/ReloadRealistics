using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/Characters }
using { /Verse.org/Concurrency }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Fortnite.com/Game }
using { /Verse.org/Random }

using { FN_Gameplay }
using { config }

# TODO: Reboot bank should be its own "module"

rr_rebooter := class:
    Config:rr_reboot_config
    TeamCollection:fort_team_collection
    DBNODevice:down_but_not_out_device

    TimeSkipHUD:hud_message_device

    AllowedHUD:hud_message_device
    RebootsEndingHUDTimerCorner:hud_message_timer
    RebootsEndingHUDTimerCenter:hud_message_timer
    RebootsEndingTimerTickSFX:audio_player_device
    RebootsEndingUrgentTimerTickSFX:audio_player_device
    DisallowedHUDCorner:hud_message_device
    DisallowedHUDCenter:hud_message_device

    DisallowedSFX:audio_player_device

    WipeHUD:hud_message_device
    WipeSFX:audio_player_device
    _WipeEvent<private>:event(?int) = event(?int){}

    RiftAsset:creative_prop_asset
    RiftSFX:audio_player_device
    RiftTeleporterDevices:[]teleporter_device

    RebootTimer:hud_message_timer
    RebootItemGranter:item_granter_device
    RebootMessageFeed:elimination_feed_device
    RebootBanks:[]hud_message_device
    NoRebootBank:?hud_message_device

    OvershieldHalfSelector:class_and_team_selector_device
    OvershieldFullSelector:class_and_team_selector_device

    HoldToRebootInputTrigger:input_trigger_device
    HoldToRebootUI:hud_message_device
    HoldToRebootUIAnimation:hud_message_device
    HoldToRebootArrowHUD:hud_message_device

    DisabledEvent<private>:event() = event(){}
    DisallowedEvent<private>:event() = event(){}

    var <private>DefaultRebootLocation<private>:vector3 = vector3{}
    var <private>LastLocationMap<private>:[agent]transform = map{}
    var <private>RebootBankIndexMap<private>:[agent]int = map{}
    var <private>CurrentRebootDurationIndex<private>:int = 0
    var <private>RegisteredAgents<private>:[]agent = array{}
    var <private>RiftTeleporterIndex<private>:int = 0
    var <private>Enabled<private>:logic = false
    var <private>Allowed<private>:logic = false
    var <private>HoldToRebootCountMap<private>:[agent]int = map{}
    var <private>AgentCancelableTaskMap<private>:[agent]?cancelable_sticky_task = map{}
    var <private>BeingRebooted<private>:[]agent = array{}
    var <private>BeingRespawned<private>:[]agent = array{}

    # Enable the Rebooting / Cycles
    Enable<public>():void =
        set Enabled = true

    # Disable Rebooting / Cycles, Cancel all Reboot Events
    Disable<public>():void =
        set Enabled = false
        DisabledEvent.Signal()
        DisallowReboots()
        for:
            MaybeCancelableStickyTask:AgentCancelableTaskMap
            CancelableStickyTask := MaybeCancelableStickyTask?
        do:
            CancelableStickyTask.Cancel()
        set AgentCancelableTaskMap = map{}
        set BeingRebooted = array{}
        set BeingRespawned = array{}
        HideRebootsEndingHUD()
        HideDisallowRebootsHUD()
        RebootTimer.StopAll()

    # Verify Rebooting is Enabled
    IsEnabled<public>()<transacts><decides>:void = 
        Enabled?

    # Allow Reboots and Await Reboot Events for each Registered Agent
    AllowReboots<public>():void =
        if(IsEnabled[]):
            set Allowed = true
            for(RegisteredAgent:RegisteredAgents):
                AwaitAgentElimination(RegisteredAgent)
            spawn{CancelOnAwaitable(AwaitAgentDowns, DisallowedEvent)}
            ShowAllowedRebootsHUD()

    # Disallow Reboots, Prevent Reboot Events going forward
    DisallowReboots<public>():void = 
        set Allowed = false
        DisallowedEvent.Signal()

        for(RegisteredAgent:RegisteredAgents):
            for(RebootBankHUDMessage:RebootBanks):
                RebootBankHUDMessage.Hide(RegisteredAgent)
            if(CurrentRebootBankIndex := GetRebootBankIndex[RegisteredAgent]):
                RebootsLeft := RebootBanks.Length - CurrentRebootBankIndex
                if(RebootsLeft = 1):
                    OvershieldHalfSelector.ChangeClass(RegisteredAgent)
                else if(RebootsLeft > 1):
                    OvershieldFullSelector.ChangeClass(RegisteredAgent)

        HideAllowedRebootsHUD()
        HideRebootBank()
        HideHoldReboot()

        if(IsEnabled[]):
            spawn{CancelOnAwaitable(ShowDisallowRebootsHUD, DisabledEvent)}

    # Verify Rebooting is Allowed
    IsAllowed<public>()<transacts><decides>:void =
        IsEnabled[] and Allowed?

    # Start Reboot Cycle to automatically Allow and Disallow Rebootings
    StartRebootCycle<public>():void =
        # set DisableCancelableTasks += array{CancelableSpawn(_StartRebootCycle)}
        spawn{CancelOnAwaitable(_StartRebootCycle, DisabledEvent)}
    
    # Register this Agent for Reboot Events
    # If Reboots are Currently Enabled and Allowed, Await those events now
    Register<public>(InAgent:agent):void =
        if(not IsRegistered[InAgent]):
            RebootsEndingTimerTickSFX.Register(InAgent)
            RebootsEndingUrgentTimerTickSFX.Register(InAgent)
            if(IsAllowed[]):
                AwaitAgentElimination(InAgent)
            if(TeamIndex := TeamCollection._GetTeamIndex[InAgent]):
                InitializeTeamCauseCombatEvents(TeamIndex)
            set RegisteredAgents = RegisteredAgents.SetAdd(InAgent)

    # Unregister this Agent for Reboot Events
    Unregister<public>(InAgent:agent):void =
        set RegisteredAgents = RegisteredAgents.SetRemove(InAgent)
        set BeingRebooted = BeingRebooted.SetRemove(InAgent)
        set BeingRespawned = BeingRespawned.SetRemove(InAgent)
        RebootsEndingTimerTickSFX.Unregister(InAgent)
        RebootsEndingUrgentTimerTickSFX.Unregister(InAgent)
        if:
            CancelableStickyTask := AgentCancelableTaskMap[InAgent]?
            set AgentCancelableTaskMap[InAgent] = false
        then:
            CancelableStickyTask.Cancel()

    # Unregister all Agent
    UnregisterAll<public>():void =
        for(RegisteredAgent:RegisteredAgents):
            Unregister(RegisteredAgent)
        set RegisteredAgents = array{}
        set BeingRebooted = array{}
        set BeingRespawned = array{}
        set AgentCancelableTaskMap = map{}

    # Verify the Agent is Registered
    IsRegistered<public>(InAgent:agent)<transacts><decides>:void =
        RegisteredAgents.Find[InAgent]

    # Checks if the agent has Teammates alive OR if there is still reboots in the bank
    IsRebootable<public>(InAgent:agent)<transacts><decides>:void =
        IsAllowed[]
        Print("Is Allowed")
        IsRegistered[InAgent]
        Print("Is Registered")
        # not IsWiped[InAgent] or HasRebootBank[InAgent]
        # Print("Is Not Wiped or Has Reboot Banks")
        InAgent.IsConnected[]
        Print("Is Connected")

    # Force Reboot
    Reboot<public>(InAgent:agent):void =
        if(NextTeleporter := RiftTeleporterDevices[Mod[RiftTeleporterIndex, 8]]):
            set RiftTeleporterIndex += 1
            spawn{SkyRespawnRift(InAgent, NextTeleporter)}

    # Team Wipe Event
    WipeEvent<public>():awaitable(?int) = 
        _WipeEvent

    # Get the Default Reboot Location if no teammates position is accessible or a previous location cannot be found
    GetDefaultRebootLocation<public>():vector3 =
        DefaultRebootLocation

    # Set the Default Reboot Location given a vector3
    SetDefaultRebootLocation<public>(InLocation:vector3):void =
        set DefaultRebootLocation = InLocation

    RebootsInProgress<public>()<transacts><decides>:void =
        IsEnabled[]
        BeingRebooted.Length > 0
        Print("There are agents being rebooted!")

    # ---------------------------------------------------------------------------------------------
    
    # Start the Reboot Cycle (Private & Suspending)
    _StartRebootCycle<private>()<suspends>:void =
        AllowReboots()
        RebootDurationCyclesLength := Config.RebootDurationCycles.Length
        for(Index -> RebootDurationCycle : Config.RebootDurationCycles):
            set CurrentRebootDurationIndex = Index
            if(Index = RebootDurationCyclesLength - 1):
                HideAllowedRebootsHUD()
                spawn{CancelOnAwaitableParam(ShowRebootsEndingHUD, RebootDurationCycle(1), DisabledEvent)}
            AwaitTimer(RebootDurationCycle(1))
        set CurrentRebootDurationIndex = -1
        DisallowReboots()

    AwaitAgentElimination<private>(InAgent:agent):void =
        if(not AgentCancelableTaskMap[InAgent]):
            ResetRebootBank(InAgent)
            AwaitEliminationTask := CancelableSpawnParam(_AwaitAgentElimination, InAgent)
            if { set AgentCancelableTaskMap[InAgent] = option{AwaitEliminationTask} }

    _AwaitAgentElimination<private>(InAgent:agent)<suspends>:void =
        loop:
            if(FortCharacter := InAgent.GetFortCharacter[]):
                EliminationResult := FortCharacter.EliminatedEvent().Await()
                Print("Agent died")
                if { set LastLocationMap[InAgent] = FortCharacter.GetTransform() }
                if(IsRebootable[InAgent]):
                    if(not IsWiped[InAgent]):
                        set BeingRebooted = BeingRebooted.SetAdd(InAgent)
                        IncrementRebootBank(InAgent)
                        RebootOnTimerSuccess(InAgent)
                    else:
                        GiveOneSpawn(InAgent)
                        Wipe(InAgent, ?MaybeEliminatingCharacter:=EliminationResult.EliminatingCharacter)
                        return
                else:
                    GiveOneSpawn(InAgent)
                    return
            else:
                return

    # On Agent Downed
    AwaitAgentDowns<private>()<suspends>:void =
        loop:
            DownedAgent := DBNODevice.AgentDownedEvent.Await()
            if(IsRebootable[DownedAgent]):
                spawn{CancelOnAwaitableParam(ShowHoldToReboot, DownedAgent, DisallowedEvent)}

    # Allowed Reboots HUD
    ShowAllowedRebootsHUD<private>():void =
        for(RegisteredAgent : RegisteredAgents):
            AllowedHUD.Show(RegisteredAgent)

    HideAllowedRebootsHUD<private>():void =
        AllowedHUD.Hide()

    ShowRebootsEndingHUD<private>(Duration:float)<suspends>:void =
        for(RegisteredAgent : RegisteredAgents):
            RebootsEndingHUDTimerCenter.Start(RegisteredAgent, Duration)
        AwaitTimer(3.0)
        RebootsEndingHUDTimerCenter.StopAll()
        for(RegisteredAgent : RegisteredAgents):
            RebootsEndingHUDTimerCorner.Start(RegisteredAgent, Duration - 3.0)
        AwaitTimer(Duration - 3.0 - Config.TimerTickSFXDuration - Config.UrgentTimerTickSFXDuration - 1.0)    
        for(I := 1..Int[Config.TimerTickSFXDuration]):
            AwaitTimer(1.0)
            RebootsEndingTimerTickSFX.Play()
        for(I := 1..Int[Config.UrgentTimerTickSFXDuration]):
            AwaitTimer(1.0)
            RebootsEndingUrgentTimerTickSFX.Play()

    HideRebootsEndingHUD<private>():void =
        RebootsEndingHUDTimerCenter.StopAll()
        RebootsEndingHUDTimerCorner.StopAll()

    ShowDisallowRebootsHUD<private>()<suspends>:void =
        for(RegisteredAgent : RegisteredAgents):
            DisallowedHUDCenter.Show(RegisteredAgent)
            DisallowedSFX.Play(RegisteredAgent)
        AwaitTimer(4.0)
        HideDisallowRebootsHUD()
        for(RegisteredAgent : RegisteredAgents):
            DisallowedHUDCorner.Show(RegisteredAgent)

    HideDisallowRebootsHUD<private>():void =
        DisallowedHUDCorner.Hide()

    ResetRebootBank<private>(InAgent:agent):void =
        SetRebootBankIndex(InAgent, 0)

    IncrementRebootBank<private>(InAgent:agent):void =
        if(CurrentRebootBankIndex := GetRebootBankIndex[InAgent]):
            SetRebootBankIndex(InAgent, CurrentRebootBankIndex + 1)
        else:
            SetRebootBankIndex(InAgent, 0)

    GetRebootBankIndex<private>(InAgent:agent)<transacts><decides>:int =
        RebootBankIndexMap[InAgent]

    SetRebootBankIndex<private>(InAgent:agent, Index:int):void =
        if { set RebootBankIndexMap[InAgent]  = Index }
        Print("Setting Reboot Bank Index to {Index} for Agent")
        HideRebootBank(InAgent)
        if(RebootBankHUDMessage := RebootBanks[GetRebootBankIndex[InAgent]]):
            Print("Valid Reboot Bank Index, Giving Infinite Spawn")
            RebootBankHUDMessage.Show(InAgent)
            GiveInfiniteSpawn(InAgent)
        else:
            Print("Invalid Reboot Bank Index, Showing/Giving No Respawns Left")
            if(NoRebootBankHUD := NoRebootBank?):
                NoRebootBankHUD.Show(InAgent)

    HasRebootBank<private>(InAgent:agent)<transacts><decides>:void =
        Print("Checking Reboot Bank")
        RebootBanks[GetRebootBankIndex[InAgent]]
        Print("Reboot Bank is good")
        

    HideRebootBank<private>():void =
        for(RegisteredAgent:RegisteredAgents):
            HideRebootBank(RegisteredAgent)

    HideRebootBank<private>(InAgent:agent):void =
        if(NoRebootBankHUD := NoRebootBank?):
            NoRebootBankHUD.Hide(InAgent)
        for(RebootBankHUDMessage : RebootBanks):
            RebootBankHUDMessage.Hide(InAgent)

    # Wiped Logic
    IsWiped<private>(InAgent:agent)<transacts><decides>:void =
        for:
            Teammate:TeamCollection._GetTeammates[InAgent]
            IsUp[Teammate] or BeingRespawned.Find[InAgent]
            IsRegistered[Teammate]
        do:
            Fail[]

    Wipe<private>(InAgent:agent, ?MaybeEliminatingCharacter:?fort_character = false):void =
        set BeingRebooted = BeingRebooted.SetRemove(InAgent)
        if(Eliminator := MaybeEliminatingCharacter?.GetAgent[]):
            WipeHUD.Show(Eliminator, Config.WipeMessage)
            WipeSFX.Play(Eliminator)
            AwardXP(Eliminator, rr_award.Wipe)
            for(Teammate:TeamCollection._GetTeammates[Eliminator]):
                if(IsUp[Teammate]):
                    WipeHUD.Show(Teammate, Config.WipeMessage)
                    WipeSFX.Play(Teammate)
                AwardXP(Teammate, rr_award.Wipe)
            if(WiperIndex := TeamCollection._GetTeamIndex[Eliminator]):
                _WipeEvent.Signal(option{WiperIndex})
        else:
            _WipeEvent.Signal(false)

    ShowHoldToReboot<private>(InAgent:agent)<suspends>:void =
        defer:
            HideHoldReboot(InAgent)
        if:
            TimesShown := HoldToRebootCountMap[InAgent] or 0
            TimesShown < Config.HoldToRebootArrowCount
            set HoldToRebootCountMap[InAgent] = TimesShown + 1
        then:
            HoldToRebootArrowHUD.Show(InAgent)
        if(FortCharacter := InAgent.GetFortCharacter[]):
            loop:
                # Await Elimination, Pressed, and Constantly Register/Show Hold To Reboot HUD
                race:
                    FortCharacter.EliminatedEvent().Await()
                    HoldToRebootInputTrigger.PressedEvent.AwaitPayloadEqual(InAgent)
                    LoopRegisterHoldRebootHUD(InAgent, FortCharacter)
                HideHoldReboot(InAgent)

                # After any of these events, confirm if the player is down and show the animated HUD.
                if:
                    FortCharacter.IsDownButNotOut[]
                    RespawnDuration := Config.RebootDurationCycles[CurrentRebootDurationIndex]
                    TimeToReboot := Int[RespawnDuration(0)]
                then:
                    HoldToRebootUIAnimation.Show(InAgent, rr_rebooter_messages.HoldToRebootMessage(TimeToReboot), ?DisplayTime:=0.0)
                else:
                    return

                # Confirm the player holds for the allocated time.
                IsHeld := HoldToRebootInputTrigger.IsHoldingFor(InAgent, 1.0)
                HideHoldReboot(InAgent)

                if(IsHeld? and FortCharacter.IsDownButNotOut[]):
                    RepeatAttemptEliminate(FortCharacter)
                    return

    LoopRegisterHoldRebootHUD<private>(InAgent : agent, FortCharacter : fort_character)<suspends>:void =
        loop:
            if:
                FortCharacter.IsDownButNotOut[]
                RespawnDuration := Config.RebootDurationCycles[CurrentRebootDurationIndex]
                TimeToReboot := Int[RespawnDuration(0)]
            then:
                HoldToRebootUI.Show(InAgent, rr_rebooter_messages.HoldToRebootMessage(TimeToReboot), ?DisplayTime:=0.0)
                HoldToRebootInputTrigger.Register(InAgent)
                AwaitServerTick()
            else:
                break

    HideHoldReboot<private>(InAgent : agent):void =
        HoldToRebootInputTrigger.Unregister(InAgent)
        HoldToRebootUI.Hide(InAgent)
        HoldToRebootUIAnimation.Hide(InAgent)
        HoldToRebootArrowHUD.Hide(InAgent)

    HideHoldReboot<private>():void =
        HoldToRebootInputTrigger.UnregisterAll()
        HoldToRebootUI.Hide()
        HoldToRebootUIAnimation.Hide()
        HoldToRebootArrowHUD.Hide()

    # Respawn Logic
    SkyRespawnRift<private>(InAgent : agent, InTeleporterDevice : teleporter_device)<suspends>:void =
        set BeingRespawned = BeingRespawned.SetAdd(InAgent)
        RebootTransform := if:
        # Spawn Above Teammate
            UpTeammates := TeamCollection._GetUpTeammates[InAgent]
            RandomUpTeamMate := UpTeammates[GetRandomInt(0, UpTeammates.Length - 1)]
            TeammateFortChar := RandomUpTeamMate.GetFortCharacter[]
        then:
            transform:
                Translation := TeammateFortChar.GetTransform().Translation.SetZ(Config.RiftHeight)
                Rotation := TeammateFortChar.GetTransform().Rotation
                Scale := v3(1)
        # Spawn Above Last Recorded Position
        else if(LastTransform := LastLocationMap[InAgent]):
            transform:
                Translation := LastTransform.Translation.SetZ(Config.RiftHeight)
                Rotation := LastTransform.Rotation
                Scale := v3(1)
        # Spawn Center to POI
        else:
            transform:
                Translation := DefaultRebootLocation.SetZ(Config.RiftHeight)
                Rotation := IdentityRotation()
                Scale := v3(1)
        sync:
            SpawnDeleteRebootRift(RebootTransform, InTeleporterDevice)
            RespawnAgent(InAgent, RebootTransform)
            SkyTeleport(InAgent, InTeleporterDevice)

    RespawnAgent<private>(InAgent:agent, RebootTransform:transform)<suspends>:void =
        InAgent.Respawn(RebootTransform.Translation, RebootTransform.Rotation)
        GiveInfiniteRespawn(InAgent)
        Sleep(0.2)
        InAgent.Respawn(RebootTransform.Translation, RebootTransform.Rotation)
        if(FortCharacter := InAgent.GetFortCharacter[]):
            FortCharacter.SetHealth(Config.RebootHealth)
            FortCharacter.SetShield(Config.RebootShield)
        set BeingRespawned = BeingRespawned.SetRemove(InAgent)
        Sleep(3.0)
        set BeingRebooted = BeingRebooted.SetRemove(InAgent)

    SkyTeleport<private>(InAgent:agent, InTeleporterDevice:teleporter_device)<suspends>:void =
        Sleep(0.2)
        AwaitServerTick()
        InTeleporterDevice.Teleport(InAgent)
        RiftSFX.Play(InAgent)
        AwardXP(InAgent, rr_award.Rebooted)
        RebootMessageFeed.Activate(InAgent)
        RebootItemGranter.GrantItem(InAgent)

    SpawnDeleteRebootRift<private>(InTransform:transform, InTeleporterDevice:teleporter_device)<suspends>:void =
        if { InTeleporterDevice.TeleportTo[InTransform] }
        SpawnResult := SpawnProp(RiftAsset, InTransform + v3(0,0,128))
        if(SpawnedProp := SpawnResult(0)?):
            Sleep(Config.RiftLifetime)
            SpawnedProp.Dispose()

    # Reboot Timer Logic
    RebootOnTimerSuccess<private>(InAgent:agent)<suspends>:void =
        TimerResult := AwaitRebootTimer(InAgent)
        if:
            TimerResult?
            IsEnabled[]
            not IsWiped[InAgent]
            NextTeleporter := RiftTeleporterDevices[Mod[RiftTeleporterIndex, 8]]
        then:
            set RiftTeleporterIndex += 1
            spawn{CancelOnAwaitableParam(SkyRespawnRift, (InAgent, NextTeleporter), DisabledEvent)}

    AwaitRebootTimer<private>(InAgent:agent)<suspends>:logic = 
        defer:
            RebootTimer.Stop(InAgent)
        if:
            RespawnDuration := Config.RebootDurationCycles[CurrentRebootDurationIndex]
            TimeToReboot := RespawnDuration(0)
        then:
            RebootTimer.SetMaxDuration(InAgent, TimeToReboot)
            RebootTimer.Start(InAgent)
            race:
                block:
                    AwaitTeamTimeSkips(InAgent)
                    false
                block:
                    RebootTimer.SuccessEvent().AwaitPayloadEqual(option{InAgent})
                    true
                if(TeamIndex := TeamCollection._GetTeamIndex[InAgent]):
                    _WipeEvent.AwaitPayloadEqual(option{TeamIndex})
                    false
                else:
                    Sleep(Inf)
                    true
        else:
            false

    AwaitTeamTimeSkips<private>(InAgent : agent)<suspends>:void =
        sync:
            AwaitTeamDowns(InAgent)
            AwaitTeamEliminations(InAgent)
            AwaitWipes(InAgent)

    AwaitTeamDowns<private>(InAgent : agent)<suspends>:void =
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseKnockEvent := GetTeamCauseDownEvent[TeamIndex]
        then:
            loop:
                KnockResult := TeamCauseKnockEvent.Await()
                if(InAgent.IsConnected[]):
                    if(IsRegistered[KnockResult.Target]):
                        TimeSkipHUD.Show(InAgent, rr_rebooter_messages.EnemyDownedMessage(Int[Config.DownTimeSkip] or 0))
                        RebootTimer.SetActiveDuration(InAgent, RebootTimer.GetActiveDuration(InAgent) - Config.DownTimeSkip)
                else:
                    return

    AwaitTeamEliminations<private>(InAgent : agent)<suspends>:void = 
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseEliminationEvent := GetTeamCauseEliminationEvent[TeamIndex]
        then:
            loop:
                EliminationResult := TeamCauseEliminationEvent.Await()
                if(InAgent.IsConnected[]):
                    if(IsRegistered[EliminationResult.Target]):
                        TimeSkipHUD.Show(InAgent, rr_rebooter_messages.EnemyEliminatedMessage(Int[Config.EliminationTimeSkip] or 0))
                        RebootTimer.SetActiveDuration(InAgent, RebootTimer.GetActiveDuration(InAgent) - Config.EliminationTimeSkip)
                else:
                    return

    AwaitWipes<private>(InAgent : agent)<suspends>:void = 
        if(TeamIndex := TeamCollection._GetTeamIndex[InAgent]):
            loop:
                WipeIndex := _WipeEvent.Await()
                if(InAgent.IsConnected[]):
                    if(WipeIndex = TeamIndex):
                        TimeSkipHUD.Show(InAgent, rr_rebooter_messages.WipedMessage(Int[Config.WipeTimeSkip] or 0))
                        RebootTimer.SetActiveDuration(InAgent, RebootTimer.GetActiveDuration(InAgent) - Config.WipeTimeSkip)
                else:
                    return

rr_rebooter_messages := module:

    HoldToRebootMessage<localizes><public>(Time:int):message = "{Time}s"
    EnemyDownedMessage<localizes><public>(TimeSkip:int):message = "-{TimeSkip}s ENEMY DOWNED"
    EnemyEliminatedMessage<localizes><public>(TimeSkip:int):message = "-{TimeSkip}s ENEMY ELIMINATED"
    WipedMessage<localizes><public>(TimeSkip:int):message = "-{TimeSkip}s TEAM WIPED"