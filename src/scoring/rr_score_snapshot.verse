using { /UnrealEngine.com/Temporary }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }

rr_score_snapshot<public> := class:
    Agents<public>:[]agent
    Wiped<public>:logic
    Count<public>:int
    Color<public>:color
    Score<public>:int
    
SnapshotComparator<public>(Lhs:rr_score_snapshot, Rhs:rr_score_snapshot)<computes><decides>:void =
    if(Lhs.Score = Rhs.Score):
        if(Lhs.Wiped? and Rhs.Wiped?):
            Lhs.Count > Rhs.Count
        else:
            not Lhs.Wiped? or Rhs.Wiped?
    else:
        Lhs.Score > Rhs.Score