using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }

using { FN_Gameplay }

rr_rebooter_interface := interface:
    IsRebootable<public>(:agent)<transacts><decides>:void

rr_reboot_team := class(rr_rebooter_interface):
    TeamCollection:fort_team_collection

    IsRebootable<override>(InAgent:agent)<transacts><decides>:void =
        var HasUpTeammates:logic = false
        for:
            UpTeammate:TeamCollection._GetUpTeammates[InAgent]
        do:
            set HasUpTeammates = true
            UpTeammate
        HasUpTeammates?

rr_reboot_bank := class:
    MaximumRebootBank:int
    RebootBankHUDMessages:[]hud_message_device
    NoRebootBankHUDMessage:hud_message_device
    var <private>AgentRebootBankMap<private>:[agent]int = map{}

    HasRebootBank<public>(InAgent:agent)<transacts><decides>:void =
        AgentRebootBankMap[InAgent] > 0

    ResetRebootBank<public>(InAgent:agent):void =
        SetRebootBankIndex(InAgent, MaximumRebootBank)

    DecrementRebootBank<public>(InAgent:agent):void =
        if(CurrentRebootBank := GetRebootBank[InAgent]):
            SetRebootBankIndex(InAgent, CurrentRebootBank - 1)
        else:
            SetRebootBankIndex(InAgent, MaximumRebootBank - 1)

    GetRebootBank<public>(InAgent:agent)<transacts><decides>:int =
        AgentRebootBankMap[InAgent]

    SetRebootBankIndex<public>(InAgent:agent, RebootBank:int):void =
        if { set AgentRebootBankMap[InAgent] = RebootBank }

    ShowRebootBankHUD<private>(InAgent:agent):void =
        if(CurrentRebootBank := AgentRebootBankMap[InAgent]):
            
    GetRebootBankHUDMessage<private>(RebootBank:int):hud_message_device =
        RebootBankHUDMessages[MaximumRebootBank - RebootBank] or NoRebootBankHUDMessage

rr_rebooting_view := interface:
    ShowRebootsAllowed():void
    HideRebootsAllowed():void
    ShowCausedWipe():void
    ShowRecievedWipe():void
    ShowRebootsEnding():void
    ShowRebootsDisallowed():void
    HideRebootsDisallowed():void