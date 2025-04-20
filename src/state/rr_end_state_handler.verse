using { /Fortnite.com/Devices }
using { FN_Gameplay }
using { scoring }

rr_end_state_handler<public> := class(fn_gameplay_state_handler):
    ParticipantManager<public>:rr_participant_manager
    ScoreController<public>:rr_scoring_controller
    RematchRequeueTimer<public>:timer_device
    OpponentsLeftTimer<public>:timer_device
    HubManager<public>:rr_hub_manager

    EnterEndingState<private>()<suspends>:void =
        ParticipantManager.GetParticipants().TeleportToOrRespawnAt(HubManager.SpawnTeleporters)
        if { HubManager.WinnerRematchProp.TeleportTo[HubManager.WinnerRematchProp.GetTransform() + v3(0, 0, 960)]}
        ScoreController.OnGameEnd()

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.RematchRequeue => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterEndingState}
                RematchRequeueTimer.GetAutoCompleteTimer(rr_state_enum.GameEnd, ?StartOnState:=true)
            rr_state_enum.OpponentsLeft => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterEndingState}
                OpponentsLeftTimer.GetAutoCompleteTimer(rr_state_enum.GameEnd, ?StartOnState:=true)