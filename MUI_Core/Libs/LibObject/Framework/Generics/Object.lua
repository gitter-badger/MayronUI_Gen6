local _, core = ...;
local LibObject = core.Lib;

if (not LibObject) then return; end

local Object = LibObject:CreateClass("Object"); -- this is fine! importing a class adds special validation lock!
LibObject:Export(Object, "Framework.Generics");

function Object:ToString() 
	return tostring(self):gsub("table", self:GetObjectType());
end

function Object:GetObjectType(private)	
	return core.Private:GetController(self).EntityName;
end

function Object:IsObjectType(private, objectName)
	local controller = core.Private:GetController(self);

	if (controller.EntityName == objectName) then
		return true;
	else
		controller = core.Private:GetController(controller.Parent);

		while (controller) do
			if (controller.EntityName == objectName) then
				return true;
			end
			controller = core.Private:GetController(controller.Parent);
		end
	end

	return false;
end

function Object:Equals(private, other)
	if (type(other) ~= "table" or not other.GetObjectType) then 
		return false; 
	end

	if (other:GetObjectType() == self:GetObjectType()) then
		local controller = core.Private:GetController(other);
		local otherPrivate = controller.PrivateInstanceData[tostring(other)];

		for key, value in pairs(private) do
			if (private[key] ~= otherPrivate[key]) then
				return false;
			end
		end
	end

	return true;
end

function Object:GetParentClass(private)
	return core.Private:GetController(self).Parent;
end

function Object:GetClass()
	return getmetatable(self).Class;
end

function Object:Clone(private) 
	local controller = core.Private:GetController(self);
	controller.CloneFrom = self;

	local instance = controller.Class();

	if (not self:Equals(instance)) then
		error("LibObject: Clone data corrupted.");
	end

	return instance;
end

function Object:Destroy(private)
	local controller = core.Private:GetController(self);

	for key, _ in pairs(private) do
		private[key] = nil;
	end

	controller.PrivateInstanceData[tostring(self)] = nil;    
	controller.ProxyInstances[tostring(self)] = nil; 
	setmetatable(self, nil);
end

-- Object['*'] = function(self) end

-- Object['/'] = function(self) end

-- Object['+'] = function(self) end

-- Object['-'] = function(self) end