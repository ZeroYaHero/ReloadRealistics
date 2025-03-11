using { /Verse.org/Simulation/Tags }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

using { FN_Gameplay }

var GlobalAnalyzerAwarder<internal> : weak_map(session, rr_analyzer_awarder) = map{}

GetGlobalAnalyzerAwarder<public>():rr_analyzer_awarder = 
    GlobalAnalyzerAwarder[GetSession()] or PrintAndErr("Failed to get Global Analyzer Awarder")

analytic_accolade_tag := class(tag){}
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

rr_analytic := enum{}

rr_award := enum:
    LobbyAFK
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

    Initialize():void =
        if:
            set GlobalAnalyzerAwarder[GetSession()] = Self
        else:
            PrintAndErr("Failed to set Global Analyzer Awarder")

    Award(InAgent : agent, AwardType : rr_award):void =
        case(AwardType):
            rr_award.LobbyAFK => LobbyAFK.Award(InAgent)
            rr_award.SelectedTeam => SelectedTeam.Award(InAgent)
            rr_award.Rebooted => Rebooted.Award(InAgent)
            rr_award.Knock => Knock.Award(InAgent)
            rr_award.Elimination => Elimination.Award(InAgent)
            rr_award.TeamWipe => TeamWipe.Award(InAgent)
            rr_award.PlayedRound => PlayedRound.Award(InAgent)
            rr_award.WonRound => WonRound.Award(InAgent)
            rr_award.PlayedGame => PlayedGame.Award(InAgent)
            rr_award.WonGame => WonGame.Award(InAgent)

    Submit(InAgent : agent, SubmissionType : rr_analytic):void =
        void