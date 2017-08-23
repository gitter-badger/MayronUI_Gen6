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
local DefineImplement = {};

local Controllers = {};
local ClassesImplementing = {}; -- classes that implement interfaces
local ProxyFunction = {};

core.Lib = LibObject;
core.Controllers = Controllers;
core.RootPackage = {};
core.Private = Private;

--------------------------------------------
-- LibObject Functions
--------------------------------------------
function LibObject:CreateClass(className, parent, ...)
    local Class = {};
    local Controller = {}; -- behind the scenes controller
    local ProxyClass = {}; -- redirect all Class keys to this   
    local ClassMT = {};

    local InstanceMT = {}; -- metatable for instances of class 
    local RawClassString = tostring(Class);

    ProxyClass.Static = {}; -- for static functions and properties

    Controller.Protected = false; -- true if functions and properties are to be protected
    Controller.EntityName = className;
    Controller.ProxyInstances = {}; -- redirect all instance keys to this  
    Controller.PrivateInstanceData = {}; -- for Class Private Instance functions and properties
    Controller.Definitions = {};
	Controller.IsClass = true;
    Controller.Class = Class;
    Controller.ProxyClass = ProxyClass;
	
    Private:SetClassParent(Controller, parent);
	Private:SetClassInterfaces(Controller, ...);    

    InstanceMT.Class = Class;
    ClassMT.Class = Class;

    -- get a value
    InstanceMT.__index = function(instance, key)
        local ProxyInstance = Controller.ProxyInstances[tostring(instance)];
        local value = ProxyInstance[key];

        if (not value) then
            value = Class[key];

            if (type(value) == "function") then
                ProxyFunction.Instance = instance;
                ProxyFunction.Private = Controller.PrivateInstanceData[tostring(instance)];  
            end
        end
        
        return value;
    end

    -- create a value
    InstanceMT.__newindex = function(instance, key, value)
        local ProxyInstance = Controller.PrivateInstanceData[tostring(instance)];

		if (type(value) == "function") then      
			Private:AttachDefines(Controller, key);
		end
		
		Private:Assert(type(value) ~= "function", "LibObject: Only unprotected classes can be assigned new function values (not instances).");
		ProxyInstance[key] = value;
    end

    InstanceMT.__gc = function(self)
        self:Destroy();
    end

    InstanceMT.__tostring = function(self)
        setmetatable(self, nil);
        local value = tostring(self);
        setmetatable(self, InstanceMT);
        return value:gsub("table", string.format("<Instance> %s", className));
    end

    -- create instance of class (static only)
    ClassMT.__call = function(_, ...)    
        local instance = {};
        local instanceData = {};

        setmetatable(instance, InstanceMT);
        Controller.PrivateInstanceData[tostring(instance)] = instanceData;    
        Controller.ProxyInstances[tostring(instance)] = {}; 

        if (Controller.CloneFrom) then
            local other = Controller.CloneFrom;
            local otherData = Controller.PrivateInstanceData[tostring(other)];

            Private:Assert(otherData, "LibObject: Invalid Clone Object.");
            instanceData = Private:CopyTable(otherData, instanceData);
            Controller.CloneFrom = nil;

        elseif (ProxyClass.__Construct) then
            instance:__Construct(...);
        end

        return instance;
    end

    ClassMT.__index = function(class, key)
        local value = ProxyClass[key];

        if (type(value) == "function") then
            value = ProxyFunction:Setup(ProxyClass, key, class, Controller);        

        elseif (not value) then
            value = Controller.Parent and Controller.Parent[key];

            if (type(value) == "function") then
                ProxyFunction.Instance = class;
            end
        end

        return value;
    end

    -- set new value (always true)
    ClassMT.__newindex = function(class, key, value)
        if (key ~= "Static") then
            if (Controller.Protected) then
                Private:Error(string.format("LibObject: %s is protected.", Controller.EntityName));
            end

            if (type(value) == "function") then
                Private:AttachDefines(Controller, key);
                ProxyClass[key] = value;				
			else
                Private:Error(string.format("LibObject: Static properties must be located in %s.Static.", Controller.EntityName));
            end
            	
        else
            Private:Error(string.format("LibObject: %s.Static property is protected.", Controller.EntityName));
        end
    end

    ClassMT.__tostring = function()
        return RawClassString:gsub("table", string.format("<Class> %s", className));
    end
    
    setmetatable(Class, ClassMT);
    Controllers[tostring(Class)] = Controller;
    return Class;
end

function LibObject:CreateInterface(interfaceName)
    local Interface = {};
    local Controller = {};
	local InterfaceMT = {};	

    Controller.Protected = false; -- true if functions and properties are to be protected
    Controller.EntityName = interfaceName;
    Controller.Definitions = {};
	Controller.IsInterface = true;
    Controller.Interface = Interface;
	
	InterfaceMT.__newindex = function(interface, key, value)
		if (type(value) == "function") then            
			Private:AttachDefines(Controller, key);
		end	
		rawset(interface, key, value);
	end

	setmetatable(Interface, InterfaceMT);
    Controllers[tostring(Interface)] = Controller;
    return Interface;
end

function LibObject:Import(namespace, subset)
    local package = core.RootPackage;

    for id, key in ipairs({strsplit(".", namespace)}) do    
        Private:Assert(not Private:IsStringNilOrWhiteSpace(key), "LibObject.Import: bad argument #1 (invalid namespace).");

		if (key == "*" or key == "+" or key == "-") then
			package = Private:GetNameSpaceMap(package, key, subset);	
            break;
		else
            package = package[key];
            Private:Assert(package, string.format("LibObject.Import: bad argument #1 (invalid namespace \"%s\").", namespace));
        end
    end

    Private:Assert(Controllers[tostring(package)] or package.IsObjectType and package:IsObjectType("Map"), "LibObject.Import: bad argument #1 (invalid namespace).");

    return package;
end

function LibObject:Export(namespace, ...)
    local package = core.RootPackage;
    local controller;

    if (not Private:IsStringNilOrWhiteSpace(namespace)) then
        for id, key in ipairs({strsplit(".", namespace)}) do        
            Private:Assert(not Private:IsStringNilOrWhiteSpace(key), "LibObject.Import: bad argument #1 (invalid namespace).");
            key = key:gsub("%s+", "");
            package[key] = package[key] or {};
            package = package[key];
        end
    end

    for id, entity in ipairs({...}) do
        controller = Controllers[tostring(entity)];
        Private:Assert(controller, string.format("LibObject.Export: bad argument #%s (not entity found).", id + 1));
        Private:Assert(not package[controller.EntityName], string.format("LibObject.Export: bad argument #%s (path already in use).", id + 1));        
        package[controller.EntityName] = entity;
    end
end

-- prevents other functions being added or modified
function LibObject:ProtectClass(class)
	local controller = Controllers[tostring(class)];

    Private:Assert(controller and controller.IsClass, "LibObject.ProtectClass: bad argument #1 (class not found).");
	controller.Protected = true;
end

function LibObject:DefineParams(...)
    Private:DefineFunction(DefineParams, ...);    
end

function LibObject:DefineReturns(...)
    Private:DefineFunction(DefineReturns, ...); 
end

function LibObject:Implements(funcName)
    Private:Assert(not DefineImplement.FuncKey, string.format("LibObject: %s was not implemented", funcName));
	DefineImplement.FuncKey = funcName;
end

function LibObject:SetSilentErrors(silent)
    Private.silent = silent;
end

function LibObject:GetErrorLog()
    return Private.errorLog;
end

function LibObject:FlushErrorLog()
    Private:EmptyTable(Private.errorLog);
end

-------------------------------------
-- ProxyFunction
-------------------------------------
ProxyFunction.Run = function(self, ...)
    local definition, message = Private:GetParamsDefinition();

    Private:ValidateFunction(definition, message, ...);

    if (not ProxyFunction.Private) then

        if (ProxyFunction.Controller.IsInterface) then
            Private:Error(string.format("LibObject: %s.%s is an interface function " .. 
                    "and must be implemented and invoked by an instance object.", 
                    ProxyFunction.Controller.EntityName, ProxyFunction.Key));
        else
            Private:Error(string.format("LibObject: %s.%s is a non static " .. 
                    "function and must be invoked by an instance object.", 
                    ProxyFunction.Controller.EntityName, ProxyFunction.Key));
        end
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
    if (addonName == otherAddonName) then
        self:UnregisterEvent("ADDON_LOADED");

        for _, class in ipairs(ClassesImplementing) do
            local controller = Controllers[tostring(class)];

            for _, interface in ipairs(controller.Interfaces) do
                for key, value in pairs(interface) do
                    if (type(value) == "function") then

                        Private:Assert(controller.ProxyClass[key], string.format(
                            "LibObject: %s does not implement interface function '%s'.", controller.EntityName, key));

                        Private:Assert(not controller.ImplementFunctions[key], string.format(
                            "LibObject: Missing \"lib:Implements('%s')\" function declaration.", key));                        
                    end

                end
            end

            for key, _ in pairs(controller.ImplementFunctions) do
                Private:Error(string.format(
                    "LibObject: %s does not implement interface function '%s'.", controller.EntityName, key));
            end
        end
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

function Private:AttachDefines(controller, funcKey)
    if (DefineImplement.FuncKey) then
        Private:Assert(DefineImplement.FuncKey == funcKey, 
            string.format("LibObject: %s does not implement interface function '%s'.", 
                controller.EntityName, DefineImplement.FuncKey));

		local interfaceDefFound = false;
        for _, interface in ipairs(controller.Interfaces) do
            if (interface[funcKey]) then			
				Private:Assert(not interfaceDefFound, 
				    string.format("LibObject: Multiple interface definitions found for function '%s'", funcKey)); 
			
                local interfaceController = Controllers[tostring(interface)];
                local funcDef = interfaceController.Definitions[funcKey]; -- a nil value

                if (funcDef) then
                    DefineParams = funcDef.Params;
                    DefineReturns = funcDef.Returns;
                end

                DefineImplement.FuncKey = nil;
				interfaceDefFound = true;
                controller.ImplementFunctions[funcKey] = nil;
            end
        end
        Private:Assert(interfaceDefFound, 
            string.format("LibObject: Failed to find interface definition for function '%s'", funcKey)); 
    end

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

        Private:Assert(not controller.Definitions[funcKey], 
                string.format("LibObject: %s.%s Definition already exists.",  
                        controller.EntityName, funcKey));

        controller.Definitions[funcKey] = funcDef;
    end
end

function Private:SetClassInterfaces(controller, ...) 
	controller.Interfaces = {};    
    controller.ImplementFunctions = {};

    for id, interface in ipairs({...}) do
        if (type(interface) == "string") then
            interface = LibObject:Import(interface);
        end

        local interfaceController = Controllers[tostring(interface)];
        if (interfaceController and interfaceController.IsInterface) then

            for key, value in pairs(interface) do
                if (type(value) == "function") then

                    Private:Assert(not controller.ImplementFunctions[key], 
                        string.format("LibObject: '%s' cannot implement function '%s', " ..
                        "as 2 or more interfaces share the same function key.", controller.EntityName, key));

                    controller.ImplementFunctions[key] = true;
                end
            end

            table.insert(controller.Interfaces, interface);           
        else
            Private:Error(string.format("(LibObject) Private.SetClassInterfaces: bad argument #%d (invalid interface)", id));
        end
    end 

    if (#controller.Interfaces > 0) then
        
        table.insert(ClassesImplementing, controller.Class);
    end   
end

function Private:GetNameSpaceMap(package, command, subset)
	local map = core.RootPackage.Framework.Collections.Map();

	for key, value in pairs(package) do
		if (type(value) == "table" and Controllers[tostring(value)]) then
			map:Add(key, value);
		end
	end	
		
	if (command ~= "*") then	
		local formattedSubset = {};
		
		for id, element in ipairs({strsplit(",", subset)}) do 
			if (not Private:IsStringNilOrWhiteSpace(element)) then
				table.insert(formattedSubset, element:gsub("%s+", ""));
			end
		end
		
		if (command == "+") then
			map:RetainAll(unpack(formattedSubset));			
		elseif (command == "-") then
			map:RemoveAll(unpack(formattedSubset));			
		end
	end
	
	return map;
end

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

function Private:IsStringNilOrWhiteSpace(strValue)       
    if (strValue) then

        Private:Assert(type(strValue) == "string", string.format(
            "(LibObject) Private.IsStringNilOrWhiteSpace: bad argument #1 (string expected, got %s)", type(strValue)));

        strValue = strValue:gsub("%s+", "");
        if (#strValue > 0) then
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

        Private:Assert(controller.Parent, "(LibObject) Private.SetClassParent: bad argument #2 (invalid parent class).");

	elseif (Private:PathExists(core, "RootPackage.Framework.Generics.Object")) then
        controller.Parent = core.RootPackage.Framework.Generics.Object;
    end
end

function Private:PathExists(root, path)
    Private:Assert(root, "(LibObject) Privatge.PathExists: bad argument #1 (invalid root).");

    for _, key in ipairs({strsplit(".", path)}) do
        if (not root[key]) then
            return false;
        end
        root = root[key];
    end

    return true;
end

function Private:GetController(entity)
    local controller = Controllers[tostring(entity)];

    if (controller) then
        return controller;
    end

    local class = getmetatable(entity).Class;
    controller = Controllers[tostring(class)];
	Private:Assert(controller, "(LibObject) Private.GetController: bad argument #1 (invalid entity).");

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
                Private:Error("(LibObject) Private.DefineFunction: Optional values must appear at the end of the definition list.");
            else
                defTable[id] = valueType;
            end
        end
    end
end

function Private:ValidateFunction(definition, message, ...)
    local errorFound;
    local errorMessage;
    local defValue;

    if (definition) then
        local id = 1;
        local arg = (select(id, ...));        

        repeat
            if (definition[id]) then
                errorFound = (arg == nil) or (definition[id] ~= "any" and definition[id] ~= type(arg));
                defValue = definition[id];
            elseif (definition.Optional and definition.Optional[id]) then
                errorFound = (arg ~= nil) and (definition.Optional[id] ~= "any" and definition.Optional[id] ~= type(arg));
                defValue = definition.Optional[id];
            else
                errorFound = true; 
                defValue = "nil";              
            end

            errorMessage = string.format(message .. " (%s expected, got %s)", defValue, tostring(type(arg)));
            errorMessage = errorMessage:gsub("##", "#" .. tostring(id));
            Private:Assert(not errorFound, errorMessage);

            id = id + 1;
            arg = (select(id, ...));

        until (not (definition[id] or definition.Optional and definition.Optional[id]));
    end

    return ...;
end

function Private:GetParamsDefinition()
    local message = string.format("LibObject: bad argument ## to '%s.%s'", 
        ProxyFunction.Controller.EntityName, ProxyFunction.Key);

    local definition = ProxyFunction.Controller.Definitions[ProxyFunction.Key];
    definition = definition and definition.Params; 

    return definition, message;
end

function Private:GetReturnsDefinition()
    local message = string.format("LibObject: bad return value ## to '%s.%s'", 
        ProxyFunction.Controller.EntityName, ProxyFunction.Key);

    local definition = ProxyFunction.Controller.Definitions[ProxyFunction.Key];
    definition = definition and definition.Returns; 

    return definition, message;
end

function Private:CopyTable(tbl, copy)
    copy = copy or {};
    for key, value in pairs(tbl) do
        if (type(value) == "table") then
            copy[key] = Private:CopyTable(value);
        else
            copy[key] = value;
        end 
    end
    return copy;
end

function Private:Assert(condition, errorMessage)
    if (not condition) then
        if (self.silent) then
            self.errorLog = self.errorLog or {};
            self.errorLog[#self.errorLog + 1] = pcall(function() error(errorMessage) end);
        else
            error(errorMessage);
        end
    end
end

function Private:Error(errorMessage)
    self:Assert(false, errorMessage);
end