using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Verse.org/Random }

using { FN_Gameplay }

combat_manager_tag := class(tag){}

    barrier_timer_tag := class(combat_manager_tag){}
    prefire_mutator_tag := class(combat_manager_tag){}
    basic_storm_tag := class(combat_manager_tag){}
    supply_drops_tag := class(combat_manager_tag){}
    win_round_tag := class(combat_manager_tag){}
    lose_round_tag := class(combat_manager_tag){}

rr_combat_manager := class:

    DBNODevice : down_but_not_out_device
    PrefireMutatorZone : mutator_zone_device
    StormController : storm_controller_device
    SupplyDropSpawners : []supply_drop_spawner_device
    CustomBarrierTimerHUD : custom_hud_timer
    LoseRoundHUD : hud_message_device
    WinRoundHUD : hud_message_device
    LoadoutSelector : rr_loadout_selector
    RebootManager : rr_reboot_manager
    # ScoreHUDManager : rr_score_hud_manager
    POIs : []rr_poi
    InitialStormPhaseRadiusCM : float
    SupplyDropTimesAndQuantities : []tuple(float, int)
    var RoundNumber : int = 0
    var TotalTeamRoundScores : [int]int = map{}
    var CurrentRoundParticipants : []agent = array{}

    GetNextPOI<public>()<transacts><decides>:rr_poi =
        POIs[RoundNumber]

    AwaitRoundReady<public>(TeamIndexAgentsMap : [int][]agent, CurrentPOI : rr_poi)<suspends>:void =
        PrefireMutatorZone.Enable()
        if { StormController.TeleportTo[CurrentPOI.GetCenter()] }
        StormController.GenerateStorm()

        TeamAgents2D := for:
            TeamIndex -> TeamAgents : TeamIndexAgentsMap
        do:
            InitializeTeamCauseCombatEvents(TeamIndex)
            TeamAgents
        CurrentPOI.Initialize()
        CurrentPOI.TeleportTeams(TeamAgents2D)
        Sleep(1.5)
        set CurrentRoundParticipants = for:
            TeamMembers : TeamAgents2D
            TeamMember : TeamMembers
        do:
            GetCombatReady(TeamMember)
            TeamMember
        Sleep(2.0)
        for:
            Participant : CurrentRoundParticipants
            not LoadoutSelector.HasKeepSelection[Participant]
        do:
            LoadoutSelector.ShowUI(Participant)
        
        RebootManager.EnableReboots(CurrentRoundParticipants)
        AwaitBarrierTimer()

    InitializeTeamEvents<private>(TeamIndexAgentsMap : [int][]agent):[][]agent =
        for(TeamIndex -> TeamAgents : TeamIndexAgentsMap):
            InitializeTeamCauseCombatEvents(TeamIndex)
            TeamAgents

    GetCombatReady<private>(InAgent : agent):void =
        DBNODevice.Revive(InAgent)
        if(FortCharacter := InAgent.GetFortChar[]):
            FortCharacter.SetHealth(100.0)
            FortCharacter.SetShield(100.0)
        if(LoadoutSelector.HasKeepSelection[InAgent]):
            LoadoutSelector.GrantLastSelected(InAgent)

    AwaitBarrierTimer<private>()<suspends>:void =
        if(RoundNumber = 0):
            CustomBarrierTimerHUD.Start(15)
        else:
            CustomBarrierTimerHUD.Start(10)
        CustomBarrierTimerHUD.SuccessEvent.Await()

    StartRound<public>(CurrentPOI : rr_poi)<suspends>:void =
        LoadoutSelector.HideUI()
        PrefireMutatorZone.Disable()
        CurrentPOI.DisableBarriers()
        branch:
            sync:
                RebootManager.AwaitReboots()
                SpawnSupplyDrops(CurrentPOI.GetCenter().Translation, InitialStormPhaseRadiusCM)
        AwaitRoundEndCondition()

    SpawnSupplyDrops<private>(CenterV3 : vector3, Radius : float)<suspends>:void =
        var SupplyDropIndex : int = 0
        for(TimeAndQuantity : SupplyDropTimesAndQuantities):
            AwaitTimer(TimeAndQuantity(0))
            for:
                I := 0..TimeAndQuantity(1) - 1
                SupplyDrop := SupplyDropSpawners[SupplyDropIndex]
                RandomYaw := GetRandomFloat(0.0, 360.0)
                RandomRotation := MakeRotationFromYawPitchRollDegrees(RandomYaw, 0.0, 0.0)
                RandomDistance := GetRandomFloat(0.0, Radius)
                SupplyDropV3 := RandomRotation.GetLocalForward() * RandomDistance + CenterV3
                SupplyDrop.TeleportTo[SupplyDropV3, IdentityRotation()]
            do:
                SupplyDrop.Spawn()
                set SupplyDropIndex += 1
        
    AwaitRoundEndCondition<private>()<suspends>:void =
        loop:
            race:
                Sleep(1.0)
                RebootManager.TeamWipeEvent.Await()
            ParticipatingAliveTeamIndexes := GetParticipatingAliveTeamIndexes() 
            if(ParticipatingAliveTeamIndexes.Length < 2):
                TallyScore(ParticipatingAliveTeamIndexes)
                break

    GetParticipatingAliveTeamIndexes<public>():[]int = 
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection() 
        TeamsWithMembers := TeamCollection._GetTeamsWithMembers()
        if(TeamsWithMembers.Length <= 1):
            SetCurrentRRState(rr_state.OpponentsLeft)
        AliveTeams := for:
            TeamIndex -> TeamMembers : TeamsWithMembers
            TeamMembersParticipating := for:
                TeamMember : TeamMembers
                CurrentRoundParticipants.Find[TeamMember]   # Verify they are a member from this round
                IsUp[TeamMember]                            # Verify they are up
            do:
                TeamMember
            TeamMembersParticipating[0]                     # Verify there exists at least one alive team
        do:
            TeamIndex

    TallyScore<private>(ParticipatingAliveTeamIndexes : []int):void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        set TotalTeamRoundScores = Dict of for(TeamIndex -> TeamMembers : TeamCollection._GetTeamsWithMembers()):
            for(TeamMember : TeamMembers):
                if(TeamCollection.IsOnTeam[TeamMember, ParticipatingAliveTeamIndexes[0]]):
                    WinRoundHUD.Show(TeamMember)
                    GetGlobalAnalyzerAwarder().Award(TeamMember, rr_award.WonRound)
                else:
                    LoseRoundHUD.Show(TeamMember)
                    GetGlobalAnalyzerAwarder().Award(TeamMember, rr_award.PlayedRound)
            if(CurrentScore := TotalTeamRoundScores[TeamIndex]):
                if(TeamIndex = ParticipatingAliveTeamIndexes[0]):
                    (TeamIndex, CurrentScore + 1)
                else:
                    (TeamIndex, CurrentScore)
            else:
                (TeamIndex, 0)

    GetSortedTeamScores<public>():[]tuple(int, int) =
        SortBy(TotalTeamRoundScores.Items(), TupleSecondGreaterComp)

    EndRound<public>():void =
        RebootManager.DisableReboots(?RoundEnding := true)
        if(RandomAgent := GetMainDevicePlayspace().GetRandomParticipant[]):
            for(SupplyDropSpawner : SupplyDropSpawners):
                SupplyDropSpawner.Open(RandomAgent)
        StormController.DestroyStorm()
        set RoundNumber += 1
        set CurrentRoundParticipants = array{}