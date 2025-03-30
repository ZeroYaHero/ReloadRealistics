using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Verse.org/Colors }

using { src }

rr_config_duos<public> := class(rr_abstract_config):
    AutoStartMinimum<override> : int = 4
    TeamSize<override> : int = 2
    MinimumSelectableTeams<override> : int = 2
    SelectableTeamCapacity<override> : int = 2
    NeutralTeamIndex<override> : int = 0
    SelectableTeamParameters<override> : []rr_selectable_team_parameter = array:
        rr_selectable_team_parameter:
            Index := 1
            Color := NamedColors.Blue
        rr_selectable_team_parameter:
            Index := 2
            Color := NamedColors.Red
        rr_selectable_team_parameter:
            Index := 3
            Color := NamedColors.LimeGreen
        rr_selectable_team_parameter:
            Index := 4
            Color := NamedColors.Yellow 
    SupplyDropTimesAndQuantities<override> : []tuple(float, int) = array:
        (10.0, 2)
        (45.0, 2)
        (45.0, 2)
    InitialStormPhaseRadiusCM<override> : float = 8500.0
    Reboot<override> : rr_reboot_parameters = rr_reboot_parameters:
        SkyZ<override> := 384.0 * 40
        KnockSkip<override> := 2.0
        EliminationSkip<override> := 4.0
        TeamWipeSkip<override> := 10.0
        MinimumTeammatesAliveRequired<override> := 1
        MaximumRebootBank<override> := 1
        RebootRiftLifetime<override> := 10.0
        RespawnDurations<override> := array:
            (1.0, 15.0)
            (3.0, 30.0)
            (5.0, 45.0)
            (7.0, 60.0)
    ScoreHUD<override> : rr_score_hud_parameters = rr_score_hud_parameters:
        HorizontalPadding<override> := 8.0
        CrownTeamBlockPadding<override> := 3.0
        TextureBlockXYSize<override> := 64.0
        TextShadowOpacity<override> := 0.3
        TextColor<override> := color:
            R := 1.0
            G := 1.0
            B := 1.0
        TextShadowColor<override> := color:
            R := 0.0
            G := 0.0
            B := 0.0
        TextShadowOffset<override> := vector2:
            X := 2.0
            Y := 1.5
        Anchor<override> := vector2:
            X := 1.0
            Y := 0.0
        Alignment<override> := vector2:
            X := 1.0
            Y := 0.0
        PositionOffset<override> := vector2:
            X := 35.0
            Y := 405.0
        TeamBlockTexture<override> := RR_UI.TeamScoring.T_TeamBlock
        TeamBlockYouTexture<override> := RR_UI.TeamScoring.T_TeamBlockYou
        YouUnderTexture<override> := RR_UI.TeamScoring.T_YouUnder
        CrownTexture<override> := RR_UI.TeamScoring.T_Crown
    TeamTags<override> : []selectable_teams_tag = array:
        team_one_tag{}
        team_two_tag{}
        team_three_tag{}
        team_four_tag{}
    POITags<override> : []rr_poi_tags = array:
        yacht_poi_tag{}
        motel_poi_tag{}
        pleasant_poi_tag{}
        catty_poi_tag{}
        retail_poi_tag{}
        sands_poi_tag{}
        frosty_poi_tag{}
        factories_poi_tag{}
        crash_poi_tag{}
        weeping_poi_tag{}
    LoadoutTags<override> : []rr_loadout_selector_tags = array:
        loadout_1_tag{}
        loadout_2_tag{}
        loadout_3_tag{}
        loadout_4_tag{}
        loadout_5_tag{}
        loadout_6_tag{}
    PairingTags<override> : []rr_poi_pairing_tags = array:
        pairing_a_tag{}
        pairing_b_tag{}
    TeamSelectTimerDurationMap<override>:[int]float = map:
        3 => 8.0
        4 => 8.0
        5 => 10.0
        6 => 10.0
        7 => 12.0
        8 => 12.0

    StormRanges<override>:[]tuple(float, float) = array:
        (512.0, 1024.0)
        (2048.0, 4096.0)

    StormBeaconTags<override>:[]round_storm_device_tag = 
        array:
            round_storm_1_device_tag{}
            round_storm_2_device_tag{}
            round_storm_3_device_tag{}


