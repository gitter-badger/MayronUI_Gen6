local _, core = ...;
local LibObject = core.Lib;
if (not LibObject) then return; end

local List = LibObject:Import("Framework.Collections.List");

local Map = LibObject:CreateClass("Map");
LibObject:Export("Framework.Collections", Map);

function Map:__Constructor(private, tbl)
    private.values = {};
end

function Map:Add(private, key, value)
    assert(not private.values[key], "(LibObject) Map.Add: key already exists.");
    private.values[key] = value;
end

function Map:AddAll(private, keyValues)
    for key, value in pairs(keyValues) do
        self:Add(key, value);
    end    
end

function Map:Remove(private, key)
    assert(private.values[key], "(LibObject) Map.Add: key not found.");
    private.values[key] = nil;
end

function Map:RemoveAll(private, keys)
    for _, key in ipairs(keys) do
        self:Remove(key);
    end    
end

function Map:RetainAll(private, keys)
    for key, _ in pairs(private.values) do
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

function Map:RemoveByValue(private, value, allValues)
    for key, value2 in pairs(private.values) do
        if (value2 == value) then
            private.values[key] = nil;
            if (not allValues) then
                break;
            end
        end
    end
end

function Map:Get(private, key)
    return private.values[key];
end

function Map:Contains(private, value)
    return (self:GetByValue(value)) ~= nil;
end

function Map:ForEach(private, func)
    for key, value in pairs(private.values) do
        func(key, value);
    end
end

function Map:Filter(private, predicate)
    for key, value in pairs(private.values) do
        if (predicate(key, value)) then
            self:Remove(key);
        end
    end
end

function Map:Select(private, predicate)
    local selected = {};

    for key, value in pairs(private.values) do
        if (predicate(key, value)) then
            selected[key] = value;
        end
    end

    return selected;
end

function Map:Empty(private)
    for key, _ in pairs(private.values) do
        private.values[key] = nil;
    end
end

function Map:IsEmpty(private)
    return self:Size() > 0;
end

function Map:Size(private)
    local size = 0;
    for _, _ in pairs(private.values) do
        size = size + 1;
    end
    return size;    
end

function Map:ToTable(private)
    local copy = {};

    for key, value in pairs(private.values) do
        copy[key] = value;
    end

    return copy;
end

function Map:GetValueList(private, ...)
    local list = List();
    for _, value in pairs(private.values) do
        list:Add(value);
    end
    return list;
end

function Map:GetKeyList(private, ...)
    local list = List();
    for key, _ in pairs(private.values) do
        list:Add(key);
    end
    return list;
end