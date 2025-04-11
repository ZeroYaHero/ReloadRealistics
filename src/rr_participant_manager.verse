using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }
using { state }

rr_participant_manager := class(fn_gameplay_participant_manager, fn_gameplay_state_observer):

    var CurrentState:comparable = comparable()
    HUDMessageDevice:hud_message_device

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
        spawn{AwaitAndAwardCombatEvents(InAgent)}

        set InitializedParticipants = InitializedParticipants.SetAdd(InAgent)
        OnParticipantInitialized(InAgent)
        _ParticipantInitializedEvent.Signal(InAgent)

    AwaitAndAwardCombatEvents<private>(InAgent:agent)<suspends>:void =
        branch:
            sync:
                AwaitAndAwardDown(InAgent)
                AwaitAndAwardElimination(InAgent)
        ParticipantExitEvent().AwaitPayloadEqual(InAgent)

    AwaitAndAwardDown<private>(InAgent:agent)<suspends>:void =
        loop:
            if(CauseDownEvent := GetCauseDownEvent[InAgent]):
                CauseDownEvent.Await()
                AwardXP(InAgent, rr_award.Knock)
            else:
                Sleep(1.0)

    AwaitAndAwardElimination<private>(InAgent:agent)<suspends>:void =
        loop:
            if(CauseEliminationEvent := GetCauseEliminationEvent[InAgent]):
                CauseEliminationEvent.Await()
                AwardXP(InAgent, rr_award.Elimination)
            else:
                Sleep(1.0)

    OnParticipantInitialized<override>(InAgent : agent):void =
        if(CurrentEnum := ComparableEnumRRStateMap[CurrentState]):
            case(CurrentEnum):
                rr_state_enum.CombatRound =>
                    HUDMessageDevice.Show(InAgent, MiddleOfRoundMessage(InAgent))
                    GiveOneSpawn(InAgent) 
                    spawn{RepeatAttemptEliminateCharacter(InAgent)}
                _ =>

    UpdateState<override>(InState:comparable)<transacts>:void =
        set CurrentState = InState

MiddleOfRoundMessage<localizes><public>(InAgent:agent):message = "Welcome {InAgent}!\nYou joined in the middle of a round!"