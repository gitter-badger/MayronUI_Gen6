local _, ns = ...;
local lib = ns.lib;
if (not lib) then return; end

local Object = lib:CreateClass("Object"); -- this is fine! importing a class adds special validation lock!

function Object:ToString() 
	return tostring(self):gsub("table", self:GetObjectType());
end -- also uses this when printing the object

function Object:GetObjectType(private) 
	return private.objectType;
end

function Object:IsObjectType(private, objectType) 
	if (private.objectType == objectType) then return true; end
	local parent;
	while (parent = self:GetParent()) do
		if (parent:IsObjectType(objectType)) then
			return true;
		end
	end
	return false;
end

function Object:Equals(private, other)
	if (type(other) ~= "table") then return false; end
	if (other.GetObjectType and other:GetObjectType() == private.objectType) then
		for key, value in ipairs(self) do
			if (type(other[key]) ~= "function" and other[key] ~= self[key]) then
				return false;
			end
		end
		return true;
	end
	return false;
end

function Object:GetParent(private)
	return private.extends -- to do!
end

function Object:Clone(private) end

function Object:Destroy(private) end

Object['*'] = function(self) end

Object['/'] = function(self) end

Object['+'] = function(self) end

Object['-'] = function(self) end


--- a new user cannot add more functions onto a class
-- private namespace gets added to function