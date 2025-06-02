using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { FN_Gameplay }

rr_storm_phase := class:
    BeaconDevice:advanced_storm_beacon_device
    MinimumMaximumRange:tuple(float, float)
    WaitDuration:float
    MoveShrinkDuration:float
    Radius:float

rr_storm_manager := class:
    AdvancedStormControllerDevice:advanced_storm_controller_device
    DelayDuration:float
    StormPhases:[]rr_storm_phase
    DestroyStormEvent<private>:event() = event(){}
    var <private>CurrentStormPhaseIndex<private>:int = -1
    var <private>OptionalMoveShrinkTimeStart<private>:?float = false

    GenerateStorm<public>(StartLocation:vector3):void =
        if { AdvancedStormControllerDevice.TeleportTo[StartLocation, IdentityRotation()] }
        for:
            Index -> StormPhase:StormPhases
        do:
            Location := if:
                Index > 0
                PreviousPhase := StormPhases[Index - 1]
            then:
                Range := GetRandomFloat(StormPhase.MinimumMaximumRange)
                RandomRotation := MakeRotationFromYawPitchRollDegrees(GetRandomFloat(0.0, 360.0), 0.0, 0.0)
                VectorOffset := RandomRotation.GetLocalForward() * Range
                PreviousPhase.BeaconDevice.GetTransform().Translation + VectorOffset
            else:
                StartLocation
            if { StormPhase.BeaconDevice.TeleportTo[Location, IdentityRotation()] }
        spawn{CancelOnAwaitable(ProcessStormQueue, DestroyStormEvent)}

    ProcessStormQueue<private>()<suspends>:void =
        defer:
            set OptionalMoveShrinkTimeStart = false
        AdvancedStormControllerDevice.GenerateStorm()
        for(Index -> StormPhase:StormPhases):
            set CurrentStormPhaseIndex = Index
            if(Index = 0):
                AwaitTimer(DelayDuration)
            Print("Storm Wait Time Starting")
            AwaitTimer(StormPhase.WaitDuration)
            Print("Storm Wait Time Finished")
            MoveShrinkStartTime := GetSimulationElapsedTime()
            set OptionalMoveShrinkTimeStart = option{MoveShrinkStartTime}
            Print("Starting Move-Shrink at {MoveShrinkStartTime}")
            AwaitTimer(StormPhase.MoveShrinkDuration)
            Print("Move-Shrink Finished")
            set OptionalMoveShrinkTimeStart = false

    DestroyStorm<public>():void =
        DestroyStormEvent.Signal()
        AdvancedStormControllerDevice.DestroyStorm()
        set CurrentStormPhaseIndex = -1

    GetStormCenter<public>()<transacts><decides>:vector3 = 
        CurrentStormPhase := StormPhases[CurrentStormPhaseIndex]
        if:
            NextStormPhase := StormPhases[CurrentStormPhaseIndex + 1] 
            MoveShrinkTimeStart := OptionalMoveShrinkTimeStart?
        then:
            Lerp(CurrentStormPhase.BeaconDevice.GetTransform().Translation,
                NextStormPhase.BeaconDevice.GetTransform().Translation,
                (GetSimulationElapsedTime() - MoveShrinkTimeStart) / StormPhases[CurrentStormPhaseIndex].MoveShrinkDuration
            )
        else:
            # Print("No Next Phase OR Storm is NOT moving")
            CurrentStormPhase.BeaconDevice.GetTransform().Translation

    GetStormRadius<public>()<transacts><decides>:float =
        CurrentStormPhase := StormPhases[CurrentStormPhaseIndex]
        if:
            NextStormPhase := StormPhases[CurrentStormPhaseIndex + 1]
            MoveShrinkTimeStart := OptionalMoveShrinkTimeStart?
        then:
            Lerp(CurrentStormPhase.Radius,
                NextStormPhase.Radius,
                (GetSimulationElapsedTime() - MoveShrinkTimeStart) / StormPhases[CurrentStormPhaseIndex].MoveShrinkDuration
            )
        else:
            # Print("No Next Phase OR Storm is NOT moving")
            CurrentStormPhase.Radius

