using { /Verse.org/Colors }

rr_abstract_config := class<abstract>:

    AutoStartMinimum : int

    TeamSize : int
    MinimumSelectableTeams : int
    NeutralTeamIndex : int
    SelectableTeamParameters : []rr_selectable_team_parameter

    SupplyDropTimesAndQuantities : []tuple(float, int)

    InitialStormPhaseRadiusCM : float

    RebootParameters : rr_reboot_parameters

    ScoreHUDParameters : rr_score_hud_parameters