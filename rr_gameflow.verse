using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/FortPlayerUtilities }
using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Colors }
using { FN_Gameplay }

gameflow_verse_tag := class(tag){}
    not_enough_players_hud_tag := class(gameflow_verse_tag){}
    auto_vote_ui_tag := class(gameflow_verse_tag){}
    round_settings_tag := class(gameflow_verse_tag){}
    all_team_set_inv_tag := class(gameflow_verse_tag){}
    barrier_timer_tag := class(gameflow_verse_tag){}
    reboot_van_starting_timer_tag := class(gameflow_verse_tag){}
    prefire_mutator_tag := class(gameflow_verse_tag){}
    winning_stage_tag := class(gameflow_verse_tag){}
    end_game_device_tag := class(gameflow_verse_tag){}
    basic_storm_tag := class(gameflow_verse_tag){}
    supply_drops_tag := class(gameflow_verse_tag){}

rr_gameflow_controller := class:

    # GameflowDevices
    GameflowDevices : rr_gameflow_devices
    # Mangers / Controllers
    # StateController : rr_state_controller
    TeamPlayerManager : rr_team_and_player_manager
    RebootManager : rr_reboot_manager
    ItemSelectManager : rr_item_manager
    HUDManager : rr_hud_manager
    # Refrences
    Positions : rr_positions
    POIs : []rr_poi
    # Parameters
    AutoStartMinimum : int
    MaxPlayers : int
    SupplyDropTimesAndQuantities : []tuple(float, int)
    # (Initialized)
    var <private>CurrentPOIIndex<private> : int = 0

    Initialize():void =
        TeamPlayerManager.FortPlayspace.ParticipantAddedEvent().Subscribe(InitializeParticipant)
        if:
            NotEnoughPlayersState :=    GetState["NotEnoughPlayers"]
            TeamSelectState :=          GetState["TeamSelect"]
            CombatState :=              GetState["Combat"]
            RematchRequeueState :=      GetState["RematchRequeue"]
            OpponentsLeftState :=       GetState["OpponentsLeft"]
        then:
            NotEnoughPlayersState.InitializedEvent.ListenToEvent(OnNotEnoughPlayersInitialized)
            TeamSelectState.InitializedEvent.ListenToEvent(OnTeamSelectInitialized)
            TeamSelectState.AttemptingCompleteEvent.ListenToEvent(OnTeamSelectCompleting)
            TeamSelectState.CompletedEvent.ListenToEvent(OnTeamSelectCompleted)
            CombatState.AttemptingInitializingEvent.ListenToEvent(OnCombatAttemptInitializing)
            CombatState.InitializedEvent.ListenToEvent(OnCombatInitialized)
            CombatState.AttemptingCompleteEvent.ListenToEvent(OnCombatCompleting)
            RematchRequeueState.InitializedEvent.ListenToEvent(OnRematchRequeueInitialized)
            RematchRequeueState.CompletedEvent.ListenToEvent(EndRound)
            OpponentsLeftState.InitializedEvent.ListenToEvent(OnOpponentsLeftInitialized)
        else:
            PrintAndErr("Global Linear State Key Error, could not retrieve gameplay states.")

    # Game Start Player Initializing
    InitializeParticipants<private>(InAgents : []agent):void =
        for(InAgent : InAgents):
            InitializeParticipant(InAgent)
    
    # Verify activity, set up references, and/or prompt team selection.
    InitializeParticipant<private>(InAgent : agent):void =
        if(Player := player[InAgent]):
            spawn{AwaitActive(Player)}
        else: # Test Player
            _InitializeParticipant(InAgent)

    # Safeguard for inactive Player's
    AwaitActive<private>(Player : player)<suspends>:void =
        loop:
            if(Player.IsActive[]):
                _InitializeParticipant(Player)
                break
            else:
                Sleep(0.1)

    # Retrieve associated FortCharacter reference, SentToSpectate and select team
    _InitializeParticipant<private>(InAgent : agent):void =
        if:
            FortCharacter := InAgent.GetFortCharacter[]
        then:
            InAgent.AttachFortChar(FortCharacter)
            InitializeCauseCombatEvents(InAgent, FortCharacter)
        else:
            Print("Failed to Get FortCharacter and Player Activity")
            spawn{AwaitFortCharacter(InAgent)}

        if(CurrentStateKey := GetCurrentState[].Key):
            if(CurrentStateKey = "NotEnoughPlayers"):
                TeamPlayerManager.NeutralizeAgent(InAgent) # TODO?:Doesnt this always need to happen

            else if(CurrentStateKey = "TeamSelect"):
                array{InAgent}.TeleportTo(Positions.TeamSelect)
            else if (CurrentStateKey <> "RematchRequeue"):
                spawn{OnPlayerJoinAfterRound(InAgent)}
        else:
            TeamPlayerManager.NeutralizeAgent(InAgent)

    # Await for the Fort Character to be present for attaching.
    AwaitFortCharacter(InAgent : agent)<suspends>:void =
        FortCharacter := InAgent.SpawnAwaitFortChar(0.0).Await()
        InitializeCauseCombatEvents(InAgent, FortCharacter)

    # Player Joined after a round took place
    OnPlayerJoinAfterRound(InAgent : agent)<suspends>:void =
        loop:
            if:
                FortCharacter := InAgent.GetFortChar[] # todo?: is this really necessary
                FortCharacter.IsActive[]
            then:
                TeamPlayerManager.NeutralizeAgent(InAgent)
                TeamPlayerManager.ShowTeamSelectUI(InAgent)
                break
            Sleep(0.0)

    # Beginning of the game when there is not enough players to start the game.
    OnNotEnoughPlayersInitialized()<suspends>:void =
        InitializeParticipants(TeamPlayerManager.GetParticipants())
        var ParticipantsCount : int = TeamPlayerManager.GetParticipants().Length
        if(ParticipantsCount = 1):
            GameflowDevices.NotEnoughPlayersHUD.Show()
            TeamPlayerManager.FortPlayspace.ParticipantAddedEvent().Await()
            GameflowDevices.NotEnoughPlayersHUD.Hide()
        if(ParticipantsCount < AutoStartMinimum):
            race:
                # Auto Start Voting
                loop:
                    GameflowDevices.AutoStartVoteTimer.Start()
                    GameflowDevices.AutoStartVoteTimer.SuccessEvent.Await()
                    AutoStart := BoyerMooreAutoStartVote()
                    if(AutoStart?):
                        break
                    GameflowDevices.AutoStartVoteTimer.Reset()
                    GameflowDevices.AutoStartFailedHUD.Show()
                # Waiting for Auto Start Minimum or 1 Player
                loop:
                    race:
                        TeamPlayerManager.FortPlayspace.ParticipantAddedEvent().Await()
                        TeamPlayerManager.FortPlayspace.ParticipantRemovedEvent().Await()
                    set ParticipantsCount = TeamPlayerManager.GetParticipants().Length
                    if(ParticipantsCount >= AutoStartMinimum):
                        GameflowDevices.AutoStartVoteTimer.Start()
                        Sleep(10.0)
                        GameflowDevices.AutoStartVoteTimer.Reset()
                        break
                    else if(ParticipantsCount = 1):
                        spawn{OnNotEnoughPlayersInitialized()}
                        return
        else:
            GameflowDevices.AutoStartVoteTimer.Start()
            Sleep(10.0)
            GameflowDevices.AutoStartVoteTimer.Reset()
        GameflowDevices.AutoStartVoteTimer.Reset()
        # StateController.NotEnoughPlayersState.AttemptComplete()
        if(NotEnoughPlayersState := GetState["NotEnoughPlayers"]):
            NotEnoughPlayersState.AttemptComplete()
        else:
            EndRound()

    # Auto Start Voting Algorithm
    # TODO: Should go into HUD manager when Verse UI shows voting counts
    BoyerMooreAutoStartVote()<suspends>:logic =
        defer:
            GameflowDevices.AutoStartVoteUI.Hide()
        AgentVotedEvent : event(tuple(agent, int)) = event(tuple(agent, int)){}
        var AgentsParticipated : []agent = array{}
        var WinningVote : int = 0
        var Score : int = 0
        GameflowDevices.AutoStartVoteUI.Show()
        race:
            loop:
                AgentIndex := AgentVotedEvent.Await()
                if(not AgentsParticipated.Find[AgentIndex(0)]):
                    if(AgentIndex(1) = WinningVote):
                        set Score += 1
                    else:
                        if(Score <= 0):
                            set WinningVote = AgentIndex(1)
                            set Score = 1
                        else:
                            set Score -= 1
                    set AgentsParticipated += array{AgentIndex(0)}
                    ParticipatingLength := AgentsParticipated.Length
                    AllPlayersLength := TeamPlayerManager.GetParticipants().Length
                    if(Score >= Ceil(AllPlayersLength / 2)):
                        break
                    else if(ParticipatingLength = AllPlayersLength):
                        break
            loop:
                AgentIndex := GameflowDevices.AutoStartVoteUI.RespondingButtonEvent.Await()
                AgentVotedEvent.Signal(AgentIndex)
            loop:
                DismissedAgent := GameflowDevices.AutoStartVoteUI.DismissedEvent.Await()
                AgentVotedEvent.Signal(DismissedAgent, 1)
            loop:
                TimedOutAgent := GameflowDevices.AutoStartVoteUI.TimeOutEvent.Await()
                AgentVotedEvent.Signal(TimedOutAgent, 1)
        return WinningVote = 0 and true or false

    # TEAM SELECT ----------------------------------------------------- #
    # Succesfully Initialized
    OnTeamSelectInitialized():void =
        GameflowDevices.RoundSettings.DisableMatchmaking()
        TeamPlayerManager.NeutralizeAgents(TeamPlayerManager.GetParticipants())
        TeamPlayerManager.GetParticipants().TeleportToOrRespawnAt(Positions.TeamSelect)
        TeamPlayerManager.HideTeamSelectUI()
        if:
            TeamPlayerManager.GetParticipants().Length = 2
            CurrentState := GetCurrentState[]
        then:
            CurrentState.AttemptComplete()
        else:
            TeamPlayerManager.AwaitTeamSelections()

    # Attempt Completing
    OnTeamSelectCompleting()<suspends>:void =
        Print(ToDiagnostic(OnTeamSelectCompleting))
        for(TeamData : TeamPlayerManager.TeamsData.Teams):
            TeamData.SelectVolume.Disable()
            TeamData.DisplayTeamSelector.Disable()
        GameflowDevices.RebootVanStartingTimer.Start()
        Sleep(2.0)

    # Completed
    OnTeamSelectCompleted()<suspends>:void =
        Print(ToDiagnostic(OnTeamSelectCompleted))
        GameflowDevices.RoundSettings.EnableMatchmaking()
    # ----------------------------------------------------- #

    # COMBAT ----------------------------------------------------- #
    # Attempt Initializing
    OnCombatAttemptInitializing():void =
        TeamPlayerManager.AutoTeamSelect()
        if(TeamPlayerManager.GetTeamsWithMembersAndCapacities().Length <= 1):
            if(CombatState := GetState["Combat"]):
                CombatState.Disable()
            else:
                Print("Could not retrieve CombatState")
                EndRound()

    # Successfully Initialized
    OnCombatInitialized()<suspends>:void =
        HUDManager.Refresh(TeamPlayerManager.SortTeamsBySize(), TeamPlayerManager.GetTeamsWithMembersAndCapacities(), TeamPlayerManager.GetSortedTeamScores())
        if(CurrentPOI := POIs[CurrentPOIIndex]):
            # Player References
            TeamsAgents2D := Shuffle(InitializeParticipatingTeams())
            Participants := Concatenate of TeamsAgents2D

            # Prepare
            TeamPlayerManager.ResetRoundWinner()
            GameflowDevices.PrefireMutatorZone.Enable()
            CurrentPOI.Initialize(TeamsAgents2D, GameflowDevices.BasicStormController)
            Sleep(1.5)
            for(Participant : Participants):
                InitializeHealthAndLoadout(Participant)
            Sleep(2.0) # ? For some reason this Sleep make's sure the Dialog shows up
            ItemSelectManager.ShowSelectionUITo(Participants)
            RebootManager.EnableReboots(Participants)
            # Await Countdown
            AwaitBarrierTimer()
            # Start
            ItemSelectManager.HideUIFromAll()
            GameflowDevices.PrefireMutatorZone.Disable()
            CurrentPOI.DisableBarriers()
            # Await Round End
            branch:
                sync:
                    RebootManager.AwaitReboots()
                    PlaceSupplyDrops(CurrentPOI.GetCenter().Translation, 8500.0)
            CheckRoundWinCondition(Participants)
            # Clean Up
            RebootManager.DisableReboots(?RoundEnding := true)
            ItemSelectManager.ClearLoadouts(Participants)
            GameflowDevices.BasicStormController.DestroyStorm()
            if(RandomAgent := TeamPlayerManager.GetParticipants()[0]):
                ClearSupplyDrops(RandomAgent)

        if(CombatState := GetState["Combat"]):
            CombatState.AttemptComplete()
        else:
            EndRound()

    # Initialize Players organized by Teams who are participating
    InitializeParticipatingTeams():[][]agent = 
        TeamsAgents2D := for:
            TeamIndex -> TeamMembers : TeamPlayerManager.GetTeamsWithMembersAndCapacities()
        do:
            TeamPlayerManager.SetTeamVulnerability(TeamIndex, true)
            InitializeTeamCauseCombatEvents(TeamIndex)
            TeamMembers
        
    # Grant Agent Health, Shield, and Items
    InitializeHealthAndLoadout(InAgent : agent):void =
        GameflowDevices.DBNODevice.Revive(InAgent)
        if(FortCharacter := InAgent.GetFortChar[]):
            FortCharacter.SetHealth(100.0)
            FortCharacter.SetShield(100.0)
        if(ItemSelectManager.HasKeepSelection[InAgent]):
            ItemSelectManager.GrantLastSelected(InAgent)

    # Awaits the timer that dictates when the barriers are down
    AwaitBarrierTimer()<suspends>:void =
        if(CurrentPOIIndex = 0):
            GameflowDevices.CustomBarrierTimerHUD.Start(15)
        else:
            GameflowDevices.CustomBarrierTimerHUD.Start(10)
        GameflowDevices.CustomBarrierTimerHUD.SuccessEvent.Await()

    PlaceSupplyDrops(CenterV3 : vector3, Radius : float)<suspends>:void =
        defer:
            GameflowDevices.SupplyDropTimer.Reset()
        var SupplyDropIndex : int = 0
        for(TimeAndQuantity : SupplyDropTimesAndQuantities):
            GameflowDevices.SupplyDropTimer.SetMaxDuration(TimeAndQuantity(0))
            Sleep(0.25)
            GameflowDevices.SupplyDropTimer.Start()
            GameflowDevices.SupplyDropTimer.SetActiveDuration(TimeAndQuantity(0))
            GameflowDevices.SupplyDropTimer.SuccessEvent.Await()
            GameflowDevices.SupplyDropTimer.Complete()
            for:
                I := 0..TimeAndQuantity(1) - 1
                SupplyDrop := GameflowDevices.SupplyDrops[SupplyDropIndex]
                RandomYaw := GetRandomFloat(0.0, 360.0)
                RandomRotation := MakeRotationFromYawPitchRollDegrees(RandomYaw, 0.0, 0.0)
                RandomDistance := GetRandomFloat(0.0, Radius)
                SupplyDropV3 := RandomRotation.GetLocalForward() * RandomDistance + CenterV3
                SupplyDrop.TeleportTo[SupplyDropV3, IdentityRotation()]
            do:
                SupplyDrop.Spawn()
                set SupplyDropIndex += 1

    ClearSupplyDrops(RandomAgent : agent):void =
        for(SupplyDrop : GameflowDevices.SupplyDrops):
            SupplyDrop.Open(RandomAgent)

    # Every "Team Wipe" Event, Check how many teams are alive.
    CheckRoundWinCondition(Participants : []agent)<suspends>:void =
        loop:
            race:
                Sleep(1.0)
                RebootManager.TeamWipeEvent.Await()

            var TeamsCount : int = 0
            UpTeams := for:
                Team : TeamPlayerManager.GetUpTeams()
                TeamMembersParticipating := for:
                    TeamMember : TeamPlayerManager.GetTeamMembers[TeamPlayerManager.GetTeamIndex[Team]]
                    Participants.Find[TeamMember]
                do:
                    TeamMember
                TeamMembersParticipating.Length > 0
            do:
                set TeamsCount += 1
                Team

            if(TeamsCount <= 1):
                if(LastStandingTeamIndex := TeamPlayerManager.GetTeamIndex[UpTeams[0]]):
                    TeamPlayerManager.SetTeamVulnerability(LastStandingTeamIndex, false)
                    TeamPlayerManager.MakeRoundWinner(LastStandingTeamIndex)
                    for:
                        TeamIndex -> TeamMembers : TeamPlayerManager.GetTeamsWithMembersAndCapacities()
                        TeamMember : TeamMembers
                    do:
                        if(TeamIndex = LastStandingTeamIndex):
                            HUDManager.WinRoundHUD.Show(TeamMember)
                        else:
                            HUDManager.LoseRoundHUD.Show(TeamMember)
                    Sleep(0.0) # TODO?: What is this for
                break

    # Completing
    OnCombatCompleting():void =
        set CurrentPOIIndex += 1
        if(not POIs[CurrentPOIIndex]):
            if(CombatState := GetState["Combat"]):
                CombatState.Disable()
            else:
                EndRound()
    # ----------------------------------------------------- #

    OnRematchRequeueInitialized():void =
        TeamPlayerManager.GetParticipants().TeleportToOrRespawnAt(Positions.Lobby)
        HUDManager.Refresh(TeamPlayerManager.SortTeamsBySize(), TeamPlayerManager.GetTeamsWithMembersAndCapacities(), TeamPlayerManager.GetSortedTeamScores())
        WinnerAndRequeueStage()

    OnOpponentsLeftInitialized():void =
        TeamPlayerManager.GetParticipants().TeleportToOrRespawnAt(Positions.Lobby)
        GameflowDevices.RoundSettings.DisableMatchmaking()
        WinnerAndRequeueStage()

    WinnerAndRequeueStage():void = 
        SortedScores := TeamPlayerManager.GetSortedTeamScores()
        if:
            FirstPlaceIndexScore := SortedScores[0]
            WinningMembers := TeamPlayerManager.GetTeamMembers[FirstPlaceIndexScore(0)]
        then:
            for:
                Index -> WinningMember : WinningMembers
                PlayerReference := GameflowDevices.WinnerReferences[Index]
            do:
                PlayerReference.Register(WinningMember)
            WinnerRematchPropTransform := GameflowDevices.WinnerRematchProp.GetTransform()
            if { GameflowDevices.WinnerRematchProp.TeleportTo[WinnerRematchPropTransform + v3(0, 0, 960)]}

    EndRound():void =
        if(RandomPlayer := TeamPlayerManager.GetParticipants()[0]):
            GameflowDevices.RoundSettings.EndRound(RandomPlayer)
            GameflowDevices.EndGameDevice.Activate(RandomPlayer)

rr_gameflow_devices := struct:

    AllTeamSettings : team_settings_and_inventory_device
    NotEnoughPlayersHUD : hud_message_device
    RoundSettings : round_settings_device
    AutoStartVoteTimer : timer_device
    AutoStartVoteUI : popup_dialog_device
    AutoStartFailedHUD : hud_message_device
    CustomBarrierTimerHUD : custom_hud_timer
    RebootVanStartingTimer : timer_device
    PrefireMutatorZone : mutator_zone_device
    WinnerReferences : []player_reference_device
    WinnerRematchProp : creative_prop
    EndGameDevice : end_game_device
    BasicStormController : basic_storm_controller_device
    SupplyDropTimer : timer_device
    SupplyDrops : []supply_drop_spawner_device
    DBNODevice : down_but_not_out_device
