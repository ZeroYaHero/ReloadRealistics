using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Verse.org/Colors }
using { /Fortnite.com/UI }

using { FN_Gameplay }

foo(t:type) := interface{}

bar := class(foo(int), foo(float)):



hud_verse_tag := class(tag){}
    win_round_hud_tag := class(hud_verse_tag){}
    lose_round_hud_tag := class(hud_verse_tag){}
    generic_popup_dialog_tag := class(hud_verse_tag){}
    generic_hud_message_tag := class(hud_verse_tag){}
    watermark_hud_tag := class(hud_verse_tag){}
    # TODO!: Make the generic timers and stuff

RR_UI := module:
    TeamScoring<public> := module{}

rr_hud_parameters := class<concrete>:

    @editable   HorizontalPadding : float = 10.0
    @editable   CrownTeamBlockPadding : float = 5.0
    @editable   TextureBlockXYSize : float = 75.0
    @editable   TextShadowOpacity : float = 0.3
    @editable   TextColor : color = color:
        R := 1.0
        G := 1.0
        B := 1.0
    @editable   TextShadowColor : color = color:
        R := 0.0
        G := 0.0
        B := 0.0
    @editable   TextShadowOffset : vector2 = vector2:
        X := 2.0
        Y := 1.5
    @editable   Anchor : vector2 = vector2:
        X := 1.0
        Y := 0.0
    @editable   Alignment : vector2 = vector2:
        X := 1.0
        Y := 0.0
    @editable   PositionOffset : vector2 = vector2:
        X := 35.0
        Y := 60.0

# TODO!: Implement
rr_hud_devices := struct:

    WinRoundHUD : hud_message_device
    LoseRoundHUD : hud_message_device
    Generic2Dialog : popup_dialog_device
    GenericHUD : hud_message_device

rr_hud_manager := class:

    Parameters : rr_hud_parameters
    WinRoundHUD : hud_message_device
    LoseRoundHUD : hud_message_device
    WatermarkHUD : hud_message_device
    TeamIndexTintMap : [int]color
    var AgentHUDMap : [agent]rr_score_hud = map{}

    Refresh(TeamsData : []rr_team_data, TeamIndexTeamMembersMap : [int][]agent, TeamScorePairings : []tuple(int, int)):void =
        WatermarkHUD.Show()
        set AgentHUDMap = Dict of for:
            TeamIndex -> TeamMembers : TeamIndexTeamMembersMap
            TeamMember : TeamMembers
        do:
            if(HUD := AgentHUDMap[TeamMember]):
                (TeamMember, HUD.Refresh(TeamScorePairings))
            else:
                (TeamMember, BuildHUD(TeamMember <# Current agent #>, TeamIndex <# Team index belonging #>, TeamsData <# Max potential teams #>, TeamScorePairings <# Teams currently active #>))

    BuildHUD(InAgent : agent, InTeamIndex : int, TeamsData : []rr_team_data, TeamScorePairings : []tuple(int, int)):rr_score_hud =
        TeamIndexScoreMap := Dict of TeamScorePairings

        TextureBlockSize := vector2:
            X := Parameters.TextureBlockXYSize
            Y := Parameters.TextureBlockXYSize

        var TeamBlocksCount : int = 0
        HorizontalTeamStackBox := stack_box:
            Orientation := orientation.Horizontal
            Slots := for:
                Team : TeamsData
                TeamTint := TeamIndexTintMap[Team.Parameter.Index]
            do:
                set TeamBlocksCount += 1
                
                CrownTextureBlock := texture_block:
                    DefaultImage := RR_UI.TeamScoring.T_Crown
                    DefaultTint := TeamTint
                    DefaultDesiredSize := TextureBlockSize
                if(not TeamBlocksCount = 1):
                    CrownTextureBlock.SetVisibility(widget_visibility.Hidden)

                YouUnderTextureBlock := texture_block:
                    DefaultImage := RR_UI.TeamScoring.T_YouUnder
                    DefaultTint := TeamTint
                    DefaultDesiredSize := TextureBlockSize

                YouUnderTextureBlock.SetVisibility(Team.Parameter.Index = InTeamIndex and widget_visibility.Visible or widget_visibility.Hidden)
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
                                            DefaultImage := Team.Parameter.Index = InTeamIndex and RR_UI.TeamScoring.T_TeamBlockYou or RR_UI.TeamScoring.T_TeamBlock
                                            DefaultTint := TeamTint
                                            DefaultDesiredSize := TextureBlockSize
                                    overlay_slot:
                                        Widget := text_block:
                                            DefaultText := ToMessage(TeamIndexScoreMap[Team.Parameter.Index] or 0)
                                            DefaultTextColor := Parameters.TextColor
                                            DefaultShadowColor := Parameters.TextShadowColor
                                            DefaultShadowOffset := option{Parameters.TextShadowOffset}
                                            DefaultShadowOpacity := type{_X:float where 0.000000 <= _X, _X <= 1.000000}[Parameters.TextShadowOpacity] or 1.0
                                        HorizontalAlignment := horizontal_alignment.Center
                                        VerticalAlignment := vertical_alignment.Center
                        stack_box_slot:
                            Widget := YouUnderTextureBlock

                TeamScoreStackBox.SetVisibility(TeamIndexScoreMap[Team.Parameter.Index] and widget_visibility.Visible or widget_visibility.Collapsed)

                stack_box_slot:
                    HorizontalAlignment := horizontal_alignment.Right
                    Padding := margin:
                        Right := TeamBlocksCount <> TeamIndexTintMap.Length and Parameters.HorizontalPadding or 0.0
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
            BelongingTeamIndex := InTeamIndex
            TeamIndexTintMap := TeamIndexTintMap
            HorizontalTeamStackBox := HorizontalTeamStackBox
            OverallCanvas := OverallCanvas

        HUD

rr_score_hud := class:

    BelongingTeamIndex : int
    TeamIndexTintMap : [int]color
    HorizontalTeamStackBox : stack_box
    OverallCanvas : canvas

    Refresh(SortedTeamScores : []tuple(int, int)):rr_score_hud =
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
                TeamTint := TeamIndexTintMap[TeamIndexScore(0)]
            then:
                Print("Updating {Position} to be Team {TeamIndexScore(0)} with Score {TeamIndexScore(1)}")
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
                TeamStackBox.SetVisibility(widget_visibility.Collapsed)
        Self