using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/Devices }
using { /Verse.org/Colors }

using { src }

rr_config_solos<public> := class(rr_abstract_config):
    AutoStartMinimum<override> : int = 2

    Teams<override>:rr_teams_config = rr_teams_config:
        MinimumNumberOfTeams<override> := 2
        TeamCapacity<override> := 1
        NeutralizedIndex<override> := -1
        MinimumSizeForKeepSelect<public> := 1
        TeamSelectTimerDurationMap<public> := map{}
        DefaultTeamSelectTimerDuration<public> := -1.0
        PlayableTeams<override> := array:
            rr_team_config:
                Index := 0
                Name := "Blue"
                Color := NamedColors.Blue
                Tag := false           
            rr_team_config:
                Index := 1
                Name := "Red"
                Color := NamedColors.Red
                Tag := false
            rr_team_config:
                Index := 2
                Name := "Green"
                Color := NamedColors.LimeGreen
                Tag := false
            rr_team_config:
                Index := 3
                Name := "Yellow"
                Color := NamedColors.Yellow
                Tag := false
            rr_team_config:
                Index := 4
                Name := "Purple"
                Color := NamedColors.Purple
                Tag := false
            rr_team_config:
                Index := 5
                Name := "Orange"
                Color := NamedColors.Orange
                Tag := false
            rr_team_config:
                Index := 6
                Name := "Cyan"
                Color := NamedColors.Cyan
                Tag := false
            rr_team_config:
                Index := 7
                Name := "Pink"
                Color := NamedColors.Pink
                Tag := false

    Reboot<override>:rr_reboot_config = rr_reboot_config:
        DownTimeSkip<override> := 2.0
        EliminationTimeSkip<override> := 4.0
        WipeTimeSkip<override> := 10.0
        TimerTickSFXDuration<override> := 7.0
        UrgentTimerTickSFXDuration<override> := 3.0
        RiftHeight<override> := 384.0 * 40
        RiftLifetime<override> := 10.0
        HoldToRebootArrowCount<override> := 2
        WipeMessage<override> := EnemyWipedMessage
        RebootDurationUnlimitedTuples<override> := array:
            (1.0, 30.0, true)
            (2.0, 60.0, true)
            (2.0, 15.0, false)
            (3.0, 30.0, false)
            (5.0, 45.0, false)
            (7.0, 60.0, false)
        RebootBank<override> := option:
            rr_reboot_bank_config:
                MaximumRebootBank<override> := 3
                RebootBankTags<override> := array:
                    reboot_bank_1_tag{}
                    reboot_bank_2_tag{}
                    reboot_bank_3_tag{}
                RebootNoBankTag<override> := reboot_no_bank_tag{}
                RebootInfiniteBankTag<override> := reboot_unlimited_bank_tag{}
                LowOvershieldTag<override> := reboot_50_over_tag{}
                HighOvershieldTag<override> := reboot_100_over_tag{}
            
        RebootHealth := 100.0
        RebootShield := 50.0

    POIs<override>:rr_pois_config = rr_pois_config:
        TeleporterPairingTags := array:
            pairing_a_tag{}
            pairing_b_tag{}
            pairing_c_tag{}
            pairing_d_tag{}
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
    Scoring<override>:rr_score_config = rr_score_config:
        Anchor<override>:=vector2{X := 0.0, Y := 0.0}
        Alignment<override>:=vector2{X := 0.0, Y := 0.0}
        Offset<override>:=vector2{X := 15.0, Y := 120.0}
    
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
        ShowPlayerCount<override>:=false

    Storm<override>:rr_storm_config = rr_storm_config:
        DelayDuration := 10.0
        Phases := array:
            rr_storm_phase_config:
                BeaconDeviceTag := storm_1_tag{}
                MinimumMaximumRange := (0.0, 0.0)
                WaitDuration := 90.0
                MoveShrinkDuration := 60.0
                Radius := 8500.0
            rr_storm_phase_config:
                BeaconDeviceTag := storm_2_tag{}
                MinimumMaximumRange := (512.0, 1024.0)
                WaitDuration := 15.0
                MoveShrinkDuration := 60.0
                Radius := 4500.0
            rr_storm_phase_config:
                BeaconDeviceTag := storm_3_tag{}
                MinimumMaximumRange := (2048.0, 4096.0)
                WaitDuration := 10.0
                MoveShrinkDuration := 60.0
                Radius := 0.0

    LoadoutTags<override> : []rr_loadout_selector_tags = array:
        loadout_1_tag{}
        loadout_2_tag{}
        loadout_3_tag{}
        loadout_4_tag{}
        loadout_5_tag{}
        loadout_6_tag{}