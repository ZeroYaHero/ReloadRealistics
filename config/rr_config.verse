using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /Verse.org/Assets }

using { FN_Gameplay }
using { src }

rr_abstract_config<public> := class<abstract>:
    AutoStartMinimum<public>:int
    Teams<public>:rr_teams_config
    Reboot<public>:rr_reboot_config
    Scoring<public>:rr_score_config
    POIs<public>:rr_pois_config
    Rounds<public>:rr_rounds_config
    LoadoutTags<public>:[]rr_loadout_selector_tags

rr_rounds_config<public> := struct:
    SupplyDropTimesAndQuantities<public>:[]tuple(float, int)
    InitialStormPhaseRadiusCM<public>:float
    StormRanges<public>:[]tuple(float, float)
    StormBeaconTags<public>:[]round_storm_device_tag

rr_teams_config<public> := struct:
    PlayableTeams:[]rr_team_config
    MinimumNumberOfTeams<public>:int
    TeamCapacity<public>:int
    NeutralizedIndex<public>:int
    MinimumSizeForKeepSelect<public>:int
    TeamSelectTimerDurationMap<public>:[int]float
    DefaultTeamSelectTimerDuration<public>:float

rr_team_config<public> := class:
    Index<public>:int
    Color<public>:color
    Name<public>:string
    Tag<public>:?selectable_teams_tag
    
rr_pois_config<public> := struct:
    TeleporterPairingTags<public>:[]rr_poi_pairing_tags
    TagAndNames:[]tuple(rr_poi_tags, string)

rr_reboot_config<public> := struct:
    DownTimeSkip:float
    EliminationTimeSkip:float
    WipeTimeSkip:float
    TimerTickSFXDuration:float
    UrgentTimerTickSFXDuration:float
    RiftHeight:float
    RiftLifetime:float
    HoldToRebootArrowCount:int
    RebootDurationCycles:[]tuple(float, float)
    WipeMessage<localizes>:message
    RebootBankTags:[]reboot_bank_tag
    RebootNoBankTag:?reboot_bank_tag

rr_score_config<public> := struct:
    Anchor:vector2
    Alignment:vector2
    Offset:vector2

    CrownImage:texture
    ScoreBlockImage:texture
    ContextBlockImage:texture
    PlayerIconImage:texture
    PlayerWipedImage:texture
    OwnerImage:texture
    NumberImages:[]texture

    ScoreTextColor:color
    ScoreTextShadowColor:color
    ScoreTextShadowOpacity:float
    ScoreTextShadowOffset:vector2

    ScoreTextPadding:margin
    ScoreSlotHorizontalPadding:float
    CrownPadding:margin
    CrownSizeXY:float
    OwnerTexturePadding:margin
    OwnerTextureSizeXY:float
    ContextBlockPadding:float
    BlockTextureSizeXY:float
    PlayerIconWipedTextureSizeXY:float
    PlayerIconWipedNumberPadding:float
    PlayerCounterPadding:margin
    NumberImageSizeXY:float
    NumberImagePadding:float
    ShowPlayerCount:logic

    MaximumScoreSlots:int
    WipedColorMultiplier:float
    ShowOwnerAtMinimum:logic
    
EnemyTeamWipedMessage<localizes><public>:message = "ENEMY TEAM WIPED"
EnemyWipedMessage<localizes><public>:message = "ENEMY WIPED"