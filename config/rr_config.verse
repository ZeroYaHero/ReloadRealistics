using { /Verse.org/Colors }

using { src }

rr_abstract_config<public> := class<abstract>:
    AutoStartMinimum<public>:int
    TeamSize<public>:int
    MinimumSelectableTeams<public>:int
    SelectableTeamCapacity<public>:int
    NeutralTeamIndex<public>:int
    SelectableTeamParameters<public>:[]rr_selectable_team_parameter
    SupplyDropTimesAndQuantities<public>:[]tuple(float, int)
    InitialStormPhaseRadiusCM<public>:float
    Reboot<public>:rr_reboot_parameters
    ScoreHUD<public>:rr_score_hud_parameters
    TeamTags<public>:[]selectable_teams_tag
    POITags<public>:[]rr_poi_tags
    LoadoutTags<public>:[]rr_loadout_selector_tags
    PairingTags<public>:[]rr_poi_pairing_tags
    TeamSelectTimerDurationMap<public>:[int]float

    POITagNamePairs<public>:[]tuple(rr_poi_tags, string) = array{}

    StormRanges<public>:[]tuple(float, float)
    StormBeaconTags<public>:[]round_storm_device_tag
