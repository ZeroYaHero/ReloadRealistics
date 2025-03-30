using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Colors }

using { FN_Gameplay }
using { config }

server_crash_trigger_tag := class(tag){}

var <internal>MainDevicePlayspaceMap<internal> : weak_map(session, fort_playspace) = map{}

GetMainDevicePlayspace()<transacts>:fort_playspace = 
    MainDevicePlayspaceMap[GetSession()] or PrintAndErr("Tried to get MainDevicePlayspace before set")

# Change to RR device
rr_device := class(creative_device):

    @editable       RebootRiftAsset : creative_prop_asset = DefaultCreativePropAsset
    @editable       RebootMessageFeed : elimination_feed_device = elimination_feed_device{}
    @editable       Configurations : rr_abstract_config = rr_config_duos{}

    StateMachine : rr_state_machine = rr_state_machine{}

    OnBegin<override>()<suspends>:void =
        spawn{AwaitServerCrash()}
        InitializeGlobals()

        ParticipantManager := BuildParticipantManager()
        HubManager := BuildHubManager(ParticipantManager)
        TeamSelector := BuildTeamSelector(ParticipantManager)
        ScoreModel := BuildScoreModel()
        ScoreView := BuildScoreView(ScoreModel, TeamSelector) 
        RoundManager := BuildRoundManager(TeamSelector, ScoreModel)

        StateMachine.AddStateObserver(ParticipantManager)
        StateMachine.AddStateHandler(ScoreModel)
        StateMachine.AddStateHandler(ScoreView)
        StateMachine.AddStateHandler(TeamSelector)
        StateMachine.AddStateHandler(RoundManager)
        StateMachine.AddStateHandler(HubManager)

        # StateMachine.AddAutoCompleteTimer(rr_state_enum.TeamSelect, GetFirstTaggedOfType(team_select_auto_timer_tag{}, timer_device), rr_state_enum.CombatRound, ?StartOnState := false)
        StateMachine.AddAutoCompleteTimer(rr_state_enum.RematchRequeue, GetFirstTaggedOfType(rematch_requeue_auto_timer_tag{}, timer_device), rr_state_enum.GameEnd, ?StartOnState := true)
        StateMachine.AddAutoCompleteTimer(rr_state_enum.OpponentsLeft, GetFirstTaggedOfType(opponents_left_auto_timer_tag{}, timer_device), rr_state_enum.GameEnd, ?StartOnState := true)
        StateMachine.AddAutoCompleteTimer(rr_state_enum.WaitingForPlayers, GetFirstTaggedOfType(van_starting_timer_tag{}, timer_device), rr_state_enum.TeamSelect, ?StartOnState := false)

        for(Participant : GetPlayspace().GetParticipants()):
            ParticipantManager.OnParticipantEntry(Participant)

        StateMachine.Start(?StateToStart:=comparable(rr_state_enum.WaitingForPlayers))

    AwaitServerCrash()<suspends>:void = 
        ServerCrashTrigger := GetFirstTaggedOfType(server_crash_trigger_tag{}, trigger_device)
        loop:
            ServerCrashTrigger.Trigger()
            Sleep(0.1)

    InitializeGlobals():void =
        if:
            set MainDevicePlayspaceMap[GetSession()] = GetPlayspace()
        else:
            PrintAndErr("Failed to add MainDevicePlayspace to WeakMap")
        InitializeTeamCombatInteractionManager(GetFirstTaggedOfType(combat_dbno_device{}, down_but_not_out_device), GetPlayspace().GetTeamCollection())
        BuildAnalyzerAwarder()

    BuildHubManager<internal>(ParticipantManager : rr_participant_manager):rr_hub_manager =
        rr_hub_manager:
            ParticipantManager := ParticipantManager
            OnePlayerHUD := GetFirstTaggedOfType(one_player_hud_tag{}, hud_message_device)
            WaitingForPlayersTimer := GetFirstTaggedOfType(waiting_players_timer_tag{}, timer_device)
            AutoStartMinimum := Configurations.AutoStartMinimum
            AutoStartVotingTimer := GetFirstTaggedOfType(auto_start_voting_tag{}, timer_device)
            AutoStartVoteUI := GetFirstTaggedOfType(auto_start_voting_tag{}, popup_dialog_device)
            AutoStartFailedHUD := GetFirstTaggedOfType(auto_start_voting_tag{}, hud_message_device)
            WinnerRematchProp := GetFirstTaggedOfType(winning_stage_tag{}, creative_prop)
            SpawnTeleporters := GetTaggedObjects(spawn_tp_tag{}, teleporter_device)
            RebootVanTimer := GetFirstTaggedOfType(van_starting_timer_tag{}, timer_device)

    BuildParticipantManager<internal>():rr_participant_manager =
        ParticipantManager := rr_participant_manager:
            FortPlayspace := GetPlayspace()
            MiddleOfRoundHUD := GetFirstTaggedOfType(middle_round_hud_tag{}, hud_message_device)
        EntryEvents := array:
            GetFirstTaggedOfType(initialize_mutator_tag{}, mutator_zone_device).AgentEntersEvent
        ExitEvents := array:
            GetPlayspace().ParticipantRemovedEvent()
        ParticipantManager.SubscribeEntryAndExits(EntryEvents, ExitEvents)
        ParticipantManager

    BuildScoreModel<internal>():rr_score_model =
        rr_score_model:
            ScoreManagerDevice := GetFirstTaggedOfType(score_device_tag{}, score_manager_device)
            WinRoundHUD := GetFirstTaggedOfType(win_round_hud_tag{}, hud_message_device)
            LoseRoundHUD := GetFirstTaggedOfType(lose_round_hud_tag{}, hud_message_device)
            BestPerformingPlayerReferences := GetTaggedObjects(game_win_reference_tag{}, player_reference_device)
            RoundWinPlayerReferences := GetTaggedObjects(round_win_reference_tag{}, player_reference_device)

    BuildScoreView<internal>(ScoreModel : rr_score_model, TeamSelector : rr_team_selector):rr_score_view = 
        ScoreView := rr_score_view:
            ScoreModel := ScoreModel
            TeamSelector := TeamSelector
            Parameters := Configurations.ScoreHUD
            TeamIndexColorMap := Configurations.SelectableTeamParameters.IndexColorMap()
        ScoreView

    BuildAnalyzerAwarder<internal>():rr_analyzer_awarder =
        AnalyzerAwarder := rr_analyzer_awarder:
            CollectedCoin := GetFirstTaggedOfType(coin_collectible_tag{}, accolades_device)
            Collectibles := GetTaggedObjects(coin_collectible_tag{}, collectible_object_device)
            LobbyAFK := GetFirstTaggedOfType(lobby_afk_tag{}, accolades_device)
            LobbyMutator := GetFirstTaggedOfType(lobby_afk_tag{}, mutator_zone_device)
            SupplyDropOpen := GetFirstTaggedOfType(supply_drop_open_tag{}, accolades_device)
            SelectedTeam := GetFirstTaggedOfType(selected_team_tag{}, accolades_device)
            Rebooted := GetFirstTaggedOfType(rebooted_tag{}, accolades_device)
            Knock := GetFirstTaggedOfType(knock_opponent_tag{}, accolades_device)
            Elimination := GetFirstTaggedOfType(eliminate_opponent_tag{}, accolades_device)
            TeamWipe := GetFirstTaggedOfType(team_wipe_xp_tag{}, accolades_device)
            PlayedRound := GetFirstTaggedOfType(played_round_tag{}, accolades_device)
            WonRound := GetFirstTaggedOfType(won_round_tag{}, accolades_device)
            PlayedGame := GetFirstTaggedOfType(played_game_tag{}, accolades_device)
            WonGame := GetFirstTaggedOfType(won_game_tag{}, accolades_device)
            DefaultSelected := GetFirstTaggedOfType(default_selected_tag{}, analytics_device)
            SelectedLoadout1 := GetFirstTaggedOfType(selected_loadout_1_tag{}, analytics_device)
            SelectedLoadout2 := GetFirstTaggedOfType(selected_loadout_2_tag{}, analytics_device)
            SelectedLoadout3 := GetFirstTaggedOfType(selected_loadout_3_tag{}, analytics_device)
            SelectedLoadout4 := GetFirstTaggedOfType(selected_loadout_4_tag{}, analytics_device)
            SelectedLoadout5 := GetFirstTaggedOfType(selected_loadout_5_tag{}, analytics_device)
            SelectedLoadout6 := GetFirstTaggedOfType(selected_loadout_6_tag{}, analytics_device)
        AnalyzerAwarder.Initialize()
        AnalyzerAwarder

    BuildTeamSelector<internal>(ParticipantManager : rr_participant_manager):rr_team_selector = 
        TeamSelector := rr_team_selector:
            TeamCollection := GetPlayspace().GetTeamCollection()
            ParticipantManager := ParticipantManager
            # SelectTeamDialog := GetFirstTaggedOfType(jip_team_ui_tag{}, popup_dialog_device)
            FailedSelectHUD := GetFirstTaggedOfType(failed_join_hud_tag{}, hud_message_device)
            SelectableTeams := BuildSelectableTeams()
            NeutralTeamSelector := GetFirstTaggedOfType(neutral_team_tag{}, class_and_team_selector_device)
            NeutralTeamSFX := GetFirstTaggedOfType(neutral_team_tag{}, audio_player_device)
            NeutralTeamIndex := Configurations.NeutralTeamIndex
            SelectableTeamCapacity := Configurations.SelectableTeamCapacity
            MinimumSelectableTeams := Configurations.MinimumSelectableTeams
            TeamSelectTeleporters := GetTaggedObjects(team_tp_tag{}, teleporter_device)
            TeamSelectTimerHUD := custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(team_select_auto_timer_tag{}, hud_message_device)
            TeamSelectStateSFX := GetFirstTaggedOfType(state_sfx_tag{}, audio_player_device)
            TeamSelectTimerDurationMap := Configurations.TeamSelectTimerDurationMap
        TeamSelector.Initialize()
        TeamSelector

    BuildSelectableTeams<internal>():[]rr_selectable_team =
        var SelectableTeams : []rr_selectable_team = array{}
        for:
            Index -> TeamParameter : Configurations.SelectableTeamParameters
            TeamTag := Configurations.TeamTags[Index]
        do:
            MaybeSelectableTeam := BuildSelectableTeam(TeamParameter, TeamTag)
            if(SelectableTeam := MaybeSelectableTeam?):
                set SelectableTeams += array{SelectableTeam}
            else:
                PrintAndErr("Could not build Team Data for Team Tag {Index + 1}")
        SelectableTeams

    BuildSelectableTeam<internal>(TeamParameter : rr_selectable_team_parameter, TeamTag : selectable_teams_tag):?rr_selectable_team =
        TaggedObjects := FindCreativeObjectsWithTag(TeamTag)
        if:
            SelectVolume := TaggedObjects.CastGeneratedObjects(mutator_zone_device)[0]
            ClassAndTeamSelector := TaggedObjects.CastGeneratedObjects(class_and_team_selector_device)[0]
            SFX := TaggedObjects.CastGeneratedObjects(audio_player_device)[0]
        then:
            VolumeTeleporters := TaggedObjects.CastGeneratedObjects(teleporter_device)
            PlayerReferenceDevices := TaggedObjects.CastGeneratedObjects(player_reference_device)
            for:
                Obj : TaggedObjects
                MaybeDisplayTeamSelectorSelector := class_and_team_selector_device[Obj]
            do:
                TagView := MaybeDisplayTeamSelectorSelector.GetTags()
                if(TagView.Has[display_selector_tag{}]):
                    return option:
                        rr_selectable_team:
                            Index := TeamParameter.Index
                            Color := TeamParameter.Color
                            SelectVolume := SelectVolume
                            Selector := ClassAndTeamSelector
                            DisplaySelector := MaybeDisplayTeamSelectorSelector
                            PlayerReferenceDevices := PlayerReferenceDevices
                            VolumeTeleporters := VolumeTeleporters
                            SFX := SFX
        return false

    BuildRoundManager<internal>(TeamSelector : rr_team_selector, ScoreModel : rr_score_model):rr_round_manager =
        rr_round_manager:
            ScoreModel := ScoreModel
            RebootManager := BuildRebootManager()
            LoadoutSelector := BuildLoadoutSelector()
            TeamSelector := TeamSelector
            POIs := BuildPOIs()
            StormDevice := GetFirstTaggedOfType(round_storm_device_tag{}, storm_controller_device)
            StormBeacons := BuildStormBeacons()
            StormRanges := Configurations.StormRanges
            BarrierTimerHUD := custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(round_barrier_timer_hud_tag{}, hud_message_device)
                Duration:=10.0
            SupplyDropSpawners := GetTaggedObjects(round_supply_spawner_tag{}, supply_drop_spawner_device)
            InitialStormPhaseRadiusCM := Configurations.InitialStormPhaseRadiusCM
            SupplyDropTimesAndQuantities := Configurations.SupplyDropTimesAndQuantities

    BuildStormBeacons<internal>():[]advanced_storm_beacon_device =
        for:
            StormBeaconTag : Configurations.StormBeaconTags
            StormBeacon := GetTaggedObjects(StormBeaconTag, advanced_storm_beacon_device)[0]
        do:
            StormBeacon
        
    BuildLoadoutSelector<internal>():rr_loadout_selector =
        ItemManager := rr_loadout_selector:
            WeaponSelectDialog := GetFirstTaggedOfType(loadout_ui_tag{}, popup_dialog_device)
            KeepSelectDialog := GetFirstTaggedOfType(keep_loadout_dialog_tag{}, popup_dialog_device)
            AlwaysGranter := GetFirstTaggedOfType(always_granter_tag{}, item_granter_device)
            ItemRemover := GetFirstTaggedOfType(item_remover_tag{}, item_remover_device)
            LoadoutGranters := BuildLoadoutGranters()
            RandomGranters := GetTaggedObjects(random_granter_tag{}, item_granter_device)
        ItemManager.Initialize()
        return ItemManager

    BuildLoadoutGranters<internal>():[]item_granter_device =
        for:
            LoadoutTag : Configurations.LoadoutTags
            LoadoutGranter := GetTaggedObjects(LoadoutTag, item_granter_device)[0]
        do:
            LoadoutGranter

    BuildPOIs<internal>():[]rr_poi =
        Shuffle of for:
            POITag : Configurations.POITags
            GetTaggedObjects(POITag, creative_device_base)[0]
        do:
            BuildPOI(POITag)

    BuildPOI<internal>(POITag : rr_poi_tags):rr_poi =
        rr_poi:
            Barriers := for:
                Obj : FindCreativeObjectsWithTag(POITag)
                Barrier := barrier_device[Obj]
            do:
                Barrier
            TeamPairings := for(PairingTag : Configurations.PairingTags):
                ((POITag, PairingTag, first_team_tag{}), (POITag, PairingTag, second_team_tag{})).MapTup(BuildPOITeleporters)
            CenterPositionProp := GetFirstTaggedOfType(POITag, creative_prop)

    BuildPOITeleporters<internal>(POITag : rr_poi_tags, PairingTag : rr_poi_pairing_tags, TeamTag : rr_poi_pairing_tags):[]teleporter_device =
        FilterOp of for(Obj : FindCreativeObjectsWithTag(POITag)):
            TagView := Obj.GetTags()
            if:
                TagView.HasAll[array{PairingTag, TeamTag}]
                Teleporter := teleporter_device[Obj]
            then:
                option{Teleporter}
            else:
                false

    BuildRebootManager<internal>():rr_reboot_manager = 
        rr_reboot_manager:
            RebootParameters := Configurations.Reboot
            RebootTimerDevice := GetFirstTaggedOfType(reboot_respawn_tag{}, timer_device)
            DisabledHUD := GetFirstTaggedOfType(reboot_disabled_corner_tag{}, hud_message_device)
            ItemGranter := GetFirstTaggedOfType(reboot_granter_tag{}, item_granter_device)
            TeamWipeHUD := GetFirstTaggedOfType(reboot_team_wipe_tag{}, hud_message_device)
            TeamWipeSFX := GetFirstTaggedOfType(reboot_team_wipe_tag{}, audio_player_device)
            HoldToRebootTrigger := GetFirstTaggedOfType(reboot_input_tag{}, input_trigger_device)
            HoldToRebootHUDNoAnim := GetFirstTaggedOfType(reboot_input_hud_tag{}, hud_message_device)
            HoldToRebootHUDAnim := GetFirstTaggedOfType(reboot_input_anim_tag{}, hud_message_device)
            StatusTimerCenterHUD :=  custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(reboot_status_center_tag{}, hud_message_device)
            StatusTimerCornerHUD :=  custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(reboot_status_corner_tag{}, hud_message_device)
            DBNODevice := GetFirstTaggedOfType(combat_dbno_device{}, down_but_not_out_device)
            RebootMessageFeed := RebootMessageFeed
            SkyDiveTeleporters := GetTaggedObjects(reboot_sky_tp_tag{}, teleporter_device)
            RiftAsset := RebootRiftAsset
            RiftSFX := GetFirstTaggedOfType(reboot_rift_sfx_tag{}, audio_player_device)
            EnabledHUD := GetFirstTaggedOfType(reboot_enabled_hud_tag{}, hud_message_device)