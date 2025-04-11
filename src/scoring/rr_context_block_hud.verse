using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }

using { FN_Gameplay }
using { config }

rr_context_block := class:
    EncompassingWidget:widget
    ContextBlockTexture:texture_block
    OwnerTexture:texture_block
    PlayerCounter:rr_player_counter

BuildContextBlock(InAgent:agent, Config:rr_score_config, ?OptionalSnapshot:?rr_score_snapshot = false):rr_context_block =
    ContextBlockTexture := texture_block:
        DefaultImage := Config.ContextBlockImage
        DefaultDesiredSize := vector2{X := Config.BlockTextureSizeXY, Y := Config.BlockTextureSizeXY}
        DefaultTint := OptionalSnapshot?.Color or NamedColors.White
    OwnerTexture := texture_block:
        DefaultImage := Config.OwnerImage
        DefaultDesiredSize := vector2{X := Config.OwnerTextureSizeXY, Y := Config.OwnerTextureSizeXY}
    PlayerCounter := BuildPlayerCounter(Config, ?OptionalSnapshot := OptionalSnapshot)
    EncompassingWidget := overlay:
        Slots := array:
            overlay_slot:
                Widget := ContextBlockTexture
            overlay_slot:
                Widget := PlayerCounter.EncompassingWidget
                Padding := Config.PlayerCounterPadding
            overlay_slot:
                Widget := OwnerTexture
                Padding := Config.OwnerTexturePadding

    if(OptionalSnapshot?.Agents.Find[InAgent]):
        PlayerCounter.EncompassingWidget.Collapse()
        EncompassingWidget.Show()
        OwnerTexture.Show()
    else if(Config.ShowPlayerCount?):
        EncompassingWidget.Show()
        PlayerCounter.EncompassingWidget.Show()
    else:
        PlayerCounter.EncompassingWidget.Hide()
        EncompassingWidget.Hide()

    rr_context_block:
        EncompassingWidget := EncompassingWidget
        ContextBlockTexture := ContextBlockTexture
        OwnerTexture := OwnerTexture
        PlayerCounter := PlayerCounter