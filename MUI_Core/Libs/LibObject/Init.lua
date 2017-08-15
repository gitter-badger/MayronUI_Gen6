local _, namespace = ...;

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

local error, rawget, rawset, setmetatable = error, rawget, rawset, setmetatable;
local type = type;

local Private = {};
Private.Directory = {};

local DefineParams = {};
local DefineReturns = {};

local Controllers = {};

local ProxyFunction = {};

ProxyFunction.Run = function(self, ...)
    Private:ValidateArgs(ProxyFunction.ClassController, ProxyFunction.Key, ...);

    if (not ProxyFunction.Private) then     
        error(string.format("LibObject: %s.%s is a non static " .. 
                "function and must be invoked by an instance object.", 
                ProxyFunction.ClassController.ClassName, ProxyFunction.Key));
    end

    return Private:ValidateReturns(ProxyFunction.ClassController, 
                ProxyFunction.Object[ProxyFunction.Key](ProxyFunction.Instance, ProxyFunction.Private, ...));
end

function ProxyFunction:Setup(proxy, key, object, controller)
    self.Object = proxy;
    self.Key = key; -- indicates which function to call through ProxyFunction
    self.Instance = object; -- 1st argument of ProxyFunction call
    self.Private = controller.PrivateInstanceData[tostring(object)]; -- 2nd argument of ProxyFunction call (Private Instance data)       
    self.ClassController = controller;
    return self.Run;
end

function LibObject:CreateClass(className, inherits, implements)

    --// todo: classes should always extend Object

    local Class = {};
    local ClassController = {}; -- behind the scenes controller
    local ProxyClass = {}; -- redirect all Class keys to this   
    local ClassMT = {};
    local InstanceMT = {}; -- metatable for instances of class 

    Class.Static = {}; -- for static functions and properties

    ClassController.Locked = false; -- true if functions and properties are to be protected
    ClassController.ClassName = className;
    ClassController.ProxyInstances = {}; -- redirect all instance keys to this  
    ClassController.PrivateInstanceData = {}; -- for Class Private Instance functions and properties
    ClassController.Definitions = {};

    if (not Private:IsStringNilOrWhiteSpace(inherits)) then
        ClassController.Parents = Private:ParseParents(inherits);
    end

    if (not Private:IsStringNilOrWhiteSpace(implements)) then
        ClassController.Interfaces = Private:ParseParents(implements);
    end   

    -- get a value
    InstanceMT.__index = function(instance, key)
        local ProxyInstance = ClassController.ProxyInstances[tostring(instance)];
        local value = ProxyInstance[key];
        
        if (not value and ClassController.Parents) then
            for _, parent in ipairs(ClassController.Parents) do
                value = parent[key];
                if (value ~= nil) then
                    break;
                end
            end
        elseif (type(value) == "function") then
            value = ProxyFunction:Setup(ProxyInstance, key, instance, ClassController);
        else
            value = Class[key];
            if (type(value) == "function") then
                ProxyFunction.Instance = instance; -- 1st argument of ProxyFunction call
                ProxyFunction.Private = ClassController.PrivateInstanceData[tostring(instance)]; -- 2nd argument of ProxyFunction call (Private Instance data)   
            end
        end

        return value;
    end

    -- create a value
    InstanceMT.__newindex = function(instance, key, value)
        local ProxyInstance = ClassController.PrivateInstanceData[tostring(instance)];

        if (Class[key] and ClassController.Locked) then
            error(string.format("LibObject: %s.%s is protected.", ClassController.ClassName, key));
        else
            if (type(value) == "function") then                
                Private:AttachDefines(ClassController, key);
            end
            ProxyInstance[key] = value;
        end
    end

    -- create instance of class (static only)
    ClassMT.__call = function(_, ...)    
        local instance = {};

        ClassController.PrivateInstanceData[tostring(instance)] = {};    
        ClassController.ProxyInstances[tostring(instance)] = {}; 
        setmetatable(instance, InstanceMT);

        if instance._Constructor then
            instance:_Constructor(...);
        end

        return instance;
    end

    ClassMT.__index = function(object, key) -- object: instance or class table
        local value = ProxyClass[key] or Class.Static[key];

        if (type(value) == "function") then
            value = ProxyFunction:Setup(ProxyClass, key, object, ClassController);
        end

        return value;
    end

    -- set new value (always true)
    ClassMT.__newindex = function(class, key, value)
        if (Class[key] and ClassController.Locked) then
            error(string.format("LibObject: %s.%s is protected.", ClassController.ClassName, key));
        elseif (key ~= "Static") then
            if (type(value) == "function") then                
                Private:AttachDefines(ClassController, key);
                ProxyClass[key] = value;
            else
                Class.Static[key] = value;
            end
        else
            error(string.format("LibObject: %s.Static property is protected.", ClassController.ClassName));
        end
    end
    
    setmetatable(Class, ClassMT);
    Controllers[tostring(Class)] = ClassController;
    return Class;
end

function LibObject:CreateAbstractClass(className, ...)

end

function LibObject:CreateInterface(interfaceName, ...)

end

function LibObject:Import(namespace)
    local root = Private.Directory;

    for id, key in ipairs({strsplit(".", namespace)}) do
        if (Private:IsStringNilOrWhiteSpace(key)) then
            error("LibObject.Export: Namespace invalid.");
        end
        
        root = root[key];

        if (root == nil) then
            error("LibObject.Import: Namespace invalid.")
        end
    end

    return root;
end

function LibObject:Export(class, namespace)
    local root = Private.Directory;
    local classController = Controllers[tostring(class)];

    if (not Private:IsStringNilOrWhiteSpace(namespace)) then
        for id, key in ipairs({strsplit(".", namespace)}) do
            if (Private:IsStringNilOrWhiteSpace(key)) then
                error("LibObject.Export: Namespace invalid.");
            end

            key = key:gsub("%s+", "");
            root[key] = root[key] or {};
            root = root[key];
        end
    end

    if (root[classController.ClassName]) then
        error("LibObject.Export: Class path already in use.");
    end

    root[classController.ClassName] = class;
end

function LibObject:LockClass(className)


end

function LibObject:DefineParams(...)
    local optionalFound = false;
    Private:EmptyTable(DefineParams);

    for id, paramType in ipairs({...}) do  
        if (not Private:IsStringNilOrWhiteSpace(paramType)) then    
            paramType = paramType:gsub("%s+", "");

            if (paramType.starts("?")) then
                DefineParams.Optional = DefineParams.Optional or {};
                paramType = paramType.replace("?", "");
                DefineParams.Optional[id] = paramType;

            elseif (DefineParams.Optional) then
                error("LibObject.DefineParams: Optional parameters must appear at the end of the method declaration.");
            else
                DefineParams[id] = paramType;
            end
        end
    end    
end

function LibObject:DefineReturns(...)
    local optionalFound = false;
    Private:EmptyTable(DefineReturns);

    for id, rtnType in ipairs({...}) do 
        if (not Private:IsStringNilOrWhiteSpace(rtnType)) then   
            rtnType = rtnType:gsub("%s+", "");

            if (rtnType.starts("?")) then
                DefineReturns.Optional = DefineReturns.Optional or {};
                rtnType = rtnType.replace("?", "");
                DefineReturns.Optional[id] = rtnType;

            elseif (DefineReturns.Optional) then
                error("LibObject.DefineReturns: Optional return values must appear at the end of the return list declaration.");
            else
                DefineReturns[id] = rtnType;
            end
        end
    end  
end

-------------------------------------
-- Private Functions
-------------------------------------
function Private:EmptyTable(tbl)
    for key, _ in pairs(tbl) do
        tbl[key] = nil;
    end
end

function Private:AttachDefines(classController, funcKey)
    if (#DefineParams > 0 or #DefineReturns > 0) then

        local funcDef = {};
        funcDef.Params = {};
        funcDef.Returns = {};

        for key, value in pairs(DefineParams) do
            funcDef.Params[key] = value;
        end
    
        for key, value in pairs(DefineReturns) do
            funcDef.Returns[key] = value;
        end

        Private:EmptyTable(DefineParams);
        Private:EmptyTable(DefineReturns);

        if (classController.Definitions[funcKey]) then
            error(string.format("LibObject: %s.%s Definition already exists.", 
                                                    classController.ClassName, funcKey));
        end

        classController.Definitions[funcKey] = funcDef;
    end
end

function Private:ParseParents(inherits) 
    local parents = {};

    for id, parent in ipairs({strsplit(",", inherits)}) do    
        parent = parent:gsub("%s+", "");

        if (#parent > 0) then
            table.insert(parents, LibObject:Import(parent));
        end
    end
end

function Private:ParseInterfaces(implements) 
    local interfaces = {};

    for id, interface in ipairs({strsplit(",", implements)}) do 
        
        if (not Private:IsStringNilOrWhiteSpace(interface)) then
            interface = interface:gsub("%s+", "");

            if (#interface > 0) then
                table.insert(interfaces, LibObject:Import(interface));
            end
        end

    end
end


-- definitions types: string, number, table, function, any

function Private:ValidateArgs(classController, funcKey, ...)

    local definition = classController.Definitions[funcKey];

    if (definition) then
        local id = 1;
        local arg = (select(id, ...));

        repeat
            -- validate arg:
            if (definition[id]) then
                if (not arg) then
                    error(string.format("LibObject: Required argument not supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
                elseif (type(arg) ~= definition[id]) then
                    error(string.format("LibObject: Incorrect argument type supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
                end
            elseif (definition.Optional[id]) then
                if (arg and type(arg) ~= definition[id]) then
                    error(string.format("LibObject: Incorrect argument type supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
                end
            else
                error(string.format("LibObject: Incorrect arguments supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
            end

            id = id + 1;
            arg = (select(id, ...));

        until (not definition[id]);
    end

    return ...;
end

function Private:ValidateReturns(definition, ...)
    return ...;
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

function Private:IsStringNilOrWhiteSpace(string)
    local value = true;

    if (string) then
        string = string:gsub("%s+", "");

        if (#string > 0) then
            value = false;
        end
    end

    return value;
end