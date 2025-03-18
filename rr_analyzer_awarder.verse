using { /Verse.org/Simulation/Tags }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

using { FN_Gameplay }

var GlobalAnalyzerAwarder<internal> : weak_map(session, rr_analyzer_awarder) = map{}

GetGlobalAnalyzerAwarder<public>():rr_analyzer_awarder = 
    GlobalAnalyzerAwarder[GetSession()] or PrintAndErr("Failed to get Global Analyzer Awarder")

AwardXP<public>(InAgent : agent, AwardType : rr_award):void =
    GetGlobalAnalyzerAwarder().AwardXP(InAgent, AwardType)

SubmitData<public>(InAgent : agent, SubmissionType : rr_analytic):void =
    GetGlobalAnalyzerAwarder().SubmitData(InAgent, SubmissionType)

analytic_accolade_tag := class(tag){}
    # XP
    lobby_afk := class(analytic_accolade_tag){}
    selected_team := class(analytic_accolade_tag){}
    rebooted := class(analytic_accolade_tag){}
    knock_opponent := class(analytic_accolade_tag){}
    eliminate_opponent := class(analytic_accolade_tag){}
    team_wipe := class(analytic_accolade_tag){}
    played_round := class(analytic_accolade_tag){}
    won_round := class(analytic_accolade_tag){}
    played_game := class(analytic_accolade_tag){}
    won_game := class(analytic_accolade_tag){}
    coin_collectible := class(analytic_accolade_tag){}
    # Selected Loadout
    default_selected := class(analytic_accolade_tag){}
    selected_loadout_1 := class(analytic_accolade_tag){}
    selected_loadout_2 := class(analytic_accolade_tag){}
    selected_loadout_3 := class(analytic_accolade_tag){}
    selected_loadout_4 := class(analytic_accolade_tag){}
    selected_loadout_5 := class(analytic_accolade_tag){}
    selected_loadout_6 := class(analytic_accolade_tag){}

rr_analytic<public> := enum:
    DefaultLoadout
    Loadout1
    Loadout3
    Loadout2
    Loadout4
    Loadout5
    Loadout6

rr_award<public> := enum:
    SelectedTeam
    Rebooted
    Knock
    Elimination
    TeamWipe
    PlayedRound
    WonRound
    PlayedGame
    WonGame

rr_analyzer_awarder<public> := class:
    
    CollectedCoin<public> : accolades_device
    Collectibles<public> : []collectible_object_device
    
    LobbyMutator<public> : mutator_zone_device
    LobbyAFK<public> : accolades_device

    SelectedTeam<public> : accolades_device
    Rebooted<public> : accolades_device
    Knock<public> : accolades_device
    Elimination<public> : accolades_device
    TeamWipe<public> : accolades_device
    PlayedRound<public> : accolades_device
    WonRound<public> : accolades_device
    PlayedGame<public> : accolades_device
    WonGame<public> : accolades_device

    DefaultSelected<public> : analytics_device
    SelectedLoadout1<public> : analytics_device
    SelectedLoadout2<public> : analytics_device
    SelectedLoadout3<public> : analytics_device
    SelectedLoadout4<public> : analytics_device
    SelectedLoadout5<public> : analytics_device
    SelectedLoadout6<public> : analytics_device

    Initialize():void =
        if:
            set GlobalAnalyzerAwarder[GetSession()] = Self
        else:
            PrintAndErr("Failed to set Global Analyzer Awarder")

        for(Collectible : Collectibles):
            Collectible.CollectedEvent.Subscribe(OnCollected)
        spawn{AwardAFKXP()}

    OnCollected<private>(InAgent : agent):void =
        CollectedCoin.Award(InAgent)

    AwardAFKXP()<suspends>:void =
        loop:
            AwaitTimer(5.0)
            for(Agent : LobbyMutator.GetAgentsInVolume()):
                LobbyAFK.Award(Agent)

    (rr_analyzer_awarder:)AwardXP(InAgent : agent, AwardType : rr_award):void =
        case(AwardType):
            rr_award.SelectedTeam => SelectedTeam.Award(InAgent)
            rr_award.Rebooted => Rebooted.Award(InAgent)
            rr_award.Knock => Knock.Award(InAgent)
            rr_award.Elimination => Elimination.Award(InAgent)
            rr_award.TeamWipe => TeamWipe.Award(InAgent)
            rr_award.PlayedRound => PlayedRound.Award(InAgent)
            rr_award.WonRound => WonRound.Award(InAgent)
            rr_award.PlayedGame => PlayedGame.Award(InAgent)
            rr_award.WonGame => WonGame.Award(InAgent)

    (rr_analyzer_awarder:)SubmitData(InAgent : agent, SubmissionType : rr_analytic):void =
        case(SubmissionType):
            rr_analytic.Loadout1 => SelectedLoadout1.Submit(InAgent)
            rr_analytic.Loadout2 => SelectedLoadout2.Submit(InAgent)
            rr_analytic.Loadout3 => SelectedLoadout3.Submit(InAgent)
            rr_analytic.Loadout4 => SelectedLoadout4.Submit(InAgent)
            rr_analytic.Loadout5 => SelectedLoadout5.Submit(InAgent)
            rr_analytic.Loadout6 => SelectedLoadout6.Submit(InAgent)
            rr_analytic.DefaultLoadout => DefaultSelected.Submit(InAgent)