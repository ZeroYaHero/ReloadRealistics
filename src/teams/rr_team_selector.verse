using { /UnrealEngine.com/Temporary }
using { /Verse.org/Concurrency }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Verse.org/Colors }

using { FN_Gameplay }
using { scoring }

rr_team_selector<public> := class(ui_component_interface):
    ParticipantManager<public>:rr_participant_manager
    TeamCollection<public>:fort_team_collection
    SelectableTeams<public>:[]rr_selectable_team
    SelectableTeamCapacity<public>:int
    MinimumSelectableTeams<public>:int
    MinimumTeamSizeForKeepSelect<public>:int
    NeutralizedIndex<public>:int
    NeutralizedTeleporters<public>:[]teleporter_device
    NeutralizedSFXDevice<public>:audio_player_device
    HUDMessageDevice<public>:hud_message_device
    TeamSelectUI<public>:popup_dialog_device
    _NeutralizedEvent<private>:event(agent) = event(agent){}
    _TeamSelectedEvent<private>:event(agent) = event(agent){}
    var <private>NeutralizedAgents<private>:[]agent = array{}
    var <private>AgentPlayerReferenceDeviceMap:[agent]?player_reference_device = map{} 
    var <private>SelectableTeamHiddenMap:[int]logic = map{}

    # Public 
    Initialize<public>():void =
        for(SelectableTeam:SelectableTeams):
            spawn{ListenTeamEnterExitEvents(SelectableTeam)}
            HideAndDisableSelectableTeam(SelectableTeam)

    Neutralize<public>(InAgent:agent):void =
        if(TeamCollection._SetTeam[InAgent, NeutralizedIndex]):
            set NeutralizedAgents = NeutralizedAgents.SetAdd(InAgent)
            _NeutralizedEvent.Signal(InAgent)
            if:
                CurrentPlayerReferenceDevice := AgentPlayerReferenceDeviceMap[InAgent]?
                set AgentPlayerReferenceDeviceMap[InAgent] = false
            then:
                CurrentPlayerReferenceDevice.Clear()

    NeutralizedEvent<public>():awaitable(agent) = 
        _NeutralizedEvent

    SelectTeam<public>(InAgent:agent, Index:int):logic =
        if:
            SelectableTeam := GetSelectableTeam[Index]
            AgentIndexOnTeam := TeamCollection._SetTeam[InAgent, Index, ?Capacity := SelectableTeam.OverrideCapacity? or SelectableTeamCapacity] - 1
        then:
            set NeutralizedAgents = NeutralizedAgents.SetRemove(InAgent)
            _TeamSelectedEvent.Signal(InAgent)
            SelectableTeam.SelectSFXDevice.Play(InAgent)
            HUDMessageDevice.Show(InAgent, SelectedTeamMessage(SelectableTeam.Name), ?DisplayTime:=2.5)
            AwardXP(InAgent, rr_award.SelectedTeam)
            RefreshPlayerReferences(SelectableTeam)
            true
        else if(TeamCollection.IsOnTeam[InAgent, Index]):
            true
        else:
            false

    TeamSelectedEvent<public>():awaitable(agent) = 
        _TeamSelectedEvent

    AutoSelectTeam<public>(InAgent:agent):void = 
        if(MaxTeamSize := GetMaxTeamSize[ParticipantManager.GetInitializedParticipants()]):
            loop:
                for:
                    IndexMembersPair:SortBy(GetSelectableTeamIndexMembersMap().Items(), TupleSecondLongerComp)
                    IndexMembersPair(1).Length < MaxTeamSize
                do:
                    SelectedTeam := SelectTeam(InAgent, IndexMembersPair(0))
                    if(SelectedTeam?):
                        break
                break

    GetSelectableTeamCapacity<public>()<transacts>:int =
        SelectableTeamCapacity

    GetMinNumberOfTeams<public>():int = 
        MinimumSelectableTeams

    GetMaxNumberOfTeams<public>(InAgents:[]agent)<transacts><decides>:int =
        Max(MinimumSelectableTeams, Ceil(InAgents.Length / SelectableTeamCapacity))

    GetMaxTeamSize<public>(InAgents:[]agent)<transacts><decides>:int =
        Ceil(InAgents.Length / GetMaxNumberOfTeams[InAgents])

    GetNeutralizedIndex<public>()<transacts>:int =
        NeutralizedIndex

    GetNeutralizedAgents<public>()<transacts>:[]agent =
        for:
            NeutralizedAgent:NeutralizedAgents
            ParticipantManager.IsInitialized[NeutralizedAgent]
        do:
            NeutralizedAgent

    GetSelectableTeams<public>()<transacts>:[]rr_selectable_team =
        SelectableTeams

    GetSelectableTeam<public>(TeamIndex:int)<transacts><decides>:rr_selectable_team =
        var OpSelectableTeam:?rr_selectable_team = false
        loop:
            for(SelectableTeam:SelectableTeams):
                if(SelectableTeam.Index = TeamIndex):
                    set OpSelectableTeam = option{SelectableTeam}
                    break
            break
        OpSelectableTeam?

    GetSelectableTeamsWithMembersMap<public>()<transacts>:[int][]agent =
        Dict of for:
            SelectableTeam:SelectableTeams
            SelectableTeamAgents := TeamCollection._GetTeamMembers[SelectableTeam.Index]
        do:
            (SelectableTeam.Index, SelectableTeamAgents)

    GetSelectableTeamIndexMembersMap<public>()<transacts>:[int][]agent =
        Dict of for:
            SelectableTeam:SelectableTeams
            SelectableTeamAgents := TeamCollection._GetTeamMembers[SelectableTeam.Index] or array{}
        do:
            (SelectableTeam.Index, SelectableTeamAgents)

    TeleportMembersToTeam<public>():void =
        for:
            TeamIndex -> TeamMembers:GetSelectableTeamIndexMembersMap()
            InitializedMembers := for:
                TeamMember:TeamMembers
                ParticipantManager.IsInitialized[TeamMember]
            do:
                TeamMember
            SelectableTeam := GetSelectableTeam[TeamIndex]
        do:
            InitializedMembers.TeleportToOrRespawnAt(SelectableTeam.TeleporterDevices)
        GetNeutralizedAgents().TeleportToOrRespawnAt(NeutralizedTeleporters)

    HideAndDisableAllSelectableTeams<public>():void =
        for(SelectableTeam:SelectableTeams):
            HideAndDisableSelectableTeam(SelectableTeam)

    RefreshAllPlayerReferences<public>():void =
        for(SelectableTeam:SelectableTeams):
            RefreshPlayerReferences(SelectableTeam)
        
    # Private
    RefreshPlayerReferences<private>(InSelectableTeam:rr_selectable_team):void =
        for:
            Index -> TeamMember:TeamCollection._GetTeamMembers[InSelectableTeam.Index]
            PlayerReferenceDevice := InSelectableTeam.PlayerReferenceDevices[Index]
            set AgentPlayerReferenceDeviceMap[TeamMember] = option{PlayerReferenceDevice} 
        do:
            PlayerReferenceDevice.ToggleEnableRegister(TeamMember)

    HideAndDisableSelectableTeam<public>(InSelectableTeam:rr_selectable_team):void =
        if { InSelectableTeam.DisplayTeamSelectorDevice.TeleportTo[InSelectableTeam.DisplayTeamSelectorDevice.GetTransform().TransZ(-384.0)] }
        if { InSelectableTeam.PlayerCounterDevice.TeleportTo[InSelectableTeam.PlayerCounterDevice.GetTransform().TransZ(-704.0)] }
        if { set SelectableTeamHiddenMap[InSelectableTeam.Index] = true }

        InSelectableTeam.MutatorZoneDevice.Disable()
        InSelectableTeam.DisplayTeamSelectorDevice.Disable()

        for:
            PlayerReferenceDevice:InSelectableTeam.PlayerReferenceDevices
        do:
            PlayerReferenceDevice.DisableClear()

    ShowAndEnableSelectableTeam<public>(InSelectableTeam:rr_selectable_team):void =
        if { InSelectableTeam.DisplayTeamSelectorDevice.TeleportTo[InSelectableTeam.DisplayTeamSelectorDevice.GetTransform().TransZ(384.0)] }
        if { InSelectableTeam.PlayerCounterDevice.TeleportTo[InSelectableTeam.PlayerCounterDevice.GetTransform().TransZ(704.0)] }
        if { set SelectableTeamHiddenMap[InSelectableTeam.Index] = false }

        InSelectableTeam.MutatorZoneDevice.Enable()
        InSelectableTeam.DisplayTeamSelectorDevice.Enable()

        for:
            PlayerReferenceDevice:InSelectableTeam.PlayerReferenceDevices
        do:
            PlayerReferenceDevice.Enable()

    ShowUIAndAwaitSelection<override>(InAgent:agent)<suspends>:void =
        loop:
            ShowUI(InAgent)
            TeamSelected := TeamSelectUI.RespondingButtonEvent.Await()
            if:
                TeamSelected(0) = InAgent
                SelectableTeam := SelectableTeams[TeamSelected(1)]
            then:
                Print("Pressed Button at Index: {TeamSelected(1)}, Which Technically should be Team {TeamSelected(1) + 1}, and is SelectableTeamIndex {SelectableTeam.Index}")
                SelectedTeam := SelectTeam(InAgent, SelectableTeam.Index)
                if(SelectedTeam?):
                    break

    ShowUI<override>(InAgent:agent):void =
        UpdateTeamSelectUI()
        TeamSelectUI.Show(InAgent)

    ShowUI<override>():void =
        UpdateTeamSelectUI()
        TeamSelectUI.Show()

    HideUI<override>(InAgent:agent):void =
        TeamSelectUI.Hide(InAgent)

    HideUI<override>():void =
        TeamSelectUI.Hide()

    UpdateTeamSelectUI<private>():void =
        for:
            SelectableTeam:SelectableTeams
            SelectableTeamAgents := TeamCollection._GetTeamMembers[SelectableTeam.Index]
        do:
            TeamMembersMessage := Join of for(I := 1..2):
                if(TeamMember := SelectableTeamAgents[I - 1]):
                    PlayerMessage(SelectableTeam.Index, TeamMember)
                else:
                    PlayerSlotMessage(I)
            TeamSelectUI.SetButtonText(TeamMembersMessage, SelectableTeam.Index - 1)

    ListenTeamEnterExitEvents<private>(InSelectableTeam:rr_selectable_team)<suspends>:void =
        sync:
            loop:
                EnteredAgent:agent = InSelectableTeam.MutatorZoneDevice.AgentEntersEvent.Await()
                if(not SelectableTeamHiddenMap[InSelectableTeam.Index]?):
                    Selected := SelectTeam(EnteredAgent, InSelectableTeam.Index)
                    if(not Selected?):
                        HUDMessageDevice.Show(EnteredAgent, FailedToSelectTeamMessage, ?DisplayTime:=2.5)
            loop:
                ExitedAgent:agent= InSelectableTeam.MutatorZoneDevice.AgentExitsEvent.Await()
                if(not SelectableTeamHiddenMap[InSelectableTeam.Index]?):
                    Neutralize(ExitedAgent)
                    NeutralizedSFXDevice.Play(ExitedAgent)

    (PlayerReferenceDevice:player_reference_device).DisableClear<private>():void =
        PlayerReferenceDevice.Clear()
        PlayerReferenceDevice.Clear()
        PlayerReferenceDevice.Disable()

    (PlayerReferenceDevice:player_reference_device).ToggleEnableRegister<private>(InAgent:agent):void =
        PlayerReferenceDevice.DisableClear()
        PlayerReferenceDevice.Enable()
        PlayerReferenceDevice.Register(InAgent)