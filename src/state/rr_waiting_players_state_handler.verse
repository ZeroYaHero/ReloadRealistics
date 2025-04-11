using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }

rr_waiting_players_state_handler<public> := class(fn_gameplay_state_handler):
    ParticipantManager<public>:rr_participant_manager
    HubManager<public>:rr_hub_manager
    WaitingForPlayersTimer<public>:timer_device
    AutoStartMinimum<public>:int
    AutoStartVoteUI<public>:popup_dialog_device
    AutoStartVotingTimer<public>:timer_device
    RebootVanTimer<public>:timer_device
    HUDMessageDevice<public>:hud_message_device

    EnterWaitingForPlayers()<suspends>:void =
        defer:
            WaitingForPlayersTimer.Reset()
            AutoStartVoteUI.Hide()
        var InitializedParticipants : []agent = ParticipantManager.GetInitializedParticipants() 
        var InitializedParticipantsCount : int = InitializedParticipants.Length
        ParticipantManager.GetInitializedParticipants().TeleportToOrRespawnAt(HubManager.SpawnTeleporters)
        if(InitializedParticipantsCount < 2):
            HUDMessageDevice.Show(OnePlayerMessage)
            ParticipantManager.ParticipantInitializedEvent().Await()
            HUDMessageDevice.Hide()
        set InitializedParticipants = ParticipantManager.GetInitializedParticipants() 
        set InitializedParticipantsCount = InitializedParticipants.Length
        if(InitializedParticipantsCount < AutoStartMinimum):
            race:
                # Auto Start Voting
                loop:
                    WaitingForPlayersTimer.Start()
                    WaitingForPlayersTimer.SuccessEvent.Await()
                    AutoStart := BoyerMooreAutoStartVote()
                    if(AutoStart?): # change to local function start logic
                        break
                    HUDMessageDevice.Show(AutoStartFailedMessage, ?DisplayTime:=3.0)
                    WaitingForPlayersTimer.Reset()
                # Waiting for Auto Start Minimum or 1 Player
                loop:
                    race:
                        ParticipantManager.ParticipantInitializedEvent().Await()
                        ParticipantManager.ParticipantExitEvent().Await()
                    set InitializedParticipantsCount = ParticipantManager.GetInitializedParticipants().Length
                    if(InitializedParticipantsCount = 1):
                        spawn{EnterWaitingForPlayers()}
                        return
                    else if(InitializedParticipantsCount >= AutoStartMinimum):
                        break
        RebootVanTimer.Start()

    BoyerMooreAutoStartVote<private>()<suspends>:logic =
        defer:
            AutoStartVotingTimer.Reset()
            AutoStartVoteUI.Hide()
        AutoStartVotingTimer.Start()
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
                    AllPlayersLength := ParticipantManager.GetInitializedParticipants().Length
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

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.WaitingForPlayers => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterWaitingForPlayers}
                RebootVanTimer.GetAutoCompleteTimer(rr_state_enum.Transition, ?StartOnState:=false)

OnePlayerMessage<localizes><public>:message = "Waiting for another player to join..."
AutoStartFailedMessage<localizes><public>:message = "Not Enough Players Voted for Auto Start!"