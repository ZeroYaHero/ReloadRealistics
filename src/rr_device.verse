using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Colors }

using { FN_Gameplay }
using { config }
using { state }
using { scoring }
using { teams }

server_crash_trigger_tag := class(tag){}

# Change to RR device
rr_device := class(creative_device):
    @editable   RebootRiftAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable   RebootMessageFeed : elimination_feed_device = elimination_feed_device{}
    @editable   Configurations : rr_abstract_config = rr_config_duos{}
    StateMachine:fn_gameplay_state_machine = fn_gameplay_state_machine{}

    OnBegin<override>()<suspends>:void =
        spawn{AwaitServerCrash()}
        InitializeTeamCombatInteractionManager(GetFirstTagged(combat_dbno_device{}, down_but_not_out_device), GetPlayspace().GetTeamCollection())
        InitializeAnalyzerAwarder()

        ParticipantManager := BuildParticipantManager()
        TeamSelector := BuildTeamSelector(ParticipantManager)
        Rebooter := BuildReloadRebooter()
        ScoreController := BuildScoreController(ParticipantManager, TeamSelector)
        RoundManager := BuildRoundManager(ParticipantManager, ScoreController, Rebooter)
        HubManager := BuildHubManager(ParticipantManager)
        ChestManager := BuildChestManager()

        StateMachine.AddStateHandler(BuildWaitingPlayersStateHandler(ParticipantManager, HubManager))
        StateMachine.AddStateHandler(BuildTeamSelectStateHandler(ParticipantManager, TeamSelector, ScoreController))
        StateMachine.AddStateHandler(BuildTransitionStateHandler(ParticipantManager, TeamSelector, RoundManager))
        StateMachine.AddStateHandler(BuildCombatRoundStateHandler(RoundManager, ScoreController))
        StateMachine.AddStateHandler(BuildEndStateHandler(ParticipantManager, HubManager, ScoreController))

        StateMachine.AddStateObserver(ParticipantManager)
        
        if(Configurations.Teams.TeamCapacity > 1):
            ParticipantManager.ParticipantInitializedEvent().SubscribeAwaitable(TeamSelector.Neutralize)
        ParticipantManager.ParticipantExitEvent().SubscribeAwaitable(Rebooter.Unregister)
        
        for(Participant : GetPlayspace().GetParticipants()):
            ParticipantManager.OnParticipantEntry(Participant)

        StateMachine.Start(?StateToStart:=comparable(rr_state_enum.WaitingForPlayers))

    BuildWaitingPlayersStateHandler<internal>(ParticipantManager:rr_participant_manager, HubManager:rr_hub_manager):rr_waiting_players_state_handler =
        WaitingPlayersStateHandler := rr_waiting_players_state_handler:
            ParticipantManager := ParticipantManager
            HubManager := HubManager
            WaitingForPlayersTimer := GetFirstTagged(waiting_players_timer_tag{}, timer_device)
            AutoStartMinimum := Configurations.AutoStartMinimum
            AutoStartVoteUI := GetFirstTagged(auto_start_voting_tag{}, popup_dialog_device)
            AutoStartVotingTimer := GetFirstTagged(auto_start_voting_tag{}, timer_device)
            RebootVanTimer := GetFirstTagged(van_starting_timer_tag{}, timer_device)
            HUDMessageDevice := GetFirstTagged(generic_hud_message_tag{}, hud_message_device)
        WaitingPlayersStateHandler

    BuildTeamSelectStateHandler<internal>(ParticipantManager:rr_participant_manager, TeamSelector:rr_team_selector, ScoreController:rr_scoring_controller):rr_team_select_state_handler =
        rr_team_select_state_handler:
            ParticipantManager := ParticipantManager
            ScoreController := ScoreController
            TeamProp := GetFirstTagged(team_prop_tag{}, creative_prop)
            TeamSelector := TeamSelector
            TeamSelectSFX := GetFirstTagged(state_sfx_tag{}, audio_player_device)
            TeamSelectTimer := hud_message_timer:
                HUDMessageDevice := GetFirstTagged(team_select_auto_timer_tag{}, hud_message_device)
            TeamSelectTimerDurationMap := Configurations.Teams.TeamSelectTimerDurationMap
            DefaultTeamSelectTimerDuration := Configurations.Teams.DefaultTeamSelectTimerDuration

    BuildTransitionStateHandler<internal>(ParticipantManager:rr_participant_manager, TeamSelector:rr_team_selector, RoundManager:rr_round_manager):rr_transition_state_handler =
        rr_transition_state_handler:
            ParticipantManager := ParticipantManager
            TeamConfig := Configurations.Teams
            TeamSelector := TeamSelector
            RoundManager := RoundManager

    BuildCombatRoundStateHandler<internal>(RoundManager:rr_round_manager, ScoreController:rr_scoring_controller):rr_combat_round_state_handler =
        rr_combat_round_state_handler:
            RoundManager := RoundManager
            ScoreController := ScoreController

    BuildEndStateHandler<internal>(ParticipantManager:rr_participant_manager, HubManager:rr_hub_manager, ScoreController:rr_scoring_controller):rr_end_state_handler =
        rr_end_state_handler:
            ParticipantManager := ParticipantManager
            HubManager := HubManager
            ScoreController := ScoreController
            RematchRequeueTimer := GetFirstTagged(rematch_requeue_auto_timer_tag{}, timer_device)
            OpponentsLeftTimer := GetFirstTagged(opponents_left_auto_timer_tag{}, timer_device)

    BuildParticipantManager<internal>():rr_participant_manager =
        ParticipantManager := rr_participant_manager:
            FortPlayspace := GetPlayspace()
            HUDMessageDevice := GetFirstTagged(generic_hud_message_tag{}, hud_message_device)
        EntryEvents := array:
            GetFirstTagged(initialize_mutator_tag{}, mutator_zone_device).AgentEntersEvent
        ExitEvents := array:
            GetPlayspace().ParticipantRemovedEvent()
        ParticipantManager.SubscribeEntryAndExits(EntryEvents, ExitEvents)
        ParticipantManager

    BuildTeamSelector<internal>(ParticipantManager : rr_participant_manager):rr_team_selector = 
        TeamSelector := rr_team_selector:
            ParticipantManager := ParticipantManager
            TeamCollection := GetPlayspace().GetTeamCollection()
            SelectableTeams := BuildSelectableTeams()
            SelectableTeamCapacity := Configurations.Teams.TeamCapacity
            MinimumTeamSizeForKeepSelect := Configurations.Teams.MinimumSizeForKeepSelect
            MinimumSelectableTeams := Configurations.Teams.MinimumNumberOfTeams
            NeutralizedIndex := Configurations.Teams.NeutralizedIndex
            NeutralizedTeleporters := GetTaggedObjects(team_tp_tag{}, teleporter_device)
            NeutralizedSFXDevice := GetFirstTagged(neutral_team_tag{}, audio_player_device)
            HUDMessageDevice := GetFirstTagged(generic_hud_message_tag{}, hud_message_device)
        TeamSelector.Initialize()
        TeamSelector

    BuildSelectableTeams<internal>():[]rr_selectable_team =
        for:
            SelectableTeamConfig:Configurations.Teams.PlayableTeams
            Tag := SelectableTeamConfig.Tag?
        do:
            rr_selectable_team:
                Index := SelectableTeamConfig.Index
                Name := SelectableTeamConfig.Name
                Color := SelectableTeamConfig.Color
                DisplayTeamSelectorDevice := GetFirstTagged(Tag, class_and_team_selector_device)
                MutatorZoneDevice := GetFirstTagged(Tag, mutator_zone_device)
                PlayerCounterDevice := GetFirstTagged(Tag, player_counter_device)
                PlayerReferenceDevices := GetTaggedObjects(Tag, player_reference_device)
                TeleporterDevices := GetTaggedObjects(Tag, teleporter_device)
                SelectSFXDevice := GetFirstTagged(Tag, audio_player_device)
                Tag := option{Tag}

    BuildReloadRebooter<internal>():rr_rebooter =
        rr_rebooter:
            Config := Configurations.Reboot
            TeamCollection := GetPlayspace().GetTeamCollection()
            DBNODevice := GetFirstTagged(combat_dbno_device{}, down_but_not_out_device)
            TimeSkipHUD := GetFirstTagged(reboot_time_skip_tag{}, hud_message_device)
            AllowedHUD := GetFirstTagged(reboot_enabled_hud_tag{}, hud_message_device)
            DisallowedHUDCorner := GetFirstTagged(reboot_disabled_corner_tag{}, hud_message_device)
            DisallowedHUDCenter := GetFirstTagged(reboot_disabled_center_tag{}, hud_message_device)
            RebootsEndingHUDTimerCorner := hud_message_timer:
                HUDMessageDevice := GetFirstTagged(reboot_status_corner_tag{}, hud_message_device)
                KeepTimerOnScreenAfterSuccess := option{2.75}
            RebootsEndingHUDTimerCenter := hud_message_timer:
                HUDMessageDevice := GetFirstTagged(reboot_status_center_tag{}, hud_message_device)
            RebootsEndingTimerTickSFX := GetFirstTagged(reboot_timer_sfx_tag{}, audio_player_device)
            RebootsEndingUrgentTimerTickSFX := GetFirstTagged(reboot_urgent_timer_sfx_tag{}, audio_player_device)
            WipeHUD := GetFirstTagged(reboot_team_wipe_tag{}, hud_message_device)
            WipeSFX := GetFirstTagged(reboot_team_wipe_tag{}, audio_player_device)
            RiftAsset := RebootRiftAsset
            RiftSFX := GetFirstTagged(reboot_rift_sfx_tag{}, audio_player_device)
            RiftTeleporterDevices := GetTaggedObjects(reboot_sky_tp_tag{}, teleporter_device)
            RebootTimer := hud_message_timer:
                HUDMessageDevice := GetFirstTagged(reboot_respawn_tag{}, hud_message_device)
            RebootItemGranter := GetFirstTagged(reboot_granter_tag{}, item_granter_device)
            RebootMessageFeed := RebootMessageFeed
            HoldToRebootInputTrigger := GetFirstTagged(reboot_input_tag{}, input_trigger_device)
            HoldToRebootUI := GetFirstTagged(reboot_input_hud_tag{}, hud_message_device)
            HoldToRebootUIAnimation := GetFirstTagged(reboot_input_anim_tag{}, hud_message_device)
            HoldToRebootArrowHUD := GetFirstTagged(reboot_input_arrow_tag{}, hud_message_device)
            DisallowedSFX := GetFirstTagged(reboot_disallowed_sfx_tag{}, audio_player_device)
            RebootBanks := for:
                RebootBankTag:Configurations.Reboot.RebootBankTags
                RebootBankHUDMessage := GetTaggedObjects(RebootBankTag, hud_message_device)[0]
            do:
                RebootBankHUDMessage
            NoRebootBank := option{GetTaggedObjects(Configurations.Reboot.RebootNoBankTag?, hud_message_device)[0]}
            OvershieldHalfSelector := GetFirstTagged(reboot_50_over_tag{}, class_and_team_selector_device)
            OvershieldFullSelector := GetFirstTagged(reboot_100_over_tag{}, class_and_team_selector_device)

    BuildScoreController<internal>(ParticipantManager:rr_participant_manager, TeamSelector:rr_team_selector):rr_scoring_controller =
        rr_scoring_controller:
            TeamIndexConfigMap := Dict of for(SelectableTeamConfig : Configurations.Teams.PlayableTeams):
                (SelectableTeamConfig.Index, SelectableTeamConfig)
            TeamCollection := GetPlayspace().GetTeamCollection()
            View := rr_scoring_view:
                Config := Configurations.Scoring
                RoundWinnerReferenceDevices := GetTaggedObjects(round_win_reference_tag{}, player_reference_device)
                GameWinnerReferenceDevices := GetTaggedObjects(game_win_reference_tag{}, player_reference_device)
                RoundWinHUD := GetFirstTagged(win_round_hud_tag{}, hud_message_device)
                RoundLoseHUD := GetFirstTagged(lose_round_hud_tag{}, hud_message_device)

    BuildRoundManager<internal>(ParticipantManager:rr_participant_manager, ScoreController : rr_scoring_controller, Rebooter : rr_rebooter):rr_round_manager =
        rr_round_manager:
            TeamCapacity := Configurations.Teams.TeamCapacity
            Config := Configurations.Rounds
            ParticipantManager := ParticipantManager
            TeamCollection := GetPlayspace().GetTeamCollection()
            PlayableTeams := Configurations.Teams.PlayableTeams
            ScoreController := ScoreController
            Rebooter := Rebooter
            LoadoutSelector := BuildLoadoutSelector()
            EliminationManagerDevice := GetFirstTagged(round_elim_manager_tag{}, elimination_manager_device)
            POIs := BuildPOIs()
            DBNODevice := GetFirstTagged(combat_dbno_device{}, down_but_not_out_device)
            StormDevice := GetFirstTagged(round_storm_device_tag{}, storm_controller_device)
            StormBeacons := BuildStormBeacons()
            BarrierTimerHUD := hud_message_timer:
                HUDMessageDevice := GetFirstTagged(round_barrier_tag{}, hud_message_device)
                Duration:=10.0
            BarrierSFX := GetFirstTagged(round_barrier_tag{}, audio_player_device)
            SupplyDropSpawners := GetTaggedObjects(round_supply_spawner_tag{}, supply_drop_spawner_device)
            RoundPOIHUD := GetFirstTagged(round_poi_hud_tag{}, hud_message_device)
            POIBarrier := GetFirstTagged(round_barrier_tag{}, barrier_device)

    BuildStormBeacons<internal>():[]advanced_storm_beacon_device =
        for:
            StormBeaconTag : Configurations.Rounds.StormBeaconTags
            StormBeacon := GetTaggedObjects(StormBeaconTag, advanced_storm_beacon_device)[0]
        do:
            StormBeacon
        
    BuildLoadoutSelector<internal>():rr_loadout_selector =
        LoadoutSelector := rr_loadout_selector:
            WeaponSelectDialog := GetFirstTagged(loadout_ui_tag{}, popup_dialog_device)
            KeepSelectDialog := GetFirstTagged(keep_loadout_dialog_tag{}, popup_dialog_device)
            AlwaysGranter := GetFirstTagged(always_granter_tag{}, item_granter_device)
            ItemRemover := GetFirstTagged(item_remover_tag{}, item_remover_device)
            LoadoutGranters := BuildLoadoutGranters()
            RandomGranters := GetTaggedObjects(random_granter_tag{}, item_granter_device)
        LoadoutSelector.Initialize()
        LoadoutSelector

    BuildLoadoutGranters<internal>():[]item_granter_device =
        for:
            LoadoutTag : Configurations.LoadoutTags
            LoadoutGranter := GetTaggedObjects(LoadoutTag, item_granter_device)[0]
        do:
            LoadoutGranter

    BuildPOIs<internal>():[]rr_poi =
        Shuffle of for:
            POI : Configurations.POIs.TagAndNames
            GetTaggedObjects(POI(0), creative_device_base)[0]
        do:
            BuildPOI(POI)

    BuildPOI<internal>(TagAndName:tuple(rr_poi_tags, string)):rr_poi =
        rr_poi:
            Name := TagAndName(1)
            Barriers := for:
                Obj : FindCreativeObjectsWithTag(TagAndName(0))
                Barrier := barrier_device[Obj]
            do:
                Barrier
            TeamPairings := for(TeleporterPairingTags : Configurations.POIs.TeleporterPairingTags):
                ((TagAndName(0), TeleporterPairingTags, first_team_tag{}), (TagAndName(0), TeleporterPairingTags, second_team_tag{})).MapTup(BuildPOITeleporters)
            CenterPositionProp := GetFirstTagged(TagAndName(0), creative_prop)

    BuildPOITeleporters<internal>(POITag : rr_poi_tags, TeleporterPairingTags : rr_poi_pairing_tags, TeamTag : rr_poi_pairing_tags):[]teleporter_device =
        FilterOp of for(Obj : FindCreativeObjectsWithTag(POITag)):
            TagView := Obj.GetTags()
            if:
                TagView.HasAll[array{TeleporterPairingTags, TeamTag}]
                Teleporter := teleporter_device[Obj]
            then:
                option{Teleporter}
            else:
                false

    BuildHubManager<internal>(ParticipantManager : rr_participant_manager):rr_hub_manager =
        rr_hub_manager:
            WinnerRematchProp := GetFirstTagged(winning_stage_tag{}, creative_prop)
            SpawnTeleporters := GetTaggedObjects(spawn_tp_tag{}, teleporter_device)

    BuildChestManager<internal>():rr_chest_manager =
        ChestManager := rr_chest_manager:
            ChestTracker := GetFirstTagged(chest_tag{}, tracker_device)
            ChestGranters := GetTaggedObjects(chest_tag{}, item_granter_device)
        ChestManager.Initialize()
        ChestManager

    InitializeAnalyzerAwarder<internal>():rr_analyzer_awarder =
        AnalyzerAwarder := rr_analyzer_awarder:
            CollectedCoin := GetFirstTagged(coin_collectible_tag{}, accolades_device)
            Collectibles := GetTaggedObjects(coin_collectible_tag{}, collectible_object_device)
            LobbyAFK := GetFirstTagged(lobby_afk_tag{}, accolades_device)
            LobbyMutator := GetFirstTagged(lobby_afk_tag{}, mutator_zone_device)
            SupplyDropOpen := GetFirstTagged(supply_drop_open_tag{}, accolades_device)
            SelectedTeam := GetFirstTagged(selected_team_tag{}, accolades_device)
            Rebooted := GetFirstTagged(rebooted_tag{}, accolades_device)
            Knock := GetFirstTagged(knock_opponent_tag{}, accolades_device)
            Elimination := GetFirstTagged(eliminate_opponent_tag{}, accolades_device)
            TeamWipe := GetFirstTagged(team_wipe_xp_tag{}, accolades_device)
            PlayedRound := GetFirstTagged(played_round_tag{}, accolades_device)
            WonRound := GetFirstTagged(won_round_tag{}, accolades_device)
            PlayedGame := GetFirstTagged(played_game_tag{}, accolades_device)
            WonGame := GetFirstTagged(won_game_tag{}, accolades_device)
            ChestOpen := GetFirstTagged(chest_tag{}, accolades_device)
            DefaultSelected := GetFirstTagged(default_selected_tag{}, analytics_device)
            SelectedLoadout1 := GetFirstTagged(selected_loadout_1_tag{}, analytics_device)
            SelectedLoadout2 := GetFirstTagged(selected_loadout_2_tag{}, analytics_device)
            SelectedLoadout3 := GetFirstTagged(selected_loadout_3_tag{}, analytics_device)
            SelectedLoadout4 := GetFirstTagged(selected_loadout_4_tag{}, analytics_device)
            SelectedLoadout5 := GetFirstTagged(selected_loadout_5_tag{}, analytics_device)
            SelectedLoadout6 := GetFirstTagged(selected_loadout_6_tag{}, analytics_device)
        AnalyzerAwarder.Initialize()
        AnalyzerAwarder

    AwaitServerCrash()<suspends>:void = 
        ServerCrashTrigger := GetFirstTagged(server_crash_trigger_tag{}, trigger_device)
        loop:
            ServerCrashTrigger.Trigger()
            Sleep(0.1)