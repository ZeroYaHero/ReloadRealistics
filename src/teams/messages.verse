using { /Verse.org/Simulation }

PlayerMessage<localizes><internal>(Enumeration:int, InAgent:agent):message = "{Enumeration}. {InAgent}\n"
PlayerSlotMessage<localizes><internal>(Enumeration:int):message = "{Enumeration}.\n"
SelectedTeamMessage<localizes><internal>(TeamName:string):message = "Joined Team {TeamName}"
NeutralizedMessage<localizes><internal>:message = "No Team!\nSelect a team or wait for auto selection."
FailedToSelectTeamMessage<localizes><internal>:message = "Too many players on team!\nTry selecting another team."