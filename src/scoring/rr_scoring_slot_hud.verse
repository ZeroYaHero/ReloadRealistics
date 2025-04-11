using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /Fortnite.com/UI }

using { FN_Gameplay }
using { config }

rr_scoring_slot := class:
    EncompassingWidget:widget
    CrownTexture:texture_block
    ScoreText:text_base
    ScoreBlockTexture:texture_block
    ContextBlock:rr_context_block

BuildScoreSlots(InAgent:agent, Config:rr_score_config, ?SortedSnapshots:[]rr_score_snapshot = array{}):[]rr_scoring_slot =
    for(I := 1..Config.MaximumScoreSlots):
        BuildScoreSlot(InAgent, Config, logic{I = 1}, ?OptionalSnapshot := option{SortedSnapshots[I]})

BuildScoreSlot(InAgent:agent, Config:rr_score_config, Leader:logic, ?OptionalSnapshot:?rr_score_snapshot = false):rr_scoring_slot =
    BlockTextureSize := vector2{X := Config.BlockTextureSizeXY, Y := Config.BlockTextureSizeXY}
    ScoreText := text_block:
        DefaultTextColor := Config.ScoreTextColor
        DefaultText := IntMessage(OptionalSnapshot?.Score or 0)
        DefaultShadowColor := Config.ScoreTextShadowColor
        DefaultShadowOffset := option{Config.ScoreTextShadowOffset}
        DefaultShadowOpacity := type{_X:float where 0.000000 <= _X, _X <= 1.000000}[Config.ScoreTextShadowOpacity] or 1.0
    CrownTexture := texture_block:
        DefaultImage := Config.CrownImage
        DefaultDesiredSize := vector2{X := Config.CrownSizeXY, Y := Config.CrownSizeXY}
        DefaultTint := OptionalSnapshot?.Color or NamedColors.White
    ScoreBlockTexture := texture_block:
        DefaultImage := Config.ScoreBlockImage
        DefaultDesiredSize := BlockTextureSize
        DefaultTint := OptionalSnapshot?.Color or NamedColors.White
    ContextBlock := BuildContextBlock(InAgent, Config, ?OptionalSnapshot := OptionalSnapshot)
    ScoreOverlay := overlay:
        Slots := array:
            overlay_slot:
                Widget := ScoreBlockTexture
            overlay_slot:
                Widget := ScoreText
                Padding := Config.ScoreTextPadding
    CrownTexture.SetVisibility(Leader? and widget_visibility.Visible or widget_visibility.Hidden)
    rr_scoring_slot:
        EncompassingWidget := stack_box:
            Orientation := orientation.Vertical
            Slots := array:
                stack_box_slot:
                    Widget := CrownTexture
                    Padding := Config.CrownPadding
                stack_box_slot:
                    Widget := ScoreOverlay
                stack_box_slot:
                    Widget := ContextBlock.EncompassingWidget
                    Padding := margin{Top := Config.ContextBlockPadding}
        CrownTexture := CrownTexture
        ScoreText := ScoreText
        ScoreBlockTexture := ScoreBlockTexture
        ContextBlock := ContextBlock
