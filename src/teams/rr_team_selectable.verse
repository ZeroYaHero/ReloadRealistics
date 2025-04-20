using { /Fortnite.com/Devices }
using { /Verse.org/Colors }

using { FN_Gameplay }
using { config }

rr_selectable_team<public> := class(rr_team_config):
    DisplayTeamSelectorDevice<public>:class_and_team_selector_device
    MutatorZoneDevice<public>:mutator_zone_device
    PlayerCounterDevice<public>:player_counter_device
    PlayerReferenceDevices<public>:[]player_reference_device
    TeleporterDevices<public>:[]teleporter_device
    SelectSFXDevice<public>:audio_player_device
    OverrideCapacity<public>:?int = false