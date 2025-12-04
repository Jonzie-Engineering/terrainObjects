ServerModules_fnc_lockInventory = {};
ServerModules_fnc_customize_Vehicles = {};
ServerModules_fnc_ToggleLight = {};

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
    private _currentNodeCount = 0;
    private _lastNodeCount = 0;

    // Main A* search loop
    while {count _openNodes > 0} do {
        // Exit if the route calculation index has changed (another calculation started)
        if (StartIndex != _index) exitWith {_returnMessage = "";};
        // Timeout after 2 minutes to prevent infinite loops
        //if (time - _startTime > 600) exitWith { CalculatingRoute = false; _returnMessage = "A route could not be calculated in less than ten minutes!";[] spawn ServerModules_fnc_GPS_removeMarkers; };

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
        _lastNodeCount = count _closedNodes;
        _closedNodes pushBackUnique _currentNode;
        if ( (count _closedNodes) > _lastNodeCount )then { _currentNodeCount = count _closedNodes; };

        // If the current node is the target, reconstruct the path and exit
        if ((_currentNode # 0) isEqualTo _end) exitWith { 
            CalculatingRoute = false; 
            private _path = [_nodes, _startNode, _currentNode, _index] call ServerModules_fnc_GPS_RetracePath; 
            {
                _markerName = createMarker ["pathMarker" + str _forEachIndex, _x];
                _markerName setMarkerType "hd_dot";
                _markerName setMarkerColor "ColorRed";
                currentPath pushBack _markerName;
                GPSPathPos pushBack _x;
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
                    if (RPF_Debug) then {
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
        if (_currentNodeCount == _lastNodeCount)exitwith {CalculatingRoute = false;[] spawn ServerModules_fnc_GPS_removeMarkers;_returnMessage = "A route could not be found!"; };
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
    if (typeName _obj isEqualTo "ARRAY")then {_obj = _nodeInfo select 0;};
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
        _radius = 15;
        //if ( count(nearestObjects [_nodePos, ["Land_RetroRP_Lift_Bridge"], 100]) > 0) then {_radius = 50;}else{_radius = 15;};//_radius = 50;
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
    if (isNil "GPSInitialized") then {GPSInitialized = false;};

    if (!GPSInitialized) exitWith {
        if (RPF_Debug) then {
            hint "The GPS is still initializing!";
        };
    };

    // Sets a global variable to indicate that route calculation is in progress.
    CalculatingRoute = true;

    // Calls the A* pathfinding function with the provided parameters and stores the result in _return.
    private _return = [_start, _end, _index] call ServerModules_fnc_GPS_AStar;
    _return
};
ServerModules_fnc_GPS_Init = 
{
    [[	
        "GPS_RetracePath",
        "GPS_FindNeighbors",
        "GPS_AStar",
        "GPS_InitClient",
        "GPS_FindPath",
        "GPS_removeMarkers",
        "GPS_findNode",
        "GPS_nodeInfo"
    ]] call Server_fnc_addPublicFunction;

    {
        _x hideObjectGlobal true;
    } forEach nearestTerrainObjects [[13307.4,8848.32,0], ["ROAD"], 15, true, true];

    diag_log "# [RRP] GPS: Module Initalized #";
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
    EnableDebug = false;

    // Flag to indicate if a route is currently being calculated
    CalculatingRoute = false;

    // Get all road objects within 100,000 meters of [0,0,0] (effectively all roads on the map)


    // Array to store the current calculated path
    CurrentPath = [];
    GPSPathPos = [];

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
            
            _obj setObjectTexture [0, "#(rgb,8,8,3)color(1,0,0,0)"];
            _obj1 setObjectTexture [0, "#(rgb,8,8,3)color(1,0,0,0)"];
            _obj2 setObjectTexture [0, "#(rgb,8,8,3)color(1,0,0,0)"];
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
            if (isNil "RPP_GPSDebug") then {RPP_GPSDebug = false;};
            if (RPP_GPSDebug) then 
            {
                private _markerName = createMarker [str _forEachIndex, (getPosATL _x)];
                _markerName setMarkerDir (_begPos getDir _endPos);
                _markerName setMarkerType "mil_triangle_noShadow";
                _markerName setMarkerColor "colorBLUFOR";
                _markerName setMarkerText (str _forEachIndex);
                debugPath pushBack _markerName;
            };

        } forEach allRoads;
        
        {
            hideObject _x;
        } forEach nearestTerrainObjects [[13307.4,8848.32,0], ["ROAD"], 15, true, true];

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
ServerModules_fnc_GPS_nodeInfo = 
{
    params [["_pos", [0,0,0]],["_start", [0,0,0]],["_end", [0,0,0]]];
    _returnMessage = [];

    if ( (_pos isEqualTo [0,0,0]) ) exitWith {_returnMessage};

    private _roadSegment = objNull;
    private _obj = _pos nearestObject "Sign_Arrow_F";

    private _nodeInfo = _obj getVariable ["GPSNodeInfo",[]];
    if ((count _nodeInfo) < 1) exitWith {_returnMessage};

    if (typeName _obj isEqualTo "ARRAY")then {_obj = _nodeInfo select 0;};
    if (typeName _pos isEqualTo "OBJECT")then {_pos = _nodeInfo select 1;};
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
ServerModules_fnc_GPS_removeMarkers = 
{
    params [["_reverse", false]];
    GPSPathPos = [];
    if (_reverse)then {_NavPath = reverse NavPath;_CurrentPath = reverse CurrentPath;}else{_NavPath = NavPath;_CurrentPath =  CurrentPath;};
    if ( ( (count CurrentPath)+(count NavPath) ) > 1000 && ! _reverse ) then {[true] call ServerModules_fnc_GPS_removeMarkers;};
    {
        deleteMarker _x;
        NavPath = NavPath - [_x];
    } forEach NavPath;
    {
        deleteMarker _x;
        CurrentPath = CurrentPath - [_x];
    } forEach CurrentPath;
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
//RPP_GPSDebug = true;
[] call ServerModules_fnc_GPS_Init;
[] call ServerModules_fnc_GPS_InitClient;

ServerModules_fnc_closeTaxiFare = 
{
    /*
        File: fn_closeTaxiFare.sqf

        Description:
            Closes the taxi fare payment dialog and notifies the client that the fare has been paid.

        Parameters:
            None

        Returns:
            Nothing

        Usage:
            call ServerModules_fnc_closeTaxiFare;

        Example:
            // To close the taxi fare dialog after payment
            call ServerModules_fnc_closeTaxiFare;

        Author: Adam Duke

        (c) Copyright, Adam Duke. All Rights Reserved.
    */

    // Retrieve the display object for the taxi fare payment dialog from the UI namespace.
    // If the dialog does not exist, displayNull is returned.
    private _display = uiNamespace getVariable ['RRP_PayTaxiFare', displayNull];

    // Close the taxi fare payment dialog with exit code 1.
    // This ensures the UI is properly closed after payment.
    _display closeDisplay 1;
    closeDialog 0;

    // Notify the client that the patron has paid for the taxi fare.
    // The notification is sent in green to indicate success.
    [[0], "A patron has paid for the taxi fare.", "Green"] call ClientModules_fnc_Notify;
};
ServerModules_fnc_drawTaxi = 
{
    /**
    *  Description:
    *      Draws taxi request icons on the map for all current taxi clients.
    *
    *  Parameters:
    *      _control: Control - The map control on which to draw the icons.
    *
    *  Returns:
    *      Nothing
    *
    *  Usage:
    *      [_control] call ServerModules_fnc_drawTaxi;
    *
    *  Example:
    *      // In a display event handler:
    *      _display displayAddEventHandler ["Draw", { [_this select 0] call ServerModules_fnc_drawTaxi }];
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Extract the map control parameter from the arguments array.
    params ["_control"];

    // Get the player's current job. If the player is not a taxi, exit the function.
    // This ensures only taxi drivers see the taxi request icons.
    private _job = player getVariable ["RRP_Job", "none"];
    if !(_job isEqualTo "taxi") exitWith {};

    // For each client in the RRP_TaxiClients array, draw a taxi request icon on the map.
    // The icon is drawn at the client's position with a label "Taxi Request".
    // The icon used is the default task icon from Arma 3.

    { _control drawIcon ["\a3\ui_f\data\Map\MapControl\taskIconCreated_ca.paa", [1,1,1,1], getPos _x, 32, 32, 0, "Taxi Request", 2]; } forEach RRP_TaxiClients;
};
ServerModules_fnc_endTaxi = 
{
    /**
    * Description:
    *   Ends a taxi ride, calculates the fare, checks if patrons are present, and handles payment or notification.
    *
    * Parameters:
    *   0: OBJECT - The taxi vehicle object.
    *   1: NUMBER - Total time of the ride in seconds.
    *   2: NUMBER - Total distance of the ride in meters.
    *   3: ARRAY  - Array of patrons (players) who were in the taxi at the start.
    *
    * Returns:
    *   Nothing.
    *
    * Usage:
    *   [_taxi, _totalTime, _totalDistance, _patrons] call ServerModules_fnc_endTaxi;
    *
    * Example:
    *   [vehicle player, 600, 3500, [player1, player2]] call ServerModules_fnc_endTaxi;
    *
    * Author: Adam Duke
    * (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Parse parameters with default values for safety
    params [["_taxi", objNull], ["_totalTime", 0], ["_totalDistance", 0], ["_patrons", []]];

    // Retrieve taxi fare rates from the taxi object (with defaults if not set)
    private _rateKM = _taxi getVariable ["RRP_TaxiRateKM", 1];    // Rate per kilometer
    private _rateHR = _taxi getVariable ["RRP_TaxiRateHR", 10];   // Rate per hour
    private _rateBase = _taxi getVariable ["RRP_TaxiBase", 20];    // Base fare
    private _isAiTaxi = !(isPlayer (driver _taxi));

    // Calculate the total price for the ride
    // - (_totalDistance / 1000) converts meters to kilometers
    // - (_totalTime / 3600) converts seconds to hours
    //private _totalPrice = round ((_rateKM * (_totalDistance / 1000)) + (_rateHR * (_totalTime / 3600)) + _rateBase);
    private _totalPrice = round(_taxi getVariable ["RRP_TaxiFare", -1]);
    // If there are no patrons (less than 2 in the array), notify the driver and exit
    if !(count _patrons > 1) exitWith {
        if !(_isAiTaxi)then {[[0], "Error! There are no patrons!", "Red"] call ClientModules_fnc_Notify;};
    };

    if (_totalPrice < 1) exitWith {
        if !(_isAiTaxi)then {[[0], "No fare found", "Red"] call ClientModules_fnc_Notify;};
    };

    // Check if any of the original patrons are still in the taxi
    // This is to ensure payment is only processed if patrons are present
    private _currentCrew = fullCrew _taxi; // Get all current crew in the taxi
    private _originalInCurrent = [];       // Array to store patrons still present

    {
        private _current = _x select 0; // Get the unit from the current crew member
        {
            private _old = _x select 0; // Get the unit from the original patrons
            // If the original patron is still in the taxi and is not the driver (player), add to the list
            if (_old isEqualTo _current && !(_old isEqualTo player) && !(_current isEqualTo player)) then {
                _originalInCurrent pushBack _current;
            };
        } forEach _patrons;
    } forEach _currentCrew;

    // Store current taxi info for reference elsewhere
    RRP_CurrentTaxiInfo = [_taxi, _totalTime, _totalDistance, _patrons, _totalPrice];

    // If any original patrons are still in the taxi, process payment
    if ((count _originalInCurrent) > 0) then {
        {
            private _player = _x select 0;
            // For each patron (excluding the driver), send a remote call to process the fare payment
            if (_player isNotEqualTo (driver _taxi)) then {
                if (local _player) then {
                    [_taxi, _totalPrice, player] call ServerModules_fnc_receiveTaxiFare;
                }else{[_taxi, _totalPrice, player] remoteExecCall ["ServerModules_fnc_receiveTaxiFare", _player];};
            };
        } forEach _patrons;
    } else {
        // If no patrons are present, show a dialog indicating the fare was not paid
        createDialog "RRP_TaxiFareNotPaid";
        ctrlShow [1601, false];
    };
};
ServerModules_fnc_initTaxi = 
{
    /**
        * Author:    Adam Duke
        * 
        * (c) Copyright, Adam Duke. All Rights Reserved
    **/

    findDisplay 12 displayCtrl 51 ctrlAddEventHandler ["Draw", { _this call ServerModules_fnc_drawTaxi; }];
};
ServerModules_fnc_payTaxiFare = 
{
    /**
    *  Description:
    *      Handles the payment or refusal of a taxi fare by the player. 
    *      Checks if the player has enough cash, processes payment, notifies the player, 
    *      and informs the taxi driver of the decision.
    *
    *  Parameters:
    *      0: BOOLEAN - true if the player chooses to pay, false if refusing.
    *
    *  Returns:
    *      Nothing
    *
    *  Usage:
    *      [_pay] spawn ServerModules_fnc_payTaxiFare;
    *
    *  Example:
    *      [true] spawn ServerModules_fnc_payTaxiFare; // Player chooses to pay the fare
    *      [false] spawn ServerModules_fnc_payTaxiFare; // Player refuses to pay the fare
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Get the parameter, defaulting to false if not provided
    params [["_pay", false]];

    // Exit if there is no current taxi fare to pay for
    if (isNil "RRP_CurrentTaxi") exitWith {};

    // Exit if someone has already paid for the taxi fare
    if (!(isNil "RRP_Taxi_SomeonePaidForItAlready") && {RRP_Taxi_SomeonePaidForItAlready}) exitWith {};

    // Extract the fare amount, driver, and taxi vehicle from the current taxi data
    private _amount = RRP_CurrentTaxi select 0;
    private _driver = RRP_CurrentTaxi select 1;
    private _taxi = RRP_CurrentTaxi select 2;
    private _isAiTaxi = !(isPlayer (driver _taxi));

    // Default action is "refuse"
    private _action = "refuse";

    if (_pay) then {
        // If the player chooses to pay, check if they have enough cash
        private _check = [1, _amount] call Client_fnc_checkMoney;

        if (_check) then {
            // Player has enough cash, process payment
            _action = "paid";
            [_amount] call Client_fnc_removeCash; // Remove the cash from the player
            [[0], "You paid for the taxi fare!", "Green"] call ClientModules_fnc_Notify; // Notify player of successful payment
        } else {
            // Player does not have enough cash
            _action = "nocash";
            [[0], "You do not have enough cash for the taxi fare!", "Red"] call ClientModules_fnc_Notify; // Notify player of insufficient funds
        };
    } else {
        // Player refused to pay
        [[0], "You've refused to pay for the taxi fare!", "Red"] call ClientModules_fnc_Notify; // Notify player of refusal
    };

    // Close the payment dialog
    closeDialog 0;

    if (_isAiTaxi) then 
    {
        if (_pay) then {RRP_NPCPanel_TaxiEnd spawn ServerModules_fnc_createNPCDialog;};
    };

    // Inform the taxi driver of the player's decision via remote execution
    if (local _driver) then 
    {
        [player, _action, _amount, _taxi]call ServerModules_fnc_receiveTaxiDecision;
    }else{
        [player, _action, _amount, _taxi] remoteExecCall ["ServerModules_fnc_receiveTaxiDecision", _driver];
    };
};
ServerModules_fnc_receiveTaxiDecision = 
{
    /**
    *  Description:
    *      Handles the decision received from a taxi patron regarding fare payment.
    *      Updates the global taxi decisions array, processes payment, notifies the driver,
    *      closes dialogs for all patrons, and resets the taxi state as needed.
    *
    *  Parameters:
    *      _patron (Object)   : The player object representing the patron making the decision.
    *      _status (String)   : The decision status, e.g., "paid".
    *      _fare (Number)     : The fare amount to be paid.
    *      _taxi (Object)     : The taxi vehicle object.
    *
    *  Returns:
    *      Nothing
    *
    *  Usage:
    *      [_patron, _status, _fare, _taxi] call ServerModules_fnc_receiveTaxiDecision;
    *
    *  Example:
    *      [player, "paid", 500, myTaxiVehicle] call ServerModules_fnc_receiveTaxiDecision;
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Parse parameters with default values for safety
    params [["_patron", objNull], ["_status", ""], ["_fare", 0], ["_taxi", objNull]];

    // Exit if either the taxi or patron object is null (invalid input)
    if (isNull _taxi || isNull _patron) exitWith {};

    private _isAiTaxi = !(isPlayer (driver _taxi));

    // Initialize the global array for taxi decisions if it doesn't exist
    if (isNil "RRP_TaxiDecisions") then {RRP_TaxiDecisions = [];};

    // Add the current patron's decision to the global decisions array
    RRP_TaxiDecisions pushBack [_patron, _status];

    // Retrieve the list of patrons currently in the taxi
    private _patrons = _taxi getVariable ["RRP_TaxiPatrons", []];

    // If the status is "paid", process the payment and notify all relevant parties
    if (_status isEqualTo "paid") then {
        // Give the driver the fare amount
        if !(_isAiTaxi) then 
        {
            [_fare] call Client_fnc_addCash;
            // Notify the driver of successful payment
            [[0], format ["Success! You've receieved $%1 for taxi fare.", _fare], "Green"] call ClientModules_fnc_Notify;
        }else{RRP_NPCPanel_TaxiEnd spawn ServerModules_fnc_createNPCDialog;};

        // For each patron except the player, remotely close the taxi fare dialog
        { 
            if ( (_x select 0) isNotEqualTo (driver _taxi) ) then { 
                [] remoteExecCall ["ServerModules_fnc_closeTaxiFare", _x select 0];
            }; 
        } forEach _patrons;

        // Reset the global taxi decisions array
        RRP_TaxiDecisions = nil;

        // Reset the taxi state to "Vacant"
        [_taxi, "Vacant"] call ServerModules_fnc_Taxi;
    };

    // If all but one patron have made a decision and none have paid, show the "fare not paid" dialog
    if ((count RRP_TaxiDecisions) isEqualTo ((count _patrons) - 1) && !("paid" in RRP_TaxiDecisions)) then { 
        if !(_isAiTaxi) then {createDialog "RRP_TaxiFareNotPaid"; }else{[(driver _taxi), RRP_CurrentTaxiInfo select 0, RRP_CurrentTaxiInfo select 3, RRP_CurrentTaxiInfo select 4] call ServerModules_fnc_taxiReport;};
    };
};
ServerModules_fnc_receiveTaxiFare = 
{
    /**
    *  Description:
    *      Opens the taxi fare payment dialog for the player, sets the fare amount, and stores relevant taxi information.
    *
    *  Parameters:
    *      _taxi   (Object)    - The taxi vehicle object.
    *      _fare   (Number)    - The fare amount to be paid.
    *      _driver (Object)    - The driver of the taxi.
    *
    *  Returns:
    *      Nothing
    *
    *  Usage:
    *      [_taxi, _fare, _driver] call ServerModules_fnc_receiveTaxiFare;
    *
    *  Example:
    *      [vehicle player, 150, player] call ServerModules_fnc_receiveTaxiFare;
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Parse parameters with default values: taxi object, fare amount, driver object
    params [["_taxi", objNull], ["_fare", 0], ["_driver", objNull]];

    // Reset the flag indicating if someone has already paid for the taxi
    RRP_Taxi_SomeonePaidForItAlready = nil;

    // Open the taxi fare payment dialog for the player
    createDialog "RRP_PayTaxiFare";

    // Get the display object for the taxi fare dialog from the UI namespace
    private _display = uiNamespace getVariable ['RRP_PayTaxiFare', displayNull];

    // Get the control (likely an edit or text field) for displaying the fare amount
    private _amount = _display displayCtrl 1001;

    // Set the fare amount in the dialog, formatted as currency
    _amount ctrlSetText (format ["$%1", _fare]);

    // Store the current taxi fare, driver, and taxi object for later reference
    RRP_CurrentTaxi = [_fare, _driver, _taxi];
};
ServerModules_fnc_requestTaxi = 
{
    /*
        File: fn_requestTaxi.sqf

        Description:
            Toggles the player's presence in the global taxi client list (RRP_TaxiClients).
            If the player is already in the list, they are removed; otherwise, they are added.
            The updated list is then broadcasted to all clients.

        Parameters:
            None

        Returns:
            None

        Usage:
            Call this function when a player requests or cancels a taxi.
            Example:
                [] call ServerModules_fnc_requestTaxi;

        Example:
            // Player requests a taxi
            [] call ServerModules_fnc_requestTaxi;

        Author: Adam Duke

        (c) Copyright, Adam Duke. All Rights Reserved.
    */

    // Check if the player is already in the taxi clients array
    private _inArray = player in RRP_TaxiClients;

    // If the player is in the array, remove them (cancel request)
    // Otherwise, add them to the array (request taxi)
    if (_inArray) then {
        RRP_TaxiClients = RRP_TaxiClients - [player]; // Remove player from list
    } else {
        RRP_TaxiClients pushBack player; // Add player to list
    };

    // Broadcast the updated taxi clients array to all clients
    publicVariable "RRP_TaxiClients";
};
ServerModules_fnc_taxiReport = 
{
    /**
    *  Description:
    *      Issues warrants for all patrons who ran from a taxi without paying the fare, notifies them, and resets the taxi status.
    *
    *  Parameters:
    *      _driver   (Object)   - The taxi driver object.
    *      _taxi     (Object)   - The taxi vehicle object.
    *      _patrons  (Array)    - Array of patrons (each element is an array, first element is the player object).
    *      _fare     (Number)   - The fare amount that was not paid.
    *
    *  Returns:
    *      Nothing
    *
    *  Usage:
    *      [_driver, _taxi, _patrons, _fare] call ServerModules_fnc_taxiReport;
    *
    *  Example:
    *      private _driver = player;
    *      private _taxi = vehicle player;
    *      private _patrons = [[player2], [player3]];
    *      private _fare = 500;
    *      [_driver, _taxi, _patrons, _fare] call ServerModules_fnc_taxiReport;
    *
    *  Author: Adam Duke
    *  (c) Copyright, Adam Duke. All Rights Reserved.
    **/

    // Parse parameters with default values for safety
    params [["_driver", objNull], ["_taxi", objNull], ["_patrons", []], ["_fare", 0]];
    private _isAiTaxi = !(isPlayer (driver _taxi));
    _driver = (driver _taxi);

    // For each patron who ran from the taxi without paying
    {
        private _player = _x select 0; // Get the player object from the patron array

        private _driverUID = getPlayerUID _driver;
        if (!(isPlayer (driver _taxi))) then {_driverUID = -1;};
        // Issue a warrant for the patron for not paying the fare
        [_player, 4, format ["Ran from taxi driver %1 without paying for the $%2 fare.", getPlayerUID _driver, _fare], objNull, false] call ServerModules_fnc_addWarrant;

        // Notify the patron that a warrant has been placed for their arrest
        [[0], "A warrant has been placed for your arrest for not paying your taxi fare!", "Red"] remoteExec ["ClientModules_fnc_Notify", _player];
        if (_isAiTaxi && isPlayer _player)then {moveOut _player;};
    } forEach _patrons;

    // Reset the taxi's status to "Vacant" so it can be used again
    [_taxi, "Vacant"] call ServerModules_fnc_Taxi;

    // Notify the driver (or all clients) that all patrons have had warrants issued
    if !(_isAiTaxi)then {[[0], "Success! All patrons have had a warrant issued for their arrest!", "Green"] call ClientModules_fnc_Notify;};
};
[] call ServerModules_fnc_initTaxi;

ServerModules_fnc_createTaxi = 
{
    params [ ["_start", [0,0,0]], ["_dir", 0], ["_hiddenMode", false]];
    if ( (_start isEqualTo [0,0,0]) ) exitWith { };

    // Spawn car + driver
    private _veh = objNull;
    ["RetroRP_Monaco",_start,_dir,false] call ClientModules_fnc_createVehicle;
    waitUntil { (player getVariable ["RRP_createVehicle",""]) isNotEqualTo "" && typeName(player getVariable ["RRP_createVehicle",""]) isEqualTo "OBJECT" && (player getVariable ["RRP_createVehicle",""]) isKindOf "RetroRP_Monaco"};
    _veh = player getVariable ["RRP_createVehicle",""];

    /*/ Handle hidden mode logic
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
        ["RetroRP_Monaco",_start,_dir,false] call ClientModules_fnc_createVehicle;
        waitUntil {player getVariable ["RRP_createVehicle",""] isNotEqualTo "" && typeName(player getVariable ["RRP_createVehicle",""]) isEqualTo "OBJECT" && player getVariable ["RRP_createVehicle",""] isKindOf "RetroRP_Monaco"};
        _veh = player getVariable ["RRP_createVehicle",""];
    };
    */
    sleep 1;
    // Configure the taxi
    _veh allowdamage false;
    [_veh, "", []] call bis_fnc_initVehicle;
    _veh Lock 0;
    _veh setVariable ['HoodLock',false,true];
    [_veh,false] call ServerModules_fnc_lockInventory;
    _veh setFuel 0.25;

    // Customize the taxi with specific components and textures
    [_veh, "Taxi",["Stock_Bonnet",1,"Stock_Front_Bumper",1,"Stock_Rear_Bumper",1,"Stock_Exhaust",1,"Police",0,"Push_Bar",0,"Spotlight",0,"Radio",0,"PoliceComputer",0,"HandSpotlight",0,"Radar",0,"RoadCone",0,"RoadFlares",0,"Shotgun",0,"Lightbar_BEACON_17",0,"Lightbar_Can",0,"Lightbar_Can_Amber",0,"Lightbar_Can_Red",0,"Lightbar_CJ_184",0,"Lightbar_mars_skybolt",0,"Lightbar_twin_sonic_chp",0,"Lightbar_Fireball",0,"Lightbar_Aerodynic",0,"TaxiMeter",1,"Mods",0,"Stock_Side_Skirt",0,"Stock_Spoiler",0,"Roll_Cage",0]] call ServerModules_fnc_customize_Vehicles;
    sleep 0.5; // Wait for customization to apply properly
    _veh setObjectTextureGlobal [0, "RetroRP\RetroRP_Textures_Vehicle\Dodge_Monaco\MonacoTaxiNoStripes.paa"];
    _veh animateSource ["Head_Lights", 3000,true];
    [_veh,['Headlight_Left','Headlight_Right','Dashlights'],0] call ServerModules_fnc_ToggleLight;

    // Enable steering system 
    if ( (!(isUsingAISteeringComponent)) && isAISteeringComponentEnabled _veh ) then {useAISteeringComponent true;};
    _veh forceFollowRoad true;

    [_veh] call ServerModules_fnc_createTaxiDriver;
    _veh setVariable ["RRP_isTaxi", true, true];
    [_veh, 'On'] call ServerModules_fnc_taxi;
    _veh setVariable ["RRP_taxiRouteOwner", player, true];

    player setVariable ["RRP_taxiNPC",_veh,true];
    _veh setVariable ["RRP_taxiCreated",time,true];
    if !(_veh getVariable ["RRP_taxiRouteLoop", false]) then {[_veh] spawn ServerModules_fnc_taxiRouteLoop;};
    _veh setVariable ["RRP_taxiMode", "WaitingForRoute", true];
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

    if (_veh getVariable ["RRP_hiddenObject", false])then
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
    (group _drv) setSpeedMode "LIMITED";
    (group _drv) setBehaviourStrong "CARELESS";

    _drv
};
ServerModules_fnc_createTaxiRoute = 
{
    params [ ["_dest", [0,0,0]], ["_veh", vehicle player], ["_mode", -1] ];
    if ( _dest isEqualTo [0,0,0] || isNull _veh || _veh isKindOf "Man" ) exitWith { };
    if (isNil "GPSInitialized") exitwith {};

    private _drv = objNull;
    private _startIndex = 0;
    private _owner = player;
    _drv = driver _veh;
    if (isNull _drv) then { _drv = [_veh] call ServerModules_fnc_createTaxiDriver; };
    if (isNull _drv) exitwith {};

    if !(local _veh)then {[[_veh,_drv],_owner] remoteExec ["Server_fnc_setOwner", 2];};
    waitUntil {local _veh};

    if (_veh getVariable ["RRP_taxiOnRoute", false])then {doStop _drv;waitUntil {speed _veh < 1};};
    //_drv doMove _dest;

    private _start = getPosATL _veh;

    if (_mode < 0) then 
    {
        waitUntil {GPSInitialized};
        if (_startIndex < 0) then {_startIndex = StartIndex + 1;};
        [_start, _dest, _startIndex] spawn ServerModules_fnc_GPS_FindPath;
    };

    waitUntil {(count GPSPathPos) > 0};
    private _route = GPSPathPos;
    {
        if (_x isNotEqualTo "") then 
        {
            _point = _x;
            if ( (count nearestLocations [_point, ["NameCity","NameCityCapital","NameVillage","Airport"], 500]) > 0 ) then {_point pushback 13.8;}else{_point pushback 16.6;};
        }else{_route = _route - [_x];};
    } forEach _route;

    // Now use setDriveOnPath with both points 


    _veh setVariable ["RRP_taxiRoute", _route, true];
    _veh setVariable ["RRP_taxiOnRoute", true, true];
    _veh setVariable ["RRP_hiddenObject", true, true];
    _veh setVariable ["RRP_taxiRouteOwner", _owner, true];

    waitUntil {vehicle _owner isEqualTo _veh};

    _veh setVariable ["RRP_taxiAutoRestart", true, true];
    _veh setDriveOnPath _route;
    if !(_veh getVariable ["RRP_TaxiRunning", false]) then { [_veh, 'Hired'] call ServerModules_fnc_taxi; };
    if (_veh getVariable ["RRP_TaxiPause", false]) then { [_veh, 'Pause'] call ServerModules_fnc_taxi; };

    _veh setVariable ["RRP_taxiCreated",9999999,true];
    _veh setVariable ["RRP_taxiMode", "OnRoute", true];
};
ServerModules_fnc_destinationPresets =
{
    params [["_destination", ""]];

    if (_destination isEqualTo "") exitwith {RRP_NPCPanel_TaxiRouteFail spawn ServerModules_fnc_createNPCDialog;};

    private _pos = [0,0,0];
    private _apartmentArray = player getVariable ["RRP_Apartment",[]];
    _pos = getArray (missionConfigFile >> "RRP_Destinations" >> _destination);
    if (_destination isEqualTo 'Apartment' && (count _apartmentArray) > 0 )then 
    {
        _pos = _apartmentArray select 1;
    };
    if (_destination isEqualTo 'Map')then 
    {
        private _id = addMissionEventHandler ["MapSingleClick", 
        {
            params ["_units", "_pos", "_alt", "_shift"];
            RRP_taxiMapClick = _pos;
            waitUntil {!(isNil "RRP_taxiMapClick")};
            openMap false;
        }];
        openMap true;
        waitUntil {!(isNil "RRP_taxiMapClick")};
        removeMissionEventHandler ["MapSingleClick", _id];
        _pos = RRP_taxiMapClick;
    };

    if ( _pos isEqualTo [0,0,0] || count _pos < 3) exitwith {RRP_NPCPanel_TaxiRouteFail spawn ServerModules_fnc_createNPCDialog;};

    [_pos] spawn ServerModules_fnc_createTaxiRoute;
    RRP_NPCPanel_TaxiDepart spawn ServerModules_fnc_createNPCDialog;
    RRP_taxiMapClick = nil;    
};
ServerModules_fnc_requestTaxiNPC =
{
    params [ ["_unit", player] ];

    private _road = [getPosATL _unit, 50, RRP_falseRoads] call BIS_fnc_nearestRoad;
    if ( (typeName _road) isNotEqualTo 'OBJECT') exitwith {[[0], "Could not find road", "Red"] call ClientModules_fnc_Notify;};

    private _info = getRoadInfo _road;
    _info params ["_mapType", "_width", "_isPedestrian", "_texture", "_textureEnd", "_material", "_begPos", "_endPos", "_isBridge"];

    private _roadDirection = _begPos getDir _endPos;
    private _midPos = getPosATL _road;

    if ( _unit getVariable ["RRP_taxiRequested",false] ) then 
    {
        if !(isNull(_unit getVariable ["RRP_taxiNPC",objNull])) then 
        {
            private _taxi = _unit getVariable ["RRP_taxiNPC",objNull];
            if (count(crew _taxi) < 2) then 
            {
                deleteVehicleCrew _taxi;
                deleteVehicle _taxi;
            };
        };
        _unit setVariable ["RRP_taxiRequested",nil,true];
        _unit setVariable ["RRP_taxiNPC",nil,true];
    }else
    {
        if (count (nearestObjects [_midPos, ["AllVehicles"], 5]-[_unit]) >= 1) exitwith {[[0], "Vehicle in the way.", "Red"] call ClientModules_fnc_Notify;};
        [_midPos, _roadDirection, false] spawn ServerModules_fnc_createTaxi;
        _unit setVariable ["RRP_taxiRequested",true,true];
    };    
};
ServerModules_fnc_taxi =
{
    params [["_vehicle", objNull], ["_mode", "On"]];

    if !(typeOf _vehicle isEqualTo "RetroRP_Monaco") exitWith {};
    private _isAiTaxi = !(isPlayer (driver _vehicle));
    switch (_mode) do {
        case "Hired":
        {
            private _patrons = fullCrew _vehicle - [driver _vehicle];
            _vehicle setVariable ["RRP_TaxiRunning", true, true];
            _vehicle setVariable ["RRP_MeterStartTime", time, true];
            _vehicle setVariable ["RRP_TaxiMeter", 0, false];
            _vehicle setVariable ["RRP_TaxiFare", _vehicle getVariable ["RRP_TaxiBase", 20], true];
            _vehicle setVariable ["RRP_TaxiPatrons", _patrons, true];

            { 
                private _patron = _x select 0; 
                if (_patron in RRP_TaxiClients) then { RRP_TaxiClients = RRP_TaxiClients - [_patron]; }; 
                [[0], "Taxi driver has started the meter!", "Green"] remoteExecCall ["ClientModules_fnc_Notify", _patron];
                _patron setVariable ["RRP_Taxi", _vehicle, true];
            } forEach _patrons;
            publicVariable "RRP_TaxiClients";

            _vehicle animateSource ["Taxi_Light", 1];
            [_vehicle] spawn ServerModules_fnc_taxiLoop;

            if !(_isAiTaxi) then {[[0], "You've started the taxi meter.", "Green"] call ClientModules_fnc_Notify;};
        };
        case "Stop":
        {
            _vehicle setVariable ["RRP_TaxiRunning", false, true];
            _vehicle setVariable ["RRP_MeterStopTime", time, true];

            private _totalTime = (_vehicle getVariable ["RRP_MeterStopTime", 0]) - (_vehicle getVariable ["RRP_MeterStartTime", 0]);
            private _totalDistance = _vehicle getVariable ["RRP_TaxiMeter", 0];
            private _patrons = _vehicle getVariable ["RRP_TaxiPatrons", []];

            [[0], "Taxi meter has stopped.", "Green"] call ClientModules_fnc_Notify;
            
            //do stuff here
            [_vehicle, _totalTime, _totalDistance, _patrons] call ServerModules_fnc_endTaxi;
            _vehicle setVariable ["RRP_taxiMode", "Returning", true];
            [-1] call RetroRP_fnc_Newsong;
        };
        case "Pause":
        {
            //todo: track how long it was paused for
            private _currentPause = _vehicle getVariable ["RRP_TaxiPause", false];
            _vehicle setVariable ["RRP_TaxiPause", !_currentPause, true];

            if !(_currentPause) then {
                [[0], "Taxi meter has been paused.", "Yellow"] call ClientModules_fnc_Notify;
                if (_vehicle getVariable ["RRP_taxiMode", ""] isNotEqualTo "RouteFailed")then {_vehicle setVariable ["RRP_taxiMode", "Paused", true];};
            } else {
                [[0], "Taxi meter has been unpaused.", "Yellow"] call ClientModules_fnc_Notify;
            };
        };
        case "Vacant":
        {
            if (_vehicle getVariable ["RRP_TaxiRunning", false]) exitWith { if !(_isAiTaxi) then {[[0], "Error! The taxi meter is still running.", "Red"] call ClientModules_fnc_Notify;}; };
            { 
                (_x select 0) setVariable ["RRP_Taxi", nil, true];
            } forEach (_vehicle getVariable ["RRP_TaxiPatrons", []]);
            //do a confirmation if driver hasn't been paid yet so they dont accidently clear it
            _vehicle setVariable ["RRP_TaxiRunning", false, true];
            _vehicle setVariable ["RRP_MeterStartTime", nil, true];
            _vehicle setVariable ["RRP_MeterStopTime", nil, true];
            _vehicle setVariable ["RRP_TaxiMeter", nil, false];
            _vehicle setVariable ["RRP_TaxiPatrons", nil, true];
            _vehicle setVariable ["RRP_MeterStationaryAcc", nil, true];
            _vehicle setVariable ["RRP_TaxiStationaryStartTime", nil, true];
            _vehicle setVariable ["RRP_TaxiFare", nil, true];
            _vehicle animateSource ["Taxi_Light", 0];
            _vehicle setVariable ["RRP_taxiMode", "Returning", true];
            [] call ServerModules_fnc_GPS_removeMarkers;
            [-1] call RetroRP_fnc_Newsong;
            RRP_CurrentTaxiInfo = nil;
            // Clear the current taxi fare data
            RRP_CurrentTaxi = nil;

            for "_i" from 14 to 27 do { _vehicle setObjectTextureGlobal [_i, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", "-"]]; };
        };
        case "On":
        {
            _vehicle setVariable ["RRP_TaxiRunning", false, true];
            _vehicle setVariable ["RRP_MeterStartTime", time, true];
            _vehicle setVariable ["RRP_TaxiMeter", 0, false];
            _vehicle animate ["TaxiMeterDisplay", 1];

            for "_i" from 14 to 27 do { _vehicle setObjectTextureGlobal [_i, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", "-"]]; };
        };
        case "Off":
        {
            if (_vehicle getVariable ["RRP_TaxiRunning", false]) exitWith { if !(_isAiTaxi) then {[[0], "Error! The taxi meter is still running.", "Red"] call ClientModules_fnc_Notify;}; };

            for "_i" from 14 to 27 do { _vehicle setObjectTextureGlobal [_i, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", "-"]]; };
            _vehicle setVariable ["RRP_TaxiRunning", nil, true];
            _vehicle setVariable ["RRP_MeterStartTime", nil, true];
            _vehicle setVariable ["RRP_MeterStopTime", nil, true];
            _vehicle setVariable ["RRP_TaxiMeter", nil, true];
            _vehicle setVariable ["RRP_TaxiPatrons", nil, true];
            _vehicle setVariable ["RRP_MeterStationaryAcc", nil, true];
            _vehicle setVariable ["RRP_TaxiStationaryStartTime", nil, true];
            _vehicle animateSource ["Taxi_Light", 0];
            _vehicle animate ["TaxiMeterDisplay", 0];
            _vehicle setVariable ["RRP_taxiMode", "Returning", true];
            RRP_CurrentTaxiInfo = nil;
        };
        case "SetFare":
        {
            createDialog "RRP_TaxiFares";
            
            private _pricePerKM = _vehicle getVariable ["RRP_TaxiRateKM", 1];
            private _pricePerHR = _vehicle getVariable ["RRP_TaxiRateHR", 10];
            private _basePrice = _vehicle getVariable ["RRP_TaxiBase", 20];

            ctrlSetText [1400, str _pricePerKM];
            ctrlSetText [1401, str _basePrice];
            ctrlSetText [1402, str _pricePerHR];
        };
        case "saveFares":
        {
            private _display = uiNamespace getVariable ['RRP_TaxiFareDisplay', displayNull];
            if (_display isEqualTo displayNull) exitWith { [[0], "Error! Could not save taxi fares!"]; };

            private _pricePerKMCTRL = _display displayCtrl 1400;
            private _basePriceCTRL = _display displayCtrl 1401;
            private _pricePerHRCTRL = _display displayCtrl 1402;

            private _pricePerKM = parseNumber (ctrlText _pricePerKMCTRL);
            private _basePrice = parseNumber (ctrlText _basePriceCTRL);
            private _pricePerHR = parseNumber (ctrlText _pricePerHRCTRL);

            _vehicle setVariable ["RRP_TaxiRateKM", _pricePerKM, true];
            _vehicle setVariable ["RRP_TaxiRateHR", _pricePerHR, true];
            _vehicle setVariable ["RRP_TaxiBase", _basePrice, true];

            closeDialog 0;
        };
        default {};
    };    
};
ServerModules_fnc_taxiLoop =
{
    params [["_vehicle", objNull]];

    if (isNull _vehicle) exitWith {};

    RRP_TaxiRateKM = _vehicle getVariable ["RRP_TaxiRateKM", 1];
    RRP_TaxiRateHR = _vehicle getVariable ["RRP_TaxiRateHR", 10];
    RRP_TaxiLastTime = time;
    RRP_TaxiLastPos = getPos _vehicle;
    RRP_TaxiLastTextureUpdate = time - 1;

    while {_vehicle getVariable ["RRP_TaxiRunning", false]} do {
        waitUntil { !(_vehicle getVariable ["RRP_TaxiPause", false]) };

        private _currentPos = getPos _vehicle;
        private _distance = _currentPos distance RRP_TaxiLastPos;
        RRP_TaxiLastPos = _currentPos;

        if (_distance > 100) then {_distance = 0;};

        private _currentMeter = _vehicle getVariable ["RRP_TaxiMeter", 0];
        private _newMeter = _currentMeter + _distance;
        _vehicle setVariable ["RRP_TaxiMeter", _newMeter, false];

        private _fare = _vehicle getVariable ["RRP_TaxiFare", 0];
        private _additionalFare = 0;

        // use a small threshold to avoid counting tiny floating jitter as movement
        private _speed = speed _vehicle;
        private _isMoving = (_speed > 10); // tweak threshold as needed

        private _deltaTime = time - RRP_TaxiLastTime;

        if (_isMoving) then {
            // distance-based fare while moving
            _additionalFare = RRP_TaxiRateKM * (_distance / 1000);
            // update the last-time so time fare doesn't accrue while moving
            RRP_TaxiLastTime = time;
        } else {
            // time-based fare while stationary (only accumulates when stopped)
            _additionalFare = RRP_TaxiRateHR * (_deltaTime / 3600);
            // DO NOT update RRP_TaxiLastTime here so deltaTime continues to grow while stopped
        };

        private _newFare = _fare + _additionalFare;
        _vehicle setVariable ["RRP_TaxiFare", _newFare, true];

        //only update texture every 5 seconds
        if (time - RRP_TaxiLastTextureUpdate >= 1) then {
            // START CHANGED BLOCK: only count meter time while vehicle is NOT moving
            private _stationaryAcc = _vehicle getVariable ["RRP_MeterStationaryAcc", 0];
            private _stationaryStart = _vehicle getVariable ["RRP_TaxiStationaryStartTime", -1];

            // Detect transitions between moving / stationary and accumulate stationary time
            if (_isMoving) then {
                // if we were previously stationary, finalize that stationary period
                if (_stationaryStart > -1) then {
                    _stationaryAcc = _stationaryAcc + (time - _stationaryStart);
                    _stationaryStart = -1;
                    _vehicle setVariable ["RRP_MeterStationaryAcc", _stationaryAcc, true];
                    _vehicle setVariable ["RRP_TaxiStationaryStartTime", _stationaryStart, true];
                };
            } else {
                // vehicle is stationary -> ensure a stationary start time exists
                if (_stationaryStart < 0) then {
                    _stationaryStart = time;
                    _vehicle setVariable ["RRP_TaxiStationaryStartTime", _stationaryStart, true];
                };
            };

            // current meter time is ONLY the accumulated stationary time + current stationary period (if any)
            private _currentMeterTime = _stationaryAcc + ( if (_isMoving) then { 0 } else { time - _stationaryStart } );

            private _minutes = floor (_currentMeterTime / 60);
            private _seconds = _currentMeterTime % 60;
            private _stringMinutes = str floor _minutes;
            private _stringSeconds = str floor _seconds;

            if (_minutes < 10) then { _stringMinutes = "0" + _stringMinutes; };
            if (_minutes >= 100) then { _stringMinutes = "99"; };

            if (_seconds < 10) then { _stringSeconds = "0" + _stringSeconds; };
            if (_seconds >= 100) then { _stringSeconds = "99"; };

            private _hiddenSelections1 = [14,15];
            { _vehicle setObjectTextureGlobal [_hiddenSelections1 # _forEachIndex, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", _x]]; } foreach (_stringMinutes splitString "");

            private _hiddenSelections2 = [16,17];
            { _vehicle setObjectTextureGlobal [_hiddenSelections2 # _forEachIndex, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", _x]]; } foreach (_stringSeconds splitString (""));

            // kilometers/fare textures unchanged
            private _kilometers = floor (_newMeter / 1000);
            private _decimal = floor ((_newMeter % 1000) / 100);
            private _stringKilometers = str floor _kilometers;
            private _stringDecimal = str _decimal;

            if (_kilometers < 100) then { _stringKilometers = "0" + _stringKilometers; };
            if (_kilometers < 10) then { _stringKilometers = "0" + _stringKilometers; };
            if (_kilometers >= 1000) then { _stringKilometers = "999"; };

            private _hiddenSelections3 = [18,19,20];
            { _vehicle setObjectTextureGlobal [_hiddenSelections3 # _forEachIndex, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", _x]]; } foreach (_stringKilometers splitString "");
            _vehicle setObjectTextureGlobal [21, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", _stringDecimal]];
            
            _fareWithCents = floor(_newFare * 10); // fare in cents
            private _stringFare = str _fareWithCents;//floor
            if (_fareWithCents < 100000) then { _stringFare = "0" + _stringFare; };
            if (_fareWithCents < 10000) then { _stringFare = "0" + _stringFare; };
            if (_fareWithCents < 1000) then { _stringFare = "0" + _stringFare; };
            if (_fareWithCents < 100) then { _stringFare = "0" + _stringFare; };
            if (_fareWithCents < 10) then { _stringFare = "0" + _stringFare; };
            if (round _fareWithCents >= 1000000) then { _stringFare = "999999"; };

            private _hiddenSelections4 = [22,23,24,25,26,27];// 27 = cents// 26 = dollars// 25 = tens// 24 = hundreds// 23 = thousands// 22 = ten-thousands
            { _vehicle setObjectTextureGlobal [_hiddenSelections4 # _forEachIndex, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", _x]]; } foreach (_stringFare splitString "");
            //_vehicle setObjectTextureGlobal [27, format ["\RetroRP\RetroRP_Assets\Textures\Didgle Numbers\%1.paa", "0"]];

            // save stationary accumulator whenever changed (already saved above on transition)
            _vehicle setVariable ["RRP_MeterStationaryAcc", _stationaryAcc, true];
            _vehicle setVariable ["RRP_TaxiStationaryStartTime", _stationaryStart, true];

            RRP_TaxiLastTextureUpdate = time;
            // END CHANGED BLOCK
        };

        if (_vehicle animationSourcePhase "TaxiMeter" < 0.5) exitWith {
            [_vehicle, "Off"] call ServerModules_fnc_taxi;
            [[0], "Taxi meter not installed!", "Red"] call ClientModules_fnc_Notify;
        };

        sleep 0.1;
    };
};
ServerModules_fnc_taxiNPCPanels = 
{
    private _publicVar = [];
    RRP_NPCPanel_TaxiMain = [
        "Taxi Driver",
        "Hey mate. Need a lift? Pick on the map or choose a destination.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Let me choose on the map.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMapChoice spawn ServerModules_fnc_createNPCDialog;"],
            ["Show popular destinations.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular1 spawn ServerModules_fnc_createNPCDialog;"],
            ["How much is the fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Never mind, I'll walk.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiGoodbye spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiMain";

    // Start node
    RRP_NPCPanel_TaxiMainNewPlayer = [
        "Taxi Driver",
        "Welcome to Sahrani. Need a lift? Pick on the map or choose a destination.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Let me choose on the map.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMapChoice spawn ServerModules_fnc_createNPCDialog;"],
            ["Show popular destinations.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular1 spawn ServerModules_fnc_createNPCDialog;"],
            ["How much is the fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Never mind, I'll walk.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiGoodbye spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiMainNewPlayer";

    RRP_NPCPanel_TaxiMainOnRoute = [
        "Taxi Driver",
        "Hey mate. What do you need?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Stop the car.", "!(isNull (driver (vehicle player)))", "(vehicle player) setVariable ['RRP_taxiMode', 'Paused', true];doStop (driver (vehicle player));RRP_NPCPanel_TaxiArrival spawn ServerModules_fnc_createNPCDialog;"],
            ["Let's start over again.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"],
            ["I have some questions about the island.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_IslandQuestionsMain spawn ServerModules_fnc_createNPCDialog;"],
            ["Can we change the music?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMusicOptions spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiMainOnRoute";

    // Popular / quick-destination pages (4 options per page)
    RRP_NPCPanel_TaxiPopular1 = [
        "Taxi Driver",
        "Where to? Pick one or view more options.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["My Apartment.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Apartment spawn ServerModules_fnc_createNPCDialog;"],
            ["Police HQ.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_PoliceHQ spawn ServerModules_fnc_createNPCDialog;"],
            ["Hospital.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Hospital spawn ServerModules_fnc_createNPCDialog;"],
            ["More options.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular2 spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiPopular1";

    RRP_NPCPanel_TaxiPopular2 = [
        "Taxi Driver",
        "More spots — pick one or view more.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Fire Station (City).", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_FireStation spawn ServerModules_fnc_createNPCDialog;"],
            ["SAR HQ.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_SARHQ spawn ServerModules_fnc_createNPCDialog;"],
            ["Capital Building.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Capital spawn ServerModules_fnc_createNPCDialog;"],
            ["More options.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular3 spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiPopular2";

    RRP_NPCPanel_TaxiPopular3 = [
        "Taxi Driver",
        "Even more options — pick one or continue.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Airport.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Airport spawn ServerModules_fnc_createNPCDialog;"],
            ["Prison.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Prison spawn ServerModules_fnc_createNPCDialog;"],
            ["Harbor.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Harbor spawn ServerModules_fnc_createNPCDialog;"],
            ["More options.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular4 spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiPopular3";

    RRP_NPCPanel_TaxiPopular4 = [
        "Taxi Driver",
        "Final set: banks, impound and car shops. Pick one or view more.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Bank (City).", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Bank spawn ServerModules_fnc_createNPCDialog;"],
            ["Impound Lot (City).", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Impound spawn ServerModules_fnc_createNPCDialog;"],
            ["Car Shop (City).", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_CarShop spawn ServerModules_fnc_createNPCDialog;"],
            ["More options.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular5 spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiPopular4";

    RRP_NPCPanel_TaxiPopular5 = [
        "Taxi Driver",
        "Extra services and shops — pick one or return to the start.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["General Store / Parking / Clothing", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_General spawn ServerModules_fnc_createNPCDialog;"],
            ["Farm Store / Industrial Supplies", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_Farm spawn ServerModules_fnc_createNPCDialog;"],
            ["Mod Shop (City).", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_ModShop spawn ServerModules_fnc_createNPCDialog;"],
            ["More options.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular6 spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiPopular5";

    RRP_NPCPanel_TaxiPopular6 = [
        "Taxi Driver",
        "Choose: Gun Store or Post Office, or return to start.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Gun Store", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_GunStore spawn ServerModules_fnc_createNPCDialog;"],
            ["Post Office (City).", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiConfirm_PostOffice spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"],
            ["More options.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiPopular1 spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiPopular6";

    // Confirmation nodes for each destination — neutral, no location or ETA claims

    RRP_NPCPanel_TaxiConfirm_Apartment = [
        "Taxi Driver",
        "You want your apartment. Shall I take you there?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, let's go.", "!(isNull (driver (vehicle player)))", "['Apartment'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare info.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Apartment";

    RRP_NPCPanel_TaxiConfirm_PoliceHQ = [
        "Taxi Driver",
        "You want Police HQ? Ready to depart?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['PoliceHQ'] spawn ServerModules_fnc_destinationPresets;"],
            ["Cost?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_PoliceHQ";

    RRP_NPCPanel_TaxiConfirm_Hospital = [
        "Taxi Driver",
        "You want the Hospital? Shall I head there now?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Take me now.", "!(isNull (driver (vehicle player)))", "['Hospital'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Hospital";

    RRP_NPCPanel_TaxiConfirm_FireStation = [
        "Taxi Driver",
        "You picked the Fire Station? Where should I drop you?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Main bay.", "!(isNull (driver (vehicle player)))", "['Fire_Station'] spawn ServerModules_fnc_destinationPresets;"],
            ["Service entrance.", "!(isNull (driver (vehicle player)))", "['Fire_Station'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_FireStation";

    RRP_NPCPanel_TaxiConfirm_SARHQ = [
        "Taxi Driver",
        "You want the SAR HQ? Shall I take you there?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, let's go.", "!(isNull (driver (vehicle player)))", "['SARHQ'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_SARHQ";

    RRP_NPCPanel_TaxiConfirm_Capital = [
        "Taxi Driver",
        "You want the Capital Building? Ready to depart?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['Capital'] spawn ServerModules_fnc_destinationPresets;"],
            ["Cost?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Capital";

    RRP_NPCPanel_TaxiConfirm_Airport = [
        "Taxi Driver",
        "You want the Airport? Head there now or pick on the map?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, please.", "!(isNull (driver (vehicle player)))", "['Airport'] spawn ServerModules_fnc_destinationPresets;"],
            ["Map instead.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMapChoice spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Airport";

    RRP_NPCPanel_TaxiConfirm_Prison = [
        "Taxi Driver",
        "You want the Prison? Continue to this destination?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['Prison'] spawn ServerModules_fnc_destinationPresets;"],
            ["Cost?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Prison";

    RRP_NPCPanel_TaxiConfirm_Harbor = [
        "Taxi Driver",
        "You want the Harbor? Proceed to this destination?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, head there.", "!(isNull (driver (vehicle player)))", "['Harbor'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Harbor";

    RRP_NPCPanel_TaxiConfirm_Bank = [
        "Taxi Driver",
        "You want the Bank? Shall I take you there?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['Bank'] spawn ServerModules_fnc_destinationPresets;"],
            ["Cost?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Bank";

    RRP_NPCPanel_TaxiConfirm_Impound = [
        "Taxi Driver",
        "You want the Impound Lot? Continue to this destination?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['Impound'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Impound";

    RRP_NPCPanel_TaxiConfirm_CarShop = [
        "Taxi Driver",
        "You want the Car Shop? Ready to go?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['Car_Shop'] spawn ServerModules_fnc_destinationPresets;"],
            ["How much?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_CarShop";

    RRP_NPCPanel_TaxiConfirm_General = [
        "Taxi Driver",
        "You picked General Stores. Which would you like: General Store, Parking Lot, or Clothing Stores?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["General Store.", "!(isNull (driver (vehicle player)))", "['General_Store'] spawn ServerModules_fnc_destinationPresets;"],
            ["Parking Lot.", "!(isNull (driver (vehicle player)))", "['General_Store'] spawn ServerModules_fnc_destinationPresets;"],
            ["Clothing Store.", "!(isNull (driver (vehicle player)))", "['General_Store'] spawn ServerModules_fnc_destinationPresets;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_General";

    RRP_NPCPanel_TaxiConfirm_Farm = [
        "Taxi Driver",
        "You want Farm Store / Industrial Supplies? Continue to this destination?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['Industrial_Supplies'] spawn ServerModules_fnc_destinationPresets;"],
            ["Too far, back.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_Farm";

    RRP_NPCPanel_TaxiConfirm_ModShop = [
        "Taxi Driver",
        "You want the Mod Shop? Shall we head there?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, head there.", "!(isNull (driver (vehicle player)))", "['ModShop'] spawn ServerModules_fnc_destinationPresets;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_ModShop";

    RRP_NPCPanel_TaxiConfirm_GunStore = [
        "Taxi Driver",
        "You want the Gun Store? Continue to this destination?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['GunStore'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare info.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_GunStore";

    RRP_NPCPanel_TaxiConfirm_PostOffice = [
        "Taxi Driver",
        "You want the Post Office? Shall I take you there?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, take me.", "!(isNull (driver (vehicle player)))", "['PostOffice'] spawn ServerModules_fnc_destinationPresets;"],
            ["Fare info.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiFare spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiConfirm_PostOffice";

    RRP_NPCPanel_TaxiMapChoice = [
        "Taxi Driver",
        "Open the map and place a marker, then tell me when it's set.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Alright I'll set the marker now", "!(isNull (driver (vehicle player)))", "['Map'] spawn ServerModules_fnc_destinationPresets;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiMapChoice";
    // Reusable supporting nodes (neutral)

    RRP_NPCPanel_TaxiFare = [
        "Taxi Driver",
        format ["Base fare: $%1 — Charged at trip start. Rate per km $%2 — Added for distance travelled. Idle rate $%3/hr — Charged while the cab is stationary. Cash ONLY.",vehicle player getVariable ["RRP_TaxiBase", 20],vehicle player getVariable ["RRP_TaxiRateKM", 1],vehicle player getVariable ["RRP_TaxiRateHR", 10]],
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Yes, go.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiDepart spawn ServerModules_fnc_createNPCDialog;"],
            ["Wait, I need cash.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiGoodbye spawn ServerModules_fnc_createNPCDialog;"],
            ["Never mind, I'll walk.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiGoodbye spawn ServerModules_fnc_createNPCDialog;"],
            ["Back to start.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiFare";
    RRP_NPCPanel_TaxiDepart = [
        "Taxi Driver",
        "Alright give me a minute while I calculate the route. Would you like some music?.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["No music, thanks.", "!(isNull (driver (vehicle player)))", "[-1] call RetroRP_fnc_Newsong;"],
            ["Yes please play some music.", "!(isNull (driver (vehicle player)))", "[] call RetroRP_fnc_Newsong;"],
            ["No music but I do have some questions about the island?", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_IslandQuestionsMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiDepart";

    RRP_NPCPanel_TaxiMusicOptions = [
        "Taxi Driver",
        "Sure what would you like?",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["No music, thanks.", "!(isNull (driver (vehicle player)))", "[-1] call RetroRP_fnc_Newsong;"],
            ["I don't like this song.", "!(isNull (driver (vehicle player)))", "[] call RetroRP_fnc_Newsong;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiMusicOptions";

    RRP_NPCPanel_TaxiGoodbye = [
        "Taxi Driver",
        "Alright, suit yourself. Give us a call if you change your mind.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Okay.", "!(isNull (driver (vehicle player)))", "[-1] call RetroRP_fnc_Newsong;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiGoodbye";

    RRP_NPCPanel_TaxiArrival = [
        "Taxi Driver",
        "We've arrived. That'll be the fare please.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["How much is the fare?", "!(isNull (driver (vehicle player)))", "[(player getVariable ['RRP_Taxi', objNull]), 'Stop'] call ServerModules_fnc_taxi;"],
            ["Actually, I want to go somewhere else.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiArrival";
    RRP_NPCPanel_TaxiExit = [
        "Taxi Driver",
        "HEY WAIT! You need to pay your fare. If you don't pay the fare, I'll have to report you to the authorities.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["How much is the fare?", "!(isNull (driver (vehicle player)))", "[(player getVariable ['RRP_Taxi', objNull]), 'Stop'] call ServerModules_fnc_taxi;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiExit";

    // End / payment nodes
    RRP_NPCPanel_TaxiEnd = [
        "Taxi Driver",
        "Much appreciated. Have a good one..",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Goodbye.", "!(isNull (driver (vehicle player)))", "[-1] call RetroRP_fnc_Newsong;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiEnd";
    RRP_NPCPanel_TaxiRouteFail = [
        "Taxi Driver",
        "Sorry I could find a route to your destination.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Let's try that again.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"],
            ["Never mind then, I'll walk.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiGoodbye spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiRouteFail";
    RRP_NPCPanel_TaxiOnRouteFail = [
        "Taxi Driver",
        "Sorry I've seem to have gotten lost, I'll try and find a new route.",
        "!(isNull (driver (vehicle player)))",
        "",
        [
            ["Okay find a new route.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"],
            ["Let's try different destination.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiMain spawn ServerModules_fnc_createNPCDialog;"],
            ["Never mind then, I'll walk.", "!(isNull (driver (vehicle player)))", "RRP_NPCPanel_TaxiGoodbye spawn ServerModules_fnc_createNPCDialog;"]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_TaxiOnRouteFail";


    RRP_NPCPanel_IslandQuestionsMain = [
        "Person",
        "What do you want to know about Sahrani?",
        "true",
        "",
        [
            ["Tell me about the major cities.", "true", ""],
            ["What services are available?", "true", ""],
            ["Back to main menu.", "true", ""]
        ]
    ];
    _publicVar pushBack "RRP_NPCPanel_IslandQuestionsMain";

    {
        publicVariable _x;
    } forEach _publicVar;
};
ServerModules_fnc_taxiRouteLoop = 
{
    params [ ["_veh", objNull] ];

    if (isNull _veh) exitwith {};
    _veh setVariable ["RRP_taxiRouteLoop", true, true];

    private _pausePos = getPos _veh;
    private _pauseTime = time;
    private _startTime = time;
    private _owner = _veh getVariable ["RRP_taxiRouteOwner", objNull];
    private _driver = driver _veh;
    private _nObjects = [];

    waitUntil {!(isNull _owner)};
    // Loop runs as long as taxi is on route
    while { alive _veh } do 
    {
        if (_veh getVariable ["RRP_taxiRouteLoop", false]) then 
        {
            if (_veh getVariable ["RRP_taxiMode", ""] isEqualTo "OnRoute") then 
            {
                if (vehicle _owner isEqualTo _veh) then 
                {
                    private _currentPos = getPos _veh;
                    private _distMoved = _pausePos distance2D _currentPos;

                    // If vehicle has moved more than 5 meters, reset pause position and timer
                    if (_distMoved > 5) then {
                        _pausePos = _currentPos;
                        _pauseTime = time;
                    };

                    // If vehicle hasn't moved for 20 seconds, consider it stuck and stop the taxi
                    if ((time - _pauseTime) > 20) then {
                        doStop _driver;
                        _pauseTime = time; // Prevent repeated stopping
                        _veh setVariable ["RRP_taxiMode", "RouteFailed", true];
                        [_veh, "Pause"] call ServerModules_fnc_Taxi;
                    };

                    // If no passengers, stop the car
                    if (count crew _veh < 2) then {
                        doStop _driver;
                        _veh setVariable ["RRP_taxiMode", "Returning", true];
                    };

                    {
                        if (_x isEqualTo "") then {GPSPathPos = GPSPathPos - [_x];};
                        if ( (  [_x#0,_x#1,_x#2] distance2D (getPos _veh) ) < 15 ) exitwith 
                        {
                            GPSPathPos = GPSPathPos - [_x];
                            //deleteMarker _x;
                        };
                    } forEach GPSPathPos;

                    if (count GPSPathPos < 1) then {
                        doStop _driver;
                        _veh setVariable ["RRP_taxiOnRoute", false, true];
                        _veh setVariable ["RRP_taxiRoute", nil, true];
                        _veh setVariable ["RRP_taxiMode", "Paused", true];
                        RRP_NPCPanel_TaxiArrival spawn ServerModules_fnc_createNPCDialog;
                    };
                    _nObjects = (nearestObjects [_veh, ["Jonzie_Tank_Base","Jonzie_RetroRP_Car_Base","Jonzie_RetroRP_truck_base","Jonzie_RetroRP_Ship_Base","RetroRP_Heli_Base","Man"], 10])-[_veh,_owner];
                    if (count _nObjects > 0 && ((getPhysicsCollisionFlag _veh)select 0)) then {_veh setPhysicsCollisionFlag false} else {if !((getPhysicsCollisionFlag _veh)select 0) then {_veh setPhysicsCollisionFlag true;};};
                };
            };
            if (vehicle _owner isEqualTo _veh && _veh getVariable ["RRP_taxiMode", ""] isEqualTo "RouteFailed")then
            {
                if ( _veh getVariable ["RRP_taxiAutoRestart", false] && count GPSPathPos > 5 ) then 
                {
                    private _dest = (selectMax GPSPathPos);
                    [[_dest#0,_dest#1,_dest#2],_veh,1] spawn ServerModules_fnc_createTaxiRoute;
                };
                if ( !(_veh getVariable ["RRP_taxiAutoRestart", false]) && count GPSPathPos > 5 ) then 
                {
                    RRP_NPCPanel_TaxiOnRouteFail spawn ServerModules_fnc_createNPCDialog;
                };
            };
            if (vehicle _owner isNotEqualTo _veh && _veh getVariable ["RRP_taxiMode", ""] isEqualTo "Paused") then 
            {
                RRP_NPCPanel_TaxiExit spawn ServerModules_fnc_createNPCDialog;
            };
            //
            if (vehicle _owner isNotEqualTo _veh && _veh getVariable ["RRP_taxiMode",""] isEqualTo "OnRoute" ) then {RRP_NPCPanel_TaxiExit spawn ServerModules_fnc_createNPCDialog;};
            if (vehicle _owner isNotEqualTo _veh && _veh getVariable ["RRP_taxiMode",""] isEqualTo "Returning" ) then {[-1] call RetroRP_fnc_Newsong;_driver doMove [9933.89,9951.86,0];if ((getPhysicsCollisionFlag _veh)select 0) then {_veh setPhysicsCollisionFlag false;};_veh setVariable ["RRP_taxiRouteLoop", false, true];};
        };
        if ((_owner distance2D _veh) > 100) then {deleteVehicleCrew _veh;deleteVehicle _veh;};
        if ( (time-(_veh getVariable ["RRP_taxiCreated",-1])) > 180 && _veh getVariable ["RRP_taxiMode",""] isEqualTo "WaitingForRoute" ) then {deleteVehicleCrew _veh;deleteVehicle _veh;};
        if (vehicle _driver isNotEqualTo _veh) then {deleteVehicle _driver;deleteVehicle _veh;};
        if (isDamageAllowed _veh)then {_veh allowDamage false;};
        if (isDamageAllowed _driver)then {_driver allowDamage false;};
        if ((fuel _veh) < 0.1) then { _veh setFuel 1; };
        if (vehicle _owner isNotEqualTo _veh && _veh getVariable ["RRP_taxiMode",""] isEqualTo "Returning" && (locked _veh) < 2) then {_veh lock 2;};
        if (vehicle _owner isEqualTo _veh && _veh getVariable ["RRP_taxiMode",""] isEqualTo "Returning" && (_veh getVariable ["RRP_TaxiFare", 0]) < 1) then {moveOut player;};
        sleep 0.5;
    };
    if !(isNull _driver) then 
    {
        waitUntil {vehicle _owner isNotEqualTo _veh};
        _veh Lock 2;
        waitUntil {(_owner distance2D _veh) > 100};
        deleteVehicle _veh;
    };

    [-1] call RetroRP_fnc_Newsong;
    _veh setVariable ["RRP_taxiRouteLoop", false, true];
    _veh setVariable ["RRP_taxiOnRoute", false, true];
    [] call ServerModules_fnc_GPS_removeMarkers;
};

_startPos = [14624.7,11865.9,0];
[_startPos,270] call ServerModules_fnc_createTaxi;
/*

[[12630.4,9204.31,0],nearestObject [_startPos,"RetroRP_Monaco"]] spawn ServerModules_fnc_createTaxiRoute;


//GPSEnabled = true;


addMissionEventHandler ["MapSingleClick", 
{
    params ["_units", "_pos", "_alt", "_shift"];
    [_pos] spawn ServerModules_fnc_createTaxiRoute;
}];

waitUntil {vehicle player != player};
vehicle player setVariable ["RRP_taxiAutoRestart", true];



_startPos = getpos player;
[_startPos,getDir player] call ServerModules_fnc_createTaxi;
[[12630.4,9204.31,0],vehicle player] spawn ServerModules_fnc_createTaxiRoute;
*/



/*
[] spawn 
{
    private _center1 = [9954.675,9969.12,0];
    private _center2 = [9893.58,9969.085,0];
    private _areaSize = [3.855,5.29];
    private _center = [0,0,0];
    private _return = false;
    private _pos = [0,0,0];
    while {alive player} do 
    {
        for "_i" from 0 to 2500 do 
        {
            _center = selectRandom [_center1, _center2];
            _return = false;
            _pos = [[[_center, 10]], []] call BIS_fnc_randomPos;
            _return = [_center, [3.86, 5.295], _pos] call BIS_fnc_isInsideArea;
            if (_return && _center isNotEqualTo [0,0,0] && _pos isNotEqualTo [0,0,0]) exitwith {player setPos _pos;player setDir (random 360);};
        };
        sleep 0.5;    
    };
};
[] spawn 
{
    private _center1 = [9954.675,9969.12,0];
    private _center2 = [9893.58,9969.085,0];
    private _areaSize = [3.855,5.29];
    private _center = [0,0,0];
    private _return = false;
    private _pos = [0,0,0];
    
    for "_i" from 0 to 150 do 
    {
        for "_i" from 0 to 2500 do 
        {
            _center = selectRandom [_center1, _center2];
            _return = false;
            _pos = [[[_center, 10]], []] call BIS_fnc_randomPos;
            _return = [_center, [3.86, 5.295], _pos] call BIS_fnc_isInsideArea;
            if (_return && _center isNotEqualTo [0,0,0] && _pos isNotEqualTo [0,0,0]) exitwith 
            {
                (typeOf player) createUnit [[0,0,0], group player, "myUnit = this",1];
                myUnit disableAI "ALL";
                myUnit setPos _pos;
                myUnit setDir (random 360);
            };
        };
        sleep 0.5;
    };
};
*/