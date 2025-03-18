using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }

using { FN_Gameplay }

rr_participant_manager := class:

    var InitializedParticipants : []agent = array{}
    ParticipantEntryEvent : event(agent) = event(agent){}
    ParticipantExitEvent : event(agent) = event(agent){}

    GetInitializedParticipants():[]agent = 
        InitializedParticipants

    GetParticipants():[]agent =
        GetMainDevicePlayspace().GetParticipants()

    # Initialize Participant
    OnParticipantAdded<private>(InAgent : agent):void =
        if(Player := player[InAgent]):
            spawn{AwaitActive(Player)}
        else: # Test Player
            OnPlayerFirstActive(InAgent)

    OnParticipantRemoved<private>(InAgent : agent):void =
        void

    # Safeguard for inactive Player's
    AwaitActive<private>(Player : player)<suspends>:void =
        loop:
            if(Player.IsActive[]):
                OnPlayerFirstActive(Player)
                break
            else:
                Sleep(0.1)

    # Retrieve associated FortCharacter reference, SentToSpectate and select team
    OnPlayerFirstActive<private>(InAgent : agent):void =
        if:
            FortCharacter := InAgent.GetFortCharacter[]
        then:
            # InAgent.AttachFortChar(FortCharacter)
            InitializeCauseCombatEvents(InAgent, FortCharacter)
            spawn{AwaitAndAwardCombatEvents(InAgent)}
        else:
            Print("Failed to Get FortCharacter and Player Activity")
            spawn{AwaitFortCharacter(InAgent)}

        # TeamSelector.Neutralize(InAgent)
        if(CurrentState := GetCurrentRRState[]):
            case(CurrentState):
                rr_state.TeamSelect =>
                    # array{InAgent}.TeleportTo(Positions.TeamSelect)
                rr_state.Combat =>
                    spawn{OnPlayerJoinDuringCombat(InAgent)}
                _ =>

            # Await for the Fort Character to be present for attaching.
    AwaitFortCharacter(InAgent : agent)<suspends>:void =
        Print("Awaiting FortCharacter")
        # FortCharacter := InAgent.SpawnAwaitFortChar(0.0).Await()
        # InitializeCauseCombatEvents(InAgent, FortCharacter)
        spawn{AwaitAndAwardCombatEvents(InAgent)}

    AwaitAndAwardCombatEvents<private>(InAgent : agent)<suspends>:void =
        race:
            GetMainDevicePlayspace().ParticipantRemovedEvent().AwaitPayloadEqual(InAgent)
            loop:
                CauseKnockEvent := GetCauseKnockEvent[InAgent] or event(combat_event_result){}
                CauseKnockEvent.Await()
                Print("Caused Knock Granting XP")
                AwardXP(InAgent, rr_award.Knock)
            loop:
                CauseEliminationEvent := GetCauseEliminationEvent[InAgent] or event(combat_event_result){}
                CauseEliminationEvent.Await()
                Print("Caused Elimination Granting XP")
                AwardXP(InAgent, rr_award.Elimination)

    # Player Joined after a round took place
    OnPlayerJoinDuringCombat(InAgent : agent)<suspends>:void =
        # race:
            # StateChangeEvent.Await()
            block:
                loop:
                    AwaitTimer(1.0)
                    # if(PlayerCounterDevice.IsCounted[InAgent]):
                        break
                # loop:
                #     if:
                #         FortCharacter := InAgent.GetFortCharacter[] # todo?: is this really necessary
                #         FortCharacter.IsActive[]
                #     then:
                #         AttemptElimination(FortCharacter)
                #         # TeamSelector.ShowUI(InAgent)
                #         break
                #     Sleep(0.0)

    AttemptElimination(FortCharacter : fort_character)<suspends>:void =
        loop:
            Sleep(0.0)
            if(FortCharacter.IsActive[] or FortCharacter.IsDownButNotOut[]):
                # FortCharacter.Eliminate()
            else:
                break