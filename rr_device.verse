using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }

using { FN_Gameplay }

var <internal>MainDevicePlayspaceMap<internal> : weak_map(session, fort_playspace) = map{}

GetMainDevicePlayspace():fort_playspace = 
    MainDevicePlayspaceMap[GetSession()] or PrintAndErr("Tried to get MainDevicePlayspace before set")

# Change to RR device
rr_device := class(creative_device):

    @editable       LinearStates : []fn_gameplay_state = array:
        fn_gameplay_state:
            Key := "NotEnoughPlayers"
            OptionalAutoCompleteTimer := false
        fn_gameplay_state:
            Key := "OpponentsLeft"
            OptionalAutoCompleteTimer := option{timer_device{}}
        fn_gameplay_state:
            Key := "TeamSelect"
            OptionalAutoCompleteTimer := option{timer_device{}}
        fn_gameplay_state:
            Key := "Combat"
            OptionalAutoCompleteTimer := false
        fn_gameplay_state:
            Key := "RematchRequeue"
            OptionalAutoCompleteTimer := option{timer_device{}}

    @editable       LinearStateLinks : []fn_gameplay_link = array:
        fn_gameplay_link:
            InitialStateKey := "NotEnoughPlayers"
            WhenToSwitch := fn_gameplay_link_type.OnInitialStateCompleted
            EndingStateKey := "TeamSelect"
        fn_gameplay_link:
            InitialStateKey := "TeamSelect"
            WhenToSwitch := fn_gameplay_link_type.OnInitialStateCompleted
            EndingStateKey := "Combat"
        fn_gameplay_link:
            InitialStateKey := "Combat"
            WhenToSwitch := fn_gameplay_link_type.OnInitialStateCompleted
            EndingStateKey := "Combat"
        fn_gameplay_link:
            InitialStateKey := "Combat"
            WhenToSwitch := fn_gameplay_link_type.OnInitialStateFailedToComplete
            EndingStateKey := "RematchRequeue"
        fn_gameplay_link:
            InitialStateKey := "Combat"
            WhenToSwitch := fn_gameplay_link_type.OnInitialStateFailedToInitialze
            EndingStateKey := "OpponentsLeft"

    @editable       RebootParameters : rr_reboot_parameters = rr_reboot_parameters{}

    @editable       TeamParameters : rr_team_parameters = rr_team_parameters:
        Teams := array:
            rr_team_parameter:
                Index := 1
                Capacity := option{2}
            rr_team_parameter:
                Index := 2
                Capacity := option{2}
            rr_team_parameter:
                Index := 3
                Capacity := option{2}
            rr_team_parameter:
                Index := 4
                Capacity := option{2}

    @editable       HUDParameters : rr_hud_parameters = rr_hud_parameters{}

    # TODO: Debug Settings? Allows one player only, test players, etc.
    OnBegin<override>()<suspends>:void =
        if:
            set MainDevicePlayspaceMap[GetSession()] = GetPlayspace()
        then:
            LinkLinearStates(LinearStates, LinearStateLinks)
            InitializeGlobalLinearStates(LinearStates)

            DBNODevice := GetTaggedObjects(combat_dbno_device{}, down_but_not_out_device)[0] or PrintAndErr("Could not find DBNO Device!")
            TeamPlayerManager := BuildTeamPlayerManager(DBNODevice)
            RebootManager := BuildRebootManager(TeamPlayerManager, DBNODevice)
            HUDManager := BuildHUDManager()
            GameflowController := BuildGameflowController(TeamPlayerManager, RebootManager, HUDManager, DBNODevice)
            
            ForceState(GetState["NotEnoughPlayers"] or PrintAndErr("Could not start the game and initialize the NotEnoughPlayers State"))
        else:
            PrintAndErr("Failed to add MainDevicePlayspace to WeakMap")

    BuildTeamPlayerManager<internal>(DBNODevice : down_but_not_out_device):rr_team_and_player_manager =
        TeamPlayerManager := rr_team_and_player_manager:
            TeamCollection := GetPlayspace().GetTeamCollection()
            DefaultCapacity := TeamParameters.DefaultCapacity
            TeamIndexCapacityMap := TeamParameters.IndexCapacityMap()
            FortPlayspace := GetPlayspace()
            TeamsData := BuildTeamsData()
        InitializeTeamCombatInteractionManager(DBNODevice, TeamPlayerManager)
        TeamPlayerManager

    BuildTeamsData<internal>():rr_teams_data =
        TeamTags := array:
            team_one_tag{}
            team_two_tag{}
            team_three_tag{}
            team_four_tag{}
        ParamTagPairs := Zip(TeamParameters.Teams, TeamTags)
        var Teams : []rr_team_data = array{}
        for:
            Index -> ParamTagPair : ParamTagPairs
        do:
            MaybeTeamData := BuildTeamData(ParamTagPair)
            if(TeamData := MaybeTeamData?):
                set Teams += array{TeamData}
            else:
                PrintAndErr("Could not build Team Data for Team Tag {Index + 1}")
        rr_teams_data:
            DefaultCapacity := TeamParameters.DefaultCapacity
            NeutralTeamIndex := TeamParameters.NeutralTeamIndex
            NeutralTeamSelector := GetTaggedObjects(team_neutral_selector_tag{}, class_and_team_selector_device)[0] or PrintAndErr("Could not find NeutralTeamSelector Device!")
            JIPTeamSelectDialog := GetTaggedObjects(jip_team_select_dialog{}, popup_dialog_device)[0]               or PrintAndErr("Could not find JIPTeamSelectDialog Device!")
            FailedToJoinTeamHUD := GetTaggedObjects(failed_to_join_team_hud{}, hud_message_device)[0]               or PrintAndErr("Could not find FailedToJoinTeamHUD Device!")
            Teams := Teams
            TeamSize := 2
    
    BuildTeamData<internal>(TeamParameter : rr_team_parameter, TeamTag : team_verse_tag):?rr_team_data =
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
                        rr_team_data:
                            Parameter := TeamParameter
                            SelectVolume := SelectVolume
                            ClassAndTeamSelector := ClassAndTeamSelector
                            PlayerReferenceDevices := PlayerReferenceDevices
                            DisplayTeamSelector := MaybeDisplayTeamSelectorSelector
        return false

    BuildRebootManager<internal>(TeamPlayerManager : rr_team_and_player_manager, DBNODevice : down_but_not_out_device):rr_reboot_manager = 
        rr_reboot_manager:
            RebootParameters := RebootParameters
            RebootDevices := BuildRebootDevices(DBNODevice)
            TeamPlayerManager := TeamPlayerManager

    BuildRebootDevices<internal>(DBNODevice : down_but_not_out_device):rr_reboot_devices =
        rr_reboot_devices:
            RebootTimerDevice := GetTaggedObjects(reboot_respawn_tag{}, timer_device)[0]                        or PrintAndErr("Could not find RebootRespawnTimer Device!")
            RebootXP := GetTaggedObjects(reboot_respawn_tag{}, accolades_device)[0]                             or PrintAndErr("Could not find RebootXP Device")
            DisabledHUD := GetTaggedObjects(reboot_disabled_hud_tag{}, hud_message_device)[0]                   or PrintAndErr("Could not find RebootDisabledHUD Device!")
            ItemGranter := GetTaggedObjects(reboot_granted_item_tag{}, item_granter_device)[0]                  or PrintAndErr("Could not find RebootItemGranter Device!")
            TeamWipeHUD := GetTaggedObjects(team_wipe_tag{}, hud_message_device)[0]                             or PrintAndErr("Could not find TeanWipeHUD Device!")
            TeamWipeXP := GetTaggedObjects(reboot_respawn_tag{}, accolades_device)[0]                           or PrintAndErr("Could not find TeamWipeXP Device")
            HoldToRebootTrigger := GetTaggedObjects(hold_to_reboot_input_tag{}, input_trigger_device)[0]        or PrintAndErr("Could not find HoldToRebootInputTrigger Device!")
            HoldToRebootHUDNoAnim := GetTaggedObjects(hold_to_reboot_hud_no_anim{}, hud_message_device)[0]      or PrintAndErr("Could not find HoldToRebootHUDNoAnim Device!")
            HoldToRebootHUDAnim := GetTaggedObjects(hold_to_reboot_hud_anim{}, hud_message_device)[0]           or PrintAndErr("Could not find HoldToRebootHUDAnim Device!")
            StatusTimerCenterHUD :=  custom_hud_timer:
                HUDMessageDevice := GetTaggedObjects(reboot_status_timer_center_tag{}, hud_message_device)[0]   or PrintAndErr("Could not find RebootStatusTimerHUD Center Device!")
            StatusTimerCornerHUD :=  custom_hud_timer:
                HUDMessageDevice := GetTaggedObjects(reboot_status_timer_corner_tag{}, hud_message_device)[0]   or PrintAndErr("Could not find RebootStatusTimerHUD Corner Device!")
            DBNODevice := DBNODevice
            RebootMessageFeed := RebootParameters.RebootMessageFeed
            SkyDiveTeleporters := GetTaggedObjects(reboot_skyzone_tag{}, teleporter_device)
            
    BuildHUDManager<internal>():rr_hud_manager = 
        HUDManager := rr_hud_manager:
            Parameters := HUDParameters
            TeamIndexTintMap := TeamParameters.IndexTintMap()
            WinRoundHUD := GetTaggedObjects(win_round_tag{}, hud_message_device)[0]     or PrintAndErr("Could not find WinRoundHUD Device!")
            LoseRoundHUD := GetTaggedObjects(lose_round_tag{}, hud_message_device)[0]   or PrintAndErr("Could not find LoseRoundHUD Device!")
            WatermarkHUD := GetTaggedObjects(watermark_hud_tag{}, hud_message_device)[0]    or PrintAndErr("Could not find WatermarkHUD Device!")
        HUDManager.WatermarkHUD.Show()
        HUDManager

    BuildGameflowController<internal>(TeamPlayerManager : rr_team_and_player_manager, RebootManager : rr_reboot_manager, HUDManager : rr_hud_manager, DBNODevice : down_but_not_out_device):rr_gameflow_controller =
        GameflowController := rr_gameflow_controller:
            TeamPlayerManager := TeamPlayerManager
            RebootManager := RebootManager
            HUDManager := HUDManager
            GameflowDevices := BuildGameflowDevices(DBNODevice)
            ItemSelectManager := BuildWeaponSelect()
            POIs := BuildPOIs()
            Positions := BuildPositions()
            AutoStartMinimum := 4
            MaxPlayers := 8
            SupplyDropTimesAndQuantities := array:
                (10.0, 2)
                (60.0, 3)
                (60.0, 2)
        GameflowController.Initialize()
        GameflowController

    BuildGameflowDevices<internal>(DBNODevice : down_but_not_out_device):rr_gameflow_devices = 
        rr_gameflow_devices:
            AllTeamSettings := GetTaggedObjects(all_team_set_inv_tag{}, team_settings_and_inventory_device)[0]                          or PrintAndErr("Could not find AllTeamSettings Device!")
            NotEnoughPlayersHUD := GetTaggedObjects(not_enough_players_hud_tag{}, hud_message_device)[0]                                or PrintAndErr("Could not find NotEnoughPlayersHUD Device!")
            RoundSettings := GetTaggedObjects(round_settings_tag{}, round_settings_device)[0]                                           or PrintAndErr("Could not find RoundSettings Device!")
            WonRoundXP := GetTaggedObjects(win_round_tag{}, accolades_device)[0]                                                        or PrintAndErr("Could not find WinRoundXP Device!")
            PlayedRoundXP := GetTaggedObjects(win_round_tag{}, accolades_device)[0]                                                     or PrintAndErr("Could not find PlayedRoundXP Device!")
            AutoStartVoteTimer := for(Obj : FindCreativeObjectsWithTag(auto_vote_ui_tag{}), Timer := timer_device[Obj]){Timer}[0]       or PrintAndErr("Could not find AutoStartVoteTimer Device!")
            AutoStartVoteUI := for(Obj : FindCreativeObjectsWithTag(auto_vote_ui_tag{}), PopUp := popup_dialog_device[Obj]){PopUp}[0]   or PrintAndErr("Could not find AutoStartVoteUI PopUp Device!")
            AutoStartFailedHUD := for(Obj : FindCreativeObjectsWithTag(auto_vote_ui_tag{}), HUD := hud_message_device[Obj]){HUD}[0]     or PrintAndErr("Could not find AutoStartFailedHUD Device!")
            RebootVanStartingTimer := GetTaggedObjects(reboot_van_starting_timer_tag{}, timer_device)[0]                                or PrintAndErr("Could not find BarrierTimer Device!")
            PrefireMutatorZone := GetTaggedObjects(prefire_mutator_tag{}, mutator_zone_device)[0]                                       or PrintAndErr("Could not find PrefireMutatorZone Device!")
            EndGameDevice := GetTaggedObjects(end_game_device_tag{}, end_game_device)[0]                                                or PrintAndErr("Could not find EndGame Device!")
            BasicStormController := GetTaggedObjects(basic_storm_tag{}, basic_storm_controller_device)[0]                               or PrintAndErr("Could not find BasicStormController Device!")
            SupplyDropTimer := GetTaggedObjects(supply_drops_tag{}, timer_device)[0]                                                    or PrintAndErr("Could not find SupplyDropTimer Device!")
            SupplyDrops := Shuffle(GetTaggedObjects(supply_drops_tag{}, supply_drop_spawner_device))
            CustomBarrierTimerHUD := custom_hud_timer:
                HUDMessageDevice := GetTaggedObjects(barrier_timer_tag{}, hud_message_device)[0]                                        or PrintAndErr("Could not find BarrierTimerHUD Device!")
            WinnerRematchProp := GetTaggedObjects(winning_stage_tag{}, creative_prop)[0] or creative_prop{}
            WinnerReferences := GetTaggedObjects(winning_stage_tag{}, player_reference_device)
            DBNODevice := DBNODevice
        
    BuildWeaponSelect<internal>():rr_item_manager =
        AlwaysGranterTag := always_granter{}
        ItemManager := rr_item_manager:
            WeaponSelectDialog := GetTaggedObjects(weapon_select_device{}, popup_dialog_device)[0]      or PrintAndErr("Could not find WeaponUI Device!")
            KeepSelectDialog := GetTaggedObjects(keep_loadout_select_device{}, popup_dialog_device)[0]  or PrintAndErr("Could not find KeepSelectUI Device!")
            AlwaysGranter := GetTaggedObjects(AlwaysGranterTag, item_granter_device)[0]                 or PrintAndErr("Could not find AlwaysGranter Device!")
            ItemRemover := GetTaggedObjects(item_remover{}, item_remover_device)[0]                     or PrintAndErr("Could not find ItemRemover Device!")
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
            CenterPositionProp := GetTaggedObjects(POITag, creative_prop)[0] or PrintAndErr("Could not find BasicStormController for " + ToDiagnostic(POITag))

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