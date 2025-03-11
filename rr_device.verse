using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Colors }

using { FN_Gameplay }

var <internal>MainDevicePlayspaceMap<internal> : weak_map(session, fort_playspace) = map{}

GetMainDevicePlayspace()<transacts>:fort_playspace = 
    MainDevicePlayspaceMap[GetSession()] or PrintAndErr("Tried to get MainDevicePlayspace before set")

# Change to RR device
rr_device := class(creative_device):

    @editable       RebootParameters : rr_reboot_parameters = rr_reboot_parameters{}

    @editable       ScoreHUDParameters : rr_score_hud_parameters = rr_score_hud_parameters{}

    @editable       SelectableTeamParameters : []rr_selectable_team_parameter = array:
        rr_selectable_team_parameter:
            Index := 1
            Color := NamedColors.Blue
        rr_selectable_team_parameter:
            Index := 2
            Color := NamedColors.Red
        rr_selectable_team_parameter:
            Index := 3
            Color := NamedColors.Green
        rr_selectable_team_parameter:
            Index := 4
            Color := NamedColors.Yellow
    @editable       NeutralTeamIndex : int = 0
    @editable       SelectableTeamCapacity : int = 2
    @editable       MinimumSelectableTeams : int = 2

    @editable       AutoStartMinimum : int = 4

    @editable       InitialStormPhaseRadiusCM : float = 8500.0

    OnBegin<override>()<suspends>:void =
        if:
            set MainDevicePlayspaceMap[GetSession()] = GetPlayspace()
        then:
            DBNODevice := GetFirstTaggedOfType(combat_dbno_device{}, down_but_not_out_device)
            InitializeTeamCombatInteractionManager(DBNODevice, GetPlayspace().GetTeamCollection())
            AnalyzerAwarder := BuildAnalyzerAwarder()
            AnalyzerAwarder.Initialize()
            TeamSelector := BuildTeamSelector()
            CombatManager := BuildCombatManager(DBNODevice)
            FiniteStateMachine := BuildFSM(TeamSelector, CombatManager)
            
            FiniteStateMachine.Initialize(rr_state.NotEnoughPlayers)
        else:
            PrintAndErr("Failed to add MainDevicePlayspace to WeakMap")

    BuildFSM<internal>(TeamSelector : rr_team_selector, CombatManager : rr_combat_manager):rr_fsm =
        rr_fsm:
            TeamSelectAutoCompleteTimer := GetFirstTaggedOfType(team_select_auto_timer_tag{}, timer_device)
            RematchRequeueAutoCompleteTimer := GetFirstTaggedOfType(rematch_requeue_auto_timer_tag{}, timer_device)
            OpponentsLeftRestartAutoCompleteTimer := GetFirstTaggedOfType(opponents_left_auto_timer_tag{}, timer_device)

            CombatStartingTimer := GetFirstTaggedOfType(reboot_van_starting_timer_tag{}, timer_device) 
            TeamSelectStartingTimer := GetFirstTaggedOfType(team_select_starting_timer_tag{}, timer_device)

            RoundSettingsDevice := GetFirstTaggedOfType(round_settings_tag{}, round_settings_device)
            EndGameDevice := GetFirstTaggedOfType(end_game_device_tag{}, end_game_device)
            WinnerReferences := GetTaggedObjects(winning_stage_tag{}, player_reference_device)
            WinnerRematchProp := GetFirstTaggedOfType(winning_stage_tag{}, creative_prop)
            OnePlayerHUD := GetFirstTaggedOfType(one_player_hud_tag{}, hud_message_device)
            AutoStartVoteTimer := GetFirstTaggedOfType(auto_vote_ui_tag{}, timer_device)
            AutoStartVoteUI := GetFirstTaggedOfType(auto_vote_ui_tag{}, popup_dialog_device)
            AutoStartFailedHUD := GetFirstTaggedOfType(auto_vote_ui_tag{}, hud_message_device)

            Positions := BuildPositions()

            ScoreHUDManager := BuildScoreHUDManager()
            TeamSelector := TeamSelector
            CombatManager := CombatManager

            AutoStartMinimum := AutoStartMinimum

    BuildCombatManager<internal>(DBNODevice : down_but_not_out_device):rr_combat_manager = 
        rr_combat_manager:
            DBNODevice := DBNODevice
            PrefireMutatorZone := GetFirstTaggedOfType(prefire_mutator_tag{}, mutator_zone_device)
            StormController := GetFirstTaggedOfType(basic_storm_tag{}, basic_storm_controller_device)
            SupplyDropSpawners := GetTaggedObjects(supply_drops_tag{}, supply_drop_spawner_device)
            CustomBarrierTimerHUD := custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(barrier_timer_tag{}, hud_message_device)
            LoadoutSelector := BuildLoadoutSelector()
            POIs := BuildPOIs()
            RebootManager := BuildRebootManager(DBNODevice)
            InitialStormPhaseRadiusCM := InitialStormPhaseRadiusCM
            WinRoundHUD := GetFirstTaggedOfType(win_round_tag{}, hud_message_device)
            LoseRoundHUD := GetFirstTaggedOfType(lose_round_tag{}, hud_message_device)
            SupplyDropTimesAndQuantities := array:
                (10.0, 2)
                (60.0, 3)
                (60.0, 2)

    BuildAnalyzerAwarder<internal>():rr_analyzer_awarder =
        rr_analyzer_awarder:
            LobbyAFK := GetFirstTaggedOfType(lobby_afk{}, accolades_device)
            SelectedTeam := GetFirstTaggedOfType(selected_team{}, accolades_device)
            Rebooted := GetFirstTaggedOfType(rebooted{}, accolades_device)
            Knock := GetFirstTaggedOfType(knock_opponent{}, accolades_device)
            Elimination := GetFirstTaggedOfType(eliminate_opponent{}, accolades_device)
            TeamWipe := GetFirstTaggedOfType(team_wipe{}, accolades_device)
            PlayedRound := GetFirstTaggedOfType(played_round{}, accolades_device)
            WonRound := GetFirstTaggedOfType(won_round{}, accolades_device)
            PlayedGame := GetFirstTaggedOfType(played_game{}, accolades_device)
            WonGame := GetFirstTaggedOfType(won_game{}, accolades_device)

    BuildTeamSelector<internal>():rr_team_selector = 
        rr_team_selector:
            SelectTeamDialog := GetFirstTaggedOfType(jip_team_select_dialog{}, popup_dialog_device)
            FailedSelectHUD := GetFirstTaggedOfType(failed_to_join_team_hud{}, hud_message_device)
            SelectableTeams := BuildSelectableTeams()
            NeutralTeamSelector := GetFirstTaggedOfType(team_neutral_selector_tag{}, class_and_team_selector_device)
            NeutralTeamIndex := NeutralTeamIndex
            SelectableTeamCapacity := SelectableTeamCapacity
            MinimumSelectableTeams := MinimumSelectableTeams

    BuildSelectableTeams<internal>():[]rr_selectable_team =
        var SelectableTeams : []rr_selectable_team = array{}
        TeamTags := array:
            team_one_tag{}
            team_two_tag{}
            team_three_tag{}
            team_four_tag{}
        for:
            Index -> TeamParameter : SelectableTeamParameters
            TeamTag := TeamTags[Index]
        do:
            MaybeSelectableTeam := BuildSelectableTeam(TeamParameter, TeamTag)
            if(SelectableTeam := MaybeSelectableTeam?):
                set SelectableTeams += array{SelectableTeam}
            else:
                PrintAndErr("Could not build Team Data for Team Tag {Index + 1}")
        SelectableTeams

    BuildSelectableTeam<internal>(TeamParameter : rr_selectable_team_parameter, TeamTag : team_verse_tag):?rr_selectable_team =
        if:
            TaggedObjects := FindCreativeObjectsWithTag(TeamTag)
            SelectVolume := TaggedObjects.CastGeneratedObjects(mutator_zone_device)[0]
            ClassAndTeamSelector := TaggedObjects.CastGeneratedObjects(class_and_team_selector_device)[0]
        then:
            PlayerReferenceDevices := TaggedObjects.CastGeneratedObjects(player_reference_device)
            for:
                Obj : TaggedObjects
                MaybeDisplayTeamSelectorSelector := class_and_team_selector_device[Obj]
            do:
                TagView := MaybeDisplayTeamSelectorSelector.GetTags()
                if(TagView.Has[display_selector_device_tag{}]):
                    return option:
                        rr_selectable_team:
                            Index := TeamParameter.Index
                            Color := TeamParameter.Color
                            SelectVolume := SelectVolume
                            Selector := ClassAndTeamSelector
                            DisplaySelector := MaybeDisplayTeamSelectorSelector
                            PlayerReferenceDevices := PlayerReferenceDevices
        return false

    BuildRebootManager<internal>(DBNODevice : down_but_not_out_device):rr_reboot_manager = 
        rr_reboot_manager:
            RebootParameters := RebootParameters
            RebootTimerDevice := GetFirstTaggedOfType(reboot_respawn_tag{}, timer_device)
            DisabledHUD := GetFirstTaggedOfType(reboot_disabled_hud_tag{}, hud_message_device)
            ItemGranter := GetFirstTaggedOfType(reboot_granted_item_tag{}, item_granter_device)
            TeamWipeHUD := GetFirstTaggedOfType(team_wipe_tag{}, hud_message_device)
            HoldToRebootTrigger := GetFirstTaggedOfType(hold_to_reboot_input_tag{}, input_trigger_device)
            HoldToRebootHUDNoAnim := GetFirstTaggedOfType(hold_to_reboot_hud_no_anim{}, hud_message_device)
            HoldToRebootHUDAnim := GetFirstTaggedOfType(hold_to_reboot_hud_anim{}, hud_message_device)
            StatusTimerCenterHUD :=  custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(reboot_status_timer_center_tag{}, hud_message_device)
            StatusTimerCornerHUD :=  custom_hud_timer:
                HUDMessageDevice := GetFirstTaggedOfType(reboot_status_timer_corner_tag{}, hud_message_device)
            DBNODevice := DBNODevice
            RebootMessageFeed := RebootParameters.RebootMessageFeed
            SkyDiveTeleporters := GetTaggedObjects(reboot_skyzone_tag{}, teleporter_device)
            
    BuildScoreHUDManager<internal>():rr_score_hud_manager = 
        ScoreHUDManager := rr_score_hud_manager:
            Parameters := ScoreHUDParameters
            TeamIndexColorMap := SelectableTeamParameters.IndexColorMap()
            WatermarkHUD := GetFirstTaggedOfType(watermark_hud_tag{}, hud_message_device)
        ScoreHUDManager.WatermarkHUD.Show()
        ScoreHUDManager
        
    BuildLoadoutSelector<internal>():rr_loadout_selector =
        AlwaysGranterTag := always_granter{}
        ItemManager := rr_loadout_selector:
            WeaponSelectDialog := GetFirstTaggedOfType(weapon_select_device{}, popup_dialog_device)
            KeepSelectDialog := GetFirstTaggedOfType(keep_loadout_select_device{}, popup_dialog_device)
            AlwaysGranter := GetFirstTaggedOfType(AlwaysGranterTag, item_granter_device)
            ItemRemover := GetFirstTaggedOfType(item_remover{}, item_remover_device)
            LoadoutGranters := BuildLoadoutGranters()
            RandomGranters := GetTaggedObjects(random_granter{}, item_granter_device)
        ItemManager.Initialize()
        return ItemManager

    BuildLoadoutGranters<internal>():[]item_granter_device =
        LoadoutTags := array:
            loadout_granter_1{}
            loadout_granter_2{}
            loadout_granter_3{}
            loadout_granter_4{}
            loadout_granter_5{}
            loadout_granter_6{}
        for:
            LoadoutTag : LoadoutTags
            LoadoutGranter := GetTaggedObjects(LoadoutTag, item_granter_device)[0]
        do:
            LoadoutGranter

    BuildPOIs<internal>():[]rr_poi =
        POITags : []poi_tag = array:
            yacht_poi{}
            motel_poi{}
            pleasant_poi{}
            catty_poi{}
            retail_poi{}
            sands_poi{}
            frosty_poi{}
            factories_poi{}
            crash_poi{}
            weeping_poi{}
        Shuffle of for:
            POITag : POITags
            GetTaggedObjects(POITag, creative_device_base)[0]
        do:
            BuildPOI(POITag)

    BuildPOI<internal>(POITag : poi_tag):rr_poi =
        PairingTags := array{pairing_blue{}, pairing_red{}}
        rr_poi:
            Barriers := for:
                Obj : FindCreativeObjectsWithTag(POITag)
                Barrier := barrier_device[Obj]
            do:
                Barrier
            TeamPairings := for(PairingTag : PairingTags):
                ((POITag, PairingTag, first_team{}), (POITag, PairingTag, second_team{})).MapTup(BuildPOITeleporters)
            CenterPositionProp := GetFirstTaggedOfType(POITag, creative_prop)

    BuildPOITeleporters<internal>(POITag : poi_tag, PairingTag : pairing_tp, TeamTag : pairing_tp):[]teleporter_device =
        FilterOp of for(Obj : FindCreativeObjectsWithTag(POITag)):
            TagView := Obj.GetTags()
            if:
                TagView.HasAll[array{PairingTag, TeamTag}]
                Teleporter := teleporter_device[Obj]
            then:
                option{Teleporter}
            else:
                false

    BuildPositions<internal>():rr_positions =
        rr_positions:
            Lobby := for(Obj : FindCreativeObjectsWithTag(lobby_tp{}), Teleporter := teleporter_device[Obj]) { Teleporter }
            TeamSelect := for(Obj : FindCreativeObjectsWithTag(team_tp{}), Teleporter := teleporter_device[Obj]) { Teleporter }
            RematchRequeue := for(Obj : FindCreativeObjectsWithTag(rematch_tp{}), Teleporter := teleporter_device[Obj]) { Teleporter }