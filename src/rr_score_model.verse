using { /UnrealEngine.com/Temporary }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }

rr_score_model := class(rr_state_handler_interface):

    ScoreManagerDevice : score_manager_device
    RoundWinPlayerReferences : []player_reference_device
    BestPerformingPlayerReferences : []player_reference_device
    WinRoundHUD : hud_message_device
    LoseRoundHUD : hud_message_device
    var AgentScoreMap : [agent]int = map{}

    # TODO: Need to clear the round win registers

    RoundWin<public>(InAgents : []agent):void =
        for(Index -> InAgent : InAgents):
            RoundWin(InAgent)
            if(PlayerReference := RoundWinPlayerReferences[Index]):
                PlayerReference.Register(InAgent)

    RoundWin<public>(InAgent : agent):void =
        if:
            set AgentScoreMap[InAgent] = (AgentScoreMap[InAgent] or 0) + 1
        then:
            ScoreManagerDevice.Activate(InAgent)
            AwardXP(InAgent, rr_award.WonRound)
            WinRoundHUD.Show(InAgent)

    RoundLose<public>(InAgents : []agent):void =
        for(InAgent : InAgents):
            RoundLose(InAgent)

    RoundLose<public>(InAgent : agent):void =
        AwardXP(InAgent, rr_award.PlayedRound)
        LoseRoundHUD.Show(InAgent) 

    GetScore<public>(InAgent : agent)<transacts>:int =
        if(Score := AgentScoreMap[InAgent]):
            Score
        else:
            ResetScore(InAgent)
            0

    ResetScore<public>(InAgent : agent)<transacts>:void =
        if:
            set AgentScoreMap[InAgent] = 0

    GetMaxScoreOf<public>(InAgents : []agent)<transacts>:int =
        MaxInt[InAgents.Map(GetScore)] or 0

    GetAgentsSortedByScore<public>()<transacts>:[]agent =
        for(AgentScore : SortBy(AgentScoreMap.Items(), TupleSecondGreaterComp)):
            AgentScore(0)

    EnterRematchRequeue<override>()<suspends>:void =
        ShowBestPerforming()

    EnterOpponentsLeft<override>()<suspends>:void =
        ShowBestPerforming()

    ShowBestPerforming():void = 
        for:
            Index -> Agent : GetAgentsSortedByScore()
        do:
            if(PlayerReference := BestPerformingPlayerReferences[Index]):
                PlayerReference.Register(Agent)
                AwardXP(Agent, rr_award.WonGame)
            else:
                AwardXP(Agent, rr_award.PlayedGame)

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.RematchRequeue => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterRematchRequeue}
            rr_state_enum.OpponentsLeft => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterOpponentsLeft}