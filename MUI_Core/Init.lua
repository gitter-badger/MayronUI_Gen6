-- Starts database and initializes modules

------------------------
-- Setup namespaces
------------------------
local addonName, core = ...;
local private = {};
local module;

core.Database = LibStub:GetLibrary("LibMayronDB"):CreateDatabase("MUIdb", addonName);
core.MuiToolkit = LibStub:GetLibrary("LibMuiToolkit");
core.GuiBuilder = LibStub:GetLibrary("LibGuiBuilder");
core.EventManager = LibStub:GetLibrary("LibEventManager");

local db = core.Database;
local em = core.EventManager;
local tk = core.MuiToolkit;
local gui = core.GuiBuilder;

------------------------
-- Add defaults
------------------------
db:AddToDefaults("global.core", {
    uiScale = 0.7,
    changeGameFont = true,
    font = "MUI_Font",

    -- TODO: Add using db:AppendOnce()
    -- addons = {
    --     {"Aura Frames", true, "AuraFrames"},
    --     {"Bartender4", true, "Bartender4"},
    --     {"Grid", true, "Grid"},
    --     {"Masque", true, "Masque"},
    --     {"Mik Scrolling Battle Text", true, "MikScrollingBattleText"},
    --     {"OmniCC", true, "OmniCC"},
    --     {"Recount", true, "Recount"},
    --     {"Shadowed Unit Frames", true, "ShadowedUnitFrames"},
    --     {"Simple Power Bar", true, "SimplePowerBar"},
    --     {"TipTac", true, "TipTac"},
    -- }
});

------------------------
-- Module Class
------------------------

-- TODO: Move to Modules.lua
-- TODO: CreateClass needs to be in a library
module = tk:CreateClass("Module");

-- TODO: Classes should have some default functions, like iterating over children
function module.static:RegisterModule(tbl)

end

function module.static:IterateModules()

end

function module:Enable(private)

end

function module:Import(private)

end

function module:Disable(private)

end

function module:OnEnable()

end

function module:OnLoad()

end

function module:OnDisable()

end


function module:OnDestroy()

end