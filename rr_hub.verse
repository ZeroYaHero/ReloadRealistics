using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { FN_Gameplay }

rr_hub_tags := class(tag){}
    overall_hub_mutator_tag := class(rr_hub_tags){}

rr_hub_manager := class(rr_state_handler_interface):

    # Dependencies
    ParticipantManager : fn_gameplay_participant_manager
    # Waiting for Players / Auto Start
    OnePlayerHUD : hud_message_device
    WaitingForPlayersTimer : timer_device
    AutoStartMinimum : int
    AutoStartVotingTimer : timer_device
    PlayersVotingTimer : timer_device
    AutoStartVoteUI : popup_dialog_device
    AutoStartFailedHUD : hud_message_device
    # Rematch / Requeue
    WinnerRematchProp : creative_prop
    # Teleporters
    SpawnTeleporters : []teleporter_device

    OnWaitingForPlayers<override>()<suspends>:void =
        var InitializedParticipants : []agent = ParticipantManager.GetInitializedParticipants() 
        var InitializedParticipantsCount : int = InitializedParticipants.Length
        ParticipantManager.GetParticipants().TeleportToOrRespawnAt(SpawnTeleporters)
        loop:
            if(InitializedParticipants = 1):
                OnePlayerHUD.Show()
                ParticipantManager.ParticipantInitializedEvent.Await()
                OnePlayerHUD.Hide()
            set InitializedParticipants = ParticipantManager.GetInitializedParticipants() 
            set InitializedParticipantsCount = InitializedParticipants.Length
            InitializedParticipants.TeleportToOrRespawnAt(SpawnTeleporters)
            if(InitializedParticipantsCount < AutoStartMinimum):
                race:
                    # Auto Start Voting
                    loop:
                        WaitingForPlayersTimer.Start()
                        WaitingForPlayersTimer.SuccessEvent.Await()
                        AutoStart := BoyerMooreAutoStartVote()
                        if(AutoStart?): # change to local function start logic
                            return
                        WaitingForPlayersTimer.Reset()
                        AutoStartFailedHUD.Show()
                    # Waiting for Auto Start Minimum or 1 Player
                    loop:
                        race:
                            ParticipantManager.ParticipantInitializedEvent.Await()
                            ParticipantManager.ParticipantExitEvent.Await()
                        set InitializedParticipantsCount = ParticipantManager.GetInitializedParticipants().Length
                        if(InitializedParticipantsCount >= AutoStartMinimum or InitializedParticipantsCount = 1):
                            break
            if(InitializedParticipantsCount >= AutoStartMinimum):
                break
            else if(InitializedParticipantsCount = 1):
                # continue

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

    OnRematchRequeue<override>()<suspends>:void =
        ParticipantManager.GetParticipants().TeleportToOrRespawnAt(SpawnTeleporters)
        WinnerRematchPropTransform := WinnerRematchProp.GetTransform()
        if { WinnerRematchProp.TeleportTo[WinnerRematchPropTransform + v3(0, 0, 960)]}

    OnOpponentsLeft<override>()<suspends>:void =
        ParticipantManager.GetParticipants().TeleportToOrRespawnAt(SpawnTeleporters)
        for(Participant : ParticipantManager.GetParticipants()):
            AwardXP(Participant, rr_award.PlayedGame)

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listener =
        map:
            rr_state_enum.WaitingForPlayers => array{CreateStateListener(OnWaitingForPlayers, ?SetStateOnExecution := option{rr_state_enum.TeamSelect})}
            rr_state_enum.RematchRequeue => array{CreateStateListener(OnRematchRequeue)}
            rr_state_enum.OpponentsLeft => array{CreateStateListener(OnOpponentsLeft)}