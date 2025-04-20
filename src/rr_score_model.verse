# using { /UnrealEngine.com/Temporary }
# using { /Fortnite.com/Devices }
# using { /Verse.org/Simulation }

# using { FN_Gameplay }

# rr_score_model := class:
#     RoundWinPlayerReferences : []player_reference_device
#     BestPerformingPlayerReferences : []player_reference_device
#     WinRoundHUD : hud_message_device
#     LoseRoundHUD : hud_message_device
#     var AgentScoreMap : [agent]int = map{}
#     var RoundWinPlayerReferenceIndex:int = 0

#     RoundWin<public>(InAgent : agent):void =
#         if:
#             set AgentScoreMap[InAgent] = (AgentScoreMap[InAgent] or 0) + 1
#         then:
#             AwardXP(InAgent, rr_award.WonRound)
#             WinRoundHUD.Show(InAgent)
#             if(PlayerReferenceDevice := RoundWinPlayerReferences[Mod[RoundWinPlayerReferenceIndex, RoundWinPlayerReferences.Length]]):
#                 PlayerReferenceDevice.Enable()
#                 PlayerReferenceDevice.Register(InAgent)
#                 set RoundWinPlayerReferenceIndex += 1

#     RoundLose<public>(InAgent : agent):void =
#         AwardXP(InAgent, rr_award.PlayedRound)
#         LoseRoundHUD.Show(InAgent) 

#     GetScore<public>(InAgent : agent)<transacts>:int =
#         if(Score := AgentScoreMap[InAgent]):
#             Score
#         else:
#             ResetScore(InAgent)
#             0

#     ResetScore<public>(InAgent : agent)<transacts>:void =
#         if:
#             set AgentScoreMap[InAgent] = 0

#     GetMaxScoreOf<public>(InAgents : []agent):int =
#         Scores := InAgents.Map(GetScore)
#         MaxInt[Scores] or 0

#     GetAgentsSortedByScore<public>()<transacts>:[]agent =
#         for(AgentScore : SortBy(AgentScoreMap.Items(), TupleSecondGreaterComp)):
#             AgentScore(0)

#     ShowBestPerforming():void = 
#         for:
#             Index -> Agent : GetAgentsSortedByScore()
#         do:
#             if(PlayerReference := BestPerformingPlayerReferences[Index]):
#                 PlayerReference.Register(Agent)
#                 AwardXP(Agent, rr_award.WonGame)
#             else:
#                 AwardXP(Agent, rr_award.PlayedGame)