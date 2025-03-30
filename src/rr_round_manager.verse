using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }

using { FN_Gameplay }

rr_round_manager := class(fn_gameplay_round_manager, fn_gameplay_state_triggerable, rr_state_handler_interface):
    # Objects
    ScoreModel:rr_score_model
    RebootManager:rr_reboot_manager
    LoadoutSelector:rr_loadout_selector
    TeamSelector:rr_team_selector
    POIs:[]rr_poi
    # Devices
    StormDevice:storm_controller_device
    StormBeacons:[]advanced_storm_beacon_device
    StormRanges:[]tuple(float, float)
    BarrierTimerHUD:custom_hud_timer
    SupplyDropSpawners:[]supply_drop_spawner_device
    # Parameters
    InitialStormPhaseRadiusCM:float
    SupplyDropTimesAndQuantities:[]tuple(float, int)
    # Variables
    var TotalTeamRoundScores:[int]int = map{}
    var AgentScoreMap:[agent]int = map{}
    var CurrentRoundParticipants:[]agent = array{}
    var CurrentRoundTeamIndexes:[]int = array{}

    EnterCombatRound<override>()<suspends>:void =
        StartRound()
        AwaitRoundCleaned()

    # Round Setup
    OnRoundSetup<override>()<suspends>:void =
        set CurrentRoundParticipants = Concatenate(TeamSelector.GetSelectableTeamMembersMap().Values())
        set CurrentRoundTeamIndexes = TeamSelector.GetSelectableTeamMembersMap().Keys()
        SetupTeams()
        SetupPOI()
        AwaitTimer(1.0)
        SetupParticipants()
        RebootManager.SetDefaultRebootLocation(POIs[RoundNumber].GetCenter().Translation or vector3{})
        RebootManager.EnableReboots()
        BarrierTimerHUD.StartAndAwaitSuccess()

    # Setup Teams
    SetupTeams<private>():void =
        for(TeamIndex : CurrentRoundTeamIndexes):
            InitializeTeamCauseCombatEvents(TeamIndex)

    # Setup POI
    SetupPOI()<suspends>:void =
        if:
            POI := POIs[RoundNumber]
            StormDevice.TeleportTo[POI.GetCenter()]
            StormBeacons[0].TeleportTo[POI.GetCenter()]
        then:
            var LastPosition:vector3 = POI.GetCenter().Translation
            for:
                Index -> StormBeacon : StormBeacons
                Index > 0
                StormRange := StormRanges[Index - 1]
                RandomRotation := MakeRotationFromYawPitchRollDegrees(GetRandomFloat(0.0, 360.0), 0.0, 0.0)
                NewPosition := RandomRotation.GetLocalForward() * GetRandomFloat(StormRange(0), StormRange(1)) + LastPosition
                StormBeacon.TeleportTo[NewPosition, IdentityRotation()]
            do:
                set LastPosition = NewPosition
            POI.Initialize()
            POI.TeleportTeams(TeamSelector.GetSelectableTeamMembersMap().Values())
            for(SupplyDropSpawner : SupplyDropSpawners):
                spawn{AwaitSupplyDropOpen(SupplyDropSpawner)}
            StormDevice.GenerateStorm()

    # Setup Participants
    SetupParticipants():void =
        for(Participant : CurrentRoundParticipants):
            GrantHealthShield(Participant)
            GrantLoadout(Participant)

    # Grant Health and Shield to InAgent
    GrantHealthShield<private>(InAgent : agent):void =
        Revive(InAgent)
        if(FortCharacter := InAgent.GetFortCharacter[]):
            FortCharacter.SetHealth(100.0)
            FortCharacter.SetShield(100.0)

    # Grant Loadout to InAgent
    GrantLoadout<private>(InAgent : agent):void =
        if(not LoadoutSelector.HasKeepSelection[InAgent]):
            LoadoutSelector.ShowUI(InAgent)
        else:
            LoadoutSelector.GrantLastSelected(InAgent)

    # Round Begin
    OnRoundBegin<override>()<suspends>:void =
        LoadoutSelector.HideUI()
        if(POI := POIs[RoundNumber]):
            POI.DisableBarriers()
        # Await Round End
        branch:
            sync:
                RebootManager.AwaitReboots(CurrentRoundParticipants)
                SpawnSupplyDrops()
        CheckRoundEndCondition()

    # Check the Round End Condition Repeatedly
    CheckRoundEndCondition<override>()<suspends>:void =
        # TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        TeamCollection := TeamSelector.TeamCollection
        loop:
            race:
                AwaitTimer(1.0)
                RebootManager.TeamWipeEvent.Await()

            TeamIndexesAlive := Set of for:
                CurrentRoundParticipant : CurrentRoundParticipants
                IsUp[CurrentRoundParticipant]
                TeamIndex := TeamCollection._GetTeamIndex[CurrentRoundParticipant]
            do:
                TeamIndex
            # One or less participating teams alive
            if(TeamIndexesAlive.Length < 2):
                # Round Winning Members
                if(RoundWinningMembers := TeamCollection._GetTeamMembers[TeamIndexesAlive[0]]):
                    ScoreModel.RoundWin(RoundWinningMembers)
                    for:
                        Participant : GetMainDevicePlayspace().GetParticipants()
                        not RoundWinningMembers.Find[Participant]
                    do:
                        ScoreModel.RoundLose(Participant)
                # All Teams Dead
                else:
                    ScoreModel.RoundLose(GetMainDevicePlayspace().GetParticipants())
                break

    # Spawn Supply Drops around Center Point
    SpawnSupplyDrops<private>()<suspends>:void =
        var SupplyDropIndex : int = 0
        for(TimeAndQuantity : SupplyDropTimesAndQuantities):
            AwaitTimer(TimeAndQuantity(0))
            for:
                I := 0..TimeAndQuantity(1) - 1
                SupplyDrop := SupplyDropSpawners[SupplyDropIndex]
                RandomYaw := GetRandomFloat(0.0, 360.0)
                RandomRotation := MakeRotationFromYawPitchRollDegrees(RandomYaw, 0.0, 0.0)
                RandomDistance := GetRandomFloat(0.0, InitialStormPhaseRadiusCM)
                POICenter := POIs[RoundNumber].GetCenter().Translation
                SupplyDropV3 := RandomRotation.GetLocalForward() * RandomDistance + POICenter
                SupplyDrop.TeleportTo[SupplyDropV3, IdentityRotation()]
            do:
                SupplyDrop.Spawn()
                set SupplyDropIndex += 1

    AwaitSupplyDropOpen<private>(SupplyDropSpawner : supply_drop_spawner_device)<suspends>:void =
        branch:
            loop:
                OpenedAgent := SupplyDropSpawner.OpenedEvent.Await()
                AwardXP(OpenedAgent, rr_award.OpenSupplyDrop)
        AwaitRoundEnd()

    # Round End
    OnRoundEnd<override>()<suspends>:void = 
        RebootManager.DisableReboots(?RoundEnding := true)
        if(RandomAgent := GetMainDevicePlayspace().GetRandomParticipant[]):
            for(SupplyDropSpawner : SupplyDropSpawners):
                SupplyDropSpawner.Open(RandomAgent)
        StormDevice.DestroyStorm()
        for(Participant : CurrentRoundParticipants):
            LoadoutSelector.ClearLoadout(Participant)
            Revive(Participant) # TODO!: Just make their health controlled here instead of modifying it in the team state
        set CurrentRoundParticipants = array{}
        Print("Round Number Updated")

    GetStateToTrigger<override>()<transacts>:comparable =
        Print("Deciding On Team Select and Rematch Requeue")
        if(POI := POIs[RoundNumber]):
            rr_state_enum.TeamSelect
        else:
            rr_state_enum.RematchRequeue

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.CombatRound => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterCombatRound}
                    PostExecutionTrigger := option{Self}
