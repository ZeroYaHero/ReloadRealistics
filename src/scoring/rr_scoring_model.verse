using { /Verse.org/Simulation }

using { FN_Gameplay }

rr_scoring_model<public> := class:
    var AgentScoreMap:[agent]int = map{}
    var PreviousRoundWinners:[]agent = array{}

    Initialize<public>(InAgent:agent)<transacts>:void =
        if { set AgentScoreMap[InAgent] = 0 }

    Remove<public>(InAgent:agent):void =
        set AgentScoreMap = Dict of for:
            Agent->Score:AgentScoreMap
            Agent <> InAgent
        do:
            (Agent, Score)

    AddRoundWin<public>(InAgent:agent):void =
        if { set AgentScoreMap[InAgent] = (AgentScoreMap[InAgent] or 0) + 1}
        set PreviousRoundWinners = PreviousRoundWinners.SetAdd(InAgent)

    AddRoundLose<public>(InAgent:agent):void =
        if { set AgentScoreMap[InAgent] = AgentScoreMap[InAgent] or 0 }
        set PreviousRoundWinners = PreviousRoundWinners.SetRemove(InAgent)

    GetScorers<public>()<transacts>:[]agent =
        AgentScoreMap.Keys()

    GetScore<public>(InAgent:agent)<transacts>:int =
        if(CurrentScore := AgentScoreMap[InAgent]):
            CurrentScore
        else:
            Initialize(InAgent)
            0