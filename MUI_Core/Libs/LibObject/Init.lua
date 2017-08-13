local _, namespace = ...;

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

function LibObject:CreateClass(className, inherits, implements)

    -- create class
    -- on __newindex, use AttachDefines(class, method) if function
    --// todo: classes should always extend Object

    local Class = {};
    local ClassController = {}; -- behind the scenes controller
    local InstanceMT = {}; -- metatable for instances of class 
    local ClassMT = {};

    Class.Static = {}; -- for static functions and properties

    ClassController.Locked = false; -- true if functions and properties are to be protected
    ClassController.ClassName = className;
    ClassController.ProxyData = {}; -- redirect all Class keys to this
    ClassController.PrivateInstanceData = {}; -- for Class Private Instance functions and properties
    ClassController.Parents = Private:ParseParents(inherits);
    ClassController.Interfaces = Private:ParseInterfaces(implements);

    ClassController.Key = nil; -- function key being called from Class instance
    ClassController.Data = nil; -- Selected Private Instance data
    ClassController.ProxyFunction = function(instance, ...)
        return Class[ClassController.Key](self, ClassController.Data, ...);
    end 

    -- get a value
    InstanceMT.__index = function(instance, key)
        if (Class[key] and typeof(Class[key]) == "function") then
            ClassController.Key = key;
            ClassController.Data = {};
            return ClassController.ProxyFunction; -- return proxy function

        elseif (Class[key]) then
            return Class[key]; -- standard inheritance

        else
            local value = nil;

            for _, parent in ipairs(ClassController.Parents) do
                value = parent[key];

                if (value ~= nil) then
                    break;
                end
            end

            return value;
        end
    end

    -- create a value
    InstanceMT.__newindex = function(instance, key, value)
        if (Class[key] and ClassController.Locked) then
            error(ClassController.ClassName .. "." .. key .. " is protected.");
        elseif (key ~= "_Static") then
            if (typeof(value) == "function" and (#DefineParams > 0 or #DefineReturns > 0)) then                
                Private:AttachDefines(ClassController, key);
            end
            rawset(instance, key, value);
        else
            error("LibObject: _Static property is protected.")
        end
    end

    -- create instance of class (static only)
    ClassMT.__call = function(_, ...)    
        local instance = {};
        local private = {};

        ClassController.PrivateInstanceData[tostring(instance)] = private;     
        setmetatable(instance, InstanceMT);

        if instance._Constructor then
            instance:_Constructor(...);
        end

        return instance;
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
        root = root[key];

        if (root == nil and id < (#nodes - 1)) then
            error("LibObject.Export: Namespace invalid.");
        end
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

function Private:AttachDefines(classPrivate, funcName)

    local attached = false;

    if (#DefineParams > 0) then

    end

    if (#DefineReturns > 0) then

    end

    return attached;

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