using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/Devices }
using { /Verse.org/Colors }

using { src }

rr_config_duos<public> := class(rr_abstract_config):
    AutoStartMinimum<override> : int = 4

    Teams<override>:rr_teams_config = rr_teams_config:
        MinimumNumberOfTeams<override> := 2
        TeamCapacity<override> := 2
        NeutralizedIndex<override> := 0
        MinimumSizeForKeepSelect<public> := 2
        TeamSelectTimerDurationMap<public> := map:
            3 => 8.0
            4 => 8.0
            5 => 10.0
            6 => 10.0
            7 => 12.0
            8 => 12.0
        DefaultTeamSelectTimerDuration<public> := 10.0
        PlayableTeams<override> := array:
            rr_team_config:
                Index := 1
                Name := "Blue"
                Color := NamedColors.Blue
                Tag := option:
                    team_one_tag{}
            rr_team_config:
                Index := 2
                Name := "Red"
                Color := NamedColors.Red
                Tag := option:
                    team_two_tag{}
            rr_team_config:
                Index := 3
                Name := "Green"
                Color := NamedColors.LimeGreen
                Tag := option:
                    team_three_tag{}
            rr_team_config:
                Index := 4
                Name := "Yellow"
                Color := NamedColors.Yellow 
                Tag := option:
                    team_four_tag{}

    Reboot<override>:rr_reboot_config = rr_reboot_config:
        DownTimeSkip<override> := 2.0
        EliminationTimeSkip<override> := 4.0
        WipeTimeSkip<override> := 10.0
        TimerTickSFXDuration<override> := 7.0
        UrgentTimerTickSFXDuration<override> := 3.0
        RiftHeight<override> := 384.0 * 40
        RiftLifetime<override> := 10.0
        HoldToRebootArrowCount<override> := 2
        WipeMessage<override> := EnemyTeamWipedMessage
        RebootDurationCycles<override> := array:
            (1.0, 15.0)
            (3.0, 30.0)
            (5.0, 45.0)
            (7.0, 60.0)
        RebootBankTags<override> := array{}
        RebootNoBankTag<override> := false
        RebootHealth := 100.0
        RebootShield := 50.0

    POIs<override>:rr_pois_config = rr_pois_config:
        TeleporterPairingTags := array:
            pairing_a_tag{}
            pairing_b_tag{}
        TagAndNames := array:
            (yacht_poi_tag{}, "The Boat")
            (motel_poi_tag{}, "Coastal Motel")
            (pleasant_poi_tag{}, "Square Park")
            (catty_poi_tag{}, "Mountain Stop")
            (retail_poi_tag{}, "The Shops")
            (sands_poi_tag{}, "The Pier")
            (frosty_poi_tag{}, "Snowy Runway")
            (factories_poi_tag{}, "Dock Factories")
            (crash_poi_tag{}, "Crash Landing")
            (weeping_poi_tag{}, "Log Cabins")

    Rounds<override>:rr_rounds_config = rr_rounds_config:
        SupplyDropTimesAndQuantities<override>:= array:
            (10.0, 2)
            (45.0, 2)
            (45.0, 2)
        InitialStormPhaseRadiusCM<override>:= 8500.0 
        StormRanges<override>:= array:
            (512.0, 1024.0)
            (2048.0, 4096.0)
        StormBeaconTags<override>:= array:
            round_storm_1_device_tag{}
            round_storm_2_device_tag{}
            round_storm_3_device_tag{}

    Scoring<override>:rr_score_config = rr_score_config:
        Anchor<override>:=vector2{X := 1.0, Y := 0.0}
        Alignment<override>:=vector2{X := 1.0, Y := 0.0}
        Offset<override>:=vector2{X := -15.0, Y := 405.0}
    
        CrownImage<override>:=RR_UI.TeamScoring.T_AboveTexture
        ScoreBlockImage<override>:=RR_UI.TeamScoring.T_ScoreBlock
        ContextBlockImage<override>:=RR_UI.TeamScoring.T_UnderBlock
        PlayerIconImage<override>:=RR_UI.TeamScoring.T_PlayerIcon
        PlayerWipedImage<override>:=RR_UI.TeamScoring.T_PlayerWiped
        OwnerImage<override>:=RR_UI.TeamScoring.T_YouText
        NumberImages<override>:= array:
            RR_UI.TeamScoring.T_0
            RR_UI.TeamScoring.T_1
            RR_UI.TeamScoring.T_2
            RR_UI.TeamScoring.T_3
            RR_UI.TeamScoring.T_4
    
        ScoreTextColor<override>:= NamedColors.White
        ScoreTextShadowColor<override>:= NamedColors.Black
        ScoreTextShadowOpacity<override>:=0.3
        ScoreTextShadowOffset<override>:=vector2{}
    
        ScoreTextPadding<override>:=margin{Right := 3.0, Bottom := 4.0}
        ScoreSlotHorizontalPadding<override>:=3.0
        CrownPadding<override>:=margin{Top := 8.0, Right := 3.0}
        CrownSizeXY<override>:=48.0
        OwnerTexturePadding<override>:=margin{Right := 3.5, Bottom := 4.0}
        OwnerTextureSizeXY<override>:=60.0
        ContextBlockPadding<override>:=-12.0
        BlockTextureSizeXY<override>:=72.0
        PlayerIconWipedTextureSizeXY<override>:=20.0
        PlayerIconWipedNumberPadding<override>:=8.0
        PlayerCounterPadding<override>:=margin{Bottom := 4.0, Right := 5.0}
        NumberImageSizeXY<override>:=20.0
        NumberImagePadding<override>:=30.0
    
        MaximumScoreSlots<override>:= 4
        WipedColorMultiplier<override>:=0.025
        ShowOwnerAtMinimum<override>:=true
        ShowPlayerCount<override>:=true

    LoadoutTags<override> : []rr_loadout_selector_tags = array:
        loadout_1_tag{}
        loadout_2_tag{}
        loadout_3_tag{}
        loadout_4_tag{}
        loadout_5_tag{}
        loadout_6_tag{}


