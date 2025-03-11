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
        SelectVolume.Enable()
        DisplaySelector.Enable()
        for(PlayerReferenceDevice : PlayerReferenceDevices):
            PlayerReferenceDevice.Enable()

    Hide():void =
        # TODO: teleport logic
        SelectVolume.Disable()
        DisplaySelector.Disable()
        for(PlayerReferenceDevice : PlayerReferenceDevices):
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

    AwaitSelections():void =
        spawn{AwaitUISelection()}
        FortPlayspace := GetMainDevicePlayspace()
        TeamCollection := FortPlayspace.GetTeamCollection()
        MaxNumberOfTeams := Max(MinimumSelectableTeams, Ceil(FortPlayspace.GetParticipants().Length / SelectableTeamCapacity))  or PrintAndErr("Unreachable: Ceil Operation Failed")
        MaxTeamSize := Ceil(FortPlayspace.GetParticipants().Length / MaxNumberOfTeams)                                          or PrintAndErr("Unreachable: Ceil Operation Failed")
        for(Index -> SelectableTeam : SelectableTeams):
            if(Index < MaxNumberOfTeams):
                spawn{AwaitVolumeSelection(SelectableTeam)}
            else:
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
            set NotYetSelected += array{InAgent}

    AwaitVolumeSelection<private>(InSelectableTeam : rr_selectable_team)<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        InSelectableTeam.Show()
        loop:
            EnteredAgent := InSelectableTeam.SelectVolume.AgentEntersEvent.Await()
            if(not TeamCollection.IsOnTeam[EnteredAgent, InSelectableTeam.Index]):
                if(PlayerIndexOnTeam := TeamCollection._SetTeam[EnteredAgent, InSelectableTeam.Index, 2, false]):
                    InSelectableTeam.Selector.ChangeTeam(EnteredAgent)
                    if(CurrentPlayerReference := AgentToReference[EnteredAgent]):
                        CurrentPlayerReference.Clear()
                    if:
                        NewPlayerReference := InSelectableTeam.PlayerReferenceDevices[PlayerIndexOnTeam]
                        set AgentToReference[EnteredAgent] = NewPlayerReference
                    then:
                        NewPlayerReference.Register(EnteredAgent)
                    GetGlobalAnalyzerAwarder().Award(EnteredAgent, rr_award.SelectedTeam)
                    set NotYetSelected = NotYetSelected.RemoveAllElements(EnteredAgent)
                else:
                    FailedSelectHUD.Show(EnteredAgent)

    AwaitUISelection<private>()<suspends>:void =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        loop:
            AgentIndex := SelectTeamDialog.RespondingButtonEvent.Await()
            if:
                SelectableTeam := SelectableTeams[AgentIndex(1)]
                TeamIndex := SelectableTeam.Index
                TeamCollection._SetTeam[AgentIndex(0), TeamIndex, SelectableTeamCapacity, false]
            then:
                SelectableTeam.Selector.ChangeTeam(AgentIndex(0))
                GetGlobalAnalyzerAwarder().Award(AgentIndex(0), rr_award.SelectedTeam)
                set NotYetSelected = NotYetSelected.RemoveAllElements(AgentIndex(0))
                RefreshUI()
            else:
                FailedSelectHUD.Show(AgentIndex(0))
                ShowUI(AgentIndex(0))

    AutoSelect<public>():void = 
        HideUI()
        FortPlayspace := GetMainDevicePlayspace()
        TeamCollection := FortPlayspace.GetTeamCollection()
        MaxNumberOfTeams := Max(MinimumSelectableTeams, Ceil(FortPlayspace.GetParticipants().Length / SelectableTeamCapacity))  or PrintAndErr("Unreachable: Ceil Operation Failed")
        MaxTeamSize := Ceil(FortPlayspace.GetParticipants().Length / MaxNumberOfTeams)                                          or PrintAndErr("Unreachable: Ceil Operation Failed")
        Print("MaxNumberOfTeams: {MaxNumberOfTeams}")
        Print("MaxTeamSize: {MaxTeamSize}")
            for(NotYetSelectedAgent : NotYetSelected):
                Print("Auto Selecting for Agent")
                loop:
                    TeamIndexSizePairings := SortSelectableTeamsBySize(true)
                    for:
                        IndexSizePair : TeamIndexSizePairings
                        PrintInFor["TeamIndex: {IndexSizePair(0)}, TeamSize: {IndexSizePair(1).Length}"]
                        IndexSizePair(1).Length < MaxTeamSize
                        PrintInFor["Size less than MaxTeamSize"]
                        TeamCollection._SetTeam[NotYetSelectedAgent, IndexSizePair(0), SelectableTeamCapacity, false]
                    do:
                        Print("Successfully Set Team")
                        GetGlobalAnalyzerAwarder().Award(NotYetSelectedAgent, rr_award.SelectedTeam)
                        set NotYetSelected = NotYetSelected.RemoveAllElements(NotYetSelectedAgent)
                        break
                    break

    SortSelectableTeamsBySize(Decreasing : logic):[]tuple(int, []agent) =
        TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
        TeamIndexSizePairings := for:
            SelectableTeam : SelectableTeams
        do:
            (SelectableTeam.Index, TeamCollection._GetTeamMembers(SelectableTeam.Index))
        if(Decreasing?):
            SortBy(TeamIndexSizePairings, TupleSecondLongerComp)
        else:
            SortBy(TeamIndexSizePairings, TupleSecondShorterComp)

# Team Select Player Member Message
DialogPlayerMemberMessage<localizes><internal>(Enumeration : int, InAgent : agent):message = "{Enumeration}. {InAgent}\n"

# Team Select Dialog Empty Slot Message
DialogPlayerSlotMessage<localizes><internal>(Enumeration : int):message = "{Enumeration}.\n"

# Basic Scores Comparator
TeamScoresComparator<public>(Lhs : tuple(int, int), Rhs : tuple(int, int))<computes><decides>:void =
    Lhs(1) > Rhs(1)
