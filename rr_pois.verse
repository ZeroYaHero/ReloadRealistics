using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }

using { FN_Gameplay }

var GlobalCurrentPOI : weak_map(session, rr_poi) = map{}

GetCurrentPOI<public>()<transacts><decides>:rr_poi =
    GlobalCurrentPOI[GetSession()]

SetCurrentPOI<internal>(InPOI : rr_poi)<transacts><decides>:void =
    set GlobalCurrentPOI[GetSession()] = InPOI

# For Generic Positions
position_tp := class(tag){}
    lobby_tp := class(position_tp){}
    team_tp := class(position_tp){}
    rematch_tp := class(position_tp){}

rr_positions := class:
    Lobby : []teleporter_device
    TeamSelect : []teleporter_device
    RematchRequeue : []teleporter_device

# For Pairings
pairing_tp := class(tag){}
    pairing_blue := class(pairing_tp){}
    pairing_red := class(pairing_tp){}
    first_team := class(pairing_tp){}
    second_team := class(pairing_tp){}

# For POIs
poi_tag := class(tag){}
    yacht_poi := class(poi_tag){}
    motel_poi := class(poi_tag){}
    pleasant_poi := class(poi_tag){}
    catty_poi := class(poi_tag){}
    retail_poi := class(poi_tag){}
    sands_poi := class(poi_tag){}
    frosty_poi := class(poi_tag){}
    factories_poi := class(poi_tag){}
    crash_poi := class(poi_tag){}
    weeping_poi := class(poi_tag){}

rr_poi<public> := class:

    TeamPairings<public> : []tuple([]teleporter_device, []teleporter_device)
    Barriers<public> : []barrier_device
    CenterPositionProp<public> : creative_prop

    Initialize()<suspends>:void =
        if { SetCurrentPOI[Self] }
        EnableBarriers()

    GetCenter()<transacts>:transform =
        CenterPositionProp.GetTransform()

    DisableBarriers():void =
        for(Barrier : Barriers):
            Barrier.Disable()

    EnableBarriers():void =
        for(Barrier : Barriers):
            Barrier.Enable()

    TeleportTeams(TeamsAgents : [][]agent)<suspends>:void =
        var StickyTasks : []sticky_task = array{}
        if(PairCount := Ceil(TeamsAgents.Length / 2)):
            var Index : int = 0
            loop:
                if:
                    Index < PairCount
                    Pairing := TeamPairings[Index]
                    ATeamAgents := TeamsAgents[Index * 2]
                then:
                    set StickyTasks += array{ATeamAgents.TeleportToOrRespawnAt(Pairing(0))}
                    if(BTeamAgents := TeamsAgents[Index * 2 + 1]):
                        set StickyTasks += array{BTeamAgents.TeleportToOrRespawnAt(Pairing(1))}
                        set Index += 1
                    else:
                        break
                else:
                    break
        StickyTasks.Await()