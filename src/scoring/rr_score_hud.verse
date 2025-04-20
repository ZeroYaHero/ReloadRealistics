using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Assets }
using { /Verse.org/Colors }

using { FN_Gameplay }

rr_scoring_hud := class:
    Agent:agent
    EncompassingWidget:widget
    ScoreSlots:[]rr_scoring_slot
    NumberImages:[]texture
    ShowOwnerAtMinimum:logic
    WipedColorMultiplier:float
    ShowPlayerCount:logic

    UpdateSlots(Snapshots:[]rr_score_snapshot):rr_scoring_hud =
        var SeenOwner:logic = false
        var ScoreSlotIndex:int = 0
        
        for:
            Position -> Snapshot:Snapshots
            ScoreSlot := ScoreSlots[ScoreSlotIndex]
            ScoreSlotIndex < ScoreSlots.Length - 1 or SeenOwner? or Snapshot.Agents.Find[Agent]
        do:
            set ScoreSlotIndex += 1
            ScoreSlotColor := Snapshot.Color * (Snapshot.Wiped? and WipedColorMultiplier or 1.0)

            ScoreSlot.ScoreText.SetText(IntMessage(Snapshot.Score))

            if(Snapshot.Agents.Find[Agent]):
                set SeenOwner = true
                ScoreSlot.ContextBlock.EncompassingWidget.Show()
                ScoreSlot.ContextBlock.OwnerTexture.Show()
                ScoreSlot.ContextBlock.PlayerCounter.EncompassingWidget.Hide()

            else if(ShowPlayerCount?):
                if(NumberImage := NumberImages[Snapshot.Count]):
                    ScoreSlot.ContextBlock.PlayerCounter.NumberTexture.SetImage(NumberImage)
                    ScoreSlot.ContextBlock.PlayerCounter.NumberTexture.Show()
                else:
                    ScoreSlot.ContextBlock.PlayerCounter.NumberTexture.Collapse()
                ScoreSlot.ContextBlock.PlayerCounter.IconTexture.SetVisibility(Snapshot.Wiped? and widget_visibility.Collapsed or widget_visibility.Visible)
                ScoreSlot.ContextBlock.PlayerCounter.WipedTexture.SetVisibility(Snapshot.Wiped? and widget_visibility.Visible or widget_visibility.Collapsed)
                ScoreSlot.ContextBlock.OwnerTexture.Hide()
                ScoreSlot.ContextBlock.PlayerCounter.EncompassingWidget.Show()

            else:
                ScoreSlot.ContextBlock.EncompassingWidget.Hide()
                ScoreSlot.ContextBlock.PlayerCounter.EncompassingWidget.Hide()

            ScoreSlot.CrownTexture.SetTint(ScoreSlotColor)
            ScoreSlot.ScoreBlockTexture.SetTint(ScoreSlotColor)
            ScoreSlot.ContextBlock.ContextBlockTexture.SetTint(ScoreSlotColor)

            if(Position = 0):
                ScoreSlot.CrownTexture.Show()

            ScoreSlot.EncompassingWidget.Show()
        for:
            I := ScoreSlotIndex..ScoreSlots.Length - 1
            ScoreSlot := ScoreSlots[I]
        do:
            ScoreSlot.EncompassingWidget.Collapse()

        Self