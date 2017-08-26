local addonName, Core = ...;

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
local Lib = LibStub:NewLibrary("LibObjectLua", 1.0);
if (not Lib) then return; end

local error, rawget, rawset = error, rawget, rawset;
local type, setmetatable = type, setmetatable;

local Controllers = {};
local ClassesImplementing = {}; -- classes that implement interfaces

local ProxyStack = {};
ProxyStack.FuncStrings = {};

Core.Lib = Lib;
Core.PREFIX = "|cffffcc00LibObjectLua: |r";
Core.Controllers = Controllers;
Core.Packages = {};

--------------------------------------------
-- LibObjectLua Functions
--------------------------------------------
function Lib:CreatePackage(packageName, namespace)
    local Package = Lib:Import("Framework.System.Package");
    local newPackage = Package(packageName);

    if (not Core:IsStringNilOrWhiteSpace(namespace)) then
        self:Export(namespace, newPackage);
    end

    return newPackage;   
end

function Lib:Import(namespace, silent)
    local package = Core.Packages;
    local currentNamespace = "";

    local nodes = {strsplit(".", namespace)};
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

-- exporting packages only
function Lib:Export(namespace, ...)
    local package = Core.Packages;
    local controller;

    Core:Assert(not Core:IsStringNilOrWhiteSpace(namespace), "Export - bad argument #1 (invalid namespace)");

    for id, key in ipairs({strsplit(".", namespace)}) do        
        Core:Assert(not Core:IsStringNilOrWhiteSpace(key), "Export - bad argument #1 (invalid namespace).");
        key = key:gsub("%s+", "");

        if (id > 1) then
            if (not package:Get(key)) then
                package:AddSubPackage(Lib:CreatePackage(key));
            end
            package = package:Get(key);
        else
            package[key] = package[key] or Lib:CreatePackage(key);
            package = package[key];
        end
    end

    for id, subPackage in ipairs({...}) do
        local controller = Core:GetController(subPackage);    
        Core:Assert(controller, "Export - bad argument #%s (invalid package).", id + 1);

        if (controller.IsPackage) then
            package:AddSubPackage(subPackage);
        else
            Core:Error("Export - bad argument #%s (package expected).", id + 1);
        end
    end
end

function Lib:SetSilentErrors(silent)
    Core.silent = silent;
end

function Lib:GetErrorLog()
    Core.errorLog = Core.errorLog or {};
    return Core.errorLog;
end

function Lib:FlushErrorLog()
    if (Core.errorLog) then
        Core:EmptyTable(Core.errorLog);
    end
end

function Lib:GetNumErrors()
    return (Core.errorLog and #Core.errorLog) or 0;
end

-------------------------------------
-- ProxyStack
-------------------------------------
function ProxyStack:Pop(proxyEntity, key, object, controller) 
    local proxyFunc;
   
    if (#self == 0) then   
        proxyFunc = setmetatable({}, ProxyStack.MT);
    else
        proxyFunc = self[#self];
        self[#self] = nil;
    end

    proxyFunc.Object        = proxyEntity;
    proxyFunc.Key           = key;
    proxyFunc.Instance      = object;
    proxyFunc.Private       = controller.PrivateInstanceData[tostring(object)];
    proxyFunc.Controller    = controller;

    proxyFunc.Run = function(_, ...)    
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
        local returnValues =  { 
            Core:ValidateFunction(definition, message, proxyFunc.Object[proxyFunc.Key](proxyFunc.Instance, proxyFunc.Private, ...)) 
        };

        ProxyStack:Push(proxyFunc);

        return unpack(returnValues);
    end

    ProxyStack.FuncStrings[tostring(proxyFunc.Run)] = proxyFunc;

    return proxyFunc.Run;
end

function ProxyStack:Push(proxyFunc)
    self[#self + 1] = proxyFunc;
    proxyFunc.Object        = nil;
    proxyFunc.Key           = nil;
    proxyFunc.Instance      = nil;
    proxyFunc.Private       = nil;
    proxyFunc.Controller    = nil;
end

function ProxyStack:Get(func)
    return ProxyStack.FuncStrings[tostring(func)];
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

-------------------------------------
-- Core Functions
-------------------------------------
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
                local proxy = ProxyStack:Get(value);
                proxy.Instance = instance;
                proxy.Private = Controller.PrivateInstanceData[tostring(instance)];  
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

        if (type(value) == "function") then
            value = ProxyStack:Pop(ProxyClass, key, class, Controller);        

        elseif (not value) then
            value = Controller.ParentClass and Controller.ParentClass[key];

            if (type(value) == "function") then
                local proxy = ProxyStack:Get(value);
                proxy.Instance = class; -- it's a ProxyFunction
            end
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

    for id, interface in ipairs({...}) do
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

    for _, key in ipairs({strsplit(".", path)}) do
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

    if (metaTbl.Class) then
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

    for id, valueType in ipairs({...}) do  
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