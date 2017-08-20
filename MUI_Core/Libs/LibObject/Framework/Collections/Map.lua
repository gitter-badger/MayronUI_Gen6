local _, core = ...;
local LibObject = core.Lib;
if (not LibObject) then return; end

local Map = LibObject:CreateClass("Map");
LibObject:Export("Framework.Collections", Map);

function Map:__Constructor(private, tbl)
    private.items = {};
end

function Map:Add(private, key, value)
    assert(not private.items[key], "(LibObject) Map.Add: key already exists.");
    private.items[key] = value;
end

function Map:Remove(private, key)
    assert(private.items[key], "(LibObject) Map.Add: key not found.");
    private.items[key] = nil;
end

function Map:RemoveByValue(private, value, allValues)
    for key, value2 in pairs(private.items) do
        if (value2 == value) then
            private.items[key] = nil;
            if (not allValues) then
                break;
            end
        end
    end
end

function Map:ForEach(private, func)
    for key, value in pairs(private.items) do
        func(key, value);
    end
end

function Map:Filter(private, predicate)
    for key, value in pairs(private.items) do
        if (predicate(key, value)) then
            self:Remove(key);
        end
    end
end

function Map:Select(private, predicate)
    local selected = {};

    for key, value in pairs(private.items) do
        if (predicate(key, value)) then
            selected[key] = value;
        end
    end

    return selected;
end

-- TODO:
local function iter(items, index)
    index = index + 1;
    if (items[index]) then
        return index, key, items[key];
    end
end

function Map:Iterate(private)
    return iter, private.items, 0;
end

function Map:Get(private, index)
    return private.items[index];
end

function Map:GetByValue(private, value)
    for index, item in ipairs(private.items) do
        if (item == value) then
            return value;
        end
    end
end

function Map:Contains(private, value)
    return (self:GetByValue(value)) ~= nil;
end

function Map:Empty(private)
    for key, _ in pairs(private.items) do
        private.items[key] = nil;
    end
end

function Map:IsEmpty(private)
    return #private.items > 0;
end

function Map:Size(private)
    return #private.items;
end

function Map:ToTable(private)
    local copy = {};

    for index, value in ipairs(private.items) do
        copy[index] = value;
    end

    return copy;
end

function Map:AddAll(private, keyValues)
    for key, value in pairs(keyValues) do
        self:Add(key, value);
    end    
end

function Map:GetValueList(private, ...)
    for _, value in ipairs({...}) do
        self:RemoveByValue(value);
    end
end

function Map:GetKeyList(private, ...)
    for _, value in ipairs({...}) do
        if (not self:Contains(value)) then
            self:RemoveByValue(value);
        end
    end
end