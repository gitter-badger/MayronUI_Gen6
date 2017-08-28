-- Starts database and initializes modules

----------------------------------
-- Setup namespaces
----------------------------------
local addonName, core = ...;
local private = {};
local Module;

local LibObjectLua = LibStub:GetLibrary("LibObjectLua");

core.api = LibObjectLua:CreatePackage("API");;
core.api.public = LibObjectLua:CreatePackage("API", "MayronUI");
core.db = LibStub:GetLibrary("LibMayronDB"):CreateDatabase("MUIdb", addonName);

-- TODO:
-- core.GuiBuilder = LibStub:GetLibrary("LibGuiBuilder");
-- core.EventManager = LibStub:GetLibrary("LibEventManager");

----------------------------------
-- Add defaults
----------------------------------
core.db:AddToDefaults("global.core", {
    UiScale = 0.7,
    ChangeGameFont = true,
    Font = "MUI_Font"
});

----------------------------------
-- Module Class
----------------------------------
Module = core.api:CreateClass("Module");

function Module:__Construct(data)

end

function Module:__Destruct(data)

end

function Module.Static:RegisterModule(tbl)

end

function Module.Static:IterateModules()

end

function Module:Enable(data)

end

function Module:Disable(data)

end

function Module:OnEnable(data)

end

function Module:OnLoad(data)

end

function Module:OnDisable(data)

end