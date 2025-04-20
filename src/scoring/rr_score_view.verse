using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Verse.org/Colors }
using { /Fortnite.com/UI }

using { FN_Gameplay }
using { config }

rr_scoring_view<public>  := class:
    Config<public>:rr_score_config
    RoundWinnerReferenceDevices<public>:[]player_reference_device
    GameWinnerReferenceDevices<public>:[]player_reference_device
    RoundWinHUD<public>:hud_message_device
    RoundLoseHUD<public>:hud_message_device
    var AgentHUDMap:[agent]rr_scoring_hud = map{}  # Store HUD canvases per agent
    var RoundReferenceIndex:int = 0
    var GameReferenceIndex:int = 0

    ShowRoundWin(InAgent:agent):void =
        RoundWinHUD.Show(InAgent)
        AwardXP(InAgent, rr_award.WonRound)
        if(RoundWinnerReferenceDevice := RoundWinnerReferenceDevices[Mod[RoundReferenceIndex, RoundWinnerReferenceDevices.Length]]):
            set RoundReferenceIndex += 1
            RoundWinnerReferenceDevice.Enable()
            RoundWinnerReferenceDevice.Register(InAgent)

    ShowRoundLose(InAgent:agent):void =
        RoundLoseHUD.Show(InAgent)
        AwardXP(InAgent, rr_award.PlayedRound)

    ShowGameWin(InAgent:agent):void =
        AwardXP(InAgent, rr_award.WonGame)
        if(GameWinnerReferenceDevice := GameWinnerReferenceDevices[Mod[GameReferenceIndex, GameWinnerReferenceDevices.Length]]):
            set GameReferenceIndex += 1
            GameWinnerReferenceDevice.Enable()
            GameWinnerReferenceDevice.Register(InAgent)

    ShowGameLose(InAgent:agent):void =
        AwardXP(InAgent, rr_award.PlayedGame)

    Show():void =
        for(Agent -> HUD:AgentHUDMap):
            HUD.EncompassingWidget.Show()

    Show(InAgent:agent):void =
        if(HUD:=AgentHUDMap[InAgent]):
            HUD.EncompassingWidget.Show()

    Hide():void =
        for(Agent -> HUD:AgentHUDMap):
            HUD.EncompassingWidget.Hide()

    Hide(InAgent:agent):void =
        if(HUD:=AgentHUDMap[InAgent]):
            HUD.EncompassingWidget.Hide()

    Refresh(InAgents:[]agent, SortedSnapshots:[]rr_score_snapshot):void =
        set AgentHUDMap = Dict of for(InAgent:InAgents):
            (InAgent, Refresh(InAgent, ?SortedSnapshots := SortedSnapshots))

    Refresh(InAgent:agent, ?SortedSnapshots:[]rr_score_snapshot = array{}):rr_scoring_hud =
        if(ScoringHUD := AgentHUDMap[InAgent]):
            ScoringHUD.UpdateSlots(SortedSnapshots)
        else:
            BuildHUD(InAgent, ?SortedSnapshots:=SortedSnapshots)
    
    BuildHUD(InAgent:agent, ?SortedSnapshots:[]rr_score_snapshot = array{}):rr_scoring_hud =
        ScoreSlots := BuildScoreSlots(InAgent, Config, ?SortedSnapshots := SortedSnapshots)
        ScoringHUD := rr_scoring_hud:
            Agent := InAgent
            EncompassingWidget := canvas:
                Slots := array:
                    canvas_slot:
                        Alignment := Config.Alignment
                        Anchors := anchors{Minimum := Config.Anchor, Maximum := Config.Anchor}
                        Offsets := margin{Left := Config.Offset.X, Top := Config.Offset.Y}
                        Widget := stack_box:
                            Orientation := orientation.Horizontal
                            Slots := for(Index -> ScoreSlot:ScoreSlots):
                                stack_box_slot:
                                    Widget := ScoreSlot.EncompassingWidget
                                    Padding := margin{Right := Index < (Config.MaximumScoreSlots - 1) and Config.ScoreSlotHorizontalPadding or 0.0}
            ScoreSlots := ScoreSlots
            NumberImages := Config.NumberImages
            ShowOwnerAtMinimum := Config.ShowOwnerAtMinimum
            WipedColorMultiplier := Config.WipedColorMultiplier
            ShowPlayerCount := Config.ShowPlayerCount
        if(PlayerUI := GetPlayerUI[player[InAgent]]):
            PlayerUI.AddWidget(ScoringHUD.EncompassingWidget)
            Print("Adding Scoring Widget")
        ScoringHUD