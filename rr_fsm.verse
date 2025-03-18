using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

using { FN_Gameplay }

var <internal>CurrentRRState<internal>:weak_map(session, rr_state) = map{}

GetCurrentRRState<public>()<transacts><decides>:rr_state =
    CurrentRRState[GetSession()]

SetCurrentRRState<public>(RRState : rr_state)<transacts>:void =
    if:
        set CurrentRRState[GetSession()] = RRState
    else:
        PrintAndErr("Could not set current state")

rr_state_tags := class(tag){}

    team_select_auto_timer_tag := class(rr_state_tags){}
    rematch_requeue_auto_timer_tag := class(rr_state_tags){}
    opponents_left_auto_timer_tag := class(rr_state_tags){}
    
    reboot_van_starting_timer_tag := class(rr_state_tags){}
    team_select_starting_timer_tag := class(rr_state_tags){}
    players_voting_timer_tag := class(rr_state_tags){}

    one_player_hud_tag := class(rr_state_tags){}
    auto_vote_ui_tag := class(rr_state_tags){}
    round_settings_tag := class(rr_state_tags){}
    winning_stage_tag := class(rr_state_tags){}
    end_game_device_tag := class(rr_state_tags){}

    player_counter_device_tag := class(rr_state_tags){}

rr_state<public> := enum:

    NotEnoughPlayers
    TeamSelect
    Combat
    RequeueRematch
    OpponentsLeft
    GameEnd

rr_fsm := class:

    TeamSelectAutoCompleteTimer : timer_device
    RematchRequeueAutoCompleteTimer : timer_device
    OpponentsLeftRestartAutoCompleteTimer : timer_device

    RoundSettingsDevice : round_settings_device
    EndGameDevice : end_game_device
    WinnerReferences : []player_reference_device
    WinnerRematchProp : creative_prop
    CombatStartingTimer : timer_device
    OnePlayerHUD : hud_message_device
    AutoStartVoteTimer : timer_device
    AutoStartVoteUI : popup_dialog_device
    AutoStartFailedHUD : hud_message_device
    PlayersVotingTimer : timer_device
    TeamSelectStartingTimer : timer_device
    AutoStartMinimum : int
    PlayerCounterDevice : player_counter_device

    Positions : rr_positions
    TeamSelector : rr_team_selector
    CombatManager : rr_combat_manager
    ScoreHUDManager : rr_score_hud_manager
    StateChangeEvent : event() = event(){}

    Initialize(StartState : rr_state):void =
        SetCurrentRRState(StartState)
        GetMainDevicePlayspace().ParticipantAddedEvent().Subscribe(OnParticipantAdded)
        spawn{StateLoop()}

    StateLoop()<suspends>:void =
        loop:
            CurrentState := GetCurrentRRState[] or PrintAndErr("Failed to retrieve state")
            StateChangeEvent.Signal()
            case(CurrentState):
                rr_state.NotEnoughPlayers =>
                    OnNotEnoughPlayers()
                rr_state.TeamSelect =>
                    OnTeamSelect()
                rr_state.Combat =>
                    OnCombat()
                rr_state.RequeueRematch =>
                    OnRequeueRematch()
                rr_state.OpponentsLeft =>
                    OnOpponentsLeft()
                rr_state.GameEnd =>
                    OnGameEnd()
                    return

    OnNotEnoughPlayers()<suspends>:void =
        defer:
            AutoStartVoteTimer.Reset()
        FortPlayspace := GetMainDevicePlayspace()
        Participants := FortPlayspace.GetParticipants()
        Participants.TeleportToOrRespawnAt(Positions.Lobby)
        for(Participant : Participants):
            OnParticipantAdded(Participant) # !
        var ParticipantsCount : int = Participants.Length
        if(ParticipantsCount = 1):
            OnePlayerHUD.Show()
            FortPlayspace.ParticipantAddedEvent().Await()
            OnePlayerHUD.Hide()
        if(ParticipantsCount < AutoStartMinimum):
            race:
                # Auto Start Voting
                loop:
                    AutoStartVoteTimer.Start()
                    AutoStartVoteTimer.SuccessEvent.Await()
                    AutoStart := BoyerMooreAutoStartVote()
                    if(AutoStart?):
                        SetCurrentRRState(rr_state.TeamSelect)
                        return
                    AutoStartVoteTimer.Reset()
                    AutoStartFailedHUD.Show()
                # Waiting for Auto Start Minimum or 1 Player
                loop:
                    race:
                        FortPlayspace.ParticipantAddedEvent().Await()
                        FortPlayspace.ParticipantRemovedEvent().Await()
                    set ParticipantsCount = FortPlayspace.GetParticipants().Length
                    if(ParticipantsCount >= AutoStartMinimum):
                        break
                    else if(ParticipantsCount = 1):
                        spawn{OnNotEnoughPlayers()}
                        return
        TeamSelectStartingTimer.Start()
        TeamSelectStartingTimer.SuccessEvent.Await()
        SetCurrentRRState(rr_state.TeamSelect)

    BoyerMooreAutoStartVote()<suspends>:logic =
        defer:
            PlayersVotingTimer.Reset()
            AutoStartVoteUI.Hide()
        PlayersVotingTimer.Start()
        FortPlayspace := GetMainDevicePlayspace()
        AgentVotedEvent : event(tuple(agent, int)) = event(tuple(agent, int)){}
        var AgentsParticipated : []agent = array{}
        var WinningVote : int = 0
        var Score : int = 0
        AutoStartVoteUI.Show()
        race:
            loop:
                AgentIndex := AgentVotedEvent.Await()
                if(not AgentsParticipated.Find[AgentIndex(0)]):
                    Print("Agent Voted")
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
                    AllPlayersLength := FortPlayspace.GetParticipants().Length
                    if(Score >= Ceil(AllPlayersLength / 2)):
                        Print("Majority Voted")
                        break
                    else if(ParticipatingLength = AllPlayersLength):
                        break
            loop:
                AgentIndex := AutoStartVoteUI.RespondingButtonEvent.Await()
                AgentVotedEvent.Signal(AgentIndex)
            loop:
                DismissedAgent := AutoStartVoteUI.DismissedEvent.Await()
                AgentVotedEvent.Signal(DismissedAgent, 1)
            loop:
                TimedOutAgent := AutoStartVoteUI.TimeOutEvent.Await()
                AgentVotedEvent.Signal(TimedOutAgent, 1)
        return WinningVote = 0 and true or false

    OnTeamSelect()<suspends>:void =
        Print("Team Select State Starting")
        FortPlayspace := GetMainDevicePlayspace()
        Participants := FortPlayspace.GetParticipants()
        for(Participant : Participants):
            TeamSelector.Neutralize(Participant)
        if(Participants.Length = 2):
            SetCurrentRRState(rr_state.Combat)
        else:
            Participants.TeleportToOrRespawnAt(Positions.TeamSelect)
            RoundSettingsDevice.DisableMatchmaking()
            TeamSelector.HideUI()
            TeamSelector.ListenToSelections()
            TeamSelectAutoCompleteTimer.Start()
            TeamSelectAutoCompleteTimer.SuccessEvent.Await()

        CombatStartingTimer.Start()
        AwaitTimer(2.0)
        for(SelectableTeam : TeamSelector.SelectableTeams):
            SelectableTeam.Hide()
        RoundSettingsDevice.EnableMatchmaking()
        SetCurrentRRState(rr_state.Combat)

    OnCombat()<suspends>:void =
        TeamSelector.AutoSelect()
        SortedTeamSizes := TeamSelector.SortSelectableTeamsBySize(true)
        SortedTeamScores := CombatManager.GetSortedTeamScores(SortedTeamSizes)
        ScoreHUDManager.Refresh(Dict of SortedTeamSizes, SortedTeamScores)
        if(NextPOI := CombatManager.GetNextPOI[]):
            CombatManager.InitializeRound(TeamSelector.GetSelectableTeamIndexMembersMap(), NextPOI)
            CombatManager.StartRound(NextPOI)
            CombatManager.EndRound()
        else:
            SetCurrentRRState(rr_state.RequeueRematch)

    OnRequeueRematch()<suspends>:void =
        FortPlayspace := GetMainDevicePlayspace()
        Participants := FortPlayspace.GetParticipants()
        SortedScores := CombatManager.GetSortedTeamScores(TeamSelector.SortSelectableTeamsBySize(true)) # ! Yuck
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        for:
            Position -> TeamIndexScore : SortedScores
            TeamMemberIndex -> TeamMember : TeamCollection._GetTeamMembers(TeamIndexScore(0))
        do:
            if:
                Position = 0
                PlayerReference := WinnerReferences[TeamMemberIndex]
            then:
                PlayerReference.Register(TeamMember)    
                AwardXP(TeamMember, rr_award.WonGame)
            else:
                AwardXP(TeamMember, rr_award.PlayedGame)

        WinnerRematchPropTransform := WinnerRematchProp.GetTransform()
        if { WinnerRematchProp.TeleportTo[WinnerRematchPropTransform + v3(0, 0, 960)]}

        Participants.TeleportToOrRespawnAt(Positions.Lobby)

        RematchRequeueAutoCompleteTimer.Start()
        RematchRequeueAutoCompleteTimer.SuccessEvent.Await()
        SetCurrentRRState(rr_state.GameEnd)

    OnOpponentsLeft()<suspends>:void =
        FortPlayspace := GetMainDevicePlayspace()
        Participants := FortPlayspace.GetParticipants()
        Participants.TeleportToOrRespawnAt(Positions.Lobby)
        for(Participant : Participants):
            AwardXP(Participant, rr_award.PlayedGame)

        OpponentsLeftRestartAutoCompleteTimer.Start()
        OpponentsLeftRestartAutoCompleteTimer.SuccessEvent.Await()
        SetCurrentRRState(rr_state.GameEnd)

    OnGameEnd():void =
        if(RandomPlayer := GetMainDevicePlayspace().GetRandomParticipant[]):
            EndGameDevice.Activate(RandomPlayer)

    # Initialize Participant
    OnParticipantAdded<private>(InAgent : agent):void =
        if(Player := player[InAgent]):
            spawn{AwaitActive(Player)}
        else: # Test Player
            OnPlayerFirstActive(InAgent)

    # Safeguard for inactive Player's
    AwaitActive<private>(Player : player)<suspends>:void =
        loop:
            if(Player.IsActive[]):
                OnPlayerFirstActive(Player)
                break
            else:
                Sleep(0.1)

    # Retrieve associated FortCharacter reference, SentToSpectate and select team
    OnPlayerFirstActive<private>(InAgent : agent):void =
        if:
            FortCharacter := InAgent.GetFortCharacter[]
        then:
            # InAgent.AttachFortChar(FortCharacter)
            InitializeCauseCombatEvents(InAgent, FortCharacter)
            spawn{AwaitAndAwardCombatEvents(InAgent)}
        else:
            Print("Failed to Get FortCharacter and Player Activity")
            spawn{AwaitFortCharacter(InAgent)}

        TeamSelector.Neutralize(InAgent)
        if(CurrentState := GetCurrentRRState[]):
            case(CurrentState):
                rr_state.TeamSelect =>
                    array{InAgent}.TeleportTo(Positions.TeamSelect)
                rr_state.Combat =>
                    spawn{OnPlayerJoinDuringCombat(InAgent)}
                _ =>

    # Await for the Fort Character to be present for attaching.
    AwaitFortCharacter(InAgent : agent)<suspends>:void =
        Print("Awaiting FortCharacter")
        # FortCharacter := InAgent.SpawnAwaitFortChar(0.0).Await()
        FortCharacter := InAgent.GetFortCharacterSuspends()
        InitializeCauseCombatEvents(InAgent, FortCharacter)
        spawn{AwaitAndAwardCombatEvents(InAgent)}

    AwaitAndAwardCombatEvents<private>(InAgent : agent)<suspends>:void =
        race:
            GetMainDevicePlayspace().ParticipantRemovedEvent().AwaitPayloadEqual(InAgent)
            loop:
                CauseKnockEvent := GetCauseKnockEvent[InAgent] or event(combat_event_result){}
                CauseKnockEvent.Await()
                Print("Caused Knock Granting XP")
                AwardXP(InAgent, rr_award.Knock)
            loop:
                CauseEliminationEvent := GetCauseEliminationEvent[InAgent] or event(combat_event_result){}
                CauseEliminationEvent.Await()
                Print("Caused Elimination Granting XP")
                AwardXP(InAgent, rr_award.Elimination)

    # Player Joined after a round took place
    OnPlayerJoinDuringCombat(InAgent : agent)<suspends>:void =
        race:
            StateChangeEvent.Await()
            block:
                TeamSelector.ShowUI(InAgent)
                TeamSelector.AwaitUISelection(InAgent)
                loop:
                    if:
                        FortCharacter := InAgent.GetFortCharacter[] # todo?: is this really necessary
                        FortCharacter.IsActive[]
                    then:
                        RepeatAttemptElimination(FortCharacter, ?MaybeInstigatorCauser := option{GetMainDevicePlayspace().GetRandomOtherParticipant[InAgent]})
                        break
                    Sleep(0.0)