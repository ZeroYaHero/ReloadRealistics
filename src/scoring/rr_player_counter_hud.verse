using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }

using { FN_Gameplay }
using { config }

rr_player_counter := class:
    EncompassingWidget:widget
    IconTexture:texture_block
    WipedTexture:texture_block
    NumberTexture:texture_block

BuildPlayerCounter(Config:rr_score_config, ?OptionalSnapshot:?rr_score_snapshot = false):rr_player_counter =
    IconWipedSize := vector2{X := Config.PlayerIconWipedTextureSizeXY, Y := Config.PlayerIconWipedTextureSizeXY}
    IconTexture := texture_block:
        DefaultImage := Config.PlayerIconImage
        DefaultDesiredSize := IconWipedSize
    WipedTexture := texture_block:
        DefaultImage := Config.PlayerWipedImage
        DefaultDesiredSize := IconWipedSize
    NumberTexture := texture_block:
        DefaultImage := Config.NumberImages[0] or Config.PlayerIconImage
        DefaultDesiredSize := vector2{X := Config.NumberImageSizeXY, Y := Config.NumberImageSizeXY}
    IconWipedOverlay := overlay:
        Slots := array:
            overlay_slot:
                Widget := IconTexture
            overlay_slot:
                Widget := WipedTexture
    if(OptionalSnapshot?.Wiped?):
        WipedTexture.Show()
        IconTexture.Hide()
    else:
        IconTexture.Show()
        WipedTexture.Hide()
    if:
        Count := OptionalSnapshot?.Count
        NumberImage := Config.NumberImages[Count]
    then:
        NumberTexture.SetImage(NumberImage)
    else:
        NumberTexture.Collapse()
    rr_player_counter:
        EncompassingWidget := stack_box:
            Orientation := orientation.Horizontal
            Slots := array:
                stack_box_slot:
                    Widget := IconWipedOverlay
                stack_box_slot:
                    Padding := margin{Left := Config.PlayerIconWipedNumberPadding}
                    Widget := NumberTexture
        IconTexture := IconTexture
        WipedTexture := WipedTexture
        NumberTexture := NumberTexture