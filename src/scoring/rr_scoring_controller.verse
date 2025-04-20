using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Verse.org/Colors }

using { FN_Gameplay }
using { config }

rr_scoring_controller<public> := class:
    TeamCollection<public>:fort_team_collection
    TeamIndexConfigMap<public>:[int]rr_team_config
    View<public>:rr_scoring_view
    Model<public>:rr_scoring_model = rr_scoring_model{}

    OnInitialized<public>(InAgent:agent):void =
        Model.Initialize(InAgent)

    OnExit<public>(InAgent:agent):void =
        Model.Remove(InAgent)

    OnRoundWin<public>(InAgent:agent):void =
        Model.AddRoundWin(InAgent)
        View.ShowRoundWin(InAgent)

    OnRoundLose<public>(InAgent:agent):void =
        Model.AddRoundLose(InAgent)
        View.ShowRoundLose(InAgent)

    OnGameEnd<public>():void =
        for(Leader:GetLeaders()):
            View.ShowGameWin(Leader)
        for(Loser:GetLosers()):
            View.ShowGameLose(Loser)
        RefreshView()

    GetLeaders()<transacts>:[]agent =
        GetSnapshots()[0].Agents or array{}

    GetLosers()<transacts>:[]agent =
        Difference(Model.GetScorers(), GetLeaders())

    GetSortedAgentScores<public>()<transacts>:[]tuple(agent, int) =
        AgentScorePairings := for:
            Scorer:Model.GetScorers()
            Score:=Model.GetScore(Scorer)
        do:
            (Scorer, Score)
        SortBy(AgentScorePairings, TupleSecondGreaterComp)

    GetSnapshots<private>()<transacts>:[]rr_score_snapshot = 
        Snapshots := for:
            Index->Config:TeamIndexConfigMap
            TeamMembers := TeamCollection._GetTeamMembers[Index]
        do:
            rr_score_snapshot:
                Agents := TeamMembers
                Wiped := logic{not TeamCollection._GetUpTeamMembers[Index]}
                Count := TeamCollection._GetUpTeamMembers[Index].Length or 0
                Color := Config.Color
                Score := GetMaxScore[TeamMembers] or 0
        SortBy(Snapshots, SnapshotComparator)

    GetMaxScore(InAgents:[]agent)<transacts><decides>:int =
        MaxInt[for(InAgent:InAgents){Model.GetScore(InAgent)}]

    RefreshView<public>():void =
        View.Refresh(Model.GetScorers(), GetSnapshots())
