using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

using { FN_Gameplay }
using { rebooting }
using { teams }
using { state }

rr_jip_manager := class(fn_gameplay_state_observer):
    HUDMessageDevice:hud_message_device
    RebootController:rr_reboot_controller
    LoadoutSelector:rr_loadout_selector
    TeamSelector:rr_team_selector

    JoinedInProgress(InAgent:agent):void =
        if(TeamSelector.SelectableTeamCapacity > 1):
            TeamSelector.Neutralize(InAgent)
        if(CurrentEnum := ComparableEnumRRStateMap[CurrentState]):
            case(CurrentEnum):
                rr_state_enum.CombatRound =>
                    if(RebootController.IsUnlimited[]):
                        spawn{SelectTeamLoadoutReboot(InAgent)}
                    else:
                        HUDMessageDevice.Show(InAgent, MiddleOfRoundMessage(InAgent), ?DisplayTime := 3.0)
                        GiveOneSpawn(InAgent) 
                        spawn{RepeatAttemptEliminateCharacter(InAgent)}
                _ =>

    SelectTeamLoadoutReboot<private>(InAgent:agent)<suspends>:void =
        RepeatAttemptEliminateCharacter(InAgent)
        Print("Successfully Eliminated Character")
        race:
            StateUpdatedEvent.Await()
            block:
                defer:
                    TeamSelector.HideUI(InAgent)
                    LoadoutSelector.HideUI(InAgent)
                if(TeamSelector.SelectableTeamCapacity > 1):
                    TeamSelector.ShowUIAndAwaitSelection(InAgent)
                LoadoutSelector.ShowUIAndAwaitSelection(InAgent)
                RebootController.Register(InAgent)
                RebootController.Reboot(InAgent)

    LeftInProgress(InAgent:agent):void =
        RebootController.Unregister(InAgent)

MiddleOfRoundMessage<localizes><public>(InAgent:agent):message = "Welcome {InAgent}!\nYou joined in the middle of a round!\nSpectating will not take long!"

