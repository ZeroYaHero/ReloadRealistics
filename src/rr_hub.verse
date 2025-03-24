using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { FN_Gameplay }

rr_hub_manager := class(rr_state_handler_interface):

    # Dependencies
    ParticipantManager : fn_gameplay_participant_manager
    # Waiting for Players / Auto Start
    OnePlayerHUD : hud_message_device
    WaitingForPlayersTimer : timer_device
    AutoStartMinimum : int
    AutoStartVotingTimer : timer_device
    AutoStartVoteUI : popup_dialog_device
    AutoStartFailedHUD : hud_message_device
    RebootVanTimer : timer_device
    HUBMutator : mutator_zone_device
    # Rematch / Requeue
    WinnerRematchProp : creative_prop
    # Teleporters
    SpawnTeleporters : []teleporter_device

    EnterWaitingForPlayers<override>()<suspends>:void =
        defer:
            WaitingForPlayersTimer.Reset()
        var InitializedParticipants : []agent = ParticipantManager.GetInitializedParticipants() 
        var InitializedParticipantsCount : int = InitializedParticipants.Length
        ParticipantManager.GetInitializedParticipants().TeleportToOrRespawnAt(SpawnTeleporters)
        if(InitializedParticipantsCount < 2):
            OnePlayerHUD.Show()
            ParticipantManager.ParticipantInitializedEvent.Await()
            OnePlayerHUD.Hide()
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
                    WaitingForPlayersTimer.Reset()
                    AutoStartFailedHUD.Show()
                # Waiting for Auto Start Minimum or 1 Player
                loop:
                    race:
                        ParticipantManager.ParticipantInitializedEvent.Await()
                        ParticipantManager.ParticipantExitEvent.Await()
                    set InitializedParticipantsCount = ParticipantManager.GetInitializedParticipants().Length
                    if(InitializedParticipantsCount = 1):
                        spawn{EnterWaitingForPlayers()}
                        return
                    else if(InitializedParticipantsCount >= AutoStartMinimum):
                        break
        RebootVanTimer.Start()
    
    EnterTeamSelect<override>()<suspends>:void =
        HUBMutator.Jiggle()

    BoyerMooreAutoStartVote<private>()<suspends>:logic =
        defer:
            AutoStartVotingTimer.Reset()
            AutoStartVoteUI.Hide()
        AutoStartVotingTimer.Start()
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

    EnterRematchRequeue<override>()<suspends>:void =
        ParticipantManager.GetParticipants().TeleportToOrRespawnAt(SpawnTeleporters)
        WinnerRematchPropTransform := WinnerRematchProp.GetTransform()
        if { WinnerRematchProp.TeleportTo[WinnerRematchPropTransform + v3(0, 0, 960)]}

    EnterOpponentsLeft<override>()<suspends>:void =
        ParticipantManager.GetParticipants().TeleportToOrRespawnAt(SpawnTeleporters)
        for(Participant : ParticipantManager.GetParticipants()):
            AwardXP(Participant, rr_award.PlayedGame)

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.WaitingForPlayers => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterWaitingForPlayers}
            rr_state_enum.TeamSelect => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterTeamSelect}
            rr_state_enum.RematchRequeue => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterRematchRequeue}
            rr_state_enum.OpponentsLeft => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterOpponentsLeft}