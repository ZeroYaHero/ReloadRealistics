using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }

custom_hud_timer := class:

    # ! This custom timer only displays in seconds
    HUDMessageDevice : hud_message_device
    Duration : int = 1
    SuccessEvent : event(?agent) = event(?agent){}
    StopEvent<internal> : event(?agent) = event(?agent){}

    Start():void =
        Start(Duration)

    Start(InDuration : int):void =
        for(Participant : HUDMessageDevice.GetPlayspace().GetParticipants()):
            spawn{TimerLoop(Participant, InDuration)}
    
    Start(InAgent : agent, InDuration : int):void =
        spawn{TimerLoop(InAgent, InDuration)}

    TimerLoop(InAgent : agent, InDuration : int)<suspends>:void =
        var TimeLeft : int = InDuration
        race:
            loop:
                MaybeAgent := StopEvent.Await()
                if(not MaybeAgent? or MaybeAgent? = InAgent):
                    break
            loop:
                if(TimeLeft <= 0):
                    HUDMessageDevice.Show(InAgent, IntToMessage(0), ?DisplayTime:=1.0)
                    AwaitTimer(1.0)
                    SuccessEvent.Signal(option{InAgent})
                    break
                HUDMessageDevice.Show(InAgent, IntToMessage(TimeLeft), ?DisplayTime:=1.0)
                AwaitTimer(1.0)
                set TimeLeft -= 1
        HUDMessageDevice.Hide(InAgent)

    Stop():void =
        StopEvent.Signal(false)

    Stop(InAgent : agent):void =
        StopEvent.Signal(option{InAgent})

    IntToMessage<localizes>(Val : int):message = "{Val}"