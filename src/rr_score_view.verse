using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Verse.org/Assets }
using { /Verse.org/Colors }
using { /Fortnite.com/UI }

using { FN_Gameplay }

rr_score_hud_parameters<public> := class<concrete>:

    @editable   HorizontalPadding<public> : float = 10.0
    @editable   CrownTeamBlockPadding<public> : float = 5.0
    @editable   TextureBlockXYSize<public> : float = 75.0
    @editable   TextShadowOpacity<public> : float = 0.3
    @editable   TextColor<public> : color = color:
        R := 1.0
        G := 1.0
        B := 1.0
    @editable   TextShadowColor<public> : color = color:
        R := 0.0
        G := 0.0
        B := 0.0
    @editable   TextShadowOffset<public> : vector2 = vector2:
        X := 2.0
        Y := 1.5
    @editable   Anchor<public> : vector2 = vector2:
        X := 1.0
        Y := 0.0
    @editable   Alignment<public> : vector2 = vector2:
        X := 1.0
        Y := 0.0
    @editable   PositionOffset<public> : vector2 = vector2:
        X := 35.0
        Y := 60.0

    @editable   TeamBlockTexture<public> : texture = RR_UI.TeamScoring.T_TeamBlock
    @editable   TeamBlockYouTexture<public> : texture = RR_UI.TeamScoring.T_TeamBlockYou
    @editable   YouUnderTexture<public> : texture = RR_UI.TeamScoring.T_YouUnder
    @editable   CrownTexture<public> : texture = RR_UI.TeamScoring.T_Crown

rr_score_view := class(rr_state_handler_interface):

    Parameters : rr_score_hud_parameters
    ScoreModel : rr_score_model
    TeamSelector : rr_team_selector
    TeamIndexColorMap : [int]color
    var AgentHUDMap : [agent]rr_score_hud = map{}

    EnterCombatRound<override>()<suspends>:void =
        Refresh()

    ExitCombatRound<override>()<suspends>:void =
        Refresh()

    EnterTeamSelect<override>()<suspends>:void =
        loop:
            TeamSelector.TeamSelectedEvent.Await()
            Refresh()

    Refresh():void =
        SortedTeamScorePairings := GetSortedTeamScorePairings()
        TeamIndexTeamMembersMap := TeamSelector.GetSelectableTeamMembersMap()

        var SeenAgents : []agent = array{}
        NewAgentHUDMap := Dict of for:
            TeamIndex -> TeamMembers : TeamSelector.GetSelectableTeamMembersMap()
            TeamMember : TeamMembers
        do:
            set SeenAgents += array{TeamMember}
            if(HUD := AgentHUDMap[TeamMember]):
                (TeamMember, HUD.Refresh(TeamIndex, SortedTeamScorePairings))
            else:
                (TeamMember, BuildHUD(TeamMember <# Current agent #>, TeamIndex <# Team index belonging #>, TeamIndexTeamMembersMap, SortedTeamScorePairings <# Teams currently active #>))

        for:
            Agent -> HUD : AgentHUDMap
            not SeenAgents.Find[Agent]
            PlayerUI := GetPlayerUI[player[Agent]]
        do:
            PlayerUI.RemoveWidget(HUD.OverallCanvas)

        set AgentHUDMap = NewAgentHUDMap

    GetSortedTeamScorePairings():[]tuple(int, int) =
        ScorePairings := for(TeamIndex -> TeamMembers : TeamSelector.GetSelectableTeamMembersMap()):
            (TeamIndex, ScoreModel.GetMaxScoreOf(TeamMembers))
        SortBy(ScorePairings, TupleSecondGreaterComp)

    BuildHUD(InAgent : agent, InTeamIndex : int, TeamIndexTeamMembersMap : [int][]agent, TeamScorePairings : []tuple(int, int)):rr_score_hud =
        TeamIndexScoreMap := Dict of TeamScorePairings

        TextureBlockSize := vector2:
            X := Parameters.TextureBlockXYSize
            Y := Parameters.TextureBlockXYSize

        var TeamBlocksCount : int = 0
        HorizontalTeamStackBox := stack_box:
            Orientation := orientation.Horizontal
            Slots := for:
                TeamIndex -> TeamColor : TeamIndexColorMap
                TeamTint := TeamIndexColorMap[TeamIndex]
            do:
                set TeamBlocksCount += 1
                
                CrownTextureBlock := texture_block:
                    DefaultImage := Parameters.CrownTexture
                    DefaultTint := TeamTint
                    DefaultDesiredSize := TextureBlockSize
                if(not TeamBlocksCount = 1):
                    CrownTextureBlock.SetVisibility(widget_visibility.Hidden)

                YouUnderTextureBlock := texture_block:
                    DefaultImage := Parameters.YouUnderTexture
                    DefaultTint := TeamTint
                    DefaultDesiredSize := TextureBlockSize

                YouUnderTextureBlock.SetVisibility(TeamIndex = InTeamIndex and widget_visibility.Visible or widget_visibility.Hidden)
                TeamScoreStackBox := stack_box:
                    Orientation := orientation.Vertical
                    Slots := array:
                        stack_box_slot:
                            Widget := CrownTextureBlock
                            Padding := margin:
                                Bottom := Parameters.CrownTeamBlockPadding
                        stack_box_slot:
                            Widget := overlay:
                                Slots := array:
                                    overlay_slot:
                                        Widget := texture_block:
                                            DefaultImage := TeamIndex = InTeamIndex and Parameters.TeamBlockYouTexture or Parameters.TeamBlockTexture
                                            DefaultTint := TeamTint
                                            DefaultDesiredSize := TextureBlockSize
                                    overlay_slot:
                                        Widget := text_block:
                                            DefaultText := ToMessage(TeamIndexScoreMap[TeamIndex] or 0)
                                            DefaultTextColor := Parameters.TextColor
                                            DefaultShadowColor := Parameters.TextShadowColor
                                            DefaultShadowOffset := option{Parameters.TextShadowOffset}
                                            DefaultShadowOpacity := type{_X:float where 0.000000 <= _X, _X <= 1.000000}[Parameters.TextShadowOpacity] or 1.0
                                        HorizontalAlignment := horizontal_alignment.Center
                                        VerticalAlignment := vertical_alignment.Center
                        stack_box_slot:
                            Widget := YouUnderTextureBlock

                WidgetVisibility := if(TeamIndexTeamMembersMap[TeamIndex][0]):
                    Print("There is a team member on Team Index {TeamIndex}, so it will be visible on HUD")
                    widget_visibility.Visible
                else:
                    Print("There is no team members on Team Index {TeamIndex}, so it will not be visible on HUD")
                    widget_visibility.Collapsed
                TeamScoreStackBox.SetVisibility(WidgetVisibility)

                stack_box_slot:
                    HorizontalAlignment := horizontal_alignment.Right
                    Padding := margin:
                        Right := TeamBlocksCount <> TeamIndexColorMap.Length and Parameters.HorizontalPadding or 0.0
                    Widget := TeamScoreStackBox

        OverallCanvas := canvas:
            Slots := array:
                canvas_slot:
                    Widget := HorizontalTeamStackBox
                    Alignment := Parameters.Alignment
                    Anchors := anchors:
                        Minimum := Parameters.Anchor
                        Maximum := Parameters.Anchor
                    Offsets := margin:
                        Top := Parameters.Alignment.Y <= 0.5 and  Parameters.PositionOffset.Y or -Parameters.PositionOffset.Y
                        Left := Parameters.Alignment.X < 0.5 and Parameters.PositionOffset.X or -Parameters.PositionOffset.X
                    SizeToContent := true

        if(PlayerUI := GetPlayerUI[player[InAgent]]):
            PlayerUI.AddWidget(OverallCanvas)
            Print("Adding Widget")
        else:
            Print("Failed to add Widget")
    
        HUD := rr_score_hud:
            TeamIndexColorMap := TeamIndexColorMap
            HorizontalTeamStackBox := HorizontalTeamStackBox
            OverallCanvas := OverallCanvas

        HUD

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.CombatRound => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterCombatRound}
                    ExitCallback := option{ExitCombatRound}
            rr_state_enum.TeamSelect => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterTeamSelect}
                    
rr_score_hud := class:

    TeamIndexColorMap : [int]color
    HorizontalTeamStackBox : stack_box
    OverallCanvas : canvas

    Refresh(BelongingTeamIndex : int, SortedTeamScores : []tuple(int, int)):rr_score_hud =
        for:
            Position -> Widget : HorizontalTeamStackBox.Slots 
            TeamStackBox := stack_box[HorizontalTeamStackBox.Slots[Position].Widget]
            CrownTextureBlock := texture_block[TeamStackBox.Slots[0].Widget] # This will always be on for first!
            TeamBoxOverlay := overlay[TeamStackBox.Slots[1].Widget]
            TeamBoxTextureBlock := texture_block[TeamBoxOverlay.Slots[0].Widget]
            TeamBoxTextBlock := text_block[TeamBoxOverlay.Slots[1].Widget]
            YouFlagTextureBlock := texture_block[TeamStackBox.Slots[2].Widget]
        do:
            if:
                TeamIndexScore := SortedTeamScores[Position]
                TeamTint := TeamIndexColorMap[TeamIndexScore(0)]
            then:
                # Print("Updating {Position} to be visible with Team {TeamIndexScore(0)} with Score {TeamIndexScore(1)}")
                TeamStackBox.SetVisibility(widget_visibility.Visible)
                TeamBoxTextBlock.SetText(ToMessage(TeamIndexScore(1)))
                if(TeamIndexScore(0) = BelongingTeamIndex):
                    TeamBoxTextureBlock.SetImage(RR_UI.TeamScoring.T_TeamBlockYou)
                    YouFlagTextureBlock.SetVisibility(widget_visibility.Visible)
                else:
                    TeamBoxTextureBlock.SetImage(RR_UI.TeamScoring.T_TeamBlock)
                    YouFlagTextureBlock.SetVisibility(widget_visibility.Hidden)
                CrownTextureBlock.SetTint(TeamTint)
                TeamBoxTextureBlock.SetTint(TeamTint)
                YouFlagTextureBlock.SetTint(TeamTint)
            else:
                # Print("Updating {Position} to be collapsed")
                TeamStackBox.SetVisibility(widget_visibility.Collapsed)
        Self