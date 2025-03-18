using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Verse.org/Colors }

rr_config_duos := class(rr_abstract_config):

    AutoStartMinimum<override> : int = 4

    TeamSize<override> : int = 2
    MinimumSelectableTeams<override> : int = 2
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
        (45.0, 3)
        (60.0, 2)

    InitialStormPhaseRadiusCM<override> : float = 8500.0

    RebootParameters<override> : rr_reboot_parameters = rr_reboot_parameters:
        SkyZ := 384.0 * 40
        KnockSkip := 2.0
        EliminationSkip := 4.0
        TeamWipeSkip := 10.0
        MinimumTeammatesAliveRequired := 1
        MaximumRebootBank := 1
        RebootRift := DefaultCreativePropAsset          # ! This also needs to be editable bc yeah
        RebootMessageFeed := elimination_feed_device{} # ! This needs to be an editable bc...yeah
        RebootRiftLifetime := 10.0
        RebootStates := array:
            rr_reboot_state:
                TimeToReboot := 0.0
                Duration := 15.0
            rr_reboot_state:
                TimeToReboot := 3.0
                Duration := 30.0
            rr_reboot_state:
                TimeToReboot := 5.0
                Duration := 30.0
            rr_reboot_state:
                TimeToReboot := 7.0
                Duration := 60.0
                ShowTimer := true

    ScoreHUDParameters<override> : rr_score_hud_parameters = rr_score_hud_parameters:

        HorizontalPadding<override> := 10.0
        CrownTeamBlockPadding<override> := 5.0
        TextureBlockXYSize<override> := 75.0
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
            Y := 60.0
    
        TeamBlockTexture<override> := RR_UI.TeamScoring.T_TeamBlock
        TeamBlockYouTexture<override> := RR_UI.TeamScoring.T_TeamBlockYou
        YouUnderTexture<override> := RR_UI.TeamScoring.T_YouUnder
        CrownTexture<override> := RR_UI.TeamScoring.T_Crown