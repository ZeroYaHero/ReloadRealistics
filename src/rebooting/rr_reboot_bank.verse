using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Fortnite.com/Teams }

rr_reboot_bank<public> := class:
    MaximumRebootBank<public>:int
    RebootBankHUDMessages<public>:[]hud_message_device
    NoRebootBankHUDMessage<public>:hud_message_device
    InfiniteRebootBankHUDMessage<public>:hud_message_device
    LowOvershieldClassSelector<public>:class_and_team_selector_device
    HighOvershieldClassSelector<public>:class_and_team_selector_device
    var <private>AgentRebootBankMap<private>:[agent]int = map{}

    OnEnabledOrRegistered(InAgent:agent):void =
        SetRebootBank(InAgent, MaximumRebootBank)

    HasRebootsLeft(InAgent:agent)<transacts><decides>:void =
        GetNumberOfRebootsLeft[InAgent] > 0

    OnReboot(InAgent:agent):void =
        if(CurrentRebootBank := AgentRebootBankMap[InAgent]):
            SetRebootBank(InAgent, CurrentRebootBank - 1)
        else:
            SetRebootBank(InAgent, MaximumRebootBank - 1)

    OnDisallowed():void =
        for(Agent->RebootBankValue:AgentRebootBankMap):
            HideRebootBank(Agent)
            if:
                NumberOfRebootsLeft := GetNumberOfRebootsLeft[Agent]
                NumberOfRebootsLeft > 0
            then:
                if(NumberOfRebootsLeft > 1):
                    HighOvershieldClassSelector.ChangeClass(Agent)
                else:
                    LowOvershieldClassSelector.ChangeClass(Agent)
            SetRebootBank(Agent, 0)

    OnDisabled():void =
        set AgentRebootBankMap = map{}
        for(Agent->RebootBankValue:AgentRebootBankMap):
            HideRebootBank(Agent)


    SetRebootBank<private>(InAgent:agent, RebootBank:int):void =
        if { set AgentRebootBankMap[InAgent] = RebootBank }
        ShowRebootBankHUD(InAgent)

    ShowRebootBankHUD<private>(InAgent:agent):void =
        if(CurrentRebootBank := AgentRebootBankMap[InAgent]):
            HUDMessageDevice := GetRebootBankHUDMessage(CurrentRebootBank)
            HUDMessageDevice.Show()

    ShowInfiniteRebootBankHUD<public>(InAgent:agent):void =
        InfiniteRebootBankHUDMessage.Show(InAgent)

    HideInfiniteRebootBankHUD<public>(InAgent:agent):void =
        InfiniteRebootBankHUDMessage.Hide(InAgent)
            
    GetRebootBankHUDMessage<private>(RebootBank:int):hud_message_device =
        RebootBankHUDMessages[MaximumRebootBank - RebootBank] or NoRebootBankHUDMessage

    GetNumberOfRebootsLeft<private>(InAgent:agent)<transacts><decides>:int =
        AgentRebootBankMap[InAgent]

    HideRebootBank<public>(InAgent:agent):void =
        for(RebootBankHUDMessage:RebootBankHUDMessages):
            RebootBankHUDMessage.Hide(InAgent)
        NoRebootBankHUDMessage.Hide(InAgent)
        InfiniteRebootBankHUDMessage.Hide(InAgent)