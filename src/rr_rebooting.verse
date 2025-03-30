using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }
using { /Fortnite.com/Game }

using { FN_Gameplay }

rr_reload_rebooter := class:

    TeamCollection:fort_team_collection

    DBNODevice:down_but_not_out_device

    RespawnTimer:timer_device

    RespawnDurations:[]tuple(float, float)
    DownTimeSkip:float
    EliminationTimeSkip:float
    TeamWipeTimeSkip:float

    StatusTimerCorner:custom_hud_timer
    StatusTimerCenter:custom_hud_timer

    EnabledHUD:hud_message_device

    DisabledHUDCorner:hud_message_device
    DisableHUDCenter:hud_message_device

    TeamWipeHUD:hud_message_device
    TeamWipeSFX:audio_player_device

    RiftAsset:creative_prop_asset
    RiftSFX:audio_player_device
    RiftHeight:float

    HoltToRebootInputTrigger:input_trigger_device
    HoldToRebootUI:hud_message_device
    HoldToRebootUIAnimation:hud_message_device

    OptionalRebootBank:?[]hud_message_device = false
    var <private>RebootBankIndexMap<private>:[agent]int = map{}

    DisabledEvent<private>:event() = event(){}
    _TeamWipeEvent<private>:event(?int) = event(?int){}

    var <private>DefaultRebootLocation<private>:vector3 = vector3{}
    var <private>LastLocationMap<private>:[agent]transform = map{}
    var <private>RegisteredAgents<private>:[]agent = array{}
    var <private>Enabled<private>:logic = false
    var <private>Allowed<private>:logic = false

    # Public

    Enable<public>():void =
        set Enabled = true
        # Await Elimination for all registered agents

    Disable<public>():void =
        set Enabled = false
        # End all awaits for elimination for all registered agents

    IsEnabled<public>()<transacts><decides>:void = 
        Enabled?

    AllowReboots<public>():void =
        set Allowed = true
    
    DisallowReboots<public>():void =
        set Allowed = false

    IsAllowed<public>()<transacts><decides>:void =
        Allowed?
    
    Register<public>(InAgent:agent):void =
        if(not RegisteredAgents.Find[InAgent]):
            set RegisteredAgents += array{InAgent}
            spawn{AwaitAgentEliminated(InAgent)}
            # Await Elimination for registered agent

    Unregister<public>(InAgent:agent):void =
        set RegisteredAgents = RegisteredAgents.SetRemove(InAgent)

    IsRebootable<public>(InAgent:agent)<transacts><decides>:void =
        not IsTeamWiped[InAgent] or OptionalRebootBank?[RebootBankIndexMap[InAgent] + 1]

    Reboot<public>(InAgent:agent):void =
        void

    TeamWipeEvent<public>():event(?int) = 
        _TeamWipeEvent

    GetDefaultRebootLocation<public>():vector3 =
        DefaultRebootLocation

    SetDefaultRebootLocation<public>(InLocation:vector3):void =
        set DefaultRebootLocation = InLocation
    
    # Private

    IsTeamWiped<private>(InAgent:agent)<transacts><decides>:void =
        var RegisteredAliveTeammateCount:int = 0
        for:
            Teammate : TeamCollection._GetUpTeammates[InAgent]
            RegisteredAgents.Find[Teammate]
        do:
            set RegisteredAliveTeammateCount += 1
        RegisteredAliveTeammateCount > 0

    TeamWipe<private>(InAgent:agent, ?MaybeInstigatingAgent:?agent = false):void =
        void

    AwaitAgentEliminated<private>(InAgent:agent)<suspends>:void =
        loop:
            if(FortCharacter := InAgent.GetFortCharacter[]):
                EliminationResult := FortCharacter.EliminatedEvent().Await()
                if(IsRebootable[InAgent]):
                    if(IsEnabled[]):
                        AttemptReboot(InAgent)
                else:
                    TeamWipe(InAgent, ?MaybeInstigatingAgent:=option{EliminationResult.EliminatingCharacter?.GetAgent[]})
            else:
                break

    AttemptReboot(InAgent : agent)<suspends>:void =
        if(IsRebootable[InAgent]):
            if(IsEnabled[] and IsAllowed[]):

        else:
            # TeamWipe(InAgent)