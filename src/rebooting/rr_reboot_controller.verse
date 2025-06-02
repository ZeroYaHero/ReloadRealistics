using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Fortnite.com/Game }
using { /Verse.org/Random }

using { FN_Gameplay }

rr_eliminated_result := class(wipe_result):
    MaybeEliminatorAgent:?agent
    SelfEliminatedTransform:transform
    DuringUnlimited:logic

rr_reboot_controller<public> := class:

    TeamCollection<public>:fort_team_collection
    DBNODevice<public>:down_but_not_out_device
    TeleporterDevices<public>:[]teleporter_device
    RebootDurationUnlimitedTuples<public>:[]tuple(float, float, logic)
    RebootHealth<public>:float
    RebootShield<public>:float
    OptionalRebootBank<public>:?rr_reboot_bank
    DownPlayerTimeSkip<public>:float
    EliminatePlayerTimeSkip<public>:float
    WipeTeamTimeSkip<public>:float
    RiftAsset<public>:creative_prop_asset
    RiftLifetime<public>:float
    RiftHeight<public>:float
    RiftSFX<public>:audio_player_device
    RebootGranter<public>:item_granter_device
    RebootMessageFeed<public>:elimination_feed_device
    var BeingRebooted:[]agent = array{}
    var TeleporterDeviceIndex:int = 0
    var RespawnTimerDuration:float = Inf
    var Allowed:logic = false
    var Disabled:logic = true
    var Unlimited:logic = false
    var EliminatedCancelableMap:[agent]?cancelable = map{}
    var Registered:[]agent = array{}
    var DefaultRebootTransform:transform = transform{}
    var LastTransformMap:[agent]transform = map{}
    CancelRebootsEvent:event() = event(){}
    _WipeEvent:event(wipe_result) = event(wipe_result){}
    _RebootedEvent:event(agent) = event(agent){}

    Reboot<public>(InAgent:agent):void =
        spawn{_Reboot(InAgent, ?Force := true)}

    RebootedEvent<public>():event(agent) = 
        _RebootedEvent

    IsUnlimited<public>()<transacts><decides>:void =
        Unlimited?

    _Reboot(InAgent:agent, ?Force:logic = false)<suspends>:void =
        if(TeleporterDevice := TeleporterDevices[Mod[TeleporterDeviceIndex, TeleporterDevices.Length]]):
            set TeleporterDeviceIndex += 1
            RebootTransform := GetRebootTransform(InAgent)
            spawn{SpawnDeleteRift(RebootTransform)}
            if { TeleporterDevice.TeleportTo[RebootTransform] }
            InAgent.Respawn(RebootTransform.Translation, RebootTransform.Rotation)
            if(FortCharacter := InAgent.GetFortCharacter[]):
                FortCharacter.SetHealth(RebootHealth)
                FortCharacter.SetShield(RebootShield)
            AwaitServerTick()
            TeleporterDevice.Teleport(InAgent)
            RiftSFX.Play(InAgent)
            RebootMessageFeed.Activate(InAgent)
            if:
                not IsUnlimited[]
                not Force?
                RebootBank := OptionalRebootBank?
            then:
                RebootBank.OnReboot(InAgent)
                if(RebootBank.HasRebootsLeft[InAgent]):
                    GiveInfiniteSpawn(InAgent)
                else:
                    GiveOneSpawn(InAgent)
            set BeingRebooted = BeingRebooted.RemoveAllElements(InAgent)
            _RebootedEvent.Signal(InAgent)
        else:
            Print("Failed to get Reboot Teleporter")

    IsRebootable(InAgent:agent)<transacts><decides>:void =
        IsRegistered[InAgent]
        InAgent.IsConnected[]

    RebootsInProgress<public>()<transacts><decides>:void =
        var ValidRebootsInProgress:logic = false 
        loop:
            for:
                BeingRebootedAgent:BeingRebooted
                IsRebootable[BeingRebootedAgent]
            do:
                Print("Found a Valid Reboot In Progress")
                set ValidRebootsInProgress = true
                break
            break
        ValidRebootsInProgress?

    IsWiped<public>(InAgent:agent, WasEliminatedDuringUnlimited:logic)<transacts><decides>:void =
        NoTeammatesAlive[InAgent]
        not OptionalRebootBank?.HasRebootsLeft[InAgent]
        not (IsUnlimited[] or WasEliminatedDuringUnlimited?)

    NoTeammatesAlive<private>(InAgent:agent)<transacts><decides>:void =
        for:
            UpTeammate:TeamCollection._GetUpTeammates[InAgent]
            IsRegistered[UpTeammate]
        do:
            Fail[]

    GetRegistered<public>():[]agent = 
        Registered

    IsRegistered<public>(InAgent:agent)<transacts><decides>:void =
        Registered.Find[InAgent]

    Register<public>(InAgent:agent):void =
        if(IsRegistered[InAgent]):
            return
        set Registered += array{InAgent}
        LimitingTimerStartSFX.Register(InAgent)
        DisablingTimerStartSFX.Register(InAgent)
        if(Allowed?):
            Initialize(InAgent)

    Initialize(InAgent:agent):void =
        if:
            not EliminatedCancelableMap[InAgent]?
            FortCharacter := InAgent.GetFortCharacter[]
        then:
            if(RebootBank := OptionalRebootBank?):
                RebootBank.OnEnabledOrRegistered(InAgent)
            Cancelable := FortCharacter.EliminatedEvent().Subscribe(OnEliminated)
            if { set EliminatedCancelableMap[InAgent] = option{Cancelable} }
            else { Cancelable.Cancel() }

    Unregister<public>(InAgent:agent):void =
        set Registered = Registered.RemoveAllElements(InAgent)
        LimitingTimerStartSFX.Unregister(InAgent)
        DisablingTimerStartSFX.Unregister(InAgent)
        if(Cancelable := EliminatedCancelableMap[InAgent]?):
            Cancelable.Cancel()
            if { set EliminatedCancelableMap[InAgent] = false }

    UnregisterAll<public>():void =
        for(RegisteredAgent:Registered):
            Unregister(RegisteredAgent)

    Enable<public>():void =
        spawn{CancelOnAwaitable(EnableAndAllow, CancelRebootsEvent)}
        spawn{CancelOnAwaitable(AwaitDowns, CancelRebootsEvent)}

    EnableAndAllow()<suspends>:void =
        set Allowed = true
        set Disabled = false
        for(RegsiteredAgent:Registered):
            Initialize(RegsiteredAgent)
        for(Index -> RebootDurationUnlimited:RebootDurationUnlimitedTuples):
            set Unlimited = RebootDurationUnlimited(2)
            set RespawnTimerDuration = RebootDurationUnlimited(0)
            if(IsUnlimited[]):
                # If Reboot Bank, Show Infinite
                if(RebootBank := OptionalRebootBank?):
                    for(RegisteredAgent:Registered):
                        RebootBank.ShowInfiniteRebootBankHUD(RegisteredAgent)
                # If the Next is Limited, Hide Corner and Show Limiting Timer
                if:
                    Next := RebootDurationUnlimitedTuples[Index + 1]
                    not Next(2)?
                then:
                    HideCornerHUD()
                    LimitingTimer.SetMaxDuration(RebootDurationUnlimited(1))
                    for(RegisteredAgent:Registered):
                        LimitingTimer.Start(RegisteredAgent)
                    LimitingTimerStartSFX.Play()
                    AwaitTimer(RebootDurationUnlimited(1))
                    ShowLimitHUD()
                else:
                    ShowCornerHUD()
                    AwaitTimer(RebootDurationUnlimited(1))
            # If there is not another Reboot Tuple, Hide Corner and Show Disabling Timer
            else if(not RebootDurationUnlimitedTuples[Index + 1]):
                HideCornerHUD()
                DisablingTimer.SetMaxDuration(RebootDurationUnlimited(1))
                for(RegisteredAgent:Registered):
                    DisablingTimer.Start(RegisteredAgent)
                DisablingTimerStartSFX.Play()
                AwaitTimer(RebootDurationUnlimited(1))
                ShowDisableHUD()
            # Show Corner
            else:
                ShowCornerHUD()
                AwaitTimer(RebootDurationUnlimited(1))
            Print("Finished Awaiting Duration")
        Print("Finished Enabled States, Disallowing Reboots")
        Disallow()
        if(RebootBank := OptionalRebootBank?):
            RebootBank.OnDisallowed()

    Disallow<private>():void =
        set Allowed = false
        for:
            Agent->MaybeEliminatedCancelable:EliminatedCancelableMap
            EliminatedCancelable := MaybeEliminatedCancelable?
        do:
            EliminatedCancelable.Cancel()
        set EliminatedCancelableMap = map{}
        ShowCornerHUD()

    Disable<public>():void =
        Disallow()
        set Disabled = true
        CancelRebootsEvent.Signal()
        if(RebootBank := OptionalRebootBank?):
            RebootBank.OnDisabled()
        HideHUDAndUIAll()

    OnEliminated(ElimResult:elimination_result):void =
        if(EliminatedAgent := ElimResult.EliminatedCharacter.GetAgent[]):
            if { set LastTransformMap[EliminatedAgent] = ElimResult.EliminatedCharacter.GetTransform()}
            if(not BeingRebooted.Find[EliminatedAgent]):
                set BeingRebooted += array{EliminatedAgent}
            spawn{CancelOnAwaitableParam(RebootOnTimerSuccess, (EliminatedAgent, option{ElimResult.EliminatingCharacter?.GetAgent[]}), CancelRebootsEvent)}

    AwaitDowns()<suspends>:void = 
        loop:
            DownedAgent := DBNODevice.AgentDownedEvent.Await()
            spawn{ShowHoldToReboot(DownedAgent)}

    RebootOnTimerSuccess<private>(EliminatedAgent:agent, MaybeEliminatingAgent:?agent)<suspends>:void =
        defer:
            RebootTimer.Stop(EliminatedAgent)
        WasEliminatedDuringUnlimited := logic{IsUnlimited[]}
        PotentialWipeResult := wipe_result:
            WipedIndex := option{TeamCollection._GetTeamIndex[EliminatedAgent]}
            WiperIndex := option{TeamCollection._GetTeamIndex[MaybeEliminatingAgent?]}
        for(I := 0..1):
            if(IsWiped[EliminatedAgent, WasEliminatedDuringUnlimited]):
                _WipeEvent.Signal(PotentialWipeResult)
                WipedAgents := TeamCollection._GetTeamMembers[EliminatedAgent] or array{}
                WiperAgents := TeamCollection._GetTeamMembers[MaybeEliminatingAgent?] or array{}
                WipeHUDAndSFX(WipedAgents, WiperAgents)
                return
            else if(not EliminatedAgent.IsConnected[]):
                return
            else if:
                not Disabled?
                IsRebootable[EliminatedAgent]
            then:
                # First Iteration
                if(I = 0):
                    if(not Allowed?):
                        return
                    RebootTimer.Start(EliminatedAgent, RespawnTimerDuration)
                    race:
                        InfiniteAwaitTeamTimeSkips(EliminatedAgent) 
                        RebootTimer.SuccessEvent().AwaitPayloadEqual(option{EliminatedAgent})
                        loop:
                            WipePayload := _WipeEvent.Await()
                            if(WipePayload.WipedIndex? = PotentialWipeResult.WipedIndex?):
                                return
                # Second Iteration
                else:
                    _Reboot(EliminatedAgent)

    SpawnDeleteRift(InTransform:transform)<suspends>:void =
        SpawnResult := SpawnProp(RiftAsset, InTransform + v3(0,0,128))
        if(SpawnedProp := SpawnResult(0)?):
            race:
                CancelRebootsEvent.Await()
                AwaitTimer(RiftLifetime)
            SpawnedProp.Dispose()

    InfiniteAwaitTeamTimeSkips<private>(InAgent:agent)<suspends>:void =
        if:
            TeamIndex := TeamCollection._GetTeamIndex[InAgent]
            TeamCauseDownEvent := GetTeamCauseDownEvent[TeamIndex]
            TeamCauseEliminationEvent := GetTeamCauseEliminationEvent[TeamIndex]
        then:
            TimeSkipAndMessage := race:
                block:
                    TeamCauseDownEvent.Await()
                    DownPlayerTimeSkip, EnemyDownedMessage(Int[DownPlayerTimeSkip] or 0)
                block:
                    TeamCauseEliminationEvent.Await()
                    EliminatePlayerTimeSkip, EnemyEliminatedMessage(Int[EliminatePlayerTimeSkip] or 0)
                block:
                    loop:
                        WipePayload := _WipeEvent.Await()
                        if(WipePayload.WiperIndex = TeamIndex):
                            break
                    WipeTeamTimeSkip, WipedMessage(Int[WipeTeamTimeSkip] or 0)
            if(InAgent.IsConnected[]):
                RebootTimer.SetActiveDuration(InAgent, TimeSkipAndMessage(0))
                TimeSkipHUD.Show(InAgent, TimeSkipAndMessage(1))

    GetRebootTransform<public>(InAgent:agent):transform =
        (GetRandomTeammateTransform[InAgent] or LastTransformMap[InAgent] or DefaultRebootTransform).TransZ(RiftHeight)

    SetDefaultRebootLocation<public>(V3:vector3)<transacts>:void =
        set DefaultRebootTransform = transform:
            Translation := V3
            Rotation := IdentityRotation()
            Scale := v3(1)

    SetDefaultRebootTransform<public>(InTransform:transform)<transacts>:void =
        set DefaultRebootTransform = InTransform

    GetRandomTeammateTransform(InAgent:agent)<transacts><decides>:transform =
        var UpTeammatesLength:int = 0
        RandomTeammateTransforms := for:
            UpTeammate:TeamCollection._GetUpTeammates[InAgent]
            FortCharacter := UpTeammate.GetFortCharacter[]
        do:
            set UpTeammatesLength += 1
            FortCharacter.GetTransform()
        RandomTeammateTransforms[GetRandomInt(0, UpTeammatesLength - 1)]

    # HUD / UI
    HoldToRebootArrowCount<public>:int
    RebootTimer<public>:hud_message_timer
    LimitingTimer<public>:timer_device
    LimitingTimerStartSFX<public>:audio_player_device
    DisablingTimer<public>:timer_device
    DisablingTimerStartSFX<public>:audio_player_device
    DisableSFX<public>:audio_player_device
    LimitSFX<public>:audio_player_device
    LimitRebootsCenterHUD<public>:hud_message_device
    DisableRebootsCenterHUD<public>:hud_message_device
    UnlimitedRebootsCornerHUD<public>:hud_message_device
    EnableRebootsCornerHUD<public>:hud_message_device
    DisableRebootsCornerHUD<public>:hud_message_device
    HoldRebootArrow:hud_message_device = hud_message_device{}
    HoldRebootHUD:hud_message_device = hud_message_device{}
    HoldRebootAnim:hud_message_device = hud_message_device{}
    HoldRebootInput:input_trigger_device = input_trigger_device{}
    WiperHUD<public>:hud_message_device
    WipedHUD<public>:hud_message_device
    WipeMessage<localizes><public>:message
    WiperSFX<public>:audio_player_device
    WipedSFX<public>:audio_player_device
    TimeSkipHUD<public>:hud_message_device
    HideEvent<private>:event(agent) = event(agent){}
    var HoldToRebootCountMap:[agent]int = map{}

    WipeHUDAndSFX(WipedAgents:[]agent, WiperAgents:[]agent):void =
        for(WiperAgent:WiperAgents):
            WiperHUD.Show(WiperAgent, WipeMessage)
            WiperSFX.Play(WiperAgent)
        for(WipedAgent:WipedAgents):
            WipedHUD.Show(WipedAgent)
            WipedSFX.Play(WipedAgent)
            set BeingRebooted = BeingRebooted.RemoveAllElements(WipedAgent)
            Print("Removed Wiped Agent from Being Rebooted???")

    ShowDisableHUD():void =
        for(RegisteredAgent:Registered):
            DisableRebootsCenterHUD.Show(RegisteredAgent)
        DisableSFX.Play()

    ShowLimitHUD():void =
        for(RegisteredAgent:Registered):
            LimitRebootsCenterHUD.Show(RegisteredAgent)

    ShowCornerHUD():void =
        for(RegisteredAgent:Registered):
            ShowCornerHUD(RegisteredAgent)

    HideCornerHUD():void =
        for(RegisteredAgent:Registered):
            HideCornerHUD(RegisteredAgent)

    ShowCornerHUD(InAgent:agent):void =
        if(Allowed?):
            if(IsUnlimited[]):
                Print("Showing Unlimited Corner???")
                UnlimitedRebootsCornerHUD.Show(InAgent)
            else:
                EnableRebootsCornerHUD.Show(InAgent)
        else:
            DisableRebootsCornerHUD.Show(InAgent)

    HideCornerHUD(InAgent:agent):void =
        UnlimitedRebootsCornerHUD.Hide(InAgent)
        EnableRebootsCornerHUD.Hide(InAgent)
        DisableRebootsCornerHUD.Hide(InAgent)

    # HideHUDAndUI(InAgent:agent):void =
    #     UnlimitedRebootsCornerHUD.Hide(InAgent)
    #     EnableRebootsCornerHUD.Hide(InAgent)
    #     DisableRebootsCornerHUD.Hide(InAgent)
    #     LimitingTimer.Reset(InAgent)
    #     DisablingTimer.Reset(InAgent)
    #     HideHoldReboot(InAgent)

    HideHUDAndUIAll():void =
        # for(RegisteredAgent:Registered):
        #     HideHUDAndUI(RegisteredAgent)
        UnlimitedRebootsCornerHUD.Hide()
        EnableRebootsCornerHUD.Hide()
        DisableRebootsCornerHUD.Hide()
        LimitingTimer.Reset()
        DisablingTimer.Reset()
        HideHoldReboot()

    ShowHoldToReboot<private>(InAgent:agent)<suspends>:void =
        defer:
            HideHoldReboot(InAgent)
        if:
            TimesShown := HoldToRebootCountMap[InAgent] or 0
            TimesShown < HoldToRebootArrowCount
            set HoldToRebootCountMap[InAgent] = TimesShown + 1
        then:
            HoldRebootArrow.Show(InAgent)
        if(FortCharacter := InAgent.GetFortCharacter[]):
            loop:
                # Await Elimination, Pressed, and Constantly Register/Show Hold To Reboot HUD
                race:
                    FortCharacter.EliminatedEvent().Await()
                    HoldRebootInput.PressedEvent.AwaitPayloadEqual(InAgent)
                    LoopRegisterHoldRebootHUD(InAgent, FortCharacter)
                HideHoldReboot(InAgent)

                # After any of these events, confirm if the player is down and show the animated HUD.
                if:
                    FortCharacter.IsDownButNotOut[]
                    TimeToReboot := Int[RespawnTimerDuration]
                then:
                    HoldRebootAnim.Show(InAgent, HoldToRebootMessage(TimeToReboot), ?DisplayTime:=0.0)
                else:
                    return

                # Confirm the player holds for the allocated time.
                IsHeld := HoldRebootInput.IsHoldingFor(InAgent, 1.0)
                HideHoldReboot(InAgent)

                if(IsHeld? and FortCharacter.IsDownButNotOut[]):
                    RepeatAttemptEliminate(FortCharacter)
                    return

    LoopRegisterHoldRebootHUD<private>(InAgent:agent, FortCharacter:fort_character)<suspends>:void =
        loop:
            if:
                FortCharacter.IsDownButNotOut[]
                TimeToReboot := Int[RespawnTimerDuration]
            then:
                HoldRebootHUD.Show(InAgent, HoldToRebootMessage(TimeToReboot), ?DisplayTime:=0.0)
                HoldRebootInput.Register(InAgent)
                AwaitServerTick()
            else:
                break

    HideHoldReboot<private>(InAgent:agent):void =
        HoldRebootInput.Unregister(InAgent)
        HoldRebootHUD.Hide(InAgent)
        HoldRebootAnim.Hide(InAgent)
        HoldRebootArrow.Hide(InAgent)

    HideHoldReboot<private>():void =
        HoldRebootInput.UnregisterAll()
        HoldRebootHUD.Hide()
        HoldRebootAnim.Hide()
        HoldRebootArrow.Hide()