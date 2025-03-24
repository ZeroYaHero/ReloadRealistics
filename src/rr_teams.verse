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

(SelectableTeamParameters : []rr_selectable_team_parameter).IndexColorMap():[int]color = 
    Dict of for(SelectableTeamParameter : SelectableTeamParameters):
        SelectableTeamParameter.Index, SelectableTeamParameter.Color

rr_selectable_team_parameter<public> := class<concrete>:

    @editable   Index<public> : int = -1
    @editable   Color<public> : color = color{}

rr_selectable_team := class:

    Index : int
    Color : color
    SelectVolume<public> : mutator_zone_device
    Selector<public> : class_and_team_selector_device
    DisplaySelector<public> : class_and_team_selector_device
    PlayerReferenceDevices<public> : []player_reference_device
    VolumeTeleporters<public> : []teleporter_device
    SFX<public> : audio_player_device

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
            PlayerReferenceDevice.Clear()
            PlayerReferenceDevice.Disable()

rr_team_selector := class(rr_state_handler_interface):
    # Objects
    TeamCollection:fort_team_collection
    ParticipantManager:rr_participant_manager
    NeutralTeamSelector:class_and_team_selector_device
    NeutralTeamSFX:audio_player_device
    TeamSelectStateSFX:audio_player_device
    TeamSelectTeleporters:[]teleporter_device
    TeamSelectTimerHUD:custom_hud_timer
    FailedSelectHUD:hud_message_device
    # Parameters
    SelectableTeams:[]rr_selectable_team
    MinimumSelectableTeams:int
    SelectableTeamCapacity:int
    NeutralTeamIndex:int
    TeamSelectTimerDurationMap:[int]float
    # Variables / Events
    TeamSelectedEvent:event(agent) = event(agent){}
    var AgentPlayerReferenceMap:[agent]player_reference_device = map{}
    var NeutralizedAgents:[]agent = array{}
    var TrustVolumeExitEvents:logic=false

    Initialize():void =
        for(SelectableTeam : SelectableTeams):
            spawn{ListenVolumeSelections(SelectableTeam)}
            SelectableTeam.Hide()
        ParticipantManager.ParticipantInitializedEvent.SubscribeAwaitable(Neutralize)

    ExitWaitingForPlayers<override>()<suspends>:void =
        ParticipantCount := ParticipantManager.GetInitializedParticipants().Length
        if(not TeamSelectTimerDurationMap[ParticipantCount]):
            Print("Auto Selecting For 2 Players")
            for(NeutralizedAgent : NeutralizedAgents):
                AutoSelect(NeutralizedAgent)

    EnterTeamSelect<override>()<suspends>:void =
        ParticipantCount := ParticipantManager.GetInitializedParticipants().Length
        if(TeamSelectTimerDuration := TeamSelectTimerDurationMap[ParticipantCount]):

            for:
                Participant : ParticipantManager.GetInitializedParticipants()
                FortCharacter := Participant.GetFortCharacter[]
            do:
                FortCharacter.SetHealth(100.0)
                FortCharacter.SetShield(100.0)
            EnableSelectorsAndTeleportParticipants()
            set TrustVolumeExitEvents = true

            TeamSelectTimerHUD.SetDuration(TeamSelectTimerDuration)
            sync:
                TeamSelectTimerHUD.StartAndAwaitSuccess()
                block:
                    AwaitTimer(3.0)
                    for(Participant : ParticipantManager.GetInitializedParticipants()):
                        TeamSelectStateSFX.Play(Participant)
            TeamSelectTimerHUD.Reset()
            set TrustVolumeExitEvents = false
            
            for(SelectableTeam : SelectableTeams):
                SelectableTeam.Hide()
            for(NeutralizedAgent : NeutralizedAgents):
                AutoSelect(NeutralizedAgent)
            
        else:
            Print("No Team Select Timer Duration...The Next State (Combat Round) Should Start Soon!")

    # ExitTeamSelect<override>()<suspends>:void =
    #     for(SelectableTeam : SelectableTeams):
    #         SelectableTeam.Hide()
    #     AutoSelect()

    EnableSelectorsAndTeleportParticipants():void = 
        Participants := ParticipantManager.GetInitializedParticipants()
        MaxNumberOfTeams := Max(MinimumSelectableTeams, Ceil(Participants.Length / SelectableTeamCapacity))  or PrintAndErr("Unreachable: Ceil Operation Failed")

        # Get Teams with a good amount of members
        var TeamsWithMultipleMembers : []int = array{}
        for(TeamIndex -> TeamMembers : GetSelectableTeamMembersMap()):
            if(TeamMembers.Length > 1):
                set TeamsWithMultipleMembers = TeamsWithMultipleMembers.SetAdd(TeamIndex)
            else:
                for(TeamMember : TeamMembers):
                    Neutralize(TeamMember)
        MaxNumberOfNewTeams := MaxNumberOfTeams - TeamsWithMultipleMembers.Length
        
        var Count : int = 0
        for(SelectableTeam : SelectableTeams):
            if:
                TeamsWithMultipleMembers.Find[SelectableTeam.Index]
                TeamMembers := TeamCollection._GetTeamMembers[SelectableTeam.Index]
            then:
                SelectableTeam.Show()
                TeamMembers.TeleportToOrRespawnAt(SelectableTeam.VolumeTeleporters)
                for:
                    MemberIndex -> TeamMember : TeamMembers
                    PlayerReferenceDevice := SelectableTeam.PlayerReferenceDevices[MemberIndex]
                    set AgentPlayerReferenceMap[TeamMember] = PlayerReferenceDevice
                do:
                    PlayerReferenceDevice.Register(TeamMember)
            else if(Count < MaxNumberOfNewTeams):
                SelectableTeam.Show()
                set Count += 1
            else:
                SelectableTeam.Hide()

        if(NeutralizedPlayers := TeamCollection._GetTeamMembers[NeutralTeamIndex]):
            NeutralizedPlayers.TeleportToOrRespawnAt(TeamSelectTeleporters)

    GetSelectableTeamWithIndex(TeamIndex : int)<transacts><decides>:rr_selectable_team = 
        var OpSelectableTeam : ?rr_selectable_team = false
        loop:
            for(SelectableTeam : SelectableTeams):
                if(SelectableTeam.Index = TeamIndex):
                    set OpSelectableTeam = option{SelectableTeam}
                    break
            break
        OpSelectableTeam?

    GetSelectableTeamMembersMap()<transacts>:[int][]agent =
        Dict of for:
            SelectableTeam : SelectableTeams
            TeamMembers := TeamCollection._GetTeamMembers[SelectableTeam.Index]
        do:
            (SelectableTeam.Index, TeamMembers)

    Neutralize(InAgent : agent):void =
        if(GetMainDevicePlayspace().GetTeamCollection()._SetTeam[InAgent, NeutralTeamIndex, ?Force := true]):
            NeutralTeamSelector.ChangeTeam(InAgent)
            set NeutralizedAgents = NeutralizedAgents.SetAdd(InAgent)
            if(CurrentPlayerReference := AgentPlayerReferenceMap[InAgent]):
                CurrentPlayerReference.Clear()

    ListenVolumeSelections<private>(InSelectableTeam : rr_selectable_team)<suspends>:void =
        sync:
            loop:
                EnteredAgent := InSelectableTeam.SelectVolume.AgentEntersEvent.Await()
                if:
                    ParticipantManager.GetInitializedParticipants().Find[EnteredAgent]
                    not TeamCollection.IsOnTeam[EnteredAgent, InSelectableTeam.Index]
                then:
                    SelectedTeam := SelectTeam(EnteredAgent, InSelectableTeam.Index)
                    if(not SelectedTeam?):
                        FailedSelectHUD.Show(EnteredAgent)
            loop:
                ExitedAgent := InSelectableTeam.SelectVolume.AgentExitsEvent.Await()
                if(TrustVolumeExitEvents?):
                    Neutralize(ExitedAgent)
                    NeutralTeamSFX.Play(ExitedAgent)

    SelectTeam(InAgent : agent, Index : int):logic =
        if:
            SelectableTeam := GetSelectableTeamWithIndex[Index]
            PlayerIndexOnTeam := TeamCollection._SetTeam[InAgent, SelectableTeam.Index, ?Capacity := SelectableTeamCapacity, ?Force := false] - 1
        then:
            SelectableTeam.Selector.ChangeTeam(InAgent)
            if(CurrentPlayerReference := AgentPlayerReferenceMap[InAgent]):
                CurrentPlayerReference.Clear()
                CurrentPlayerReference.Clear()
            if:
                NewPlayerReference := SelectableTeam.PlayerReferenceDevices[PlayerIndexOnTeam]
                set AgentPlayerReferenceMap[InAgent] = NewPlayerReference
            then:
                NewPlayerReference.Register(InAgent)
            SelectableTeam.SFX.Play(InAgent)
            AwardXP(InAgent, rr_award.SelectedTeam)
            set NeutralizedAgents = NeutralizedAgents.RemoveAllElements(InAgent)
            TeamSelectedEvent.Signal(InAgent)
            true
        else:
            false

    # AutoSelect<public>():void = 
    #     for(NeutralizedAgent : NeutralizedAgents):
    #         AutoSelect(NeutralizedAgent)

    AutoSelect(InAgent : agent):void =
        ParticipantCount := ParticipantManager.GetInitializedParticipants().Length
        MaxNumberTeams := Max(MinimumSelectableTeams, Ceil(ParticipantCount / SelectableTeamCapacity))  or PrintAndErr("Unreachable: Ceil Operation Failed")
        MaxTeamSize := Ceil(ParticipantCount / MaxNumberTeams)                                          or PrintAndErr("Unreachable: Ceil Operation Failed")
        loop:
            TeamIndexMemberPairings := SortSelectableTeamBySize(true)
            for:
                IndexMembersPair : TeamIndexMemberPairings
                PrintInFor["TeamIndex: {IndexMembersPair(0)}, TeamSize: {IndexMembersPair(1)}"]
                IndexMembersPair(1) < MaxTeamSize
                PrintInFor["Size less than MaxTeamSize"]
            do:
                SelectedTeam := SelectTeam(InAgent, IndexMembersPair(0))
                if(SelectedTeam?):
                    break
            break

    SortSelectableTeamBySize(Decreasing : logic):[]tuple(int, int) = 
        TeamIndexMemberPairings := for:
            SelectableTeam : SelectableTeams
            Length := TeamCollection._GetTeamSize(SelectableTeam.Index)
        do:
            (SelectableTeam.Index, Length)
        if(Decreasing?):
            SortBy(TeamIndexMemberPairings, TupleSecondGreaterComp)
        else:
            SortBy(TeamIndexMemberPairings, TupleSecondLesserComp)

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable = 
        map:
            rr_state_enum.WaitingForPlayers => array:
                fn_gameplay_state_listener:
                    ExitCallback := option{ExitWaitingForPlayers}
            rr_state_enum.TeamSelect => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterTeamSelect}
                    PostExecutionTrigger := option:
                        fn_gameplay_state_trigger:
                            DefaultStateToTrigger := rr_state_enum.CombatRound

        # RefreshUI():void =
    #     TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
    #     for:
    #         SelectableTeam : SelectableTeams
    #     do:
    #         TeamMembers := TeamCollection._GetTeamMembers[SelectableTeam.Index] or array{}
    #         TeamMembersMessage := Join of for(I := 0..1):
    #             if(TeamMember := TeamMembers[I]):
    #                 DialogPlayerMemberMessage(SelectableTeam.Index, TeamMember)
    #             else:
    #                 DialogPlayerSlotMessage(I + 1)
    #         SelectTeamDialog.SetButtonText(TeamMembersMessage, SelectableTeam.Index - 1)

    # ShowUI():void =
    #     RefreshUI()
    #     SelectTeamDialog.Show()

    # ShowUI(InAgent : agent):void =
    #     RefreshUI()
    #     SelectTeamDialog.Show(InAgent)

    # HideUI():void =
    #     SelectTeamDialog.Hide() 

    # HideUI(InAgent : agent):void = 
    #     SelectTeamDialog.Hide(InAgent) 

    # ListenUISelections<private>()<suspends>:void =
    #     TeamCollection := GetMainDevicePlayspace().GetTeamCollection()
    #     loop:
    #         AgentIndex := SelectTeamDialog.RespondingButtonEvent.Await()
    #         if:
    #             SelectableTeam := SelectableTeams[AgentIndex(1)]
    #             TeamIndex := SelectableTeam.Index
    #             Print("Selected Button Index {AgentIndex(1)} which is Team Index {TeamIndex}")
    #             TeamCollection._SetTeam[AgentIndex(0), TeamIndex, ?Capacity := SelectableTeamCapacity, ?Force := false]
    #         then:
    #             SelectableTeam.Selector.ChangeTeam(AgentIndex(0))
    #             AwardXP(AgentIndex(0), rr_award.SelectedTeam)
    #             set NeutralizedAgents = NeutralizedAgents.RemoveAllElements(AgentIndex(0))
    #             Print("Team Set on {TeamIndex} Succeeded! Removed them from NeutralizedAgents")
    #             RefreshUI()
    #         else:
    #             ShowUI(AgentIndex(0))
    #             Print("Team Set Failed! Attempted to Show Again")

    # AwaitUISelection<public>(InAgent : agent)<suspends>:void =
    #     loop:
    #         AgentIndex := SelectTeamDialog.RespondingButtonEvent.Await()
    #         Print("Agent Selected a Team??? Why no Print")
    #         if(AgentIndex(0) = InAgent):
    #             break

# Team Select Player Member Message
# DialogPlayerMemberMessage<localizes><internal>(Enumeration : int, InAgent : agent):message = "{Enumeration}. {InAgent}\n"

# # Team Select Dialog Empty Slot Message
# DialogPlayerSlotMessage<localizes><internal>(Enumeration : int):message = "{Enumeration}.\n"

# Basic Scores Comparator
# TeamScoresComparator<public>(Lhs : tuple(int, int), Rhs : tuple(int, int))<computes><decides>:void =
#     Lhs(1) > Rhs(1)
