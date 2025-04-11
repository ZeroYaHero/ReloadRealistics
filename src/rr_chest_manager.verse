using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

rr_chest_manager := class:
    ChestTracker:tracker_device
    ChestGranters:[]item_granter_device

    Initialize():void =
        ChestTracker.CompleteEvent.Subscribe(OnChestOpen)

    OnChestOpen(InAgent:agent):void =
        for(ChestGranter:ChestGranters):
            ChestGranter.CycleToRandomItem(InAgent)
        AwardXP(InAgent, rr_award.OpenChest)