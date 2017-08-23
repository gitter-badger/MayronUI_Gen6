local _, core = ...;
local LibObject = core.Lib;
if (not LibObject) then return; end

local List = LibObject:CreateClass("List");
LibObject:Export("Framework.Collections", List);

function List:__Construct(private, ...)
    private.values = {};
    self:AddAll(...);
end

function List:Add(private, value, index)
    if (index) then
        table.insert(private.values, index, value);
    else
        table.insert(private.values, value);
    end
end

function List:Remove(private, index)
    table.remove(private.values, index);
end

function List:RemoveByValue(private, value, allValues)
    local index = 1;
    local value2 = private.values[index];

    while (value2) do
        if (value2 == value) then
            self:Remove(index);
            if (not allValues) then
                break;
            end
        else
            index = index + 1;
        end

        value2 = private.values[index];
    end
end

function List:ForEach(private, func)
    for index, value in ipairs(private.values) do
        func(index, value);
    end
end

function List:Filter(private, predicate)
    local index = 1;
    local value = private.values[index];

    while (value) do
        if (predicate(index, value)) then
            self:Remove(index);
        else
            index = index + 1;
        end

        value = private.values[index];
    end
end

function List:Select(private, predicate)
    local selected = {};

    for index, value in ipairs(private.values) do
        if (predicate(index, value)) then
            selected[#selected] = value;
        end
    end

    return selected;
end

local function iter(values, index)
    index = index + 1;
    if (values[index]) then
        return index, values[index];
    end
end

function List:Iterate(private)
    return iter, private.values, 0;
end

function List:Get(private, index)
    return private.values[index];
end

function List:Contains(private, value)    
    for index, value2 in ipairs(private.values) do
        if (value2 == value) then
            return true;
        end
    end
    return false;
end

function List:Empty(private)
    for index, _ in ipairs(private.values) do
        private.values[index] = nil;
    end
end

function List:IsEmpty(private)
    return #private.values > 0;
end

function List:Size(private)
    return #private.values;
end

function List:ToTable(private)
    local copy = {};

    for index, value in ipairs(private.values) do
        copy[index] = value;
    end

    return copy;
end

function List:AddAll(private, ...)
    for _, value in ipairs({...}) do
        table.insert(private.values, value);
    end    
end

function List:RemoveAll(private, ...)
    for _, value in ipairs({...}) do
        self:RemoveByValue(value);
    end
end

function List:RetainAll(private, ...)
    for _, value in ipairs({...}) do
        if (not self:Contains(value)) then
            self:RemoveByValue(value);
        end
    end
end