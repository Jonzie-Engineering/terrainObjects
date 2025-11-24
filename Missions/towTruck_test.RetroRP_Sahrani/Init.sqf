vehicleInit = {
    params [["_truck", objNull], ["_object", objNull]];
    _truck animateSource ["flatdeck_body", 1, true];
    _truck animateSource ["flatdeck_lift", 1, true];
    _truck animateSource ["flatdeck_slide", 1, true];
    _truck animateSource ["PTO", 1, true];
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
[towTruck1,car1] call vehicleInit;
ServerModules_fnc_towTruckAutoLoad = {
    params [ ["_truck", objNull] ];

    if (isNull _truck)exitwith {hint "Towtruck not found."};
    if (_truck animationSourcePhase "flatdeck_body" < 1)exitwith {hint "Flatbed not installed"};
    if (_truck animationSourcePhase "flatdeck_lift" < 1 || _truck animationSourcePhase "flatdeck_slide" < 1)exitwith {hint "Flatbed not on the ground"};
    
    private _object = objNull;
    private _pos1 = (_truck selectionPosition "Flatdeck_AttachPoint_Rear");
    private _pos2 = _pos1 vectorAdd [0,-1,3];
    private _backPos = _truck modelToWorldWorld _pos1;
    private _backPosDir = _truck modelToWorldWorld _pos2;
    private _frontPos = _truck modelToWorldWorld (_truck selectionPosition "Flatdeck_IntersectStart");
    private _frontPosDir = _truck modelToWorldWorld ((_truck selectionPosition "Flatdeck_IntersectEnd")vectorAdd [0,0.85,0.2]);
    
    private _intersectBack = lineIntersectsObjs [_backPos, _BackPosDir, _truck];
    private _intersectFront = lineIntersectsObjs [_frontPos, _frontPosDir, _truck];
    if (count _intersectBack < 1) exitwith {hint "No vehicle found"};
    // Boost system
    private _boost     = 0;
    private _boostStep = 0.01;
    private _boostMax  = 5;
    private _targetSpeed = 5;// Target speed in m/s (1 kph ≈ 0.27778)
    
    while {count _intersectFront < 1} do 
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
        sleep 0.01;
    };
    {
        _x disableBrakes false;
        [_truck,_x,"Flatdeck_AttachPoint_Center",true] call ServerModules_fnc_attachRelativeMemory;
    } forEach _intersectBack;
    _truck animateSource ["flatdeck_lift", 0];
    _truck animateSource ["flatdeck_slide", 0];
};
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

ServerModules_fnc_attachRelativeMemory = {
    params [
        ["_object1", objNull],
        ["_object2", objNull],
        ["_memoryPoint", ""],
        ["_Debug", false]
    ];

    // POSITION OFFSET
    private _memModel   = _object1 selectionPosition [_memoryPoint, "memory"];
    private _childModel = _object1 worldToModel (_object2 modelToWorld [0,0,0]);
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
    
    diag_log format ["memModel:%1",_memModel];
    diag_log format ["childModel:%1",_childModel];
    diag_log format ["offset:%1",_offset];

    //_object2 setVectorDirAndUp [[0,1,0],[0,0,1]];
    //_object2 setVectorDir _childDir;
    _object2 setDir _dir;
};
//

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

sleep 3;
[towTruck1,car1,"Flatdeck_AttachPoint_Center",true] call ServerModules_fnc_attachRelativeMemory;
//[towTruck1] call ServerModules_fnc_towTruckAutoLoad;
//towTruck1 animateSource ["flatdeck_lift", 0];towTruck1 animateSource ["flatdeck_slide", 0];