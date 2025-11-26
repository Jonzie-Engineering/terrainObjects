vehicleInit = {
    params [["_truck", objNull], ["_object", objNull]];
    _truck animateSource ["flatdeck_body", 1, true];
    _truck animateSource ["flatdeck_lift", 1, true];
    _truck animateSource ["flatdeck_slide", 1, true];
    _truck animateSource ["PTO", 1, true];
    [_truck] spawn towTruckTest;
    //[_truck,_object] spawn towLoop;
};
randomVehicle = {
    params [["_truck", objNull]];
    _className = selectRandom ["RetroRP_Mini","RetroRP_Monaco","RetroRP_Dart","RetroRP_Charger69","RetroRP_F100","RetroRP_Vandura","RetroRP_288_GTO","RetroRP_CorvetteZR1","RetroRP_Vandura_Ambulance","RetroRP_W900","RetroRP_Dozer","RetroRP_Forklift","RetroRP_Frontend_Loader","RetroRP_Defender"];
    _newCar = createVehicle [_className, ((_truck modelToWorldVisual (_truck selectionPosition ["Flatdeck_AttachPoint_Rear", "memory"])) vectorAdd [-0.6,0,2]), [], 0, "CAN_COLLIDE"];
    _newCar setDir (random 360);
    _newCar
};
towTruckTest = {
    params [ ["_truck", objNull] ];
    private _object = objNull;
    _object = [_truck] call randomVehicle;
    waitUntil {!(isNull _object)};
    sleep 2;
    [_truck] call ServerModules_fnc_towTruckAutoLoad;

    waitUntil {_truck animationSourcePhase "flatdeck_lift" <= 0 && _truck animationSourcePhase "flatdeck_slide" <= 0 || !alive _object};
    if (isNull _object) exitwith {[_truck] spawn towTruckTest;};
    sleep 2;
    _truck animateSource ["flatdeck_lift", 1];
    _truck animateSource ["flatdeck_slide", 1];
    waitUntil {_truck animationSourcePhase "flatdeck_lift" >= 1 && _truck animationSourcePhase "flatdeck_slide" >= 1};
    detach _object;
    sleep 2;
    deleteVehicle _object;
    [_truck] spawn towTruckTest;
    //[_truck,_object] spawn towLoop;
};
towLoop = {
    params [["_truck", objNull], ["_object", objNull]];

    // Rope setup
    private _ropeFix = "RetroRP_RopeFix" createVehicle [0,0,0];
    _ropeFix attachTo [_truck, [0,0,0], "Winch1_pos",true];
    
    
    // Target speed in m/s (1 kph ≈ 0.27778)
    private _targetSpeed = 1;

    // Boost system
    private _boost     = 0;
    private _boostStep = 0.01;
    private _boostMax  = 5;
    private _Ball = createVehicle ["Sign_Sphere25cm_F", [0,0,0], [], 0, "CAN_COLLIDE"];
    private _Ball2 = createVehicle ["Sign_Sphere25cm_F", [0,0,0], [], 0, "CAN_COLLIDE"];
    private _rope = ropeCreate [_ropeFix, [0,0,0], _object, (getCenterOfMass _object), (_ropeFix distance _object)+3,nil,nil,"RetroRP_TowCable"];
    ropeUnwind [_rope, _targetSpeed, 5];
    while {true} do {
        // Ensure brakes are off and physics awake
        if !(brakesDisabled _object) then {_object disableBrakes true;};
        if !(isAwake _object) then {_object awake true;};

        private _curSpeed    = abs speed _object;
        private _relativeDir = [_object,_truck] call BIS_fnc_relativeDirTo;
        private _velocity    = velocityModelSpace _object;

        // Decide if rope is in front or behind
        private _dirSign = if ((_relativeDir <= 90) || (_relativeDir >= 270)) then {1} else {-1};

        // Adjust boost gradually
        if (_curSpeed < _targetSpeed) then {
            _boost = (_boost + _boostStep) min _boostMax;
        } else {
            _boost = (_boost - _boostStep) max 0;
        };

        // Apply boost in correct direction
        private _Yvector = _dirSign * _boost;

        // Update velocity
        _velocity set [1,_Yvector];
        _object setVelocityModelSpace _velocity;

        _begPos = _truck modelToWorldWorld (_truck selectionPosition "Flatdeck_IntersectStart");
        _endPos = _truck modelToWorldWorld (_truck selectionPosition "Flatdeck_IntersectEnd");
        _Intersect = lineIntersectsObjs [_begPos, _endPos, _truck];
        if (_object IN _Intersect)exitwith{};
        _Ball setPosASL _begPos;
        _Ball2 setPosASL _endPos;
        sleep 0.05;
        hintSilent format [
            "_begPos:%1 _endPos:%2 Intersect:%3 Speed:%4 Target:%5",
            _begPos, _endPos, _Intersect, _curSpeed, _targetSpeed
        ];
    };
    ropeUnwind [_rope, 10, 0,true];
    _object disableBrakes false;
};
ServerModules_fnc_towTruckAutoLoad = {
    params [ ["_truck", objNull] ];

    if (isNull _truck)exitwith {hint "Towtruck not found."};
    if (_truck animationSourcePhase "flatdeck_body" < 1)exitwith {hint "Flatbed not installed"};
    if (_truck animationSourcePhase "flatdeck_lift" < 1 || _truck animationSourcePhase "flatdeck_slide" < 1)exitwith {hint "Flatbed not on the ground"};
    
    // Boost system
    private _boost     = 0;
    private _boostStep = 0.01;
    private _boostMax  = 5;
    private _targetSpeed = 5;// Target speed in m/s (1 kph ≈ 0.27778)
    private _object = objNull;
    private _exit = false;
    private _aligned = [];
    private _pos1 = (_truck selectionPosition "Flatdeck_AttachPoint_Rear");
    private _pos2 = _pos1 vectorAdd [0,-1,3];
    private _backPos = _truck modelToWorldWorld _pos1;
    private _backPosDir = _truck modelToWorldWorld _pos2;
    private _frontPos = _truck modelToWorldWorld (_truck selectionPosition "Flatdeck_IntersectStart");
    private _frontPosDir = _truck modelToWorldWorld ((_truck selectionPosition "Flatdeck_IntersectEnd")vectorAdd [0,0.85,0.2]);
    
    private _intersectBack = lineIntersectsObjs [_backPos, _BackPosDir, _truck];
    private _intersectFront = lineIntersectsObjs [_frontPos, _frontPosDir, _truck];
    if (count _intersectBack < 1) exitwith {hint "No vehicle found";deleteVehicle (nearestObject [_truck, ["RetroRP_Mini","RetroRP_Monaco","RetroRP_Dart","RetroRP_Charger69","RetroRP_F100","RetroRP_Vandura","RetroRP_288_GTO","RetroRP_CorvetteZR1","RetroRP_Vandura_Ambulance","RetroRP_W900","RetroRP_Dozer","RetroRP_Forklift","RetroRP_Frontend_Loader","RetroRP_Defender"]])};
    
    {
        // alignment of truck relative to _x (0..360)
        private _alignment = [_truck, _x] call BIS_fnc_relativeDirTo;
        hint format ["alignment:%1",_alignment];

        // if truck is not roughly behind _x (outside 160..200) then bail out
        if (_alignment < 179 || _alignment > 181) exitWith { _exit = true;deleteVehicle _x};

        // alignment of _x relative to truck (0..360)
        private _alignmentTruck = [_x, _truck] call BIS_fnc_relativeDirTo;

        // if _x is facing roughly the same direction as the truck (within ±20° of 0/360)
        if ((_alignmentTruck <= 10) || (_alignmentTruck >= 350)) exitWith { _x setDir (getDir _truck);_aligned pushBack _x; };
        
        // if _x is facing roughly opposite the truck (within 160..200)
        if (_alignmentTruck >= 170 && _alignmentTruck <= 190) exitWith { _x setDir (getDir _truck + 180);_aligned pushBack _x; };
        
        if (_exit || count _aligned < 1) exitWith {deleteVehicle _x;hint "Vehicle not positioned correctly"};

    } forEach _intersectBack;
    if (_exit || count _aligned < 1) exitWith {hint "Vehicle not positioned correctly";deleteVehicle (nearestObject [_truck, ["RetroRP_Mini","RetroRP_Monaco","RetroRP_Dart","RetroRP_Charger69","RetroRP_F100","RetroRP_Vandura","RetroRP_288_GTO","RetroRP_CorvetteZR1","RetroRP_Vandura_Ambulance","RetroRP_W900","RetroRP_Dozer","RetroRP_Forklift","RetroRP_Frontend_Loader","RetroRP_Defender"]])};
    
    for "_i" from 0 to 1000 do
	{
		{
            _object = _x;
            // Ensure brakes are off and physics awake
            if !(brakesDisabled _object) then {_object disableBrakes true;};
            if !(isAwake _object) then {_object awake true;};

            private _curSpeed    = abs speed _object;
            private _relativeDir = [_object,_truck] call BIS_fnc_relativeDirTo;
            private _velocity    = velocityModelSpace _object;

            // Decide if rope is in front or behind
            private _dirSign = if ((_relativeDir <= 90) || (_relativeDir >= 270)) then {1} else {-1};

            // Adjust boost gradually
            if (_curSpeed < _targetSpeed) then {
                _boost = (_boost + _boostStep) min _boostMax;
            } else {
                _boost = (_boost - _boostStep) max 0;
            };

            // Apply boost in correct direction
            private _Yvector = _dirSign * _boost;

            // Update velocity
            _velocity set [1,_Yvector];
            _object setVelocityModelSpace _velocity;
            if (_object IN _intersectFront)exitwith{};
        
        } forEach _intersectBack;
        
        _intersectFront = lineIntersectsObjs [_frontPos, _frontPosDir, _truck];
        if (count _intersectFront > 0)exitwith{};
        sleep 0.01;
	};
    if (count _intersectFront < 1)exitwith{};
    {
        _x disableBrakes false;
        [_truck,_x,"Flatdeck_AttachPoint_Center"] call ServerModules_fnc_attachRelativeMemory;
    } forEach _intersectBack;
    _truck animateSource ["flatdeck_lift", 0];
    _truck animateSource ["flatdeck_slide", 0];
};
ServerModules_fnc_attachRelativeMemory = {
    params [
        ["_object1", objNull],
        ["_object2", objNull],
        ["_memoryPoint", ""]
    ];


    // POSITION OFFSET
    private _memModel   = _object1 selectionPosition [_memoryPoint, "memory"];
    private _childModel = _object1 worldToModelVisual (_object2 modelToWorldVisual [0,0,0]);
    private _offset     = _childModel vectorDiff _memModel;
    

    // ORIENTATION OFFSET (ROTATION MATRIX COMPONENTS)
    private _dir = [_object2, _object1] call BIS_fnc_relativeDirTo;
    private _memDirUp   = _object1 selectionVectorDirAndUp [_memoryPoint, "memory"];
    private _memDir     = _memDirUp select 0;
    private _memUp      = _memDirUp select 1;

    private _childDir   = _object1 vectorWorldToModel (vectorDir _object2);
    private _childUp    = _object1 vectorWorldToModel (vectorUp  _object2);

    private _relDir = _childDir vectorDiff _memDir;
    private _relUp  = _childUp  vectorDiff _memUp;

    // ATTACH
    _object2 attachTo [_object1, _offset, _memoryPoint, true];
    if ( _memDirUp isNotEqualTo [[0,1,0],[0,0,1]] ) then
    {
        [_object1,_object2,_memoryPoint,_offset,_dir] spawn 
        { 
            params [ ["_object1", objNull], ["_object2", objNull], ["_memoryPoint", ""], ["_offset", [0,0,0]], ["_dir", [0,0,0]] ];
            waitUntil {_object1 selectionVectorDirAndUp [_memoryPoint, "memory"] isEqualTo [[0,1,0],[0,0,1]]};
            detach _object2;
            waitUntil {!(_object2 IN (attachedObjects _object1))};
            sleep 1;
            [_object1,_object2,"Flatdeck_AttachPoint_Center",true] call ServerModules_fnc_attachRelativeMemory;
        };
        /*
        _object2 attachTo [_object1, _offset, _memoryPoint, false];
        [_object1,_object2,_memoryPoint,_offset,_dir] spawn 
        { 
            params [ ["_object1", objNull], ["_object2", objNull], ["_memoryPoint", ""], ["_offset", [0,0,0]], ["_dir", [0,0,0]] ];
            waitUntil {_object2 IN (attachedObjects _object1)};
            while {_object2 IN (attachedObjects _object1) && _object1 selectionVectorDirAndUp [_memoryPoint, "memory"] isNotEqualTo [[0,1,0],[0,0,1]] } do 
            {
                private _memDirUp   = _object1 selectionVectorDirAndUp [_memoryPoint, "memory"];
                private _memDir     = _memDirUp select 0;
                private _memUp      = _memDirUp select 1;
                //_object2 setVectorDirAndUp _memDirUp;
                _object2 setVectorUp _memUp;
                //_object2 setDir _dir;
                sleep 0.05;
            };
            if (_object2 IN (attachedObjects _object1) && _object1 selectionVectorDirAndUp [_memoryPoint, "memory"] isEqualTo [[0,1,0],[0,0,1]])then {detach _object2;sleep 0.5;_object2 attachTo [_object1, _offset, _memoryPoint, true];_object2 setDir _dir;};
        };
        */
    };
    _object2 setDir _dir;
    
    diag_log format ["memModel:%1",_memModel];
    diag_log format ["childModel:%1",_childModel];
    diag_log format ["offset:%1",_offset];

    //_object2 setVectorDirAndUp [[0,1,0],[0,0,1]];
    //_object2 setVectorDir _childDir;
    
};

//[towTruck1] call vehicleInit;
//[towTruck2] call vehicleInit;
//[towTruck3] call vehicleInit;
//[towTruck4] call vehicleInit;
towTruck1 animateSource ["flatdeck_body", 1, true];
towTruck1 animateSource ["flatdeck_lift", 1, true];
towTruck1 animateSource ["flatdeck_slide", 1, true];
sleep 3;
[towTruck1,car1,"Flatdeck_AttachPoint_Center"] call ServerModules_fnc_attachRelativeMemory;

/*
ServerModules_fnc_attachRelativeMemory = {
    params [
        ["_object1", objNull],
        ["_object2", objNull],
        ["_memoryPoint", ""],
        ["_Debug", false]
    ];

    // POSITION OFFSET
    private _memModel   = _object1 selectionPosition [_memoryPoint, "memory"];
    private _childModel = _object1 worldToModel (ASLToAGL getPosASL _object2);
    private _offset     = _childModel vectorDiff _memModel;

    // ORIENTATION OFFSET (ROTATION MATRIX COMPONENTS)
    private _memDirUp   = _object1 selectionVectorDirAndUp [_memoryPoint, "memory"];
    private _memDir     = _memDirUp select 0;
    private _memUp      = _memDirUp select 1;

    private _childDir   = vectorWorldToModel _object1 (vectorDir _object2);
    private _childUp    = vectorWorldToModel _object1 (vectorUp  _object2);

    private _relDir = _childDir vectorDiff _memDir;
    private _relUp  = _childUp  vectorDiff _memUp;

    // ATTACH
    _object2 attachTo [_object1, _offset, _memoryPoint, false];

    // APPLY ORIENTATION RELATIVE TO MEMORY POINT
    private _finalDir = _memDir vectorAdd _relDir;
    private _finalUp  = _memUp  vectorAdd _relUp;

    _object2 setVectorDirAndUp [_finalDir, _finalUp];
    towtruck1 selectionVectorDirAndUp ["Flatdeck_AttachPoint_Center", "memory"];
};
*/

//[towTruck1] call ServerModules_fnc_towTruckAutoLoad;
//towTruck1 animateSource ["flatdeck_lift", 0];towTruck1 animateSource ["flatdeck_slide", 0];

/*
    Attach object2 to object1 at memory point using ASL/world orientation
    Usage:
    [_object1, _object2, "memoryPointName", true] call ServerModules_fnc_attachRelativeMemory;
*/

/*
    Perfect relative attach that:
    - uses ASL (never underground)
    - preserves correct dir/up
    - follows model/bone movement perfectly
*/