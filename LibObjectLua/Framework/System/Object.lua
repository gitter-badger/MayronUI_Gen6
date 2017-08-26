local _, Core = ...;
local Lib = Core.Lib;
if (not Lib) then return; end

local System = Lib:Import("Framework.System");
local Object = System:CreateClass("Object");

function Object:GetObjectType(data)	
	return Core:GetController(self).EntityName;
end

function Object:IsObjectType(data, objectName)
	local controller = Core:GetController(self);

	if (controller.EntityName == objectName) then
		return true;
	else
		for _, interface in ipairs(controller.Interfaces) do
			local interfaceController = Core:GetController(interface);
			if (interfaceController.EntityName == objectName) then
				return true;
			end
		end

		controller = Core:GetController(controller.ParentClass);

		while (controller) do
			if (controller.EntityName == objectName) then
				return true;
			end
			controller = Core:GetController(controller.ParentClass);
		end
	end

	return false;
end

function Object:Equals(data, other)
	if (type(other) ~= "table" or not other.GetObjectType) then 
		return false; 
	end

	if (other:GetObjectType() == self:GetObjectType()) then
		local otherData = Core:GetPrivateInstanceData(other);

		for key, value in pairs(data) do
			if (data[key] ~= otherData[key]) then
				return false;
			end
		end
	end

	return true;
end

function Object:GetParentClass(data)
	return Core:GetController(self).ParentClass;
end

function Object:GetClass()
	return getmetatable(self).Class;
end

function Object:Clone(data) 
	local controller = Core:GetController(self);
	controller.CloneFrom = self;

	local instance = controller.Class();

	if (not self:Equals(instance)) then
		error("LibObject: Clone data corrupted.");
	end

	return instance;
end

function Object:Destroy(data)
	local controller = Core:GetController(self);

	if (self.__Destruct) then
		self:__Destruct();
	end

	for key, _ in pairs(data) do
		data[key] = nil;
	end

	controller.PrivateInstanceData[tostring(self)] = nil;    
	controller.ProxyInstances[tostring(self)] = nil; 
	setmetatable(self, nil);
end