using { /Fortnite.com/Devices }
using { FN_Gameplay }
using { teams }
using { scoring }

rr_team_select_state_handler<public> := class(fn_gameplay_state_handler):
    ParticipantManager<public>:rr_participant_manager
    ScoreController<public>:rr_scoring_controller
    TeamProp<public>:creative_prop
    TeamSelector<public>:rr_team_selector
    TeamSelectSFX<public>:audio_player_device
    TeamSelectTimer<public>:hud_message_timer
    TeamSelectTimerDurationMap<public>:[int]float
    DefaultTeamSelectTimerDuration<public>:float

    block:
        TeamProp.Hide()

    EnterTeamSelect()<suspends>:void =
        spawn{ShowTeamsDecideTimer()}
        RefreshScoreHUDOnTeamSelect()

    ShowTeamsDecideTimer()<suspends>:void =
        TeamProp.Show()
        ShowAndEnableSelectableTeams()
        TeamSelector.TeleportMembersToTeam()
        TeamSelector.RefreshAllPlayerReferences()
        TeamSelectTimer.SetMaxDuration(GetTeamSelectTimerDuration())
        TeamSelectTimer.StartAll()
        AwaitTimer(1.0)
        for(Participant:ParticipantManager.GetInitializedParticipants()):
            TeamSelectSFX.Play(Participant)

    ShowAndEnableSelectableTeams():void =
        var TeamsWithMultipleMembersSet:[]int = array{}
        for:
            TeamIndex -> TeamMembers:TeamSelector.GetSelectableTeamIndexMembersMap()
            SelectableTeam := TeamSelector.GetSelectableTeam[TeamIndex]
        do:
            if(TeamMembers.Length >= TeamSelector.MinimumTeamSizeForKeepSelect):
                TeamSelector.ShowAndEnableSelectableTeam(SelectableTeam)
                set TeamsWithMultipleMembersSet = TeamsWithMultipleMembersSet.SetAdd(TeamIndex)
            else:
                TeamSelector.HideAndDisableSelectableTeam(SelectableTeam)
                for(TeamMember:TeamMembers):
                    TeamSelector.Neutralize(TeamMember)

        NumberOfNewTeams := Abs((TeamSelector.GetMaxNumberOfTeams[ParticipantManager.GetInitializedParticipants()] or 0) - TeamsWithMultipleMembersSet.Length)

        var Count:int = 0
        for:
            SelectableTeam:TeamSelector.GetSelectableTeams()
            not TeamsWithMultipleMembersSet.Find[SelectableTeam.Index]
        do:
            if(Count < NumberOfNewTeams):
                TeamSelector.ShowAndEnableSelectableTeam(SelectableTeam)
                set Count += 1
            else:
                TeamSelector.HideAndDisableSelectableTeam(SelectableTeam)

    RefreshScoreHUDOnTeamSelect()<suspends>:void =
        loop:
            ScoreController.RefreshView()
            race:
                TeamSelector.TeamSelectedEvent().Await()
                TeamSelector.NeutralizedEvent().Await()

    GetTeamSelectTimerDuration<private>():float =
        TeamSelectTimerDurationMap[ParticipantManager.GetParticipants().Length] or DefaultTeamSelectTimerDuration

    ExitTeamSelect()<suspends>:void =
        TeamSelector.HideAndDisableAllSelectableTeams()
        for(NeutralizedAgent:TeamSelector.GetNeutralizedAgents()):
            TeamSelector.AutoSelectTeam(NeutralizedAgent)
        TeamProp.Hide()

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.TeamSelect => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterTeamSelect}
                    ExitCallback := option{ExitTeamSelect}
                TeamSelectTimer.GetAutoCompleteTimer(rr_state_enum.CombatRound, ?StartOnState:=false) # Auto complete to CombatRound when timer expires