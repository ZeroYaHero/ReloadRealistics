using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }

using { FN_Gameplay }
using { teams }
using { config }

rr_transition_state_handler<public> := class(fn_gameplay_state_triggerable, fn_gameplay_state_handler):
    ParticipantManager<public>:rr_participant_manager
    TeamSelector<public>:rr_team_selector
    TeamConfig<public>:rr_teams_config
    RoundManager<public>:rr_round_manager

    GetStateToTrigger<override>():comparable =
        if(NotAnyRoundsLeft[]):
            return rr_state_enum.RematchRequeue
        if(Solos[]):
            for(NeutralizedAgent:TeamSelector.GetNeutralizedAgents()):
                TeamSelector.AutoSelectTeam(NeutralizedAgent)
            return rr_state_enum.CombatRound
        if(OnlyOneTeam[]):
            return rr_state_enum.OpponentsLeft
        return rr_state_enum.TeamSelect

    NotAnyRoundsLeft()<transacts><decides>:void = 
        not RoundManager.HasNextRound[]

    OnlyOneTeam()<transacts><decides>:void =
        TeamSelector.GetNeutralizedAgents().Length = 0
        var TeamWithPlayers:logic = false
        for(TeamIndex->TeamMembers:TeamSelector.GetSelectableTeamIndexMembersMap()):
            if(TeamMembers.Length > 0):
                if(TeamWithPlayers?):
                    Fail[]
                set TeamWithPlayers = true

    # TODO: Solos is being triggered when there are just 2 players. 
    Solos()<transacts><decides>:void =
        ParticipantManager.GetInitializedParticipants().Length > 1
        TeamSelector.GetSelectableTeamCapacity() = 1 or ParticipantManager.GetInitializedParticipants().Length < 3

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.Transition => array:
                fn_gameplay_state_listener:
                    PostExecutionTrigger := option{Self}