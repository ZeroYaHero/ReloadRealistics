using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { FN_Gameplay }

rr_state_enum := enum:
    WaitingForPlayers
    TeamSelect
    Combat
    RematchRequeue
    OpponentsLeft
    GameEnd

rr_state_handler_interface := interface:

    OnWaitingForPlayers()<suspends>:void =
        void

    OnTeamSelect()<suspends>:void =
        void

    OnCombat()<suspends>:void =
        void

    OnRematchRequeue()<suspends>:void =
        void

    OnOpponentsLeft()<suspends>:void =
        void

    OnGameEnd()<suspends>:void =
        void

    GetStateListenersMap()<transacts>:[comparable][]fn_gameplay_state_listener =
        map:
            rr_state_enum.WaitingForPlayers => array{CreateStateListener(OnWaitingForPlayers)}
            rr_state_enum.TeamSelect => array{CreateStateListener(OnTeamSelect)}
            rr_state_enum.Combat => array{CreateStateListener(OnCombat)}
            rr_state_enum.RematchRequeue => array{CreateStateListener(OnRematchRequeue)}
            rr_state_enum.OpponentsLeft => array{CreateStateListener(OnOpponentsLeft)}

rr_state_machine := class(fn_gameplay_state_machine):

    AddAutoCompleteTimer(State : rr_state_enum, TimerDevice : timer_device, StateToPush : rr_state_enum)<transacts>:void =
        Self.AddStateListener(State, CreateStateListener(TimerDevice.SuccessEvent.Await, ?SetStateOnExecution := option{StateToPush}))

    AddStateHandler(InHandler : rr_state_handler_interface)<transacts>:void =
        Self.AddStateListeners(InHandler.GetStateListenersMap())

var RRStateMachine : weak_map(session, rr_state_machine) = map{}

SetState(InState : rr_state_enum):void =
    if(StateMachine := RRStateMachine[GetSession()]):
        StateMachine.SetState(InState)