local addonName, core = ...;

_G["SLASH_RELOADUI1"] = "/rl";
SlashCmdList.RELOADUI = ReloadUI;

_G["SLASH_FRAMESTK1"] = "/fs";
SlashCmdList.FRAMESTK = function()
    LoadAddOn('Blizzard_DebugTools');
    FrameStackTooltip_Toggle();
end

for i = 1, NUM_CHAT_WINDOWS do
    _G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
end
--------------------------------------------
--------------------------------------------
local LibObject = LibStub:NewLibrary("LibObject", 1.0);
if (not LibObject) then return; end

local error, rawget, rawset = error, rawget, rawset;
local type, setmetatable = type, setmetatable;

local Private = {};

local DefineParams = {};
local DefineReturns = {};
local DefineImplements = {};

local Controllers = {};
local ProxyFunction = {};

core.Lib = LibObject;
core.Controllers = Controllers;
core.RootPackage = {};
core.Private = Private;

--------------------------------------------
-- LibObject Functions
--------------------------------------------
function LibObject:CreateClass(className, parent, implements)
    local Class = {};
    local Controller = {}; -- behind the scenes controller
    local ProxyClass = {}; -- redirect all Class keys to this   
    local ClassMT = {};
    local InstanceMT = {}; -- metatable for instances of class 

    ProxyClass.Static = {}; -- for static functions and properties

    Controller.Locked = false; -- true if functions and properties are to be protected
    Controller.EntityName = className;
    Controller.ProxyInstances = {}; -- redirect all instance keys to this  
    Controller.PrivateInstanceData = {}; -- for Class Private Instance functions and properties
    Controller.Definitions = {};
	Controller.IsClass = true;
    Controller.Class = Class;
	
    Private:SetClassParent(Controller, parent);
	Private:SetClassInterfaces(Controller, implements);

    InstanceMT.Class = Class;
    ClassMT.Class = Class;

    -- get a value
    InstanceMT.__index = function(instance, key)
        local ProxyInstance = Controller.ProxyInstances[tostring(instance)];
        local PrivateData = Controller.PrivateInstanceData[tostring(instance)];
        local value = ProxyInstance[key];

        if (type(value) == "function") then
            value = ProxyFunction:Setup(ProxyInstance, key, instance, Controller);        

        elseif (not value) then
            value = Class[key] or (Controller.Parent and Controller.Parent[key]); -- problem chaining

            if (type(value) == "function") then
                ProxyFunction.Instance = instance; -- 1st argument of ProxyFunction call
                ProxyFunction.Private = Controller.PrivateInstanceData[tostring(instance)]; -- 2nd argument of ProxyFunction call (Private Instance data)   
            end
        end
        
        return value;
    end

    -- create a value
    InstanceMT.__newindex = function(instance, key, value)
        local ProxyInstance = Controller.PrivateInstanceData[tostring(instance)];

        if (Class[key] and Controller.Locked) then
            error(string.format("LibObject: %s.%s is protected.", Controller.EntityName, key));
        else
            if (type(value) == "function") then                
                Private:AttachDefines(Controller, key);
            end
            ProxyInstance[key] = value;
        end
    end

    InstanceMT.__gc = function(self)
        self:Destroy();
    end

    -- create instance of class (static only)
    ClassMT.__call = function(_, ...)    
        local instance = {};
        local instanceData = {};

        Controller.PrivateInstanceData[tostring(instance)] = instanceData;    
        Controller.ProxyInstances[tostring(instance)] = {}; 
        setmetatable(instance, InstanceMT);

        if (Controller.CloneFrom) then
            local other = Controller.CloneFrom;
            local otherData = Controller.PrivateInstanceData[tostring(other)];
            
            if (not otherData) then
                error("LibObject: Invalid Clone Object.");
            end

            for key, value in pairs(otherData) do
                instanceData[key] = value;
            end

            Controller.CloneFrom = nil;

        elseif (ProxyClass._Constructor) then
            instance:_Constructor(...);
        end

        return instance;
    end

    ClassMT.__index = function(entity, key) -- object: instance or class table
        local value = ProxyClass[key];

        if (type(value) == "function") then
            value = ProxyFunction:Setup(ProxyClass, key, entity, Controller);        

        elseif (not value) then
            value = Controller.Parent and Controller.Parent[key];

            if (type(value) == "function") then
                ProxyFunction.Instance = entity; -- 1st argument of ProxyFunction call
            end
        end

        return value;
    end

    -- set new value (always true)
    ClassMT.__newindex = function(class, key, value)
        if (key ~= "Static") then
            if (ProxyClass[key] and Controller.Locked) then
                error(string.format("LibObject: %s.%s is protected.", Controller.EntityName, key));
            end

            if (type(value) == "function") then                
                Private:AttachDefines(Controller, key);
                ProxyClass[key] = value;
            else
                Class.Static[key] = value;
            end
        else
            error(string.format("LibObject: %s.Static property is protected.", Controller.EntityName));
        end
    end
    
    setmetatable(Class, ClassMT);
    Controllers[tostring(Class)] = Controller;
    return Class;
end

function LibObject:CreateInterface(interfaceName, ...)
    local Interface = {};
    local InterfaceController = {};

    Interface.Static = {};

    Controller.EntityName = interfaceName;
    Controller.Definitions = {};
	Controller.IsInterface = true;  

    Controllers[tostring(Interface)] = InterfaceController;
    return Interface;
end

function LibObject:Import(namespace, subset)
    local package = core.RootPackage;
	local command;

    for id, key in ipairs({strsplit(".", namespace)}) do    
        assert(not Private:IsStringNilOrWhiteSpace(key), "LibObject.Import: Invalid namespace argument.");   
		package = package[key];
        assert(package, string.format("LibObject.Import: Invalid namespace \"%s\".", namespace));
		
		if (key == "*" or key == "+" or key == "-") then
			command = key;			
			package = Private:GetNameSpaceList(package, key, subset);	
			break;
		end
    end

    return package;
end

function LibObject:Export(entity, namespace)
    local package = core.RootPackage;
    local controller = Controllers[tostring(entity)];

    assert(controller, "LibObject.Export: Invalid entity argument.");

    if (not Private:IsStringNilOrWhiteSpace(namespace)) then
        for id, key in ipairs({strsplit(".", namespace)}) do        
            assert(not Private:IsStringNilOrWhiteSpace(key), "LibObject.Import: Invalid namespace argument.");

            key = key:gsub("%s+", "");
            package[key] = package[key] or {};
            package = package[key];
        end
    end

    assert(not package[controller.EntityName], "LibObject.Export: Path already in use.");
    package[controller.EntityName] = entity;
end

-- prevents other functions being added or modified
function LibObject:LockClass(class)
	local controller = Controllers[tostring(class)];

    assert(controller and controller.IsClass, "LibObject.LockClass: Unknown entity supplied.");
	controller.Locked = true;
end

function LibObject:DefineParams(...)
    Private:DefineFunction(DefineParams, ...);    
end

function LibObject:DefineReturns(...)
    Private:DefineFunction(DefineReturns, ...); 
end

function LibObject:Implements(funcName)
	if (DefineImplements) then
		error(string.format("LibObject: %s was not implemented", funcName));	
	end

	DefineImplements = funcName;
end

-------------------------------------
-- ProxyFunction
-------------------------------------
ProxyFunction.Run = function(self, ...)
    local definition, message = Private:GetParamsDefinition();

    Private:ValidateFunction(definition, message, ...);

    if (not ProxyFunction.Private) then     
        error(string.format("LibObject: %s.%s is a non static " .. 
                "function and must be invoked by an instance object.", 
                ProxyFunction.Controller.EntityName, ProxyFunction.Key));
    end

    definition, message = Private:GetReturnsDefinition();
    return Private:ValidateFunction(definition, message,
                ProxyFunction.Object[ProxyFunction.Key](ProxyFunction.Instance, ProxyFunction.Private, ...));
end

function ProxyFunction:Setup(proxy, key, object, controller)
    self.Object         = proxy;
    self.Key            = key; -- indicates which function to call through ProxyFunction
    self.Instance       = object; -- 1st argument of ProxyFunction call
    self.Private        = controller.PrivateInstanceData[tostring(object)]; -- 2nd argument of ProxyFunction call (Private Instance data)       
    self.Controller     = controller;
    return self.Run;
end

-------------------------------------
-- Events
-------------------------------------
local frame = CreateFrame("Frame");
frame:RegisterEvent("ADDON_LOADED");

frame:SetScript("OnEvent", function(self, _, otherAddonName)
	-- iterate over every class to check if it has implemented the interface functions
    if (addonName == otherAddonName) then
        self:UnregisterEvent("ADDON_LOADED");

        -- check all interfaces to make sure loaded correctly.
    end
end);

-------------------------------------
-- Private Functions
-------------------------------------
function Private:EmptyTable(tbl)
    for key, _ in pairs(tbl) do
        tbl[key] = nil;
    end
end

function Private:AttachDefines(Controller, funcKey)
    if (#DefineParams > 0 or #DefineReturns > 0) then

        local funcDef = {};

        for key, value in pairs(DefineParams) do
            funcDef.Params = funcDef.Params or {};
            funcDef.Params[key] = value;
        end
    
        for key, value in pairs(DefineReturns) do
            funcDef.Returns = funcDef.Returns or {};
            funcDef.Returns[key] = value;
        end

        Private:EmptyTable(DefineParams);
        Private:EmptyTable(DefineReturns);

        if (Controller.Definitions[funcKey]) then
            error(string.format("LibObject: %s.%s Definition already exists.", 
                                                    Controller.EntityName, funcKey));
        end

        Controller.Definitions[funcKey] = funcDef;
    end
end

function Private:SetClassInterfaces(controller, implements)  
	controller.Interfaces = {};
	
    if (not Private:IsStringNilOrWhiteSpace(implements)) then
        for id, interface in ipairs({strsplit(",", implements)}) do 			
            if (not Private:IsStringNilOrWhiteSpace(interface)) then
                interface = interface:gsub("%s+", "");			
                table.insert(controller.Interfaces, LibObject:Import(interface));
            end
        end	
    end
end

function Private:GetNameSpaceList(package, modifier, subset)

	local list = core.RootPackage.Framework.Collections.List();
	
	for _, value in ipairs(package) do
		if (type(value) == "table" and value.GetObjectType) then
			list:Add(value);
		end		
	end	
		
	if (modifier ~= "*") then	
		local formattedSubset = {};
		
		for id, element in ipairs({strsplit(",", subset)}) do 
			if (not Private:IsStringNilOrWhiteSpace(element)) then
				table.insert(formattedSubset, element:gsub("%s+", ""));
			end
		end
		
		if (modifier == "+") then
			list:RetainAll(unpack(formattedSubset));			
		elseif (modifier == "-") then
			list:RemoveAll(unpack(formattedSubset));			
		end
	end
	
	return list;
end

<<<<<<< HEAD
-- definitions types: string, number, table, function, any
function Private:ValidateArgs(Controller, funcKey, ...)

    local definition = Controller.Definitions[funcKey];

    if (definition) then
        local id = 1;
        local arg = (select(id, ...));

        repeat
            -- validate arg:
            if (definition[id]) then
                if (not arg) then
                    error(string.format("LibObject: Required argument not supplied for %s.%s", 
                                                        Controller.EntityName, funcKey));
                elseif (type(arg) ~= definition[id]) then
                    error(string.format("LibObject: Incorrect argument type supplied for %s.%s", 
                                                        Controller.EntityName, funcKey));
                end
            elseif (definition.Optional[id]) then
                if (arg and type(arg) ~= definition[id]) then
                    error(string.format("LibObject: Incorrect argument type supplied for %s.%s", 
                                                        Controller.EntityName, funcKey));
                end
            else
                error(string.format("LibObject: Incorrect arguments supplied for %s.%s", 
                                                        Controller.EntityName, funcKey));
            end

            id = id + 1;
            arg = (select(id, ...));

        until (not definition[id]);
    end

    return ...;
end
local new;

--\\ TODO:
function Private:ValidateReturns(definition, ...)
    return ...;
end

=======
>>>>>>> 8f1d38046f7e3744c8ad8b4cdebb3563fcc1152d
function Private:FillTable(tbl, ...)
    local id = 1;
    local arg = (select(id, ...));
    self:EmptyTable(tbl);

    repeat    
        tbl[id] = arg;
        id = id + 1;
        arg = (select(id, ...));
    until (not arg);
end

function Private:IsStringNilOrWhiteSpace(string)
    if (string) then
        string = string:gsub("%s+", "");
        if (#string > 0) then
            return false;
        end
    end
    return true;
end

function Private:SetClassParent(controller, parent)
	if (parent) then
		if (type(parent) == "string" and not Private:IsStringNilOrWhiteSpace(parent)) then
			controller.Parent = LibObject:Import(parent); -- needs testing (is namespace required?)
		
		elseif (type(parent) == "table" and parent.Static) then
			controller.Parent = parent;
		end

        assert(controller.Parent, "(LibObject) Private.SetClassParent: Invalid parent argument.");

	elseif (Private:PathExists(core, "RootPackage.Framework.Generics.Object")) then
        controller.Parent = core.RootPackage.Framework.Generics.Object;
    end
end

function Private:PathExists(root, path)
    assert(root, "(LibObject) Privatge.PathExists: Invalid root argument.");

    for _, key in ipairs({strsplit(".", path)}) do
        if (not root[key]) then
            return false;
        end
        root = root[key];
    end

    return true;
end

function Private:GetController(entity)
    local class = getmetatable(entity).Class;
    local controller = Controllers[tostring(class)];

	assert(controller, "(LibObject) Private.GetController: Invalid entity argument.");

    return controller;
end

function Private:DefineFunction(defTable, ...)
    local optionalFound = false;
    Private:EmptyTable(defTable);

    for id, valueType in ipairs({...}) do  
        if (not Private:IsStringNilOrWhiteSpace(valueType)) then    
            valueType = valueType:gsub("%s+", ""); 

            if (valueType:match("^%?")) then
                defTable.Optional = defTable.Optional or {};
                valueType = valueType:gsub("?", "");
                defTable.Optional[id] = valueType;

            elseif (defTable.Optional) then
                error("(LibObject) Private.DefineFunction: Optional values must appear at the end of the definition list.");
            else
                defTable[id] = valueType;
            end
        end
    end
end

function Private:ValidateFunction(definition, message, ...)
    local errorFound;

    if (definition) then

        local id = 1;
        local arg = (select(id, ...));

        repeat      
            -- validate arg:
            if (definition[id]) then
                errorFound = (not arg) or type(arg) ~= definition[id];

            elseif (definition.Optional and definition.Optional[id]) then
                errorFound = arg and type(arg) ~= definition.Optional[id];

            else
                errorFound = true;                 
            end

            if (errorFound) then
                error(message);
            end

            id = id + 1;
            arg = (select(id, ...));

        until (not (definition[id] or definition.Optional and definition.Optional[id]));
    end

    return ...;
end

function Private:GetParamsDefinition()
    local message = string.format("LibObject: Incorrect argument type[s] found for %s.%s", 
        ProxyFunction.Controller.EntityName, ProxyFunction.Key);

    local definition = ProxyFunction.Controller.Definitions[ProxyFunction.Key];
    definition = definition and definition.Params; 

    return definition, message;
end

function Private:GetReturnsDefinition()
    local message = string.format("LibObject: Incorrect return type[s] found for %s.%s", 
        ProxyFunction.Controller.EntityName, ProxyFunction.Key);

    local definition = ProxyFunction.Controller.Definitions[ProxyFunction.Key];
    definition = definition and definition.Returns; 

    return definition, message;
end