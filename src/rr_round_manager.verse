using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Verse.org/Random }

using { FN_Gameplay }
using { scoring }
using { teams }
using { config }

rr_round_manager := class(fn_gameplay_round_manager):
    # Objects
    ScoreController:rr_scoring_controller
    RebootController:rebooting.rr_reboot_controller
    ParticipantManager:rr_participant_manager
    LoadoutSelector:rr_loadout_selector
    TeamCollection:fort_team_collection
    PlayableTeams:[]rr_team_config
    TeamCapacity:int
    EliminationManagerDevice:elimination_manager_device
    POIs:[]rr_poi
    # Devices
    DBNODevice:down_but_not_out_device
    # StormDevice:storm_controller_device
    # StormBeacons:[]advanced_storm_beacon_device
    StormManager:rr_storm_manager
    SupplyDropSpawners:[]supply_drop_spawner_device
    Config:rr_rounds_config
    BarrierTimerHUD:hud_message_timer
    RoundPOIHUD:hud_message_device
    POIBarrier:barrier_device
    BarrierSFX:audio_player_device
    # Variables
    var TotalTeamRoundScores:[int]int = map{}
    var AgentScoreMap:[agent]int = map{}
    var CurrentRoundParticipants:[]agent = array{}
    var RoundCancelables:[]cancelable = array{}
    DebugDraw:debug_draw = debug_draw{}

    HasNextRound<override>()<transacts><decides>:void =
        POIs[RoundNumber]

    # Round Setup
    OnRoundSetup<override>()<suspends>:void =
        set CurrentRoundParticipants = for:
            PlayableTeam:PlayableTeams
            TeamMembers := ParticipantManager.GetInitializedOf(TeamCollection._GetTeamMembers[PlayableTeam.Index])
            TeamMember:TeamMembers
        do:
            TeamMember
        SetupPOI()
        AwaitTimer(1.0)
        SetupParticipants()
        RebootController.SetDefaultRebootTransform(POIs[RoundNumber].GetCenter() or transform{})
        BarrierTimerHUD.StartAndAwaitSuccessAll()

    # Setup POI
    SetupPOI()<suspends>:void =
        if:
            POI := POIs[RoundNumber]
            # StormDevice.TeleportTo[POI.GetCenter()]
            # StormBeacons[0].TeleportTo[POI.GetCenter()]
            POIBarrier.TeleportTo[POI.GetCenter().TransZ(-1024.0)]
        then:
            for(Participant : CurrentRoundParticipants):
                RoundPOIHUD.Show(Participant, RoundPOIMessage(RoundNumber + 1, POI.Name))
            # var LastPosition:vector3 = POI.GetCenter().Translation
            # for:
            #     Index -> StormBeacon : StormBeacons
            #     Index > 0
            #     StormRange := Config.StormRanges[Index - 1]
            #     RandomRotation := MakeRotationFromYawPitchRollDegrees(GetRandomFloat(0.0, 360.0), 0.0, 0.0)
            #     NewPosition := RandomRotation.GetLocalForward() * GetRandomFloat(StormRange(0), StormRange(1)) + LastPosition
            #     StormBeacon.TeleportTo[NewPosition, IdentityRotation()]
            # do:
            #     set LastPosition = NewPosition
            POI.Initialize()
            AwaitTimer(1.0)

            Pairs := for:
                PlayableTeam:PlayableTeams
                TeamMembers := ParticipantManager.GetInitializedOf(TeamCollection._GetTeamMembers[PlayableTeam.Index])
            do:
                TeamMembers

            POI.TeleportPairs(Pairs)
            ScoreController.RefreshView()
            for(SupplyDropSpawner : SupplyDropSpawners):
                set RoundCancelables += array:
                    SupplyDropSpawner.OpenedEvent.Subscribe(OnSupplyDropOpen)
            StormManager.GenerateStorm(POI.GetCenter().Translation)

    # Setup Participants
    SetupParticipants():void =
        for(Participant:CurrentRoundParticipants):
            GiveOneSpawn(Participant)
            GrantHealthShield(Participant)
            GrantLoadout(Participant)
            RebootController.Register(Participant)
            if(TeamIndex := TeamCollection._GetTeamIndex[Participant]):
                InitializeTeamCauseCombatEvents(TeamIndex)

    # Grant Health and Shield to InAgent
    GrantHealthShield<private>(InAgent : agent):void =
        DBNODevice.Revive(InAgent)
        if(FortCharacter := InAgent.GetFortCharacter[]):
            FortCharacter.SetVulnerability(true)
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
        for(CurrentRoundParticipant:CurrentRoundParticipants):
            BarrierSFX.Play(CurrentRoundParticipant)
        RebootController.Enable()
        LoadoutSelector.HideUI()
        if(POI := POIs[RoundNumber]):
            POI.DisableBarriers()
        branch:
            sync:
                SpawnSupplyDrops()
                UpdateDefaultRebootLocation()
                GrantLoadoutsOnReboot()
        CheckRoundEndCondition()

    # Check the Round End Condition Repeatedly
    CheckRoundEndCondition<override>()<suspends>:void =
        var AgentsLeft:[]agent = array{}
        race:
            loop:
                set AgentsLeft += array{ParticipantManager.ParticipantExitEvent().Await()}
            loop:
                race:
                    AwaitTimer(1.0)
                    EliminationManagerDevice.EliminatedEvent.Await()
                ScoreController.RefreshView()

                for(AgentLeft:AgentsLeft):
                    RebootController.Unregister(AgentLeft)
                set AgentsLeft = array{}

                TeamIndexesAlive := Set of for:
                    CurrentRoundParticipant:CurrentRoundParticipants
                    IsUp[CurrentRoundParticipant]
                    TeamIndex := TeamCollection._GetTeamIndex[CurrentRoundParticipant]
                do:
                    TeamIndex

                if(TeamIndexesAlive.Length < 2):
                    if(not RebootController.RebootsInProgress[]):
                        for(Participant:CurrentRoundParticipants):
                            if(TeamCollection._GetTeamMembers[TeamIndexesAlive[0]].Find[Participant]):
                                ScoreController.OnRoundWin(Participant)
                            else:
                                ScoreController.OnRoundLose(Participant)
                        return

    # Spawn Supply Drops around Center Point
    SpawnSupplyDrops<private>()<suspends>:void =
        var SupplyDropIndex : int = 0
        for(TimeAndQuantity : Config.SupplyDropTimesAndQuantities):
            AwaitTimer(TimeAndQuantity(0))
            for:
                I := 0..TimeAndQuantity(1) - 1
                SupplyDrop := SupplyDropSpawners[SupplyDropIndex]
                RandomYaw := GetRandomFloat(0.0, 360.0)
                RandomRotation := MakeRotationFromYawPitchRollDegrees(RandomYaw, 0.0, 0.0)
                RandomDistance := GetRandomFloat(0.0, StormManager.GetStormRadius[])
                POICenter := StormManager.GetStormCenter[]
                SupplyDropV3 := RandomRotation.GetLocalForward() * RandomDistance + POICenter
                SupplyDrop.TeleportTo[SupplyDropV3, IdentityRotation()]
            do:
                SupplyDrop.Spawn()
                set SupplyDropIndex += 1

    UpdateDefaultRebootLocation<private>()<suspends>:void =
        loop:
            # DebugDraw.Clear()
            if(StormCenter := StormManager.GetStormCenter[]):
                RebootController.SetDefaultRebootLocation(StormCenter)
                # if(Radius := StormManager.GetStormRadius[]):
                #     DebugDraw.DrawCylinder(StormCenter.SetZ(0.0), StormCenter.SetZ(RebootController.RiftHeight), ?NumSegments := 16, ?Radius := Radius, ?Thickness := 20.0)
            Sleep(0.0)

    GrantLoadoutsOnReboot<private>()<suspends>:void =
        loop:
            Rebooted := RebootController.RebootedEvent().Await()
            LoadoutSelector.GrantLastSelected(Rebooted)

    OnSupplyDropOpen<private>(InAgent:agent):void =
        AwardXP(InAgent, rr_award.OpenSupplyDrop)

    # Round End
    OnRoundEnd<override>()<suspends>:void = 
        RebootController.Disable()
        RebootController.UnregisterAll()
        StormManager.DestroyStorm()
        for:
            Participant : CurrentRoundParticipants
            FortCharacter := Participant.GetFortCharacter[]
        do:
            DBNODevice.Revive(Participant)
            FortCharacter.SetVulnerability(false)
        AwaitTimer(3.0)
        if(RandomAgent := CurrentRoundParticipants[GetRandomInt(0, CurrentRoundParticipants.Length - 1)]):
            for(SupplyDropSpawner : SupplyDropSpawners):
                SupplyDropSpawner.Open(RandomAgent)
        for(RoundCancelable:RoundCancelables):
            RoundCancelable.Cancel()
        set RoundCancelables = array{}
        for(Participant:CurrentRoundParticipants):
            LoadoutSelector.ClearLoadout(Participant)
            GrantHealthShield(Participant)
        set CurrentRoundParticipants = array{}

RoundPOIMessage<localizes><public>(RoundNumber:int, POIName:string):message = "Round {RoundNumber}:\n{POIName}"