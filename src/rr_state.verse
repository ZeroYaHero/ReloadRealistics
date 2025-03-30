using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { FN_Gameplay }

rr_state_enum<public> := enum:
    WaitingForPlayers
    TeamSelect
    CombatRound
    RematchRequeue
    OpponentsLeft
    GameEnd

rr_state_handler_interface := interface(fn_gameplay_state_handler):
    EnterWaitingForPlayers()<suspends>:void = void
    ExitWaitingForPlayers()<suspends>:void = void
    # GetWaitingForPlayersListener()<transacts>:fn_gameplay_state_listenable =
    #     fn_gameplay_state_listener:
    #         EnterCallback := option{EnterWaitingForPlayers}
    #         ExitCallback := option{ExitWaitingForPlayers}

    EnterTeamSelect()<suspends>:void = void
    ExitTeamSelect()<suspends>:void = void
    # GetTeamSelectListener()<transacts>:fn_gameplay_state_listenable =
    #     fn_gameplay_state_listener:
    #         EnterCallback := option{EnterTeamSelect}
    #         ExitCallback := option{ExitTeamSelect}

    EnterCombatRound()<suspends>:void = void
    ExitCombatRound()<suspends>:void = void
    # GetCombatRoundListener()<transacts>:fn_gameplay_state_listenable =
    #     fn_gameplay_state_listener:
    #         EnterCallback := option{EnterCombatRound}
    #         ExitCallback := option{ExitCombatRound}

    EnterRematchRequeue()<suspends>:void = void
    ExitRematchRequeue()<suspends>:void = void
    # GetRematchRequeueListener()<transacts>:fn_gameplay_state_listenable =
    #     fn_gameplay_state_listener:
    #         EnterCallback := option{EnterRematchRequeue}
    #         ExitCallback := option{ExitRematchRequeue}

    EnterOpponentsLeft()<suspends>:void = void
    ExitOpponentsLeft()<suspends>:void = void
    # GetOpponentsLeftListener()<transacts>:fn_gameplay_state_listenable =
    #     fn_gameplay_state_listener:
    #         EnterCallback := option{EnterOpponentsLeft}
    #         ExitCallback := option{ExitOpponentsLeft}

    # GetEnterExitListeners()<transacts>:[comparable][]fn_gameplay_state_listenable =
    #     map:
    #         rr_state_enum.WaitingForPlayers => array{GetWaitingForPlayersListener()}
    #         rr_state_enum.TeamSelect => array{GetTeamSelectListener()}
    #         rr_state_enum.CombatRound => array{GetCombatRoundListener()}
    #         rr_state_enum.RematchRequeue => array{GetRematchRequeueListener()}
    #         rr_state_enum.OpponentsLeft => array{GetOpponentsLeftListener()}

rr_state_machine := class(fn_gameplay_state_machine):

    AddAutoCompleteTimer(State : rr_state_enum, TimerDevice : timer_device, StateToTrigger : rr_state_enum, ?StartOnState : logic = false)<transacts>:void =
        TimerListenerWrapper := timer_listener_wrapper{TimerDevice := TimerDevice}
        StateListener := fn_gameplay_state_listener:
            EnterCallback := option{StartOnState? and TimerListenerWrapper.StartAndAwaitSuccess or TimerListenerWrapper.AwaitSuccess}
            ExitCallback := option{type{_()<suspends>:void}(TimerListenerWrapper.Reset)}
            PostExecutionTrigger := option:
                fn_gameplay_state_trigger:
                    DefaultStateToTrigger := StateToTrigger
        Self.AddStateListener(?State:=comparable(State), ?Listener:=StateListener)

    AddAutoCompleteTimer(State : rr_state_enum, HUDTimer : custom_hud_timer, StateToTrigger : rr_state_enum, ?StartOnState : logic = false)<transacts>:void =
        StateListener := fn_gameplay_state_listener:
            EnterCallback := option{StartOnState? and HUDTimer.StartAndAwaitSuccess or HUDTimer.AwaitSuccess}
            ExitCallback := option{type{_()<suspends>:void}(HUDTimer.Reset)}
            PostExecutionTrigger := option:
                fn_gameplay_state_trigger:
                    DefaultStateToTrigger := StateToTrigger
        Self.AddStateListener(?State:=comparable(State), ?Listener:=StateListener)

    # AddStateHandler<override>(InStateHandler:fn_gameplay_state_handler)<transacts>:void =
    #     if(RRStateHandler := rr_state_handler_interface[InStateHandler]):
    #         AddStateListeners(RRStateHandler.GetEnterExitListeners())
    #     else:
    #         (super:)AddStateHandler(InStateHandler)

    # AddAutoCompleteTimer(State : rr_state_enum, TimerDevice : timer_device, StateTrigger : fn_gameplay_state_triggerable, ?StartOnState : logic = false)<transacts>:void =
    #     TimerListenerWrapper := timer_listener_wrapper{TimerDevice := TimerDevice}
    #     StateListener := fn_gameplay_state_listener:
    #         EnterCallback := option{StartOnState? and TimerListenerWrapper.StartAndAwaitSuccess or TimerListenerWrapper.AwaitSuccess}
    #         ExitCallback := option{type{_()<suspends>:void}(TimerListenerWrapper.Reset)}
    #         PostExecutionTrigger := option{StateTrigger}
    #     Self.AddStateListener(?State:=comparable(State), ?Listener:=StateListener)

timer_listener_wrapper := class:
    TimerDevice : timer_device

    AwaitSuccess()<suspends>:void =
        TimerDevice.SuccessEvent.Await()

    StartAndAwaitSuccess()<suspends>:void =
        TimerDevice.StartAndAwaitSuccess()

    Reset():void =
        TimerDevice.Reset()