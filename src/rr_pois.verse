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

rr_positions := class:
    Lobby : []teleporter_device
    TeamSelect : []teleporter_device

rr_poi<public> := class:

    TeamPairings<public> : []tuple([]teleporter_device, []teleporter_device)
    Barriers<public> : []barrier_device
    CenterPositionProp<public> : creative_prop

    Initialize():void =
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

    TeleportTeams(Agents2D : [][]agent)<suspends>:void =
        var StickyTasks : []sticky_task = array{}
        if(PairCount := Ceil(Agents2D.Length / 2)):
            var Index : int = 0
            loop:
                if:
                    Index < PairCount
                    Pairing := TeamPairings[Index]
                    ATeamAgents := Agents2D[Index * 2]
                then:
                    set StickyTasks += array{ATeamAgents.TeleportToOrRespawnAt(Pairing(0))}
                    if(BTeamAgents := Agents2D[Index * 2 + 1]):
                        set StickyTasks += array{BTeamAgents.TeleportToOrRespawnAt(Pairing(1))}
                        set Index += 1
                    else:
                        break
                else:
                    break
        StickyTasks.Await()