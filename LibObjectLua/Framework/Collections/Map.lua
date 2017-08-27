local _, Core = ...;
local Lib = Core.Lib;
if (not Lib) then return; end

local Collections = Lib:Import("Framework.Collections");
local List = Collections:Get("List");

local Map = Collections:CreateClass("Map");

Collections:DefineParams("?table");
function Map:__Construct(data, tbl)
    data.values = {};

    if (tbl) then
        for key, value in pairs(tbl) do
            self:Add(key, value);
        end
    end
end

function Map:Add(data, key, value)
    Core:Assert(not data.values[key], "Map.Add - key '%s' already exists.", key);
    data.values[key] = value;
end

function Map:AddAll(data, keyValues)
    for key, value in pairs(keyValues) do
        self:Add(key, value);
    end    
end

function Map:Remove(data, key)
    Core:Assert(data.values[key], "Map.Add: key '%s' not found.", key);
    data.values[key] = nil;
end

function Map:RemoveAll(data, keys)
    for _, key in ipairs(keys) do
        self:Remove(key);
    end    
end

function Map:RetainAll(data, keys)
    for key, _ in pairs(data.values) do
        local keyExists = false;

        for _, retainKey in ipairs(keys) do
            if (key == retainKey) then
                keyExists = true;
                break;
            end
        end

        if (not keyExists) then
            self:Remove(key);
        end
    end    
end

function Map:RemoveByValue(data, value, allValues)
    for key, value2 in pairs(data.values) do
        if (value2 == value) then
            data.values[key] = nil;
            if (not allValues) then
                break;
            end
        end
    end
end

function Map:Get(data, key)
    return data.values[key];
end

function Map:Contains(data, value)
    return (self:GetByValue(value)) ~= nil;
end

function Map:ForEach(data, func)
    for key, value in pairs(data.values) do
        func(key, value);
    end
end

function Map:Filter(data, predicate)
    for key, value in pairs(data.values) do
        if (predicate(key, value)) then
            self:Remove(key);
        end
    end
end

function Map:Select(data, predicate)
    local selected = {};

    for key, value in pairs(data.values) do
        if (predicate(key, value)) then
            selected[key] = value;
        end
    end

    return selected;
end

function Map:Empty(data)
    for key, _ in pairs(data.values) do
        data.values[key] = nil;
    end
end

function Map:IsEmpty(data)
    return self:Size() > 0;
end

function Map:Size(data)
    local size = 0;
    for _, _ in pairs(data.values) do
        size = size + 1;
    end
    return size;    
end

function Map:ToTable(data)
    local copy = {};

    for key, value in pairs(data.values) do
        copy[key] = value;
    end

    return copy;
end

function Map:GetValueList(data, ...)
    local list = List();
    for _, value in pairs(data.values) do
        list:Add(value);
    end
    return list;
end

function Map:GetKeyList(data, ...)
    local list = List();
    for key, _ in pairs(data.values) do
        list:Add(key);
    end
    return list;
end