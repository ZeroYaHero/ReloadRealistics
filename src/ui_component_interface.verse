using { /Verse.org/Simulation }

ui_component_interface := interface:
    ShowUIAndAwaitSelection<public>(:agent)<suspends>:void
    ShowUI<public>(:agent):void
    ShowUI<public>():void
    HideUI<public>(:agent):void
    HideUI<public>():void