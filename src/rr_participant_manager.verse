using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }

rr_participant_manager := class(fn_gameplay_participant_manager, fn_gameplay_state_observer):

    var CurrentState:comparable = comparable()
    MiddleOfRoundHUD:hud_message_device

    EnumMap : [comparable]rr_state_enum = map:
        rr_state_enum.WaitingForPlayers =>  rr_state_enum.WaitingForPlayers
        rr_state_enum.TeamSelect        =>  rr_state_enum.TeamSelect
        rr_state_enum.CombatRound       =>  rr_state_enum.CombatRound
        rr_state_enum.RematchRequeue    =>  rr_state_enum.RematchRequeue
        rr_state_enum.OpponentsLeft     =>  rr_state_enum.OpponentsLeft
        rr_state_enum.GameEnd           =>  rr_state_enum.GameEnd

    _InitializeParticipant<override>(InAgent : agent)<suspends>:void =
        if:
            Player := player[InAgent]
            not Player.IsActive[]
        then:
            loop:
                if(Player.IsActive[]):
                    break
                AwaitServerTick()
        FortCharacter := InAgent.GetFortCharacter[] or InAgent.GetFortCharacterSuspends()
        InitializeCauseCombatEvents(InAgent, FortCharacter)

        set InitializedParticipants = InitializedParticipants.SetAdd(InAgent)
        OnParticipantInitialized(InAgent)
        ParticipantInitializedEvent.Signal(InAgent)

    OnParticipantInitialized<override>(InAgent : agent):void =
        if(CurrentEnum := EnumMap[CurrentState]):
            case(CurrentEnum):
                # rr_state_enum.WaitingForPlayers => InAgent.EliminateCharacter()
                # rr_state_enum.TeamSelect => void
                rr_state_enum.CombatRound =>
                    MiddleOfRoundHUD.Show(InAgent)
                    GiveOneSpawn(InAgent) 
                    spawn{RepeatAttemptEliminateCharacter(InAgent)}
                # rr_state_enum.RematchRequeue => InAgent.EliminateCharacter()
                # rr_state_enum.OpponentsLeft => InAgent.EliminateCharacter()
                # rr_state_enum.GameEnd => InAgent.EliminateCharacter()
                _ =>

    UpdateState<override>(InState : comparable)<transacts>:void =
        set CurrentState = InState