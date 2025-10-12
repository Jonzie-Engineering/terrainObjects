ServerModules_fnc_GPS_nodeInfo = 
{
    params [["_pos", [0,0,0]],["_start", [0,0,0]],["_end", [0,0,0]]];
    _returnMessage = [];
    
    if ( (_pos isEqualTo [0,0,0]) ) exitWith {_returnMessage};
    
    private _roadSegment = objNull;
    private _obj = _pos nearestObject "Sign_Arrow_F";
    
    private _nodeInfo = _obj getVariable ["GPSNodeInfo",[]];
    if ((count _nodeInfo) < 1) exitWith {_returnMessage};
    
    _obj = _nodeInfo select 0;
    _pos = _nodeInfo select 1;
    private _begPos = _nodeInfo select 2;
    private _begObj = _nodeInfo select 3;
    private _endPos = _nodeInfo select 4;
    private _endObj = _nodeInfo select 5;
    private _roadDir = _nodeInfo select 6;

    private _gCost = _pos distance2D _start; // Cost from start node
    private _hCost = _pos distance2D _end;   // Heuristic cost to end node
    private _fCost = _gCost + _hCost;      // Total cost
    private _nodeIndex = _obj getVariable ["GPSNodeIndex",-1];

    for "_i" from 0 to 25 do 
    { 
        {
            if ( (typeName _x) isEqualTo "OBJECT" )then {_roadSegment = _x;}; 
        } forEach (_pos nearRoads _i);
        if !(isNull _roadSegment) exitWith {}; 
    };
    _returnMessage = [_pos, _gCost, _hCost, _fCost, _nodeIndex, _roadSegment,_begPos,_begObj,_endPos,_endObj,_roadDir];
    _returnMessage
};
ServerModules_fnc_GPS_findNode = 
{
    params [["_nodeIndex", -1]];
    _returnMessage = [];
    if (isNil "RRP_GPSnodes" || (count RRP_GPSnodes) < 1) exitWith {_returnMessage};
    
    if ( (typeName _nodeIndex) isEqualTo "SCALAR")exitWith 
    {
        if ( _nodeIndex isEqualTo -1) exitWith {_returnMessage};

        {
            if (count _x > 1) then 
            {
                private _nodeID = _x select 4;
                if ( _nodeIndex isEqualTo _nodeID )then {_returnMessage = _x;};
            };
        } forEach RRP_GPSnodes;
        _returnMessage
    };
    if ( (typeName _nodeIndex) isEqualTo "ARRAY")exitWith 
    {
        if ( _nodeIndex isEqualTo [0,0,0] ) exitWith {_returnMessage};
        
        {
            if (count _x > 1) then 
            {
                private _pos = _x select 0;
                if ( _nodeIndex isEqualTo _pos )then {_returnMessage = _x;};
            }
        } forEach RRP_GPSnodes;
        _returnMessage
    };
    _returnMessage
};
ServerModules_fnc_GPS_removeMarkers = 
{
    {
    deleteMarker _x;
    } forEach NavPath;

    {
        deleteMarker _x;
    } forEach CurrentPath;
};
ServerModules_fnc_GPS_AStar = 
{
    /**
    * Description:
    *   Implements the A* pathfinding algorithm to calculate the shortest route between two points using road nodes.
    *   This function is used for GPS navigation in the RetroRP framework.
    *
    * Parameters:
    *   _start: ARRAY - The starting position [x, y, z].
    *   _end: ARRAY - The ending position [x, y, z].
    *   _index: (Optional) NUMBER - The route calculation index, default is -1.
    *
    * Returns:
    *   STRING - A message indicating the result of the route calculation.
    *
    * Usage:
    *   private _result = [_startPos, _endPos, _routeIndex] call ServerModules_fnc_GPS_AStar;
    *
    * Example:
    *   private _msg = [[1234,5678,0], [2345,6789,0], 1] call ServerModules_fnc_GPS_AStar;
    *   hint _msg;
    *
    * Author: Adam Duke
    * (c) Copyright, Adam Duke. All Rights Reserved
    **/

    // Parse parameters: _start and _end are required, _index is optional (default -1)
    params ["_start", "_end", ["_index", -1]];
    private _returnMessage = "";
    private _pos = [];
    private _obj = objNull;
    private _nodeInfo = [];
    private _begPos = [];
    private _begObj = objNull;
    private _endPos = [];
    private _endObj = objNull;
    private _roadDir = -1;

    // Remove any existing navigation markers from previous calculations
    [] call ServerModules_fnc_GPS_removeMarkers;

    // Snap _start and _end to the nearest road positions for accurate routing
    private _start = getPosATL ([_start, 100, RRP_falseRoads] call BIS_fnc_nearestRoad);
    private _end = getPosATL ([_end, 10000, RRP_falseRoads] call BIS_fnc_nearestRoad);
    private _startTime = time;

    // Prepare the list of all road nodes with their costs for A* algorithm
    // Node format: [pos, gcost, hcost, fcost, parent, roadObj]
    //_obj setVariable ["GPSNodeInfo", [_obj,(getPosATL _x),_begPos,_obj1,_endPos,_obj2,(_begPos getDir _endPos)], false];
    _nodes = [];
    {
        private _pos = getPosATL _x;
        _nodeInfo = [_pos,_start,_end] call ServerModules_fnc_GPS_nodeInfo;
        _nodes pushBack _nodeInfo;
    } forEach allRoads;
    if (isNil "RRP_GPSnodes") then {RRP_GPSnodes = _nodes;};
    

    // Initialize the open and closed node lists for A* search
    private _startNode = [_start,_start,_end] call ServerModules_fnc_GPS_nodeInfo;
    private _openNodes = [_startNode]; // Nodes to be evaluated
    private _closedNodes = [];         // Nodes already evaluated

    // Main A* search loop
    while {count _openNodes > 0} do {
        // Exit if the route calculation index has changed (another calculation started)
        if (StartIndex != _index) exitWith {};
        // Timeout after 2 minutes to prevent infinite loops
        if (time - _startTime > 120) exitWith { CalculatingRoute = false; _returnMessage = "A route could not be calculated in less than two minutes!";[] spawn ServerModules_fnc_GPS_removeMarkers; };

        // Find the node in OPEN with the lowest f_cost (best candidate)
        private _currentNode = _nodes # 0;
        {
            _hCost = _x # 2;
            _fCost = _x # 3;
            _currentHCost = _currentNode # 2;
            _currentFCost = _currentNode # 3;
            if (_fCost < _currentFCost || (_fCost isEqualTo _currentFCost && _hCost < _currentHCost)) then {
                _currentNode = _x;
            };
        } forEach _openNodes;

        // Remove current node from OPEN and add to CLOSED
        _openNodes = _openNodes - [_currentNode];
        _closedNodes pushBack _currentNode;

        // If the current node is the target, reconstruct the path and exit
        if ((_currentNode # 0) isEqualTo _end) exitWith { 
            CalculatingRoute = false; 
            private _path = [_nodes, _startNode, _currentNode, _index] call ServerModules_fnc_GPS_RetracePath; 
            {
                _markerName = createMarker ["pathMarker" + str _forEachIndex, _x];
                _markerName setMarkerType "hd_dot";
                _markerName setMarkerColor "ColorRed";
                currentPath pushBack _markerName;
            } forEach (_path select 0);

            _returnMessage = format ["A route has been found! Total Distance: %1m", _path select 1]; 
        };

        // For each neighbor of the current node
        {
            _node = _nodes # _x;

            // Skip if neighbor is already evaluated (in CLOSED)
            if ( !(_node in _closedNodes) && (count _node) > 0 ) then {
                // Calculate new movement cost to neighbor

                _newMovementCostToNeighbor = (_currentNode # 1) + ((_node # 0) distance2D (_currentNode # 0));
                _shorter = _newMovementCostToNeighbor < (_node # 1);

                // If new path is shorter or neighbor is not in OPEN
                if (_shorter || (!(_node in _openNodes))) then {
                    // Update costs and parent for neighbor
                    _node set [1, _newMovementCostToNeighbor];
                    _node set [3, (_node # 1) + (_node # 2)];

                    _obj = (getPosATL (_currentNode # 5)) nearestObject "Sign_Arrow_F";
                    _node set [4, _obj getVariable "GPSNodeIndex"];
                    _nodes set [_x, _node];
                    
                    // Debug: create a marker for this node
                    if (EnableDebug) then {
                        _markerName = createMarker [str _x, _node # 0];
                        _markerName setMarkerType "hd_dot";
                        _markerName setMarkerColor "ColorGreen";
                        _markerName setMarkerText str _x;
                        NavPath pushBack _markerName;
                    };

                    // Add neighbor to OPEN if not already present
                    _openNodes pushBack _node;
                };
            };
        } forEach ([_currentNode] call ServerModules_fnc_GPS_FindNeighbors);
    };
    
    // If no route was found, return a failure message
    if (_returnMessage isEqualTo "") then { _returnMessage = "A route could not be found!"; [] spawn ServerModules_fnc_GPS_removeMarkers;};
    // Return the result message
    _returnMessage
};
ServerModules_fnc_GPS_FindNeighbors = 
{
    /**
    *  Description:
    *      Finds neighboring GPS nodes for a given node by checking connected roads and nearby roads.
    *
    *  Parameters:
    *      _node: ARRAY - The GPS node array. Expects at least 6 elements, where:
    *          _node select 0: Position (ARRAY)
    *          _node select 5: Road object (OBJECT)
    *
    *  Returns:
    *      ARRAY - Array of GPS node indices for neighboring nodes.
    *
    *  Usage:
    *      private _neighbors = [_node] call ServerModules_fnc_GPS_FindNeighbors;
    *
    *  Example:
    *      // Assuming _node is a valid GPS node array
    *      private _neighbors = [_node] call ServerModules_fnc_GPS_FindNeighbors;
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    params ["_node"]; // Extract the input node array
    private _neighbors = []; // Initialize array to store neighboring node indices
    
    
    private _nodePos = _node select 0;
    private _roadSegment = _node select 5;
    private _roadInfo = getRoadInfo _roadSegment;
    private _roadWidth = _roadInfo select 1;
    private _obj = _nodePos nearestObject "Sign_Arrow_F";
    private _nodeInfo = _obj getVariable ["GPSNodeInfo",[]];
    private _radius = _roadWidth;
    
    _obj = _nodeInfo select 0;
    private _pos = _nodeInfo select 1;
    private _begPos = _nodeInfo select 2;
    private _begObj = _nodeInfo select 3;
    private _endPos = _nodeInfo select 4;
    private _endObj = _nodeInfo select 5;
    private _roadDir = _nodeInfo select 6;
    private _roadLength = _begPos distance2D _endPos;

    //if (_roadLength > _radius) then {_radius = _roadLength;};

    if (_roadInfo select 8)then 
    {
        if ( count(nearestObjects [_nodePos, ["Land_RetroRP_Lift_Bridge"], 100]) > 0) then {_radius = 50;}else{_radius = 15;};
    };

    {
        if ( !(_x IN [_begObj,_endObj,_obj]) && _x getVariable ["GPSNodeIndex",-1] > 0 && !( (_x getVariable ["GPSNodeIndex",-1]) IN _neighbors ) )then 
        {
            _neighbors pushBack (_x getVariable ["GPSNodeIndex",-1]);
        };
    } forEach ( (roadsConnectedTo (_node select 5)) + (_endObj nearObjects ["Sign_Arrow_F", _radius]) + (_begObj nearObjects ["Sign_Arrow_F", _radius]) + (_obj nearObjects ["Sign_Arrow_F", _radius]) + (nearestTerrainObjects [_obj, ["ROAD", "MAIN ROAD", "TRACK", "TRAIL"], _radius, true, true]) );
    // Return the array of neighboring node indices
    _neighbors
};
ServerModules_fnc_GPS_FindPath = 
{
    /**
    *  Description:
    *      Finds a path between two points using the A* algorithm for the GPS module.
    *
    *  Parameters:
    *      _start: ARRAY - The starting position [x, y, z].
    *      _end:   ARRAY - The destination position [x, y, z].
    *      _index: NUMBER - The index or identifier for the route calculation.
    *
    *  Returns:
    *      ARRAY - The calculated path as an array of positions, or empty if failed.
    *
    *  Usage:
    *      private _path = [_startPos, _endPos, _routeIndex] call ServerModules_fnc_GPS_FindPath;
    *
    *  Example:
    *      private _start = [1234, 5678, 0];
    *      private _end = [2345, 6789, 0];
    *      private _index = 1;
    *      private _path = [_start, _end, _index] call ServerModules_fnc_GPS_FindPath;
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Extracts the parameters passed to the function: start position, end position, and route index.
    params ["_start", "_end", "_index"];

    // Checks if the GPS system has finished initializing.
    // If not, and debugging is enabled, shows a hint to the user and exits the function.
    if (!GPSInitialized) exitWith {
        if (RPF_Debug) then {
            hint "The GPS is still initializing!";
        };
    };

    // Sets a global variable to indicate that route calculation is in progress.
    CalculatingRoute = true;

    // Calls the A* pathfinding function with the provided parameters and stores the result in _return.
    private _return = [_start, _end, _index] call ServerModules_fnc_GPS_AStar;
    hint _return;

};
ServerModules_fnc_GPS_InitClient = 
{
    /**
    * Description:
    *   Initializes the client-side GPS navigation system. Sets up variables, prepares road nodes, and handles map click events for route calculation.
    *
    * Parameters:
    *   None
    *
    * Returns:
    *   Nothing
    *
    * Usage:
    *   Call this script on client initialization to enable GPS navigation features.
    *
    * Example:
    *   [] execVM "functions/fn_GPS_InitClient.sqf";
    *
    * Author: Adam Duke
    * (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Enable debug mode for GPS system (set to true for debugging, false for production)
    EnableDebug = true;

    // Flag to indicate if a route is currently being calculated
    CalculatingRoute = false;

    // Get all road objects within 100,000 meters of [0,0,0] (effectively all roads on the map)
    

    // Array to store the current calculated path
    CurrentPath = [];

    // Array to store the navigation path
    NavPath = [];

    roadHelpers = [];

    // Index to track the current route calculation
    StartIndex = 0;

    // Flag to enable or disable GPS functionality
    GPSEnabled = false;

    // Flag to indicate if the GPS system has been initialized
    GPSInitialized = false;

    // Spawn a background process to create local arrow sign objects at each road node for visualization/debugging
    [] spawn 
    {
        
        
        if (isNil "RRP_falseRoads") then {RRP_falseRoads = [];};
        if (isNil "allRoads") then {allRoads = [];};
        {
            if (typeName _x isEqualTo "OBJECT")then 
            {
                _roadInfo = getRoadInfo _x;
                if ( (_roadInfo select 0) IN ["","HIDE"] && !(_x IN RRP_falseRoads)) then 
                {
                    RRP_falseRoads pushBack _x;
                }else
                {
                    if (!(_x IN allRoads)) then {allRoads pushBack _x;};
                };
            };
        } forEach (nearestTerrainObjects [[0,0,0], ["ROAD", "MAIN ROAD", "TRACK", "TRAIL"], (worldSize*2), true, true]);

        {
            if (typeName _x isEqualTo "OBJECT")then 
            {
                _roadInfo = getRoadInfo _x;
                if ( (_roadInfo select 0) IN ["","HIDE"] && !(_x IN RRP_falseRoads)) then 
                {
                    RRP_falseRoads pushBack _x;
                }else
                {
                    if (!(_x IN allRoads)) then {allRoads pushBack _x;};
                };
            };
        } forEach ([0,0,0] nearRoads (worldSize*2));
        
        {
            private _roadInfo = getRoadInfo _x;
            _begPos = ASLtoATL(_roadInfo select 6);
            _endPos = ASLtoATL(_roadInfo select 7);
            
           
            private _obj = "Sign_Arrow_F" createVehicleLocal [0,0,0]; // Create a local arrow sign object
            private _obj1 = "Sign_Arrow_F" createVehicleLocal [0,0,0]; // Create a local arrow sign object
            private _obj2 = "Sign_Arrow_F" createVehicleLocal [0,0,0]; // Create a local arrow sign object
            //hideObject _obj; // Hide the object so it's not visible to players
            //hideObject _obj1; // Hide the object so it's not visible to players
            //hideObject _obj2; // Hide the object so it's not visible to players
            
            _obj setPosATL (getPosATL _x); // Set the object's position to the road node's position
            _obj setVectorDirAndUp [[1,0,0], [0,0,1]];
            _obj1 setPosATL _begPos;
            _obj1 setVectorDirAndUp [[1,0,0], [0,0,1]];
            _obj2 setPosATL _endPos;
            _obj2 setVectorDirAndUp [[1,0,0], [0,0,1]];
            
            _obj setVariable ["GPSNodeIndex", _forEachIndex, false]; // Store the node index for reference
            _obj1 setVariable ["GPSNodeIndex", _forEachIndex, false]; // Store the node index for reference
            _obj2 setVariable ["GPSNodeIndex", _forEachIndex, false]; // Store the node index for reference
            _obj setVariable ["GPSNodeInfo", [_obj,(getPosATL _x),_begPos,_obj1,_endPos,_obj2,(_begPos getDir _endPos)], false];

            roadHelpers pushBack _obj;
            roadHelpers pushBack _obj1;
            roadHelpers pushBack _obj2;

            if (isNil "debugPath") then {debugPath = [];};
            if (isNil "RPF_Debug2") then {RPF_Debug2 = false;};
            if (RPF_Debug2) then 
            {
                private _markerName = createMarker [str _forEachIndex, (getPosATL _x)];
                _markerName setMarkerDir (_begPos getDir _endPos);
                _markerName setMarkerType "mil_triangle_noShadow";
                _markerName setMarkerColor "colorBLUFOR";
                _markerName setMarkerText (str _forEachIndex);
                debugPath pushBack _markerName;
            };

        } forEach allRoads;

        // Mark GPS as initialized after all nodes are processed
        GPSInitialized = true;
    };

    // Add a mission event handler for map single-clicks
    // When the map is clicked and GPS is enabled, increment StartIndex and spawn the pathfinding function
    addMissionEventHandler ["MapSingleClick", {
        params ["_units", "_pos", "_alt", "_shift"];
        if (GPSEnabled) then {
            StartIndex = StartIndex + 1;
            [getPosATL player, _pos, StartIndex] spawn ServerModules_fnc_GPS_FindPath;
        };
    }];
};
ServerModules_fnc_GPS_RetracePath = 
{
    /**
    * Description:
    *   Retraces a path from the end node to the start node using a list of nodes, calculates the total distance, and returns the path and distance.
    *
    * Parameters:
    *   _nodes      - ARRAY: List of nodes, each node is expected to be an array with at least 5 elements.
    *   _startNode  - ARRAY: The starting node (format: [position, ...]).
    *   _endNode    - ARRAY: The ending node (format: [position, ...]).
    *   _index      - (Optional) NUMBER: Index to check against StartIndex, default is -1.
    *
    * Returns:
    *   ARRAY: [path (ARRAY of positions), totalDistance (NUMBER)]
    *
    * Usage:
    *   _result = [_nodes, _startNode, _endNode, _index] call ServerModules_fnc_GPS_RetracePath;
    *   _path = _result select 0;
    *   _distance = _result select 1;
    *
    * Example:
    *   _nodes = [[pos1, ..., 0], [pos2, ..., 1], ...];
    *   _startNode = _nodes select 0;
    *   _endNode = _nodes select 5;
    *   _result = [_nodes, _startNode, _endNode] call ServerModules_fnc_GPS_RetracePath;
    *   hint format ["Path: %1\nDistance: %2", _result select 0, _result select 1];
    *
    * Author: Adam Duke
    * (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Parse parameters: nodes array, start node, end node, and optional index (default -1)
    params ["_nodes", "_startNode", "_endNode", ["_index", -1]];

    // Initialize an empty array to store the path
    private _path = [];

    // Set the current node to the end node (we will retrace from end to start)
    private _currentNode = _endNode;

    // Initialize total distance to 0
    private _totalDistance = 0;

    // Find the nearest "Sign_Arrow_F" object to the start node's position
    private _obj = (_startNode # 0) nearestObject "Sign_Arrow_F";

    // Loop to retrace the path from end node to start node
    while {(_currentNode # 4) != (_obj getVariable "GPSNodeIndex")} do {
        // If StartIndex does not match _index, exit the loop (prevents retracing if not matching)
        if (StartIndex != _index) exitWith {};
        // Add the current node's position to the path
        _path pushBack (_currentNode # 0);

        // Move to the previous node in the path using the node's index
        _currentNode = _nodes # (_currentNode # 4);
    };

    // Calculate the total distance along the path
    for "_i" from 0 to (count _path - 1) step 2 do {
        // Error checking: exit if index is out of bounds
        if (_i > ( count _path - 1)) exitWith {};
        if ((_i + 1) > ( count _path - 1)) exitWith {};

        // Get two consecutive positions from the path
        private _pos1 = _path select _i;
        private _pos2 = _path select (_i + 1);

        // Calculate the 2D distance between the two positions
        private _distance = _pos1 distance2D _pos2;

        // Add the distance to the total
        _totalDistance = _totalDistance + _distance;
    };

    // Delete any existing navigation path markers
    {
        deleteMarker _x;
    } forEach NavPath;

    // Clear the NavPath array
    NavPath = [];

    // Reverse the path array so it goes from start to end
    reverse _path;

    // Return the path and the total distance as an array
    [_path, _totalDistance]

    /*
    {
        _markerName = createMarker ["pathMarker" + str _forEachIndex, _x];
        _markerName setMarkerType "hd_dot";
        _markerName setMarkerColor "ColorRed";
        currentPath pushBack _markerName;
    } forEach _path;
    */
};

[] call ServerModules_fnc_GPS_InitClient;
ServerModules_fnc_createTaxi = 
{
    params [ ["_start", [0,0,0]], ["_dir", -1], ["_hiddenMode", false]];
    if ( (_start isEqualTo [0,0,0]) ) exitWith { };
    
    // Spawn car + driver
    private _veh = objNull;
    
    // Handle hidden mode logic
    if (_hiddenMode)then
    {
        // Create the taxi locally and hide it along with the player and driver
        _veh = "RetroRP_Monaco" createVehicleLocal _start;
        [_veh, true] remoteExecCall ['hideObjectGlobal', 2];_veh hideObject false;
        [player, true] remoteExecCall ['hideObjectGlobal', 2];player hideObject false;
        // Ensure the taxi and driver remain visible
        [_veh] spawn 
        {
            params [["_veh",objNull]];
            while { alive _veh } do 
            {
                player hideObject false;
                _veh hideObject false;
                if ( alive (driver _veh) )then { (driver _veh) hideObject false;}else {deleteVehicle (driver _veh)};
                waitUntil {! (isObjectHidden player)};
            };
        };
    }else
    {
        // Create the taxi normally
        _veh = createVehicle ["RetroRP_Monaco",_start, [], 0, "CAN_COLLIDE"];
    };
    if (_dir > -1) then {_veh setDir _dir;};
    _veh allowdamage false;
    private _drv = [_veh] call ServerModules_fnc_createTaxiDriver;

    // Configure the taxi
    _veh allowdamage false;
    [_veh, "", []] call bis_fnc_initVehicle;
    _veh Lock 0;
    _veh setVariable ['HoodLock',false,true];
    [_veh,false] call ServerModules_fnc_lockInventory;
    _veh setFuel 0.25;

    // Customize the taxi with specific components and textures
    [_veh, "Taxi",["Stock_Bonnet",1,"Stock_Front_Bumper",1,"Stock_Rear_Bumper",1,"Stock_Exhaust",1,"Police",0,"Push_Bar",0,"Spotlight",0,"Radio",0,"PoliceComputer",0,"HandSpotlight",0,"Radar",0,"RoadCone",0,"RoadFlares",0,"Shotgun",0,"Lightbar_BEACON_17",0,"Lightbar_Can",0,"Lightbar_Can_Amber",0,"Lightbar_Can_Red",0,"Lightbar_CJ_184",0,"Lightbar_mars_skybolt",0,"Lightbar_twin_sonic_chp",0,"Lightbar_Fireball",0,"Lightbar_Aerodynic",0,"TaxiMeter",1,"Mods",0,"Stock_Side_Skirt",0,"Stock_Spoiler",0,"Roll_Cage",0]] call ServerModules_fnc_customize_Vehicles;
    _veh setObjectTextureGlobal [0, "RetroRP\RetroRP_Textures_Vehicle\Dodge_Monaco\MonacoTaxiNoStripes.paa"];
    _veh animateSource ["Head_Lights", 3000,true];
    [_veh,['Headlight_Left','Headlight_Right','Dashlights'],0] call ServerModules_fnc_ToggleLight;

    // Enable steering system 
    if ( (!(isUsingAISteeringComponent)) && isAISteeringComponentEnabled _veh ) then {useAISteeringComponent true;};
    _veh forceFollowRoad true;

    player moveInCargo _veh;
};
ServerModules_fnc_createTaxiDriver = 
{
    params [ ["_veh", objNull] ];
    if ( (isNull _veh) ) exitWith { };
    
    // Spawn driver
    private _grp = createGroup civilian; 
    private _drv = _grp createUnit ["C_man_1", [0,0,0], [], 0, "NONE"]; 
    //private _drv = createAgent ["C_man_1", [0,0,0], [], 0, "NONE"];
    // Handle hidden mode logic
    
    if (_veh getVariable ["RRP_taxiHidden", false])then
    {
        // Create the taxi locally and hide it along with the player and driver
        [_drv, true] remoteExecCall ['hideObjectGlobal', 2];_drv hideObject false;
    };
    
    _drv allowdamage false;
    // Configure the taxi
    _drv moveInDriver _veh;
    _drv action ['lightOn', _veh];
    
    // Disable unnecessary AI features for the driver
    _drv disableAI "TARGET";
    _drv disableAI "SUPPRESSION";
    _drv disableAI "TEAMSWITCH";
    _drv disableAI "AUTOTARGET";
    _drv disableAI "MINEDETECTION";
    _drv disableAI "ANIM";
    _drv disableAI "AIMINGERROR";
    _drv disableAI "WEAPONAIM";
    _drv disableAI "COVER";
    _drv disableAI "AUTOCOMBAT";
    _drv disableAI "CHECKVISIBLE";
    _drv allowFleeing 0;
    _drv setBehaviourStrong "CARELESS";
    _drv setCombatBehaviour "CARELESS";

    // Set driver skills to maximum
    _drv setSkill ["spotDistance",1];
    _drv setSkill ["aimingSpeed",1];
    _drv setSkill ["reloadSpeed",1];
    _drv setSkill ["aimingAccuracy",1];
    _drv setSkill ["commanding",1];
    _drv setSkill ["courage",1];
    _drv setSkill ["spotTime",1];
    _drv setSkill ["general",1];
    _drv setSkill ["aimingShake",1];
    _veh forceFollowRoad true;
    _drv
};
ServerModules_fnc_createTaxiRoute = 
{
    params [ ["_dest", [0,0,0]], ["_veh", vehicle player] ];
    if ( _dest isEqualTo [0,0,0] ) exitWith { };
    
    if (isNull _veh || _veh isKindOf "Man") exitWith { };

    
    _drv = driver _veh;
    doStop _drv;
    waitUntil {speed _veh < 1};

    if (_veh getVariable ["RRP_taxiOnRoute", false])then { deleteVehicle (driver _veh); waitUntil { !alive (driver _veh) };};
    private _drv = [_veh] call ServerModules_fnc_createTaxiDriver;
    
    if (isNull _drv) exitWith { };
    
    private _start = getPosATL _veh;
    
    waitUntil {GPSInitialized};
    StartIndex = StartIndex + 1;
    [_start, _dest, StartIndex] spawn ServerModules_fnc_GPS_FindPath;
    //_veh setPhysicsCollisionFlag false;

    waitUntil {(count CurrentPath) > 0};
    _route = [];
    {
        _point = getMarkerPos _x;
        if ( (count nearestLocations [_point, ["NameCity","NameCityCapital","NameVillage","Airport"], 500]) > 0 ) then {_point set [3, 13.8];}else{_point set [3, 16.6];};
        _route pushBack _point;
    } forEach CurrentPath;

    // Now use setDriveOnPath with both points 
    _veh setDriveOnPath _route;
    
    _drv setVariable ["RRP_taxiRoute", _route, true];
    _drv setVariable ["RRP_taxiOnRoute", true, true];

    _veh setVariable ["RRP_taxiRoute", _route, true];
    _veh setVariable ["RRP_taxiOnRoute", true, true];
    _veh setVariable ["RRP_taxiHidden", true, true];
};

ServerModules_fnc_TaxiDrive = 
{
    params [ ["_start", [0,0,0]], ["_dest", [0,0,0]] , ["_dir", -1] , ["_hiddenMode", false]];
    if ( (_start isEqualTo [0,0,0]) || (_dest isEqualTo [0,0,0]) ) exitWith { hint "Invalid start or destination position!"; };
    
    private _veh = objNull; 
    private _grp = createGroup civilian; 
    private _drv = _grp createUnit ["C_man_1", _start, [], 0, "NONE"]; 
    //private _drv = createAgent ["C_man_1", _start, [], 0, "NONE"];
    // Handle hidden mode logic
    if (_hiddenMode)then
    {
        // Create the taxi locally and hide it along with the player and driver
        _veh = "RetroRP_Monaco" createVehicleLocal _start;
        [_veh, true] remoteExecCall ['hideObjectGlobal', 2];_veh hideObject false;
        [player, true] remoteExecCall ['hideObjectGlobal', 2];player hideObject false;
        [_drv, true] remoteExecCall ['hideObjectGlobal', 2];_drv hideObject false;
        // Ensure the taxi and driver remain visible
        [_veh,_drv] spawn 
        {
            params [["_veh",objNull],["_drv",objNull]];
            while {alive _veh && alive _drv} do 
            {
                player hideObject false;
                _drv hideObject false;
                _veh hideObject false;
                sleep 10;
            };
        };
    }else
    {
        // Create the taxi normally
        _veh = createVehicle ["RetroRP_Monaco",_start, [], 0, "CAN_COLLIDE"];
    };
    if (_dir > -1) then {_veh setDir _dir;};
    _drv allowdamage false;
    _veh allowdamage false;

    // Configure the taxi
    _veh allowdamage false;
    _drv moveInDriver _veh;
    _drv action ['lightOn', _veh]; 
    [_veh, "", []] call bis_fnc_initVehicle;
    _veh Lock 0;
    _veh setVariable ['HoodLock',false,true];
    [_veh,false] call ServerModules_fnc_lockInventory;
    _veh setFuel 0.25;

    // Customize the taxi with specific components and textures
    [_veh, "Taxi",["Stock_Bonnet",1,"Stock_Front_Bumper",1,"Stock_Rear_Bumper",1,"Stock_Exhaust",1,"Police",0,"Push_Bar",0,"Spotlight",0,"Radio",0,"PoliceComputer",0,"HandSpotlight",0,"Radar",0,"RoadCone",0,"RoadFlares",0,"Shotgun",0,"Lightbar_BEACON_17",0,"Lightbar_Can",0,"Lightbar_Can_Amber",0,"Lightbar_Can_Red",0,"Lightbar_CJ_184",0,"Lightbar_mars_skybolt",0,"Lightbar_twin_sonic_chp",0,"Lightbar_Fireball",0,"Lightbar_Aerodynic",0,"TaxiMeter",1,"Mods",0,"Stock_Side_Skirt",0,"Stock_Spoiler",0,"Roll_Cage",0]] call ServerModules_fnc_customize_Vehicles;
    _veh setObjectTextureGlobal [0, "RetroRP\RetroRP_Textures_Vehicle\Dodge_Monaco\MonacoTaxiNoStripes.paa"];
    _veh animateSource ["Head_Lights", 3000,true];
    [_veh,['Headlight_Left','Headlight_Right','Dashlights'],0] call ServerModules_fnc_ToggleLight;
    _veh setPhysicsCollisionFlag false;

    // Enable steering system 
    if ( (!(isUsingAISteeringComponent)) && isAISteeringComponentEnabled _veh ) then {useAISteeringComponent true;};
    
    // Disable unnecessary AI features for the driver
    
    _drv disableAI "TARGET";
    _drv disableAI "SUPPRESSION";
    _drv disableAI "TEAMSWITCH";
    _drv disableAI "AUTOTARGET";
    _drv disableAI "MINEDETECTION";
    _drv disableAI "ANIM";
    _drv disableAI "AIMINGERROR";
    _drv disableAI "WEAPONAIM";
    _drv disableAI "COVER";
    _drv disableAI "AUTOCOMBAT";
    _drv disableAI "CHECKVISIBLE";
    _drv allowFleeing 0;
    _grp setCombatBehaviour "CARELESS";
    _grp setBehaviourStrong "CARELESS";
    _grp setSpeedMode "LIMITED";

    // Set driver skills to maximum
    _drv setSkill ["spotDistance",1];
    _drv setSkill ["aimingSpeed",1];
    _drv setSkill ["reloadSpeed",1];
    _drv setSkill ["aimingAccuracy",1];
    _drv setSkill ["commanding",1];
    _drv setSkill ["courage",1];
    _drv setSkill ["spotTime",1];
    _drv setSkill ["general",1];
    _drv setSkill ["aimingShake",1];
    
    _veh forceFollowRoad true;
    
    //if ( (count nearestLocations [_point, ["NameCity","NameCityCapital","NameVillage","Airport"], 500]) > 0 ) then {_point set [3, 13.8];}else{_point set [3, 27.7];};

    //player moveInCargo _veh;
    // Now use setDriveOnPath with both points 
    _newDest = getPosATL ([_dest, 500,RRP_falseRoads] call BIS_fnc_nearestRoad);
    hint format ["newDest: %1", _newDest];
    _drv doMove _newDest;
};



[[9933.85,9951.83,0],90] call ServerModules_fnc_createTaxi;
sleep 1;
//GPSEnabled = true;

addMissionEventHandler ["MapSingleClick", 
{
    params ["_units", "_pos", "_alt", "_shift"];
    [_pos] spawn ServerModules_fnc_createTaxiRoute;
}];