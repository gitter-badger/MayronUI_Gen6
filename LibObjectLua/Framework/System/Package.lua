local _, Core = ...;
local Lib = Core.Lib;
if (not Lib) then return; end

local Package = Core:CreateClass(nil, "Package");

function Package:__Construct(data, packageName)
    data.packageName = packageName;
    data.defineParams = {};
    data.defineReturns = {};
    data.defineImplement = {};
    data.entities = {};
end

function Package:GetName(data)
    return data.packageName;
end

function Package:AddSubPackage(data, subPackage)
    local packageName = subPackage:GetName();

    Core:Assert(not data.entities[packageName], 
        "Package.AddSubPackage - bad argument #1 ('%s' package already exists inside this package).", packageName);

    data.entities[packageName] = subPackage;
end

function Package:Get(data, entityName)
    return data.entities[entityName];
end

function Package:CreateClass(data, className, parentClass, ...)
    Core:Assert(not data.entities[className], 
        "Class '%s' already exists in this package.", className);

    local class = Core:CreateClass(data, className, parentClass, ...);
    data.entities[className] = class;
    
    return class;
end

function Package:CreateInterface(data, interfaceName)
    Core:Assert(not data.entities[interfaceName], 
        "Interface '%s' already exists in this package.", interfaceName);

    local Interface = Core:CreateInterface(data, interfaceName);
    data.entities[interfaceName] = Interface;

    return Interface;
end

function Package:DefineParams(data, ...)
    Core:DefineFunction(data.defineParams, ...);
end

function Package:DefineReturns(data, ...)
    Core:DefineFunction(data.defineReturns, ...); 
end

-- prevents other functions being added or modified
function Package:ProtectEntity(data, entity)
	local controller = Controllers[tostring(entity)];

    Core:Assert(controller, "Package.ProtectEntity - bad argument #1 (entity not found).");
	controller.Protected = true;
end

function Package:Implements(data, funcName)
    Core:Assert(not data.defineImplement.FuncKey, "%s was not implemented", funcName);
	data.defineImplement.FuncKey = funcName;
end

function Package:GetObjectType()
    return "Package";
end

function Package:IsObjectType(data, objectName)
    return "Package" == objectName;
end

function Package:ForEach(data, func)
    for entityName, entity in pairs(data.entities) do
        func(entityName, entity);
    end
end

function Package:Size(data)
    local size = 0;

    for _, _ in pairs(data.entities) do
        size = size + 1;
    end

    return size;
end

-- Export Package manually: Cannot use Lib:Export() without Package first being established!
Core.Packages.Framework = Package("Framework");

local System = Package("System");
local SystemData = Core:GetPrivateInstanceData(System);

Core.Packages.Framework:AddSubPackage(System);
SystemData.entities["Package"] = Package;