using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }

custom_hud_timer := class:

    # ! This custom timer only displays in seconds
    HUDMessageDevice : hud_message_device
    var Duration : float = 1.0
    SuccessEvent : event(?agent) = event(?agent){}
    StopEvent<internal> : event(?agent) = event(?agent){}

    Start():void =
        Start(Duration)

    SetDuration(InDuration : float):void =
        set Duration = InDuration

    Start(InDuration : float):void =
        for(Participant : HUDMessageDevice.GetPlayspace().GetParticipants()):
            spawn{_TimerLoop(Participant, InDuration)}
    
    Start(InAgent : agent, InDuration : float):void =
        spawn{_TimerLoop(InAgent, InDuration)}

    StartAndAwaitSuccess()<suspends>:void =
        sync:
            SuccessEvent.Await()
            block:
                Sleep(-1.0)
                Start(Duration)

    AwaitSuccess()<suspends>:void =
        SuccessEvent.Await() 

    Reset():void =
        Stop()

    Stop():void =
        StopEvent.Signal(false)

    Stop(InAgent : agent):void =
        StopEvent.Signal(option{InAgent})

    _TimerLoop<private>(InAgent : agent, InDuration : float)<suspends>:void =
        var TimeLeft : float = InDuration
        race:
            loop:
                MaybeAgent := StopEvent.Await()
                if(not MaybeAgent? or MaybeAgent? = InAgent):
                    break
            loop:
                if(TimeLeft <= 0.0):
                    HUDMessageDevice.Show(InAgent, IntToMessage(0), ?DisplayTime:=1.0)
                    AwaitTimer(1.0)
                    SuccessEvent.Signal(option{InAgent})
                    break
                if(Trunc := Int[TimeLeft]):
                    HUDMessageDevice.Show(InAgent, IntToMessage(Trunc), ?DisplayTime:=1.0)
                AwaitTimer(1.0)
                set TimeLeft -= 1.0
        HUDMessageDevice.Hide(InAgent)