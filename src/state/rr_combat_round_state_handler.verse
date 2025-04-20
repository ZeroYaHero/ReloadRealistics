using { FN_Gameplay }
using { scoring }

rr_combat_round_state_handler<public> := class(fn_gameplay_state_handler):
    RoundManager<public>:rr_round_manager
    ScoreController<public>:rr_scoring_controller

    EnterCombatRound()<suspends>:void =
        ScoreController.RefreshView()
        RoundManager.StartRound()
        RoundManager.AwaitRoundCleaned()

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.CombatRound => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterCombatRound}
                    PostExecutionTrigger := option:
                        fn_gameplay_state_trigger:
                            DefaultStateToTrigger := rr_state_enum.Transition