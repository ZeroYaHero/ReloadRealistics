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
    selected_team_tag := class(team_verse_tag){}

(SelectableTeamParameters : []rr_selectable_team_parameter).IndexColorMap():[int]color = 
    Dict of for(SelectableTeamParameter : SelectableTeamParameters):
        SelectableTeamParameter.Index, SelectableTeamParameter.Color

rr_selectable_team_parameter := class<concrete>:

    @editable   Index : int = -1
    @editable   Color : color = color{}

rr_selectable_team := class:

    Index : int
    Color : color
    SelectVolume<public> : mutator_zone_device
    Selector<public> : class_and_team_selector_device
    DisplaySelector<public> : class_and_team_selector_device
    PlayerReferenceDevices<public> : []player_reference_device

    Show():void =
        # TODO: teleport logic
        if { DisplaySelector.TeleportTo[DisplaySelector.GetTransform().TransZ(384.0)] }

        SelectVolume.Enable()
        DisplaySelector.Enable()
        for:
            PlayerReferenceDevice : PlayerReferenceDevices
        do:
            PlayerReferenceDevice.Enable()

    Hide():void =
        # TODO: teleport logic
        if { DisplaySelector.TeleportTo[DisplaySelector.GetTransform().TransZ(-384.0)] }

        SelectVolume.Disable()
        DisplaySelector.Disable()
        for:
            PlayerReferenceDevice : PlayerReferenceDevices
        do:
            PlayerReferenceDevice.Disable()

rr_team_selector := class:

    SelectableTeams : []rr_selectable_team
    NeutralTeamSelector : class_and_team_selector_device
    SelectTeamDialog : popup_dialog_device
    FailedSelectHUD : hud_message_device
    MinimumSelectableTeams : int
    SelectableTeamCapacity : int
    NeutralTeamIndex : int
    var AgentToReference : [agent]player_reference_device = map{}
    var NotYetSelected : []agent = array{}

    ListenToSelections():void =
        spawn{ListenUISelections()}
        FortPlayspace := GetMainDevicePlayspace()
        TeamCollection := FortPlayspace.GetTeamCollection()
        ParticipantCount := FortPlayspace.GetParticipants().Length
        MaxNumberOfTeams := Max(MinimumSelectableTeams, Ceil(ParticipantCount / SelectableTeamCapacity))  or PrintAndErr("Unreachable: Ceil Operation Failed")
        MaxTeamSize := Ceil(ParticipantCount / MaxNumberOfTeams)                                          or PrintAndErr("Unreachable: Ceil Operation Failed")
        for(Index -> SelectableTeam : SelectableTeams):
            if(Index < MaxNumberOfTeams):
                Print("Showing/Awaiting Volume Selection")
                spawn{ListenVolumeSelections(SelectableTeam)}
            else:
                Print("Hiding Volume Selection")
                SelectableTeam.Hide()

    GetSelectableTeamWithIndex(TeamIndex : int)<transacts><decides>:rr_selectable_team = 
        var OpSelectableTeam : ?rr_selectable_team = false
        loop:
            for(SelectableTeam : SelectableTeams):
                if(SelectableTeam.Index = TeamIndex):
                    set OpSelectableTeam = option{SelectableTeam}
                    break
            break
        OpSelectableTeam?

    GetSelectableTeamIndexMembersMap()<transacts>:[int][]agent =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        Dict of for:
            SelectableTeam : SelectableTeams
            TeamMembers := TeamCollection._GetTeamMembers(SelectableTeam.Index)
        do:
            (SelectableTeam.Index, TeamMembers)

    RefreshUI():void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        for(SelectableTeam : SelectableTeams):
            TeamMembers := TeamCollection._GetTeamMembers(SelectableTeam.Index)
            TeamMembersMessage := Join of for(I := 0..1):
                if(TeamMember := TeamMembers[I]):
                    DialogPlayerMemberMessage(SelectableTeam.Index, TeamMember)
                else:
                    DialogPlayerSlotMessage(I + 1)
            SelectTeamDialog.SetButtonText(TeamMembersMessage, SelectableTeam.Index - 1)

    ShowUI():void =
        RefreshUI()
        SelectTeamDialog.Show()

    ShowUI(InAgent : agent):void =
        RefreshUI()
        SelectTeamDialog.Show(InAgent)

    HideUI():void =
        SelectTeamDialog.Hide() 

    HideUI(InAgent : agent):void = 
        SelectTeamDialog.Hide(InAgent) 

    Neutralize(InAgent : agent):void =
        if(GetMainDevicePlayspace().GetTeamCollection()._SetTeam[InAgent, NeutralTeamIndex, 100, true]):
            NeutralTeamSelector.ChangeTeam(InAgent)
            if(not NotYetSelected.Find[InAgent]):
                set NotYetSelected += array{InAgent}

    ListenVolumeSelections<private>(InSelectableTeam : rr_selectable_team)<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        InSelectableTeam.Show()
        loop:
            EnteredAgent := InSelectableTeam.SelectVolume.AgentEntersEvent.Await()
            Print("Agent Entered Volume")
            if(not TeamCollection.IsOnTeam[EnteredAgent, InSelectableTeam.Index]):
                Print("EnteredAgent is not on Team")
                if(PlayerIndexOnTeam := TeamCollection._SetTeam[EnteredAgent, InSelectableTeam.Index, 2, false] - 1):
                    InSelectableTeam.Selector.ChangeTeam(EnteredAgent)
                    Print("Set Team Was Succesful")
                    if(CurrentPlayerReference := AgentToReference[EnteredAgent]):
                        CurrentPlayerReference.Clear()
                        Print("Cleared old Reference")
                    if:
                        NewPlayerReference := InSelectableTeam.PlayerReferenceDevices[PlayerIndexOnTeam]
                        set AgentToReference[EnteredAgent] = NewPlayerReference
                    then:
                        NewPlayerReference.Register(EnteredAgent)
                        Print("Registered new Reference")
                    AwardXP(EnteredAgent, rr_award.SelectedTeam)
                    set NotYetSelected = NotYetSelected.RemoveAllElements(EnteredAgent)
                else:
                    Print("Set Team Failed!")
                    FailedSelectHUD.Show(EnteredAgent)

    ListenUISelections<private>()<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        loop:
            AgentIndex := SelectTeamDialog.RespondingButtonEvent.Await()
            if:
                SelectableTeam := SelectableTeams[AgentIndex(1)]
                TeamIndex := SelectableTeam.Index
                Print("Selected Button Index {AgentIndex(1)} which is Team Index {TeamIndex}")
                TeamCollection._SetTeam[AgentIndex(0), TeamIndex, SelectableTeamCapacity, false]
            then:
                SelectableTeam.Selector.ChangeTeam(AgentIndex(0))
                AwardXP(AgentIndex(0), rr_award.SelectedTeam)
                set NotYetSelected = NotYetSelected.RemoveAllElements(AgentIndex(0))
                Print("Team Set on {TeamIndex} Succeeded! Removed them from NotYetSelected")
                RefreshUI()
            else:
                ShowUI(AgentIndex(0))
                Print("Team Set Failed! Attempted to Show Again")

    AwaitUISelection<public>(InAgent : agent)<suspends>:void =
        loop:
            AgentIndex := SelectTeamDialog.RespondingButtonEvent.Await()
            Print("Agent Selected a Team??? Why no Print")
            if(AgentIndex(0) = InAgent):
                break

    AutoSelect<public>():void = 
        HideUI()
        FortPlayspace := GetMainDevicePlayspace()
        TeamCollection := FortPlayspace.GetTeamCollection()
        ParticipantCount := FortPlayspace.GetParticipants().Length
        Print("Participant Count: {ParticipantCount}")
        MaxNumberOfTeams := Max(MinimumSelectableTeams, Ceil(ParticipantCount / SelectableTeamCapacity))  or PrintAndErr("Unreachable: Ceil Operation Failed")
        MaxTeamSize := Ceil(ParticipantCount / MaxNumberOfTeams)                                          or PrintAndErr("Unreachable: Ceil Operation Failed")
        Print("MaxNumberOfTeams: {MaxNumberOfTeams}")
        Print("MaxTeamSize: {MaxTeamSize}")
            for(NotYetSelectedAgent : NotYetSelected):
                Print("Auto Selecting for Agent")
                loop:
                    TeamIndexMemberPairings := SortSelectableTeamsBySize(true)
                    for:
                        IndexSizePair : TeamIndexMemberPairings
                        PrintInFor["TeamIndex: {IndexSizePair(0)}, TeamSize: {IndexSizePair(1).Length}"]
                        IndexSizePair(1).Length < MaxTeamSize
                        PrintInFor["Size less than MaxTeamSize"]
                        TeamCollection._SetTeam[NotYetSelectedAgent, IndexSizePair(0), SelectableTeamCapacity, false]
                    do:
                        Print("Successfully Set Team")
                        AwardXP(NotYetSelectedAgent, rr_award.SelectedTeam)
                        set NotYetSelected = NotYetSelected.RemoveAllElements(NotYetSelectedAgent)
                        break
                    break

    SortSelectableTeamsBySize(Decreasing : logic):[]tuple(int, []agent) = 
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        TeamIndexMemberPairings := for:
            SelectableTeam : SelectableTeams
            TeamMembers := TeamCollection._GetTeamMembers(SelectableTeam.Index)
        do:
            (SelectableTeam.Index, TeamMembers)
        if(Decreasing?):
            SortBy(TeamIndexMemberPairings, TupleSecondLongerComp)
        else:
            SortBy(TeamIndexMemberPairings, TupleSecondShorterComp)

# Team Select Player Member Message
DialogPlayerMemberMessage<localizes><internal>(Enumeration : int, InAgent : agent):message = "{Enumeration}. {InAgent}\n"

# Team Select Dialog Empty Slot Message
DialogPlayerSlotMessage<localizes><internal>(Enumeration : int):message = "{Enumeration}.\n"

# Basic Scores Comparator
TeamScoresComparator<public>(Lhs : tuple(int, int), Rhs : tuple(int, int))<computes><decides>:void =
    Lhs(1) > Rhs(1)
