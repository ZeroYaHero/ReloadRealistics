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
    Transition

ComparableEnumRRStateMap<public>:[comparable]rr_state_enum = map:
    rr_state_enum.WaitingForPlayers =>  rr_state_enum.WaitingForPlayers
    rr_state_enum.TeamSelect        =>  rr_state_enum.TeamSelect
    rr_state_enum.CombatRound       =>  rr_state_enum.CombatRound
    rr_state_enum.RematchRequeue    =>  rr_state_enum.RematchRequeue
    rr_state_enum.OpponentsLeft     =>  rr_state_enum.OpponentsLeft
    rr_state_enum.GameEnd           =>  rr_state_enum.GameEnd
    rr_state_enum.Transition        =>  rr_state_enum.Transition

(TimerDevice:timer_device).GetAutoCompleteTimer(StateToTrigger:rr_state_enum, ?StartOnState:logic = false)<transacts>:fn_gameplay_state_listenable =
    TimerListenerWrapper := timer_listener_wrapper{TimerDevice := TimerDevice}
    fn_gameplay_state_listener:
        EnterCallback := option{StartOnState? and TimerListenerWrapper.StartAndAwaitSuccess or TimerListenerWrapper.AwaitSuccess}
        ExitCallback := option{type{_()<suspends>:void}(TimerListenerWrapper.Reset)}
        PostExecutionTrigger := option:
            fn_gameplay_state_trigger:
                DefaultStateToTrigger := StateToTrigger

(HUDTimer:hud_message_timer).GetAutoCompleteTimer(StateToTrigger:rr_state_enum, ?StartOnState:logic = false)<transacts>:fn_gameplay_state_listenable =
    fn_gameplay_state_listener:
        EnterCallback := option{StartOnState? and HUDTimer.StartAndAwaitSuccessAll or HUDTimer.AwaitSuccessAll}
        ExitCallback := option{type{_()<suspends>:void}(HUDTimer.StopAll)}
        PostExecutionTrigger := option:
            fn_gameplay_state_trigger:
                DefaultStateToTrigger := StateToTrigger

timer_listener_wrapper := class:
    TimerDevice : timer_device

    AwaitSuccess()<suspends>:void =
        TimerDevice.SuccessEvent.Await()

    StartAndAwaitSuccess()<suspends>:void =
        TimerDevice.StartAndAwaitSuccess()

    Reset():void =
        TimerDevice.Reset()