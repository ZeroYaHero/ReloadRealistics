using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

using { FN_Gameplay }

rr_waiting_players_state_handler<public> := class(fn_gameplay_state_handler):
    ParticipantManager<public>:rr_participant_manager
    HubManager<public>:rr_hub_manager
    WaitingForPlayersTimer<public>:timer_device
    AutoStartMinimum<public>:int
    # AutoStartVoteUI<public>:popup_dialog_device
    # AutoStartVotingTimer<public>:timer_device
    RebootVanTimer<public>:timer_device
    HUDMessageDevice<public>:hud_message_device

    EnterWaitingForPlayers()<suspends>:void =
        spawn{NonCancelableWaitingForPlayers()}
    NonCancelableWaitingForPlayers()<suspends>:void =
        defer:
            WaitingForPlayersTimer.Reset()
        var InitializedParticipants : []agent = ParticipantManager.GetInitializedParticipants() 
        var InitializedParticipantsCount : int = InitializedParticipants.Length
        ParticipantManager.GetInitializedParticipants().TeleportToOrRespawnAt(HubManager.SpawnTeleporters)
        if(InitializedParticipantsCount < 2):
            for(InitializedParticipant:InitializedParticipants):
                HUDMessageDevice.Show(InitializedParticipant, OnePlayerMessage, ?DisplayTime := 0.0)
                Print("Showed the Waiting for Players HUD")
            ParticipantManager.ParticipantInitializedEvent().Await()
            for(InitializedParticipant:InitializedParticipants):
                HUDMessageDevice.Hide(InitializedParticipant)
            HUDMessageDevice.Hide()
        RebootVanTimer.Start()

    GetStateListenersMap<override>()<transacts>:[comparable][]fn_gameplay_state_listenable =
        map:
            rr_state_enum.WaitingForPlayers => array:
                fn_gameplay_state_listener:
                    EnterCallback := option{EnterWaitingForPlayers}
                RebootVanTimer.GetAutoCompleteTimer(rr_state_enum.Transition, ?StartOnState:=false)

OnePlayerMessage<localizes><public>:message = "Waiting for another player to join..."
AutoStartFailedMessage<localizes><public>:message = "Not Enough Players Voted for Auto Start!"