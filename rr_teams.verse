using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Teams }
using { /Verse.org/Colors }
using { /Verse.org/Simulation/Tags }
using { /Fortnite.com/FortPlayerUtilities }
using { /UnrealEngine.com/Temporary }
using { /Fortnite.com/Characters }

using { FN_Gameplay }

team_verse_tag := class(tag){}
    team_neutral_selector_tag := class(team_verse_tag){}
    team_one_tag := class(team_verse_tag){}
    team_two_tag := class(team_verse_tag){}
    team_three_tag := class(team_verse_tag){}
    team_four_tag := class(team_verse_tag){}
    display_selector_device_tag := class(team_verse_tag){}
    jip_team_select_dialog := class(team_verse_tag){}
    failed_to_join_team_hud := class(team_verse_tag){}

# Team Parameter Groups
rr_team_parameters<public> := class<concrete>(fn_team_manager_parameters):
    @editable   DefaultCapacity<public> : int = 100
    @editable   Teams : []rr_team_parameter = array{}
    @editable   NeutralTeamIndex : int = 0

    IndexCapacityMap<override>():[int]int =
        Dict of for(TeamParam : Teams):
            (TeamParam.Index, TeamParam.Capacity? or DefaultCapacity)

    IndexTintMap():[int]color =
        Dict of for(TeamParam : Teams):
            (TeamParam.Index, TeamParam.Color)
    
rr_team_parameter<public> := class<concrete>(fn_team_parameter_basic):
    @editable   Color<public> : color = color{}

# Team Data
rr_teams_data := struct:
    DefaultCapacity : int
    NeutralTeamIndex : int
    NeutralTeamSelector : class_and_team_selector_device
    JIPTeamSelectDialog : popup_dialog_device
    FailedToJoinTeamHUD : hud_message_device
    TeamSize : int
    Teams : []rr_team_data

rr_team_data<public> := class<unique>:
    Parameter<public> : rr_team_parameter
    SelectVolume<public> : mutator_zone_device
    ClassAndTeamSelector<public> : class_and_team_selector_device
    PlayerReferenceDevices<public> : []player_reference_device
    DisplayTeamSelector<public> : class_and_team_selector_device

# Team and Participant Manager
rr_team_and_player_manager := class(fn_team_manager):

    FortPlayspace : fort_playspace
    TeamsData : rr_teams_data <# ! Teams Data is IN-ORDER #>
    var AgentToReference : [agent]player_reference_device = map{}
    var ParticipantsWithoutTeam : []agent = array{}
    var <private>RoundWinnerIndex<private> : ?int = false
    var <private>TeamScores<private> : [int]int = map{}

    # Sets the Agents team to the specified index
    SetTeam<override>(InAgent:agent, Index:int, ?Force:logic=false)<transacts><decides>:int =
        Result := (super:)SetTeam[InAgent, Index, ?Force := Force]
        if(Index <> TeamsData.NeutralTeamIndex):
            set ParticipantsWithoutTeam = ParticipantsWithoutTeam.RemoveAllElements(InAgent)
        else if(not ParticipantsWithoutTeam.Find[InAgent]):
            set ParticipantsWithoutTeam += array{InAgent}
        Result

    # Auto Team Select
    AutoTeamSelect<public>():void = 
        NumberOfTeams := Max(2, Ceil(GetParticipants().Length / TeamsData.TeamSize))    or PrintAndErr("Unreachable: NoT Ceil Operation Failed")
        MaxTeamSize := Ceil(FortPlayspace.GetParticipants().Length / NumberOfTeams)     or PrintAndErr("Unreachable: MTS Ceil Operation Failed")
            for(Participant : ParticipantsWithoutTeam):
                HideTeamSelectUI(Participant)
                loop:
                    for:
                        InTeamData : SortTeamsBySize()
                        TeamSize := GetTeamSize(InTeamData.Parameter.Index)
                        TeamSize < MaxTeamSize
                        SetTeam[Participant, InTeamData.Parameter.Index]
                    do:
                        InTeamData.ClassAndTeamSelector.ChangeTeam(Participant)
                        break
                    break

    # Puts agents on the neutral team
    NeutralizeAgent(InAgent : agent):void = 
        if { SetTeam[InAgent, TeamsData.NeutralTeamIndex] }

    # Puts an array of agents on the neutral team
    NeutralizeAgents(InAgents : []agent):void =
        for(InAgent : InAgents):
            NeutralizeAgent(InAgent)

    # Set Team Members Vulnerability
    SetTeamVulnerability<public>(WinningIndex : int, Vulnerable : logic):void = 
        for:
            TeamMember : GetTeamMembers[WinningIndex]
            FortCharacter := TeamMember.GetFortChar[]
        do:
            FortCharacter.SetVulnerability(Vulnerable)

    # Simple Wrapper for GetParticipants
    GetParticipants()<transacts>:[]agent =
        FortPlayspace.GetParticipants()

    # Show the Team Select UI (intended for JIP Players)
    ShowTeamSelectUI<public>(InAgent : agent):void =
        UpdateTeamSelectUI()
        TeamsData.JIPTeamSelectDialog.Show(InAgent)

    # Hide the Team Select UI
    HideTeamSelectUI<public>(InAgent : agent):void =
        TeamsData.JIPTeamSelectDialog.Hide(InAgent)

    HideTeamSelectUI<public>():void =
        TeamsData.JIPTeamSelectDialog.Hide()

    MakeRoundWinner(TeamIndex : int)<transacts>:void =
        set RoundWinnerIndex = option{TeamIndex}

    ResetRoundWinner()<transacts>:void =
        set RoundWinnerIndex = false

    # Returns a sorted array of pairings where the left element is the team index and the right is their score (the comparable value).
    GetSortedTeamScores():[]tuple(int, int) =
        set TeamScores = Dict of for:
            TeamIndex -> TeamMembers : GetTeamsWithMembersAndCapacities()
        do:
            if(CurrentScore := TeamScores[TeamIndex]):
                if(TeamIndex = RoundWinnerIndex?):
                    (TeamIndex, CurrentScore + 1)
                else:
                    (TeamIndex, CurrentScore)
            else:
                (TeamIndex, 0)
        SortBy(TeamScores.Items(), TeamScoresComparator)

    # Await Team Selection
    AwaitTeamSelections<public>():void =
        Spawn(AwaitJIPTeamSelection)
        NumberOfTeams := Max(2, Ceil(GetParticipants().Length / TeamsData.TeamSize))    or PrintAndErr("Unreachable: Ceil Operation Failed")
        MaxTeamSize := Ceil(FortPlayspace.GetParticipants().Length / NumberOfTeams)     or PrintAndErr("Unreachable: Ceil Operation Failed")
        for:
            Index -> Team : TeamsData.Teams
        do:
            if(Index < NumberOfTeams):
                SpawnParam(AwaitVolumeTeamSelection, (Team, NumberOfTeams, MaxTeamSize))
            else:
                Team.DisplayTeamSelector.Disable()
                Team.ClassAndTeamSelector.Disable()

    # Await Volume Team Selection
    AwaitVolumeTeamSelection<private>(InTeamData : rr_team_data, NumberOfTeams : int, MaxTeamSize : int)<suspends>:void =
        InTeamData.DisplayTeamSelector.Enable()
        InTeamData.ClassAndTeamSelector.Enable()
        InTeamData.SelectVolume.Enable()
        loop:
            Agent := InTeamData.SelectVolume.AgentEntersEvent.Await()
            if:
                not IsOnTeam[Agent, InTeamData.Parameter.Index]
                PlayerIndexOnTeam := SetTeam[Agent, InTeamData.Parameter.Index]
            then:
                InTeamData.ClassAndTeamSelector.ChangeTeam(Agent)

                # Agent Reference Device Clear and Registering
                if (CurrentPlayerReference := AgentToReference[Agent]):
                    CurrentPlayerReference.Clear()
                if (NewPlayerReference := InTeamData.PlayerReferenceDevices[PlayerIndexOnTeam], set AgentToReference[Agent] = NewPlayerReference):
                    NewPlayerReference.Register(Agent)

                    # Check if all player that need to be added to a team have been.
                    # TeamsWithSpace := for:
                    #     Index -> TeamData : TeamsData.Teams
                    #     Index < NumberOfTeams
                    #     GetTeamMembers[TeamData.Parameter.Index].Length < MaxTeamSize
                    # do:
                    #     TeamData

                    # # All players are on a team or no teams have space
                    # if:
                    #     ParticipantsWithoutTeam.Length = 0 or TeamsWithSpace.Length <= 1
                    #     GetCurrentState().Key = "TeamSelect" # FIXME!: Isn't this unecessary?
                    # then:
                    #     GetState(rr_state.TeamSelect).AttemptComplete()
    
    # Await JIP Team Selection
    AwaitJIPTeamSelection<private>()<suspends>:void =
        loop:
            AgentIndex := TeamsData.JIPTeamSelectDialog.RespondingButtonEvent.Await()
            if:
                TeamIndex := TeamsData.Teams[AgentIndex(1)].Parameter.Index
                SetTeam[AgentIndex(0), TeamIndex]
            then:
                AgentIndex(0).Eliminate()
                UpdateTeamSelectUI()
            else:
                spawn{RetryJIPTeamSelection(AgentIndex(0))}

    # Called when the player selected a team that could not be selected, therefore they need to be notified of the reason and attempt again.
    RetryJIPTeamSelection<private>(InAgent : agent)<suspends>:void =
        TeamsData.FailedToJoinTeamHUD.Show(InAgent)
        race:
            if(CombatState := GetState["Combat"]):
                CombatState.AttemptingInitializingEvent.Await()
                CombatState.CompletedEvent.Await()
            else:
                Sleep(Inf)
            block:
                Sleep(1.0)
                ShowTeamSelectUI(InAgent)

    # Update the messages that represent the members on a team
    UpdateTeamSelectUI<private>():void =
        for:
            Team : TeamsData.Teams
            TeamMembers := GetTeamMembers[Team.Parameter.Index]
        do:
            TeamMembersMessage := Join of for(I := 0..1):
                if(TeamMember := TeamMembers[I]):
                    PlayerMessage(Team.Parameter.Index, TeamMember)
                else:
                    PlayerSlotMessage(I + 1)
            TeamsData.JIPTeamSelectDialog.SetButtonText(TeamMembersMessage, Team.Parameter.Index - 1)

    # Helper Player Messages for Team Select UI
    PlayerMessage<localizes><private>(Enumeration : int, InAgent : agent):message = "{Enumeration}. {InAgent}\n"
    PlayerSlotMessage<localizes><private>(Enumeration : int):message = "{Enumeration}.\n"

    # Sort Teams By Size
    SortTeamsBySize<public>()<transacts>:[]rr_team_data =
        TeamIndexSize := for:
            TeamData : TeamsData.Teams
            TeamSize := GetTeamSize(TeamData.Parameter.Index)
        do:
            (TeamData, TeamSize)
    
        SortBy(TeamIndexSize, TeamSizeComparator).ToMap().Keys()

# Basic Scores Comparator
TeamScoresComparator<public>(Lhs : tuple(int, int), Rhs : tuple(int, int))<computes><decides>:void =
    Lhs(1) > Rhs(1)

# Basic Size Comparator
TeamSizeComparator<public>(Lhs : tuple(rr_team_data, int), Rhs : tuple(rr_team_data, int))<computes><decides>:void =
    Lhs(1) > Rhs(1)


