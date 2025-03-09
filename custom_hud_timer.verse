using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

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
                if(not MaybeAgent?):            # If there is no agent
                    return
                else if(MaybeAgent? = InAgent): # If there is an agent and the agent is self
                    return
            loop:
                if(TimeLeft <= 0):
                    HUDMessageDevice.Show(InAgent, IntToMessage(TimeLeft), ?DisplayTime:=1.0)
                    Sleep(1.0)
                    break
                HUDMessageDevice.Show(InAgent, IntToMessage(TimeLeft), ?DisplayTime:=1.0)
                Sleep(1.0)
                set TimeLeft -= 1
        HUDMessageDevice.Hide(InAgent)
        SuccessEvent.Signal(option{InAgent})

    Stop():void =
        StopEvent.Signal(false)

    Stop(InAgent : agent):void =
        StopEvent.Signal(option{InAgent})

    IntToMessage<localizes>(Val : int):message = "{Val}"