using { /Verse.org/Simulation/Tags }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { FN_Gameplay }

weapon_select_tag := class(tag){}
    weapon_select_device := class(weapon_select_tag){}
    loadout_granter_1 := class(weapon_select_tag){}
    loadout_granter_2 := class(weapon_select_tag){}
    loadout_granter_3 := class(weapon_select_tag){}
    loadout_granter_4 := class(weapon_select_tag){}
    loadout_granter_5 := class(weapon_select_tag){}
    loadout_granter_6 := class(weapon_select_tag){}
    always_granter := class(weapon_select_tag){}
    random_granter := class(weapon_select_tag){}
    item_remover := class(weapon_select_tag){}
    keep_loadout_select_device := class(weapon_select_tag){}

rr_loadout_selector := class:

    WeaponSelectDialog : popup_dialog_device
    KeepSelectDialog : popup_dialog_device
    AlwaysGranter : item_granter_device
    LoadoutGranters : []item_granter_device
    RandomGranters : []item_granter_device
    ItemRemover : item_remover_device
    LoadoutSubmissionTypes : []rr_analytic = array:
        rr_analytic.Loadout1
        rr_analytic.Loadout2
        rr_analytic.Loadout3
        rr_analytic.Loadout4
        rr_analytic.Loadout5
        rr_analytic.Loadout6
    var LastSelectedMap : [agent]int = map{}
    var KeepSelection : [agent]logic = map{}
    var CurrentlyBeingGrantedItems : []agent = array{}

    Initialize():void =
        spawn{AwaitSelections()}

    HasKeepSelection(InAgent : agent)<transacts><decides>:void =
        KeepSelection[InAgent]?

    AwaitSelections()<suspends>:void =
        sync:
            loop:
                AgentIndex := WeaponSelectDialog.RespondingButtonEvent.Await()
                spawn{GrantLoadout(AgentIndex(0), AgentIndex(1), true)}
            loop:
                DismissedAgent := WeaponSelectDialog.DismissedEvent.Await()
                if(not CurrentlyBeingGrantedItems.Find[DismissedAgent]):
                    GrantLastSelected(DismissedAgent)
            loop:
                AgentIndex := KeepSelectDialog.RespondingButtonEvent.Await()
                if:
                    AgentIndex(1) = 0
                    set KeepSelection[AgentIndex(0)] = true
                else if:
                    set KeepSelection[AgentIndex(0)] = false
                else:
                    PrintAndErr("Unreachable")

    ShowUI(InAgent : agent):void =
        WeaponSelectDialog.Show(InAgent)

    ShowUI():void =
        WeaponSelectDialog.Show()

    HideUI(InAgent : agent):void =
        WeaponSelectDialog.Hide(InAgent)
        KeepSelectDialog.Hide(InAgent)

    HideUI():void =
        WeaponSelectDialog.Hide()
        KeepSelectDialog.Hide()

    ClearLoadout(InAgent : agent):void =
        ItemRemover.Remove(InAgent)
    
    GrantLoadout(InAgent : agent, Index : int, Manual : logic)<suspends>:void =
        set CurrentlyBeingGrantedItems += array{InAgent}
        Print("Granting to Agent")
        if { set LastSelectedMap[InAgent] = Index }
        if(LoadoutGranter := LoadoutGranters[Index]):
            ClearLoadout(InAgent)
            Sleep(0.0)
            AlwaysGranter.GrantItem(InAgent)
            Sleep(0.0)
            LoadoutGranter.GrantItem(InAgent)
            Sleep(0.0)
            if(Index <> 4):
                for(RandomGranter : RandomGranters):
                    RandomGranter.CycleToRandomItem(InAgent)
            if(Manual? and not KeepSelection[InAgent]):
                KeepSelectDialog.Show(InAgent)
        else:
            PrintAndErr("Loadout Selected Does Not Exist!")
        if:
            Manual?
            LoadoutSubmissionType := LoadoutSubmissionTypes[Index]
        then:
            SubmitData(InAgent, LoadoutSubmissionType)
        else:
            SubmitData(InAgent, rr_analytic.DefaultLoadout)
        set CurrentlyBeingGrantedItems = CurrentlyBeingGrantedItems.RemoveAllElements(InAgent)
        
    # This should use the persistent map if set
    GrantLastSelected(InAgent : agent):void =
        if(LastSelected := LastSelectedMap[InAgent]):
            spawn{GrantLoadout(InAgent, LastSelected, false)}
        else:
            spawn{GrantLoadout(InAgent, 0, false)}