local addonName, Core = ...;

local Lib = LibStub:NewLibrary("LibObjectLua", 2.1);
if (not Lib) then return; end

local error, assert, rawget, rawset = error, assert, rawget, rawset;
local type, setmetatable, table, string = type, setmetatable, table, string;
local getmetatable, unpack, select = getmetatable, unpack, select;

local Controllers = {}; -- meta-data for objects and interfaces.
local ClassesImplementing = {}; -- a list of classes that implement interfaces.

local ProxyStack = {}; -- handles parameter and return value validation when executing functions.
ProxyStack.FuncStrings = {}; -- contains functions converted to strings to track function locations when inheritance is used.

Core.Lib = Lib;
Core.PREFIX = "|cffffcc00LibObjectLua: |r";
Core.Controllers = Controllers;
Core.Packages = {}; -- contains all packages exported.

--------------------------------------------
-- LibObjectLua Functions
--------------------------------------------
-- @param packageName (string) - the name of the package.
-- @param namespace (string) - the parent package namespace. Example: "Framework.System.Package".
-- @return package (Package) - returns a package object.
function Lib:CreatePackage(packageName, namespace)
    local Package = Lib:Import("Framework.System.Package");
    local newPackage = Package(packageName);

    if (not Core:IsStringNilOrWhiteSpace(namespace)) then
        self:Export(newPackage, namespace);
    end

    return newPackage;   
end

-- @param namespace (string) - the entity namespace (required for locating it).
--      (an entity = a package, class or interface).
-- @param silent (boolean) - if true, no error will be triggered if the entity cannot be found.
-- @return entity (Package, or class/interface) - returns the found entity (or false if silent).
function Lib:Import(namespace, silent)
    local package = Core.Packages;
    local currentNamespace = "";

    local nodes = Core:PopWrapper(strsplit(".", namespace))
    for id, key in ipairs(nodes) do

        Core:Assert(not Core:IsStringNilOrWhiteSpace(key), "Import - bad argument #1 (invalid entity name).");

        if (id > 1) then
            currentNamespace = string.format("%s.%s", currentNamespace, key);
            package = package:Get(key);
        else
            currentNamespace = key;
            package = package[key];
        end        

        if (not package and silent) then
            return false;
        end

        if (id < #nodes) then
            Core:Assert(package, "Import - bad argument #1 ('%s' package not found).", currentNamespace);
        else
            Core:Assert(package, "Import - bad argument #1 ('%s' entity not found).", currentNamespace);
        end        
    end

    Core:Assert(Controllers[tostring(package)] or package.IsObjectType and package:IsObjectType("Package"), 
        "Import - bad argument #1 (invalid namespace '%s').", namespace);

    return package;
end

-- @param package (Package) - a package instance object.
-- @param namespace (string) - the package namespace (required for locating and importing it).
function Lib:Export(package, namespace)
    local controller = Core:GetController(package);
    local parentPackage;

    Core:Assert(not Core:IsStringNilOrWhiteSpace(namespace), 
        "Export - bad argument #2 (invalid namespace)");

    Core:Assert(controller and controller.IsPackage, 
        "Export - bad argument #1 (package expected)");

    for id, key in Core:IterateArgs(strsplit(".", namespace)) do 

        Core:Assert(not Core:IsStringNilOrWhiteSpace(key),
            "Export - bad argument #2 (invalid namespace).");

        key = key:gsub("%s+", "");

        if (id > 1) then
            if (not parentPackage:Get(key)) then
                parentPackage:AddSubPackage(Lib:CreatePackage(key));
            end
            parentPackage = parentPackage:Get(key);
        else
            Core.Packages[key] = Core.Packages[key] or Lib:CreatePackage(key);
            parentPackage = Core.Packages[key];
        end
    end

    parentPackage:AddSubPackage(package);        
end

-- @param silent (boolean) - true if errors should be cause in the error log instead of triggering.
function Lib:SetSilentErrors(silent)
    Core.silent = silent;
end

-- @return errorLog (table) - contains index/string pairs of errors caught while in silent mode.
function Lib:GetErrorLog()
    Core.errorLog = Core.errorLog or {};
    return Core.errorLog;
end

-- empties the error log table.
function Lib:FlushErrorLog()
    if (Core.errorLog) then
        Core:EmptyTable(Core.errorLog);
    end
end

-- @return numErrors (number) - the total number of errors caught while in silent mode.
function Lib:GetNumErrors()
    return (Core.errorLog and #Core.errorLog) or 0;
end

-------------------------------------
-- ProxyStack
-------------------------------------
-- intercepts function calls on classes and instance objects and returns a proxy function used for validation. 
-- @param proxyEntity (table) - a table containing all functions assigned to a class or interface.
-- @param key (string) - the function name/key being called.
-- @param entity (table) - the instance or class object originally being called with the function name/key.
-- @param controller (table) - the entities meta-data (stores validation rules and more).
-- @return proxyFunc (function) - the proxy function is returned and called instead of the real function.
function ProxyStack:Pop(proxyEntity, key, entity, controller) 
    local proxyFunc;
   
    if (#self == 0) then   
        proxyFunc = setmetatable({}, ProxyStack.MT);
    else
        proxyFunc = self[#self];
        self[#self] = nil;
    end

    proxyFunc.Object        = proxyEntity;
    proxyFunc.Key           = key;
    proxyFunc.Self          = entity;
    proxyFunc.Private       = controller.PrivateInstanceData[tostring(entity)];
    proxyFunc.Controller    = controller;

    proxyFunc.Run = proxyFunc.Run or function(_, ...)    
        local definition, message = Core:GetParamsDefinition(proxyFunc);    
        Core:ValidateFunction(definition, message, ...);

        if (not proxyFunc.Private) then

            if (proxyFunc.Controller.IsInterface) then
                Core:Error("%s.%s is an interface function and must be implemented and invoked by an instance object.", 
                        proxyFunc.Controller.EntityName, proxyFunc.Key);
            else  
                Core:Error("%s.%s is a non static function and must be invoked by an instance object.", 
                        proxyFunc.Controller.EntityName, proxyFunc.Key);
            end
        end
        
        definition, message = Core:GetReturnsDefinition(proxyFunc);
        local returnValues =  Core:PopWrapper(
            Core:ValidateFunction(definition, message, proxyFunc.Object[proxyFunc.Key](proxyFunc.Self, proxyFunc.Private, ...)) 
        );

        if (proxyFunc.Key ~= "Destroy") then
            Core:GetController(proxyFunc.Self).UsingChild = nil;
        end

        ProxyStack:Push(proxyFunc);       

        return Core:UnpackWrapper(returnValues);
    end

    ProxyStack.FuncStrings[tostring(proxyFunc.Run)] = proxyFunc;

    return proxyFunc.Run;
end

-- Pushes the proxy function back into the stack object once no longer needed.
-- Also, resets the state of the proxy function for future use.
-- @param proxyFunc (function) - a proxy function returned from ProxyStack:Pop();
function ProxyStack:Push(proxyFunc)
    self[#self + 1] = proxyFunc;

    proxyFunc.Object        = nil;
    proxyFunc.Key           = nil;
    proxyFunc.Self          = nil;
    proxyFunc.Private       = nil;
    proxyFunc.Controller    = nil;

    ProxyStack.FuncStrings[tostring(proxyFunc.Run)] = nil;
end

-- @param func (function) - converts function to string to be used as a key to access the corresponding proxy function.
-- @return proxyFunc (function) - the proxy function (called instead of real functions for validation).
function ProxyStack:Get(func)
    return ProxyStack.FuncStrings[tostring(func)];
end

-------------------------------------
-- Events
-------------------------------------
-- Only executed once when the game starts-up.
-- Checks if all interfaces have been successfully implemented by classes using them.
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

                        Core:Assert(controller.ProxyClass[key],
                            "Class '%s' does not implement interface function '%s'.", controller.EntityName, key);

                        Core:Assert(not controller.ImplementFunctions[key], 
                            "Missing \"lib:Implements('%s')\" function declaration.", key);                        
                    end

                end
            end

            for key, _ in pairs(controller.ImplementFunctions) do
                Core:Error("Class '%s' does not implement interface function '%s'.", controller.EntityName, key);
            end
        end
    end
end);

-----------------------------------------------------
-- Core Functions (not accessible outside of AddOn)
-----------------------------------------------------
function Core:CreateClass(packageData, className, parentClass, ...)
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
    Controller.PrivateInstanceData = {}; -- for Class Core Instance functions and properties
    Controller.Definitions = {};
	Controller.IsClass = true;
    Controller.Class = Class;
    Controller.ProxyClass = ProxyClass;

    Controller.PackageData = packageData;
    Controller.IsPackage = not packageData;
	
    self:SetParentClass(Controller, parentClass);
    self:SetInterfaces(Controller, ...);    

    InstanceMT.Class = Class;

    -- get a value
    InstanceMT.__index = function(instance, key)        
        local ProxyInstance = Controller.ProxyInstances[tostring(instance)];
        local value = ProxyInstance[key];

        if (not value) then
            value = Class[key];

            if (type(value) == "function") then                
                local proxyFunc = ProxyStack:Get(value);
                proxyFunc.Self = instance;
                proxyFunc.Private = Controller.PrivateInstanceData[tostring(instance)];  
            end
        end
        
        return value;
    end

    -- create a value
    InstanceMT.__newindex = function(instance, key, value)
        local ProxyInstance = Controller.PrivateInstanceData[tostring(instance)];

		if (type(value) == "function") then      
			self:AttachDefines(Controller, key);
		end
		
		self:Assert(type(value) ~= "function", "Only unprotected classes can be assigned new function values (not instances).");
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

            self:Assert(otherData, "Invalid Clone Object.");
            instanceData = self:CopyTable(otherData, instanceData);
            Controller.CloneFrom = nil;

        elseif (ProxyClass.__Construct) then
            instance:__Construct(...);
        end

        return instance;
    end

    ClassMT.__index = function(class, key)
        local value = ProxyClass[key];
        local child = Controller.UsingChild;
        
        if (type(value) == "function") then
            value = ProxyStack:Pop(ProxyClass, key, class, Controller);

        elseif (not value) then
            value = (Controller.ParentClass and Controller.ParentClass[key]) or nil;

            if (type(value) == "function") then
                local proxyFunc = ProxyStack:Get(value);
                proxyFunc.Self = class;
            end
        end

        if (child and type(value) == "function") then
            local proxyFunc = ProxyStack:Get(value);
            local childController = Core:GetController(child);    
            proxyFunc.Private = childController.PrivateInstanceData[tostring(child)];
        end 

        return value;
    end

    -- set new value (always true)
    ClassMT.__newindex = function(class, key, value)
        if (key ~= "Static") then
            if (Controller.Protected) then
                self:Error("%s is protected.", Controller.EntityName);
            end

            if (type(value) == "function") then
                self:AttachDefines(Controller, key);
                ProxyClass[key] = value;				
			else
                self:Error("Static properties must be located in %s.Static.", Controller.EntityName);
            end
            	
        else
            self:Error("%s.Static property is protected.", Controller.EntityName);
        end
    end

    ClassMT.__tostring = function()
        return RawClassString:gsub("table", string.format("<Class> %s", className));
    end
    
    setmetatable(Class, ClassMT);
    Controllers[tostring(Class)] = Controller;

    return Class;
end

function Core:CreateInterface(packageData, interfaceName)
    local Interface = {};
    local Controller = {};
	local InterfaceMT = {};	

    Controller.Protected = false; -- true if functions and properties are to be protected
    Controller.EntityName = interfaceName;
    Controller.Definitions = {};
	Controller.IsInterface = true;
    Controller.Interface = Interface;

    Controller.PackageData = packageData;
    Controller.IsPackage = not packageData;
	
	InterfaceMT.__newindex = function(interface, key, value)
		if (type(value) == "function") then            
			self:AttachDefines(Controller, key);
		end	
		rawset(interface, key, value);
	end

	setmetatable(Interface, InterfaceMT);
    Controllers[tostring(Interface)] = Controller;

    return Interface;
end

function Core:EmptyTable(tbl)
    for key, _ in pairs(tbl) do
        tbl[key] = nil;
    end
end

function Core:AttachDefines(controller, funcKey)
    if (not controller.PackageData and controller.EntityName == "Package") then
        return;
    end

    local implement = controller.PackageData.defineImplement;
    local params = controller.PackageData.defineParams;
    local returns = controller.PackageData.defineReturns;

    if (implement.FuncKey) then
        self:Assert(implement.FuncKey == funcKey, "%s does not implement interface function '%s'.", 
                controller.EntityName, implement.FuncKey);

		local interfaceDefFound = false;
        for _, interface in ipairs(controller.Interfaces) do
            if (interface[funcKey]) then			
				self:Assert(not interfaceDefFound, "Multiple interface definitions found for function '%s'", funcKey); 
			
                local interfaceController = Controllers[tostring(interface)];
                local funcDef = interfaceController.Definitions[funcKey];

                if (funcDef) then
                    params = funcDef.Params or params;
                    returns = funcDef.Returns or returns;
                end

                implement.FuncKey = nil;
				interfaceDefFound = true;
                controller.ImplementFunctions[funcKey] = nil;
            end
        end
        self:Assert(interfaceDefFound, "Failed to find interface definition for function '%s'", funcKey); 
    end

    if (#params > 0 or #returns > 0) then
        local funcDef = {};

        for key, value in pairs(params) do
            funcDef.Params = funcDef.Params or {};
            funcDef.Params[key] = value;
        end
    
        for key, value in pairs(returns) do
            funcDef.Returns = funcDef.Returns or {};
            funcDef.Returns[key] = value;
        end

        self:EmptyTable(params);
        self:EmptyTable(returns);

        self:Assert(not controller.Definitions[funcKey], 
            "%s.%s Definition already exists.", controller.EntityName, funcKey);

        controller.Definitions[funcKey] = funcDef;
    end
end

function Core:SetInterfaces(controller, ...) 
	controller.Interfaces = {};    
    controller.ImplementFunctions = {};

    for id, interface in self:IterateArgs(...) do
        if (type(interface) == "string") then
            interface = Lib:Import(interface);
        end

        local interfaceController = Controllers[tostring(interface)];
        if (interfaceController and interfaceController.IsInterface) then

            for key, value in pairs(interface) do
                if (type(value) == "function") then

                    self:Assert(not controller.ImplementFunctions[key], 
                        "'%s' cannot implement function '%s', as 2 or more interfaces share the same function key.", 
                            controller.EntityName, key);

                    controller.ImplementFunctions[key] = true;
                end
            end

            table.insert(controller.Interfaces, interface);           
        else
            self:Error("Core.SetInterfaces: bad argument #%d (invalid interface)", id);
        end
    end 

    if (#controller.Interfaces > 0) then        
        table.insert(ClassesImplementing, controller.Class);
    end   
end

function Core:FillTable(tbl, ...)
    local id = 1;
    local arg = (select(id, ...));
    self:EmptyTable(tbl);

    repeat    
        tbl[id] = arg;
        id = id + 1;
        arg = (select(id, ...));
    until (not arg);
end

function Core:IsStringNilOrWhiteSpace(strValue)       
    if (strValue) then
        Core:Assert(type(strValue) == "string",
            "Core.IsStringNilOrWhiteSpace - bad argument #1 (string expected, got %s)", type(strValue));

        strValue = strValue:gsub("%s+", "");

        if (#strValue > 0) then
            return false;
        end
    end

    return true;
end

function Core:SetParentClass(controller, ParentClass)
	if (ParentClass) then
		if (type(ParentClass) == "string" and not self:IsStringNilOrWhiteSpace(ParentClass)) then
			controller.ParentClass = Lib:Import(ParentClass); -- needs testing (is namespace required?)
		
		elseif (type(ParentClass) == "table" and ParentClass.Static) then
			controller.ParentClass = ParentClass;
		end

        self:Assert(controller.ParentClass, "Core.SetParentClass - bad argument #2 (invalid parent class).");
	else
        controller.ParentClass = Lib:Import("Framework.System.Object", true);
    end
end

function Core:PathExists(root, path)
    self:Assert(root, "Core.PathExists - bad argument #1 (invalid root).");

    for _, key in self:IterateArgs(strsplit(".", path)) do
        if (not root[key]) then
            return false;
        end
        root = root[key];
    end

    return true;
end

function Core:GetController(entity)
    if (Controllers[tostring(entity)]) then
        return Controllers[tostring(entity)];
    end

    local metaTbl = getmetatable(entity);

    if (metaTbl and metaTbl.Class) then
        return Controllers[tostring(metaTbl.Class)];
    end

	self:Error("Core.GetController - bad argument #1 (invalid entity).");
end

function Core:GetPrivateInstanceData(instance)
    local controller = self:GetController(instance);
    return controller.PrivateInstanceData[tostring(instance)];
end

function Core:DefineFunction(defTable, ...)
    local optionalFound = false;
    self:EmptyTable(defTable);

    for id, valueType in self:IterateArgs(...) do  
        if (not self:IsStringNilOrWhiteSpace(valueType)) then    
            valueType = valueType:gsub("%s+", ""); 

            if (valueType:match("^%?")) then
                defTable.Optional = defTable.Optional or {};
                valueType = valueType:gsub("?", "");
                defTable.Optional[id] = valueType;

            elseif (defTable.Optional) then
                self:Error("Optional values must appear at the end of the definition list.");
            else
                defTable[id] = valueType;
            end
        end
    end
end

function Core:ValidateFunction(definition, message, ...)
    local errorFound;
    local errorMessage;
    local defValue;

    if (definition) then
        local id = 1;
        local arg = (select(id, ...));        

        repeat
            if (definition[id]) then
                errorFound = (arg == nil) or (definition[id] ~= "any" and not self:IsMatchingTypes(definition[id], arg));
                defValue = definition[id];

            elseif (definition.Optional and definition.Optional[id]) then

                errorFound = (arg ~= nil) and (definition.Optional[id] ~= "any" and not self:IsMatchingTypes(definition.Optional[id], arg));
                defValue = definition.Optional[id];

            else
                errorFound = true; 
                defValue = "nil";
            end

            errorMessage = string.format(message .. " (%s expected, got %s)", defValue, self:GetArgType(arg));
            errorMessage = errorMessage:gsub("##", "#" .. tostring(id));
            self:Assert(not errorFound, errorMessage);

            id = id + 1;
            arg = (select(id, ...));

        until (not (definition[id] or definition.Optional and definition.Optional[id]));
    end

    return ...;
end

function Core:GetParamsDefinition(proxyFunc)
    local message = string.format("bad argument ## to '%s.%s'", 
        proxyFunc.Controller.EntityName, proxyFunc.Key);

    local definition = proxyFunc.Controller.Definitions[proxyFunc.Key];
    definition = definition and definition.Params; 

    return definition, message;
end

function Core:GetReturnsDefinition(proxyFunc)
    local message = string.format("bad return value ## to '%s.%s'", 
        proxyFunc.Controller.EntityName, proxyFunc.Key);

    local definition = proxyFunc.Controller.Definitions[proxyFunc.Key];
    definition = definition and definition.Returns; 

    return definition, message;
end

function Core:CopyTable(tbl, copy)
    copy = copy or {};
    for key, value in pairs(tbl) do
        if (type(value) == "table") then
            copy[key] = self:CopyTable(value);
        else
            copy[key] = value;
        end 
    end
    return copy;
end

function Core:Assert(condition, errorMessage, ...)
    if (not condition) then
        if ( (select(1, ...)) ) then
            errorMessage = string.format(errorMessage, ...);
        end

        if (self.silent) then
            self.errorLog = self.errorLog or {};
            self.errorLog[#self.errorLog + 1] = pcall(function() error(Core.PREFIX .. errorMessage) end);
        else
            error(self.PREFIX .. errorMessage);
        end
    end
end

function Core:Error(errorMessage, ...)
    self:Assert(false, errorMessage, ...);
end

function Core:IsMatchingTypes(expected, arg)
    if (arg == nil) then
        return expected == "nil";
    end

    if (expected == "table" or expected == "number" or expected == "function" 
            or expected == "boolean" or expected == "string") then

        return expected == type(arg);

    elseif (arg.GetObjectType) then

        local controller = self:GetController(arg);

        repeat
            if (expected == arg:GetObjectType()) then
                return true;
            end            

            if (controller) then
                for _, interface in ipairs(controller.Interfaces) do
                    if (expected == Controllers[tostring(interface)].EntityName) then
                        return true;
                    end
                end

                if (expected == arg:GetObjectType()) then
                    return true;
                end
                
                arg = controller.ParentClass;
                controller = self:GetController(arg);
            end

        until (not (arg and controller));
    end

    return false;
end

function Core:GetArgType(arg)
    if (arg == nil) then
        return "nil";
    end

    local argType = type(arg);

    if (argType ~= "table") then
        return argType;
    else
        if (arg.GetObjectType) then
            return arg:GetObjectType();
        end

        return "table";
    end    
end

do
    local wrappers = {};

    local function iter(wrapper, id)
        id = id + 1;
        local arg = wrapper[id];

        if (arg) then
            return id, arg;
        else
            Core:PushWrapper(wrapper);
        end
    end

    function Core:PopWrapper(...)
        local wrapper;

        if (#wrappers > 0) then
            wrapper = wrappers[#wrappers];
            wrappers[#wrappers] = nil;
        else
            wrapper = {};
        end

        Core:EmptyTable(wrapper);

        local id = 1;
        local arg = (select(id, ...));
        repeat
            -- fill wrapper
            wrapper[id] = arg;
            id = id + 1;
            arg = (select(id, ...));
        until (not arg);

        return wrapper;
    end

    function Core:PushWrapper(wrapper)
        Core:EmptyTable(wrapper);
        table.insert(wrappers, wrapper);
    end

    function Core:UnpackWrapper(wrapper)
        table.insert(wrappers, wrapper);        
        return unpack(wrapper);
    end

    function Core:IterateArgs(...)
        local wrapper = self:PopWrapper(...);
        return iter, wrapper, 0;
    end
end