using { /Verse.org/Simulation/Tags }

rr_round_tags<public> := class(tag){}
    round_barrier_tag := class(rr_round_tags){}
    round_storm_device_tag<public> := class(rr_round_tags){}
        round_storm_1_device_tag<public> := class(round_storm_device_tag){}
        round_storm_2_device_tag<public> := class(round_storm_device_tag){}
        round_storm_3_device_tag<public> := class(round_storm_device_tag){}
    round_supply_spawner_tag := class(rr_round_tags){}
    round_poi_hud_tag := class(rr_round_tags){}
    round_elim_manager_tag := class(rr_round_tags){}

# Loadout Selection
rr_loadout_selector_tags<public> := class(tag){}
    loadout_ui_tag := class(rr_loadout_selector_tags){}
    loadout_1_tag<public> := class(rr_loadout_selector_tags){}
    loadout_2_tag<public> := class(rr_loadout_selector_tags){}
    loadout_3_tag<public> := class(rr_loadout_selector_tags){}
    loadout_4_tag<public> := class(rr_loadout_selector_tags){}
    loadout_5_tag<public> := class(rr_loadout_selector_tags){}
    loadout_6_tag<public> := class(rr_loadout_selector_tags){}
    always_granter_tag := class(rr_loadout_selector_tags){}
    random_granter_tag := class(rr_loadout_selector_tags){}
    item_remover_tag := class(rr_loadout_selector_tags){}
    keep_loadout_dialog_tag := class(rr_loadout_selector_tags){}

rr_loot_tags<public> := class(tag){}
    chest_tag := class(rr_loot_tags){}

rr_score_tags := class(tag){}
    round_win_reference_tag := class(rr_score_tags){}
    game_win_reference_tag := class(rr_score_tags){}
    win_round_hud_tag := class(rr_score_tags){}
    lose_round_hud_tag := class(rr_score_tags){}

# For Generic Positions
rr_tp_tags := class(tag){}
    spawn_tp_tag := class(rr_tp_tags){}
    team_tp_tag := class(rr_tp_tags){}

# For Pairings
rr_poi_pairing_tags<public> := class(tag){}
    pairing_a_tag<public> := class(rr_poi_pairing_tags){}
    pairing_b_tag<public> := class(rr_poi_pairing_tags){}
    pairing_c_tag<public> := class(rr_poi_pairing_tags){}
    pairing_d_tag<public> := class(rr_poi_pairing_tags){}
    first_team_tag<public> := class(rr_poi_pairing_tags){}
    second_team_tag<public> := class(rr_poi_pairing_tags){}

# For POIs
rr_poi_tags<public> := class(tag){}
    yacht_poi_tag<public> := class(rr_poi_tags){}
    motel_poi_tag<public> := class(rr_poi_tags){}
    pleasant_poi_tag<public> := class(rr_poi_tags){}
    catty_poi_tag<public> := class(rr_poi_tags){}
    retail_poi_tag<public> := class(rr_poi_tags){}
    sands_poi_tag<public> := class(rr_poi_tags){}
    frosty_poi_tag<public> := class(rr_poi_tags){}
    factories_poi_tag<public> := class(rr_poi_tags){}
    crash_poi_tag<public> := class(rr_poi_tags){}
    weeping_poi_tag<public> := class(rr_poi_tags){}

rr_reboot_tags := class(tag){}
    reboot_respawn_tag := class(rr_reboot_tags){}
    reboot_status_center_tag := class(rr_reboot_tags){}
    reboot_status_corner_tag := class(rr_reboot_tags){}
    reboot_team_wipe_tag := class(rr_reboot_tags){}
    reboot_granter_tag := class(rr_reboot_tags){}
    reboot_sky_tp_tag := class(rr_reboot_tags){}
    reboot_disabled_corner_tag := class(rr_reboot_tags){}
    reboot_disabled_center_tag := class(rr_reboot_tags){}
    reboot_enabled_hud_tag := class(rr_reboot_tags){}
    reboot_input_tag := class(rr_reboot_tags){}
    reboot_input_hud_tag := class(rr_reboot_tags){}
    reboot_input_anim_tag := class(rr_reboot_tags){}
    reboot_input_arrow_tag := class(rr_reboot_tags){}
    reboot_rift_sfx_tag := class(rr_reboot_tags){}
    reboot_time_skip_tag := class(rr_reboot_tags){}
    reboot_timer_sfx_tag := class(rr_reboot_tags){}
    reboot_urgent_timer_sfx_tag := class(rr_reboot_tags){}
    reboot_disallowed_sfx_tag := class(rr_reboot_tags){}
    reboot_bank_tag<public> := class(rr_reboot_tags){}
        reboot_bank_1_tag<public> := class(reboot_bank_tag){}
        reboot_bank_2_tag<public> := class(reboot_bank_tag){}
        reboot_bank_3_tag<public> := class(reboot_bank_tag){}
        reboot_bank_4_tag<public> := class(reboot_bank_tag){}

rr_state_timer_tags := class(tag){}
    team_select_auto_timer_tag := class(rr_team_tags){}
    rematch_requeue_auto_timer_tag := class(rr_hub_tags){}
    opponents_left_auto_timer_tag := class(rr_hub_tags){}

rr_team_tags<public> := class(tag){}
    team_prop_tag<public> := class(rr_team_tags){}
    neutral_team_tag := class(rr_team_tags){}
    selectable_teams_tag<public> := class(rr_team_tags){}
        team_one_tag<public> := class(selectable_teams_tag){}
        team_two_tag<public> := class(selectable_teams_tag){}
        team_three_tag<public> := class(selectable_teams_tag){}
        team_four_tag<public> := class(selectable_teams_tag){}
        team_five_tag<public> := class(selectable_teams_tag){}
        team_six_tag<public> := class(selectable_teams_tag){}
        team_seven_tag<public> := class(selectable_teams_tag){}
        team_eight_tag<public> := class(selectable_teams_tag){}
    display_selector_tag<public> := class(rr_team_tags){}
    state_sfx_tag := class(rr_team_tags){}
    
rr_hub_tags := class(tag){}
    initialize_mutator_tag := class(rr_hub_tags){}  
    waiting_players_timer_tag := class(rr_hub_tags){}
    auto_start_voting_tag := class(rr_hub_tags){}
    winning_stage_tag := class(rr_hub_tags){}
    van_starting_timer_tag := class(rr_hub_tags){}

rr_generic_tags := class(tag){}
    generic_hud_message_tag := class(rr_generic_tags){}

rr_analytic_accolade_tags := class(tag){}
    # XP
    lobby_afk_tag := class(rr_analytic_accolade_tags){}
    supply_drop_open_tag := class(rr_analytic_accolade_tags){}
    selected_team_tag := class(rr_analytic_accolade_tags){}
    rebooted_tag := class(rr_analytic_accolade_tags){}
    knock_opponent_tag := class(rr_analytic_accolade_tags){}
    eliminate_opponent_tag := class(rr_analytic_accolade_tags){}
    team_wipe_xp_tag := class(rr_analytic_accolade_tags){}
    played_round_tag := class(rr_analytic_accolade_tags){}
    won_round_tag := class(rr_analytic_accolade_tags){}
    played_game_tag := class(rr_analytic_accolade_tags){}
    won_game_tag := class(rr_analytic_accolade_tags){}
    coin_collectible_tag := class(rr_analytic_accolade_tags){}
    # Analytics
    default_selected_tag := class(rr_analytic_accolade_tags){}
    selected_loadout_1_tag := class(rr_analytic_accolade_tags){}
    selected_loadout_2_tag := class(rr_analytic_accolade_tags){}
    selected_loadout_3_tag := class(rr_analytic_accolade_tags){}
    selected_loadout_4_tag := class(rr_analytic_accolade_tags){}
    selected_loadout_5_tag := class(rr_analytic_accolade_tags){}
    selected_loadout_6_tag := class(rr_analytic_accolade_tags){}