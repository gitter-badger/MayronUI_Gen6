local _, namespace = ...;

print("loaded...")
_G["SLASH_RELOADUI1"] = "/rl";
SlashCmdList.RELOADUI = ReloadUI;

_G["SLASH_FRAMESTK1"] = "/fs";
SlashCmdList.FRAMESTK = function()
    tk.LoadAddOn('Blizzard_DebugTools');
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
local typeof = typeof;

local Private = {};
Private.Directory = {};

local DefineParams = {};
local DefineReturns = {};

-- local Classes = {};
-- local AbstractClasses = {};
-- local Interfacees = {};

local ProxyFunctionStack = {};
ProxyFunctionStack.items = {};

function ProxyFunctionStack:Push(item)
    self.items[#self.items + 1] = item;
end

function ProxyFunctionStack:Pop()
    local item;

    if (self:IsEmpty()) then
        -- create new
        item = {};
        item.ReturnValues = {};

        setmetatable(item, {
            __call = function(self, ...)
                Private:ValidateArgs(item.ClassController, item.Key);

                Private:FillTable(item.ReturnValues, Private:ValidateReturns(
                        item.ClassController, 
                        item.Object[item.Key](item.Instance, item.Private, ...)));         

                ProxyFunctionStack:Push(item);
                return unpack(item.ReturnValues);
            end
        });         
    else    
        item = self.items[#self.items];
        self.items[#self.items] = nil;
    end
    return item;
end

-- might not need
function ProxyFunctionStack:IsEmpty()
    return (#self.items == 0);
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
    ClassController.Parents = Private:ParseParents(inherits);
    ClassController.Interfaces = Private:ParseInterfaces(implements);
    ClassController.Definitions = {};

    -- get a value
    InstanceMT.__index = function(instance, key)
        local ProxyInstance = ClassController.PrivateInstanceData[tostring(instance)];
        local value = ProxyInstance[key] or Class[key];

        if (not value) then
            for _, parent in ipairs(ClassController.Parents) do
                value = parent[key];

                if (value ~= nil) then
                    break;
                end
            end

        elseif (typeof(value) == "function") then
            -- controlled function call
            value = ProxyFunctionStack:Pop();

            value.Object = Class;
            value.Key = key; -- indicates which function to call through ProxyFunction
            value.Instance = instance; -- 1st argument of ProxyFunction call
            value.Private = ClassController.PrivateInstanceData[tostring(instance)]; -- 2nd argument of ProxyFunction call (Private Instance data)       
            value.ClassController = ClassController;
        end

        return value;
    end

    -- create a value
    InstanceMT.__newindex = function(instance, key, value)
    local ProxyInstance = ClassController.PrivateInstanceData[tostring(instance)];

        if (Class[key] and ClassController.Locked) then
            error(string.format("LibObject: %s.%s is protected.", ClassController.ClassName, key));

        else
            if (typeof(value) == "function") then                
                Private:AttachDefines(ClassController, key);
            end
            ProxyInstance[key] = value;
        end
    end

    -- create instance of class (static only)
    ClassMT.__call = function(_, ...)    
        local instance = {};
        local private = {};

        ClassController.PrivateInstanceData[tostring(instance)] = private;    
        ClassController.ProxyInstances[tostring(instance)] = {}; 
        setmetatable(instance, InstanceMT);

        if instance._Constructor then
            instance:_Constructor(...);
        end

        return instance;
    end

    ClassMT.__index = function(class, key)
        local value = ProxyClass[key] or Class.Static[key];

        if (typeof(value) == "function") then
            value = ProxyFunctionStack:Pop();

            value.Object = Class;
            value.Key = key; -- indicates which function to call through ProxyFunction
            value.Instance = class; -- 1st argument of ProxyFunction call
            value.Private = ClassController.PrivateInstanceData[tostring(instance)]; -- 2nd argument of ProxyFunction call (Private Instance data)       
            value.ClassController = ClassController;
        end

        return value;
    end

    -- set new value (always true)
    ClassMT.__newindex = function(class, key, value)
        if (Class[key] and ClassController.Locked) then
            error(string.format("LibObject: %s.%s is protected.", ClassController.ClassName, key));

        elseif (key ~= "Static") then
            if (typeof(value) == "function") then                
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
    return Class;
end

function LibObject:CreateAbstractClass(className, ...)

end

function LibObject:CreateInterface(interfaceName, ...)

end

function LibObject:Import(namespace)
    local nodes = strsplit(".", namespace);
    local root = Private.Directory;
    local lastKey = nil;

    for id, key in ipairs(nodes) do
        root = root[key];

        if (root == nil) then
            error("LibObject.Import: Namespace invalid.")
        end
    end

    return root[lastKey];
end

function LibObject:Export(namespace, class)
    local nodes = strsplit(".", namespace);
    local root = Private.Directory;
    local lastKey = nil;

    for id, key in ipairs(nodes) do 
        if (id < #nodes) then
            root[key] = root[key] or {};
            root = root[key];
        end

        lastKey = key;
    end

    if (not lastKey or lastKey:match("%s+")) then
        error("LibObject.Export: Namespace invalid.");
    end

    if (root[lastKey]) then
        error("LibObject.Export: Namespace already in use.");
    end

    root[lastKey] = class;
end

function LibObject:LockClass(className)


end

function LibObject:DefineParams(...)
    local optionalFound = false;
    Private:EmptyTable(DefineParams);

    for id, paramType in ipairs({...}) do    
        paramType = paramType:gsub("%s+", "");
        if (#paramType > 0) then

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
        rtnType = rtnType:gsub("%s+", "");
        if (#rtnType > 0) then

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
    for key, _ in tk.pairs(tbl) do
        tbl[key] = nil;
    end
end

function Private:AttachDefines(classController, funcKey)
    if (#DefineParams > 0 or #DefineReturns > 0) then

        local funcDef = {};
        funcDef.Params = {};
        funcDef.Returns = {};

        for key, value in tk.pairs(DefineParams) do
            funcDef.Params[key] = value;
        end
    
        for key, value in tk.pairs(DefineReturns) do
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
        interface = interface:gsub("%s+", "");

        if (#interface > 0) then
            table.insert(interfaces, LibObject:Import(interface));
        end
    end
end


-- definitions types: string, number, table, function, any

function Private:ValidateArgs(classController, funcKey, ...)

    local definition = classController.Definitions[funcKey];

    if (definition) then
        local id = 1;
        local arg = (tk.select(id, ...));

        repeat
            -- validate arg:
            if (definition[id]) then
                if (not arg) then
                    error(string.format("LibObject: Required argument not supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
                elseif (typeof(arg) ~= definition[id]) then
                    error(string.format("LibObject: Incorrect argument type supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
                end
            elseif (definition.Optional[id]) then
                if (arg and typeof(arg) ~= definition[id]) then
                    error(string.format("LibObject: Incorrect argument type supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
                end
            else
                error(string.format("LibObject: Incorrect arguments supplied for %s.%s", 
                                                        classController.ClassName, funcKey));
            end

            id = id + 1;
            arg = (tk.select(id, ...));

        until (not definition[id]);
    end

    return ...;
end

function Private:ValidateReturns(definition, ...)
    return ...;
end

function Private:FillTable(tbl, ...)
    local id = 1;
    local arg = (tk.select(id, ...));
    self:EmptyTable(tbl);

    repeat    
        tbl[id] = arg;
        id = id + 1;
        arg = (tk.select(id, ...));
    until (not arg);
end