ServerModules_fnc_ChangeLightbar = 
{
    // Extracts parameters: _veh (vehicle object), _LightArray (array of hitpoints to ignore)
    params [["_veh", objNull],["_LightArray", []]];

    // Exits if the vehicle is null or not local to this machine (to prevent remote execution)
    if (isNull _veh || !(local _veh)) exitWith {};

    // (Commented out) Previously, a hardcoded array of all possible light-related hitpoints was used
    // private _HitArray = ['Headlight_Left', ...];

    // Retrieves the array of hitpoints to process from mission config (for easier maintenance and flexibility)
    private _HitArray = (missionConfigFile >> "RRP_Hitpoints" >> "ignoreArray") call BIS_fnc_getCfgDataArray;

    // Removes any hitpoints listed in _LightArray from _HitArray, so they are not disabled
    _HitArray = _HitArray - _LightArray;

    // For each remaining hitpoint in _HitArray, sets its damage to 1 (fully damaged/off)
    {_veh setHit [_x, 1];} forEach _HitArray;

    // Resets the 'Head_Lights' animation source to 0 (off)
    _veh animateSource ['Head_Lights', 0];

    // Resets the 'Lightbar' animation source to 0 (off), with force flag set to true
    _veh animateSource ['Lightbar', 0, true];
};
ServerModules_fnc_Lightbar_ID = 
{
    // Get the vehicle parameter, defaulting to objNull if not provided
    params [["_veh", objNull]];

    // Exit if the vehicle is null (not valid)
    if (isNull _veh) exitWith {};

    // Initialize the return array to empty
    private _return = [];

    // Check each possible lightbar animation source on the vehicle
    // If the animation source phase is >= 1, set _return to the corresponding light IDs

    // Lightbar_BEACON_17: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_BEACON_17' >= 1) then {
        _return = ['Light1','Light2','Light3','Light4'];
    };

    // Lightbar_Can_Amber: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_Can_Amber' >= 1) then {
        _return = ['Light22','Light23','Light24','Light25'];
    };

    // Lightbar_Can_Red: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_Can_Red' >= 1) then {
        _return = ['Light26','Light27','Light28','Light29'];
    };

    // Lightbar_CJ_184: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_CJ_184' >= 1) then {
        _return = ['Light5','Light6','Light7','Light8'];
    };

    // Lightbar_mars_skybolt: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_mars_skybolt' >= 1) then {
        _return = ['Light9','Light10','Light11','Light12','Light13','Light14','Light15','Light16'];
    };

    // Lightbar_twin_sonic_chp: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_twin_sonic_chp' >= 1) then {
        _return = ['Light17','Light18','Light19','Light20','Light30'];
    };

    // Lightbar_Fireball: If present, assign its single light ID
    if (_veh animationSourcePhase 'Lightbar_Fireball' >= 1) then {
        _return = 'Light21';
    };

    // Lightbar_Aerodynic: If present, assign its light IDs
    if (_veh animationSourcePhase 'Lightbar_Aerodynic' >= 1) then {
        _return = ['Light31','Light32','Light33','Light34','Light35','Light36','Light37','Light38'];
    };

    // Return the detected light IDs (empty array if none matched)
    _return
};
ServerModules_fnc_ToggleLight = 
{
    // Get parameters with default values
    params [["_veh", objNull],["_LightArray", []],["_state", 1]];

    // Exit if vehicle is null (does not exist)
    if (isNull _veh) exitWith {};

    // If the vehicle is not local, remote execute this function on the vehicle's owner
    if (!(local _veh)) exitWith {[_veh, _LightArray, _state] remoteExecCall ["ServerModules_fnc_ToggleLight", _veh];};

    // Exit if the light array is nil (not defined)
    if (isNil {_LightArray}) exitWith {};

    // Get the type of _LightArray (can be ARRAY or STRING)
    private _type = typeName _LightArray;

    // Switch based on the type of _LightArray
    switch _type do 
    {
        case "ARRAY":
        {
            // If it's an array, loop through each hitpoint and set its state
            {
                _veh setHit [_x, _state];
            } forEach _LightArray;
        };
        case "STRING":
        {
            // If it's a string, set the state for the single hitpoint
            _veh setHit [_LightArray, _state];
        };
        default {};
    };

    // If the state is less than 1 (i.e., turning off), ensure the vehicle's lights are switched on
    if (_state < 1) then {
        _veh switchLight "ON";
        _veh animateSource ['Lightbar', 999999];
    }else{_veh animateSource ['Lightbar', 0,true];};
};
sleep 1;
{
    [_x] call ServerModules_fnc_ChangeLightbar;
    _x engineOn true;
    _x animateSource ['Head_Lights', 1];
    _x switchLight "ON";
    _x setPilotLight true;
    [_x,([_x] call ServerModules_fnc_Lightbar_ID),0] call ServerModules_fnc_ToggleLight;
} forEach nearestObjects [player, ["AllVehicles"], 150000];


achievementArray = [
  "GamePlayed",
  "GamePlayedDays",
  "GamePlayedTimeStamp",
  "MPPlayTime",
  "SPPlayTime",
  "WorkshopMissionPublishedCount",
  "WorkshopMissionPublishedFlag",
  "DevPlayTime",
  "StablePlayTime",
  "TotalPlayTime",
  "EditorPlayTime",
  "WorkshopMissionPlayTime",
  "CampaignPlayTime",
  "CampaignEPAPlayTime",
  "CampaignEPBPlayTime",
  "CampaignEPCPlayTime",
  "AltisPlayTime",
  "StratisPlayTime",
  "OtherWorldPlayTime",
  "ChallengesPlayTime",
  "ShowcasesPlayTime",
  "ZeusPlayerPlayTime",
  "ZeusNormalPlayerGamePlayTime",
  "FieldManualPlayTime",
  "FiringDrillsPlayTime",
  "ZeusUnitControlPlayTime",
  "CompletedEPA",
  "CompletedEPB",
  "CompletedEPC",
  "CompletedEPC_A",
  "CompletedEPC_B",
  "StartedAnyScenario",
  "CompletedFD01",
  "CompletedFD02",
  "CompletedFD03",
  "CompletedFD04",
  "CompletedFD05",
  "CompletedFD06",
  "CompletedFD07",
  "CompletedFD08",
  "CompletedFD09",
  "CompletedFD10",
  "CompletedBronzeFD01",
  "CompletedBronzeFD02",
  "CompletedBronzeFD03",
  "CompletedBronzeFD04",
  "CompletedBronzeFD05",
  "CompletedBronzeFD06",
  "CompletedBronzeFD07",
  "CompletedBronzeFD08",
  "CompletedBronzeFD09",
  "CompletedBronzeFD10",
  "CompletedSilverFD01",
  "CompletedSilverFD02",
  "CompletedSilverFD03",
  "CompletedSilverFD04",
  "CompletedSilverFD05",
  "CompletedSilverFD06",
  "CompletedSilverFD07",
  "CompletedSilverFD08",
  "CompletedSilverFD09",
  "CompletedSilverFD10",
  "CompletedGoldFD01",
  "CompletedGoldFD02",
  "CompletedGoldFD03",
  "CompletedGoldFD04",
  "CompletedGoldFD05",
  "CompletedGoldFD06",
  "CompletedGoldFD07",
  "CompletedGoldFD08",
  "CompletedGoldFD09",
  "CompletedGoldFD10",
  "AchievedFDSpecial1",
  "AchievedFDSpecial2",
  "CompletedTT01",
  "CompletedTT02",
  "CompletedTT03",
  "CompletedTT04",
  "CompletedTT05",
  "CompletedBronzeTT01",
  "CompletedBronzeTT02",
  "CompletedBronzeTT03",
  "CompletedBronzeTT04",
  "CompletedBronzeTT05",
  "CompletedSilverTT01",
  "CompletedSilverTT02",
  "CompletedSilverTT03",
  "CompletedSilverTT04",
  "CompletedSilverTT05",
  "CompletedGoldTT01",
  "CompletedGoldTT02",
  "CompletedGoldTT03",
  "CompletedGoldTT04",
  "CompletedGoldTT05",
  "AchievedTTSpecial1",
  "AchievedTTSpecial2",
  "AchFDFirst",
  "AchFDBronze",
  "AchFDGold",
  "AchTTFirst",
  "AchTTBronze",
  "AchTTGold",
  "ZeusUnitsCreated",
  "AchZeusHerosJourney",
  "AchZeusDietyForADay",
  "AchZeusMagnumOpus",
  "AchZeusGodlyCreations",
  "AchZeusScapegoat",
  "AchZeusWorshiper",
  "AchZeusMercifulGod",
  "ZeusPingResponded",
  "KartsPTKart_01_F",
  "KartsPTPistol_Signal_01_F",
  "KartsPTC_RacingHelmet_F",
  "KartsPTC_Driver_F",
  "BCFirstDeployment",
  "BCKIA",
  "BCDrillInstructor",
  "BCReadyForDuty",
  "BCStarRecruit",
  "BCVirtualReality",
  "BCVirtualCommand",
  "BCRealVirtuality",
  "BCLockAndLoad",
  "BCRelentlessCreator",
  "VRPlayTime",
  "WorkshopMissionSubscribedFlag",
  "WorkshopMissionUpdatedFlag",
  "HeliPTTaru",
  "HeliPTHuron",
  "HeliPTM900",
  "HeliShowcasing",
  "HeliMeetAndGreet",
  "HeliShowtime",
  "HeliAirbridge",
  "HeliDustOff",
  "HeliNapOfTheEarth",
  "TTHeliGold",
  "TTHeliBronze",
  "BCVirtualNOEFlight",
  "BCAdvVirtualPilot",
  "BCVirtualPilot",
  "CompletedTT06",
  "CompletedTT07",
  "CompletedTT08",
  "CompletedTT09",
  "CompletedTT10",
  "CompletedBronzeTT06",
  "CompletedBronzeTT07",
  "CompletedBronzeTT08",
  "CompletedBronzeTT09",
  "CompletedBronzeTT10",
  "CompletedGoldTT06",
  "CompletedGoldTT07",
  "CompletedGoldTT08",
  "CompletedGoldTT09",
  "CompletedGoldTT10",
  "MarkPT_DMR_02",
  "MarkPT_DMR_03",
  "MarkPT_DMR_04",
  "MarkPT_DMR_05",
  "MarkPT_DMR_06",
  "MarkPT_MMG_01",
  "MarkPT_MMG_02",
  "MarkPT_fullghillie",
  "MarkPT_equip_b_carrier_gl_rig",
  "MarkPT_acco_khs",
  "MarkPT_Designator_01",
  "MarkPT_acco_ams",
  "MarkVirtualShooter",
  "MarkBadOmens",
  "MarkDodgeThis",
  "MarkHacker",
  "MarkCarrier",
  "MarkHipShooter",
  "MarkConservativeSharpshooter",
  "MarkVirtualVehicleInspection",
  "MarkMassVirtualDestruction",
  "MarkRockStable",
  "MarkMarksmenWeaponMaster",
  "CompletedFD11",
  "CompletedFD12",
  "CompletedFD13",
  "CompletedBronzeFD11",
  "CompletedBronzeFD12",
  "CompletedBronzeFD13",
  "CompletedGoldFD11",
  "CompletedGoldFD12",
  "CompletedGoldFD13",
  "CompletedSilverFD11",
  "CompletedSilverFD12",
  "CompletedSilverFD13",
  "GamePlayedWin",
  "GamePlayedDaysWin",
  "GamePlayedTimeStampWin",
  "GamePlayedLinux",
  "GamePlayedDaysLinux",
  "GamePlayedTimeStampLinux",
  "GamePlayedMacOS",
  "GamePlayedDaysMacOS",
  "GamePlayedTimeStampMacOS",
  "2DEditorPlayTime",
  "3DEditorPlayTime",
  "3DENModelStudent",
  "3DENPuppeteer",
  "3DENArsenal",
  "3DENImport2D",
  "ExpPT_ctar",
  "ExpPT_cmr",
  "ExpPT_erco",
  "ExpPT_lmg",
  "ExpPT_pm9",
  "ExpPT_rpg7",
  "ExpPT_spar16",
  "ExpPT_spar17",
  "ExpPT_arx",
  "ExpPT_planeCivil",
  "ExpPT_kh3a",
  "ExpPT_mq12",
  "ExpPT_offroad",
  "ExpPT_prowler",
  "ExpPT_qilin",
  "ExpPT_rhib",
  "ExpPT_v44x",
  "ExpPT_y32",
  "ExpPT_scooter",
  "ExpPT_ctrg",
  "ExpPT_paraTT",
  "ExpPT_paraTee",
  "ExpPT_sphHex",
  "ExpPT_spsHex",
  "ExpPT_sch",
  "ExpPT_ak12",
  "ExpPT_aks",
  "ExpPT_akm",
  "ExpPT_protector",
  "ExpFirestarter",
  "ExpFastExtract",
  "ExpWarlockDown",
  "ExpBetterWithFriends",
  "ExpLoneWolf",
  "ExpBiggerPicture",
  "ExpNoneTheWiser",
  "ExpWelcomeToTanoa",
  "ExpTransportService",
  "ExpGamePlan",
  "ExpSerpentMark",
  "ExpChangingBalance",
  "ExpMrAnderson",
  "ExpVehLoadUnload",
  "ExpPT_adr97",
  "TanoaPlaytime",
  "ExpPT_snds65",
  "ExpPT_paraRF",
  "ExpPT_paraMK",
  "ExpPT_paraLNCH",
  "ExpPT_bandMK",
  "ExpPT_bandLNCH",
  "ExpPT_bandMG",
  "ExpPT_bandRF",
  "ExpPT_bandSCT",
  "ExpPT_helmetSkate",
  "ExpPT_balacava",
  "ExpPT_tacChessRig",
  "ExpPT_viperHarness",
  "ExpPT_backBergen",
  "ExpPT_nvgComp",
  "ExpPT_envgII",
  "JetsPT_PlaneFighter01",
  "JetsPT_PlaneFighter02",
  "JetsPT_PlaneFighter04",
  "JetsPT_UAV05",
  "JetsPT_DeckCrewVest",
  "JetsBomberman",
  "JetsDeadstickLanding",
  "JetsGetArrested",
  "JetsArmedAndDangerous",
  "JetsPunchOut",
  "MaldenPlayTime",
  "OrangeCampaignDone",
  "OrangeCampaignComplete",
  "OrangeCampaignGood",
  "OrangeShowcaseIDAP",
  "OrangeShowcaseLoW",
  "OrangeTTBronze",
  "OrangeTTGold",
  "CompletedTT11",
  "CompletedTT12",
  "CompletedTT13",
  "CompletedTT14",
  "CompletedTT15",
  "CompletedBronzeTT11",
  "CompletedBronzeTT12",
  "CompletedBronzeTT13",
  "CompletedBronzeTT14",
  "CompletedBronzeTT15",
  "CompletedGoldTT11",
  "CompletedGoldTT12",
  "CompletedGoldTT13",
  "CompletedGoldTT14",
  "CompletedGoldTT15",
  "AIKillCount",
  "PlayerKillCount",
  "RenegadeCount",
  "OrangePT_Van02",
  "OrangePT_UAV06",
  "OrangePT_APERSMineDispenser",
  "OrangePT_TrainingMine",
  "OrangePT_SafetyVest",
  "OrangePT_MultiPocketVest",
  "OrangePT_IdentificationVest",
  "OrangePT_EODVest",
  "OrangePT_MessengerBag",
  "OrangePT_LegStrapBag",
  "OrangePT_WirelessEarpiece",
  "OrangePT_EarProtectors",
  "OrangePT_HardHat",
  "OrangePT_SafariHat",
  "OrangePT_HeadBandage",
  "OrangePT_BasicHelmet",
  "OrangePT_Respirator",
  "OrangePT_EyeProtectors",
  "OrangePT_ParamedicOutfit",
  "OrangePT_MechanicClothes",
  "OrangeCampaignArticleDecisionA",
  "OrangeCampaignArticleDecisionB",
  "OrangeCampaignArticleDecisionC",
  "OrangeCampaignArticleDecisionD",
  "OrangeCampaignArticleDecisionE",
  "OrangeCampaignAirDropDecisionA",
  "OrangeCampaignAirDropDecisionB",
  "OrangeCampaignLeafletsDecisionA",
  "OrangeCampaignLeafletsDecisionB",
  "OrangeCampaignClusterDecisionA",
  "OrangeCampaignClusterDecisionB",
  "OrangeCampaignEscapeDecisionA",
  "OrangeCampaignEscapeDecisionB",
  "OrangeCampaignMineDispenserDecisionA",
  "OrangeCampaignMineDispenserDecisionB",
  "ToDifferentPerspective",
  "ToForwardObserver",
  "ToBeyondHope",
  "ToChangingPlaces",
  "ToSteppingStone",
  "ToSeasonedWarfighter",
  "ToSteelPegasus",
  "ToSavior",
  "ToLifeline",
  "TankPT_rhino",
  "TankPT_nyx",
  "TankPT_angara",
  "TankPT_tankCrew",
  "TankTTBronze",
  "TankTTGold",
  "TankByTheBook",
  "TankFromWithin",
  "TankEasyMoney",
  "TankSteelSniper",
  "TankCommander",
  "TankSizeNotMatter",
  "TankInItTogether",
  "CompletedTT16",
  "CompletedTT17",
  "CompletedTT18",
  "CompletedBronzeTT16",
  "CompletedBronzeTT17",
  "CompletedBronzeTT18",
  "CompletedGoldTT16",
  "CompletedGoldTT17",
  "CompletedGoldTT18",
  "TankFromWithinCount",
  "TankCommanderCount",
  "TankSizeNotMatterCount",
  "TankInItTogetherCount",
  "ContactPT_UGV02",
  "ContactPT_Tractor01",
  "ContactPT_MSBS65",
  "ContactPT_MSBS65_ICO",
  "ContactPT_HunterShotgun01",
  "ContactPT_DMR_06",
  "ContactPT_RPK12",
  "ContactPT_AKU12",
  "ContactPT_ESD01",
  "ContactPT_ESD01_Light",
  "ContactPT_ESD01_Antenna01",
  "ContactPT_ESD01_Antenna02",
  "ContactPT_ESD01_Antenna03",
  "ContactPT_LDFFatigues",
  "ContactPT_LDFHelmet",
  "ContactPT_LDFVest",
  "ContactPT_Granit",
  "ContactPT_Avenger",
  "ContactPT_Kipchak",
  "ContactPT_CBRNSuit",
  "ContactPT_CBRNAPR",
  "ContactPT_CBRNCUR",
  "ContactPT_RegulatorMask",
  "ContactPT_SCBA",
  "ContactPT_SIMCOM",
  "ContactPT_RadioPack",
  "ContactPT_Blindfold",
  "ContactPT_TinFoilHat",
  "ContactPT_Offroad01_Covered",
  "EnochPlayTime",
  "ContactCampaignIntro1PlayTime",
  "ContactCampaignIntro2PlayTime",
  "ContactCampaignIntro3PlayTime",
  "ContactCampaignFreeRoam1PlayTime",
  "ContactCampaignFreeRoam2PlayTime",
  "ContactCampaignOutro2PlayTime",
  "ContactCampaignOutro3PlayTime",
  "ContactCampaignIntro1Finished",
  "ContactCampaignIntro2Finished",
  "ContactCampaignIntro3Finished",
  "ContactCampaignFreeRoam1Finished",
  "ContactCampaignFreeRoam2Finished",
  "ContactCampaignOutro2Finished",
  "ContactCampaignOutro3Finished",
  "ContactCampaignTotalPlayTime",
  "ContactCampaignCompleted"
];

{
    setStatValue [_x, 1];
    unlockAchievement _x;
} forEach (profileNamespace getVariable "achievementArray");
["end", true, 2] call BIS_fnc_endMission;

lifeLoop = nil;
[] spawn
{ 
    if (isNil "lifeLoop")then  
    {
        lifeLoop =  true;
        lootBox = objNull;
        while {lifeLoop} do  
        {
            {
                vehicle _x setVehicleAmmo 1; 
                _x setAmmo [currentWeapon _unit, 1000000];
                if (isDamageAllowed vehicle _x)then {vehicle _x setDamage 0;vehicle _x allowDamage false;}; 
                if (isDamageAllowed _x)then {_x setDamage 0;_x allowDamage false;}; 
                if (fuel vehicle _x < 0.5)then {vehicle _x setfuel 1;}; 
                if (getFatigue _x > 0) then {_x setFatigue 1;_x enableFatigue false;}; 
                if (getStamina _x < 60) then {_x setStamina 70;_x enableStamina false;}; 
                if (_x skill "general" < 1) then {_x setSkill ["general", 1];}; 
                if (_x skill "aimingAccuracy" < 1) then {_x setSkill ["aimingAccuracy", 1];}; 
                if (_x skill "aimingSpeed" < 1) then {_x setSkill ["aimingSpeed", 1];}; 
                if (_x skill "endurance" < 1) then {_x setSkill ["endurance", 1];}; 
                if (_x skill "spotTime" < 1) then {_x setSkill ["spotTime", 1];}; 
                if (_x skill "courage" < 1) then {_x setSkill ["courage", 1];}; 
                if (_x skill "aimingShake" < 1) then {_x setSkill ["aimingShake", 1];}; 
                if (_x skill "commanding" < 1) then {_x setSkill ["commanding", 1];}; 
                if (_x skill "spotDistance" < 1) then {_x setSkill ["spotDistance", 1];}; 
                if (_x skill "reloadSpeed" < 1) then {_x setSkill ["reloadSpeed", 1];}; 
                if (!(_x getVariable ["EH_Fired",false]))then 
                { 
                    _x addEventHandler ["Fired",  
                    { 
                        params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_gunner"]; 
                        if (_weapon isEqualTo (secondaryWeapon _unit))then {_unit addSecondaryWeaponItem _magazine;}; 
                        if (isThrowable _magazine)then {_unit addItem _magazine;};
                        if (!(_weapon isEqualTo (secondaryWeapon _unit)) && !(_weapon isEqualTo (primaryWeapon _unit)) && !(_weapon isEqualTo (handgunWeapon _unit)) && !(_weapon isEqualTo (currentWeapon _unit)) && !(isThrowable _magazine) ) then {_unit addMagazine _magazine;}; 
                        vehicle _unit setVehicleAmmo 1; 
                        _unit setAmmo [currentWeapon _unit, 1000000];
                    }]; 
                    _x setVariable ["EH_Fired",true]; 
                };
                if ((speed (vehicle _x)) < 25 && (vehicle _x) isKindOf "Air" && (vehicle _x) isNotEqualTo (vehicle player) )then 
                {
                    _ilsPos = [0,0,500];
                    _ilsDir = random 360;
                    _nObject = nearestObjects [_ilsPos, ["Air"], 100];
                    if ((count _nObject) <= 0) then 
                    {
                        if (isDamageAllowed vehicle _x)then {vehicle _x setDamage 0;vehicle _x allowDamage false;}; 
                        if (isDamageAllowed _x)then {_x setDamage 0;_x allowDamage false;}; 
                        vehicle _x setDir _ilsDir;
                        vehicle _x setpos _ilsPos;
                        vehicle _x setVelocityModelSpace [0,75,0];
                    };
                    sleep 0.1;
                };
            } foreach (units group player);
            if !(isNull lootBox) then
            {
                _nObject = nearestObjects [player, ["ReammoBox_F","WeaponHolderSimulated", "GroundWeaponHolder", "WeaponHolder","GroundWeaponHolder_Scripted","AllVehicles","Man"], 250];
                if (isDamageAllowed lootBox)then {lootBox setDamage 0;lootBox allowDamage false;}; 
                if ( time > (player getVariable ["lastLoot",0])+60 && (count _nObject) > 2 ) then 
                {
                    player setVariable ["lastLoot",time];
                    {
                        if (_x isNotEqualTo lootBox && _x isNotEqualTo player && !(isPlayer _x) && !(_x IN (units group player)) && (side _x) isNotEqualTo (side player) && !(_x isKindOf "A3AP_Box_Syndicate_Ammo_F") ) then
                        {
                            _ammoBox = _x;
                            _container = objNull;
                            if (_ammoBox isKindOf "Man")then 
                            {
                                if ( !(alive _ammoBox) )then
                                {
                                    _container = uniformContainer _ammoBox;
                                    {
                                        lootBox addWeaponCargoGlobal [_x, 1];
                                        _container addWeaponCargoGlobal [_x, -1];
                                    } forEach weaponCargo _container;
                                    {
                                        lootBox addMagazineCargoGlobal [_x, 1];
                                        _container addMagazineCargoGlobal [_x, -1];
                                        
                                    } forEach magazineCargo _container;
                                    {
                                        lootBox addItemCargoGlobal [_x, 1];
                                        _container addItemCargoGlobal [_x, -1];
                                        
                                    } forEach itemCargo _container;
                                    {
                                        lootBox addBackpackCargoGlobal [_x, 1];
                                        _container addBackpackCargoGlobal [_x, -1];

                                    } forEach backpackCargo _container;


                                    _container = vestContainer _ammoBox;
                                    {
                                        lootBox addWeaponCargoGlobal [_x, 1];
                                        _container addWeaponCargoGlobal [_x, -1];
                                    } forEach weaponCargo _container;
                                    {
                                        lootBox addMagazineCargoGlobal [_x, 1];
                                        _container addMagazineCargoGlobal [_x, -1];
                                        
                                    } forEach magazineCargo _container;
                                    {
                                        lootBox addItemCargoGlobal [_x, 1];
                                        _container addItemCargoGlobal [_x, -1];
                                        
                                    } forEach itemCargo _container;
                                    {
                                        lootBox addBackpackCargoGlobal [_x, 1];
                                        _container addBackpackCargoGlobal [_x, -1];

                                    } forEach backpackCargo _container;


                                    _container = backpackContainer _ammoBox;
                                    {
                                        lootBox addWeaponCargoGlobal [_x, 1];
                                        _container addWeaponCargoGlobal [_x, -1];
                                    } forEach weaponCargo _container;
                                    {
                                        lootBox addMagazineCargoGlobal [_x, 1];
                                        _container addMagazineCargoGlobal [_x, -1];
                                        
                                    } forEach magazineCargo _container;
                                    {
                                        lootBox addItemCargoGlobal [_x, 1];
                                        _container addItemCargoGlobal [_x, -1];
                                        
                                    } forEach itemCargo _container;
                                    {
                                        lootBox addBackpackCargoGlobal [_x, 1];
                                        _container addBackpackCargoGlobal [_x, -1];

                                    } forEach backpackCargo _container;

                                    {
                                        lootBox addWeaponCargoGlobal [_x, 1];
                                        _ammoBox removeWeapon _x;
                                    } forEach weapons _ammoBox;
                                    {
                                        lootBox addMagazineCargoGlobal [_x, 1];
                                        
                                    } forEach magazines _ammoBox;
                                    {
                                        lootBox addItemCargoGlobal [_x, 1];
                                        
                                    } forEach items _ammoBox;
                                    {
                                        lootBox addBackpackCargoGlobal [_x, 1];
                                    } forEach backpacks _ammoBox;
                                    removeAllWeapons _ammoBox; 
                                    removeAllItems _ammoBox; 
                                    removeAllAssignedItems _ammoBox;
                                    removeVest _ammoBox; 
                                    removeBackpack _ammoBox; 
                                    removeHeadgear _ammoBox; 
                                    removeGoggles _ammoBox; 
                                    removeAllItemsWithMagazines _ammoBox; 
                                };
                            }else
                            {
                                if (maxLoad _ammoBox > 0) then 
                                {
                                    {
                                        lootBox addWeaponCargoGlobal [_x, 1];
                                        _ammoBox addWeaponCargoGlobal [_x, -1];
                                    } forEach weaponCargo _ammoBox;
                                    {
                                        lootBox addMagazineCargoGlobal [_x, 1];
                                        _ammoBox addMagazineCargoGlobal [_x, -1];
                                        
                                    } forEach magazineCargo _ammoBox;
                                    {
                                        lootBox addItemCargoGlobal [_x, 1];
                                        _ammoBox addItemCargoGlobal [_x, -1];
                                        
                                    } forEach itemCargo _ammoBox;
                                    {
                                        lootBox addBackpackCargoGlobal [_x, 1];
                                        _ammoBox addBackpackCargoGlobal [_x, -1];
                                        
                                    } forEach backpackCargo _ammoBox;
                                };
                            };
                        };
                    } forEach _nObject;
                    systemChat "Loot Taken";
                };
                if (getDammage lootBox > 0.1) then {deleteVehicle lootBox;lootBox = objNull;};
            }
            else
            {
                _nObject = nearestObject [player, "A3AP_Box_Syndicate_Ammo_F"];
                if (local _nObject)then
                {
                    lootBox = _nObject;
                    systemChat format ["lootBox found: %1",lootBox];
                    lootBox allowDamage false;
                };
                if (isNull lootBox)then
                {
                    {
                        if (_x isKindOf "A3AP_Box_Syndicate_Ammo_F")then {lootBox = _x;systemChat format ["lootBox found: %1",lootBox];};
                    } forEach attachedObjects player;
                };
            };
            sleep 1; 
        }; 
        lifeLoop =  nil; 
    }; 
};

(typeOf player) createUnit [position player, group player, "myUnit = this",1]; 
_unit = myUnit; 
removeAllWeapons _unit; 
removeAllItems _unit; 
removeAllAssignedItems _unit; 
removeUniform _unit; 
removeVest _unit; 
removeBackpack _unit; 
removeHeadgear _unit; 
removeGoggles _unit; 
removeAllItemsWithMagazines _unit; 

_unit forceAddUniform (uniform player); 
{ 
_unit addItemToUniform _x; 
} forEach (magazineCargo (uniformContainer player))+(itemCargo (uniformContainer player)); 

_unit addVest (vest player); 
{ 
_unit addItemToVest _x; 
} forEach (magazineCargo (vestContainer player))+(itemCargo (vestContainer player)); 

_unit addBackpack (backpack player); 
clearAllItemsFromBackpack _unit; 
{ 
_unit addItemToBackpack _x; 
} forEach (magazineCargo (backpackContainer player))+(itemCargo (backpackContainer player)); 

_unit addHeadgear (headgear player); 
_unit addGoggles (goggles player); 
_unit addWeapon (binocular player); 
{ 
_unit linkItem _x; 
} forEach assignedItems [player, false, false]; 

{ 
_weaponClass =  _x select 0; 
_attachment1 =  _x select 1; 
_attachment2 =  _x select 2; 
_attachment3 =  _x select 3; 
_attachment4 =  _x select 6; 
_magClass =  (_x select 4)select 0; 
_unit addWeapon _weaponClass; 
if ((secondaryWeapon _unit) isEqualTo _weaponClass)then  
{ 
_unit addSecondaryWeaponItem _attachment1; 
_unit addSecondaryWeaponItem _attachment2; 
_unit addSecondaryWeaponItem _attachment3; 
_unit addSecondaryWeaponItem _attachment4; 
_unit addSecondaryWeaponItem _magClass; 
_unit addItemToBackpack _magClass; 
}; 
if ((primaryWeapon _unit) isEqualTo _weaponClass)then  
{ 
_unit addPrimaryWeaponItem _attachment1; 
_unit addPrimaryWeaponItem _attachment2; 
_unit addPrimaryWeaponItem _attachment3; 
_unit addPrimaryWeaponItem _attachment4; 
_unit addPrimaryWeaponItem _magClass; 
}; 
if ((handgunWeapon _unit) isEqualTo _weaponClass)then  
{ 
_unit addHandgunItem _attachment1; 
_unit addHandgunItem _attachment2; 
_unit addHandgunItem _attachment3; 
_unit addHandgunItem _attachment4; 
_unit addHandgunItem _magClass; 
}; 
} forEach (weaponsItems player);

[] spawn 
{
   _ilsPos = [0,0,500];
   (typeOf player) createUnit [position player, group player, "myUnit = this",1];
    _unit = myUnit;
    removeAllWeapons _unit;
    removeAllItems _unit;
    removeAllAssignedItems _unit;
    removeUniform _unit;
    removeVest _unit;
    removeBackpack _unit;
    removeHeadgear _unit;
    removeGoggles _unit;
    removeAllItemsWithMagazines _unit;

    _unit forceAddUniform (uniform player);
    {
        _unit addItemToUniform _x;
    } forEach (magazineCargo (uniformContainer player))+(itemCargo (uniformContainer player));

    _unit addVest (vest player);
    {
        _unit addItemToVest _x;
    } forEach (magazineCargo (vestContainer player))+(itemCargo (vestContainer player));

    _unit addBackpack (backpack player);
    clearAllItemsFromBackpack _unit;
    {
        _unit addItemToBackpack _x;
    } forEach (magazineCargo (backpackContainer player))+(itemCargo (backpackContainer player));

    _unit addHeadgear (headgear player);
    _unit addGoggles (goggles player);
    _unit addWeapon (binocular player);
    {
        _unit linkItem _x;
    } forEach assignedItems [player, false, false];

    {
        _weaponClass =  _x select 0;
        _attachment1 =  _x select 1;
        _attachment2 =  _x select 2;
        _attachment3 =  _x select 3;
        _attachment4 =  _x select 6;
        _magClass =  (_x select 4)select 0;
        _unit addWeapon _weaponClass;
        if ((secondaryWeapon _unit) isEqualTo _weaponClass)then 
        {
            _unit addSecondaryWeaponItem _attachment1;
            _unit addSecondaryWeaponItem _attachment2;
            _unit addSecondaryWeaponItem _attachment3;
            _unit addSecondaryWeaponItem _attachment4;
            _unit addSecondaryWeaponItem _magClass;
            _unit addItemToBackpack _magClass;
        };
        if ((primaryWeapon _unit) isEqualTo _weaponClass)then 
        {
            _unit addPrimaryWeaponItem _attachment1;
            _unit addPrimaryWeaponItem _attachment2;
            _unit addPrimaryWeaponItem _attachment3;
            _unit addPrimaryWeaponItem _attachment4;
            _unit addPrimaryWeaponItem _magClass;
        };
        if ((handgunWeapon _unit) isEqualTo _weaponClass)then 
        {
            _unit addHandgunItem _attachment1;
            _unit addHandgunItem _attachment2;
            _unit addHandgunItem _attachment3;
            _unit addHandgunItem _attachment4;
            _unit addHandgunItem _magClass;
        };
    } forEach (weaponsItems player);
    while {count(units group player) < 10} do 
    {
        _nObject = nearestObjects [_ilsPos, ["Air"], 100];
        if ((count _nObject) <= 0) then 
        {
            _plane = createVehicle ["B_Plane_Fighter_01_F", _ilsPos, [], 0, "CAN_COLLIDE"];
            _plane setDir (random 360);
            _plane setVelocityModelSpace [0,75,0];
            "B_Fighter_Pilot_F" createUnit [_ilsPos, group player, "myUnit = this",1];
            _unit = myUnit;
            _unit moveInDriver _plane;
            _plane setDamage 0;_plane allowDamage false;
            _unit setDamage 0;_unit allowDamage false;
            _plane setfuel 1;
            _unit setFatigue 1;_unit enableFatigue false;
            _unit setStamina 70;_unit enableStamina false;
            _unit setSkill ["general", 1];_unit setSkill ["aimingAccuracy", 1];_unit setSkill ["aimingSpeed", 1];_unit setSkill ["endurance", 1];_unit setSkill ["spotTime", 1];_unit setSkill ["courage", 1];_unit setSkill ["aimingShake", 1];_unit setSkill ["commanding", 1];_unit setSkill ["spotDistance", 1];_unit setSkill ["reloadSpeed", 1];
            sleep 1;
        };
    };
};

[] spawn
{ 
   _veh = vehicle player;
   _force = 80;
   _maxSpeed = 300;
   while { true } do 
   {
        if (speed _veh < _maxSpeed && (getDammage _veh) <= 0) then {_veh addForce [[0,_force,0],getCenterOfMass _veh];};
        if (player getVariable ['ace_isunconscious', false]) then {[player, player] call ace_medical_treatment_fnc_fullHeal;hint "Dead!";};
        sleep 0.01;
   };
};