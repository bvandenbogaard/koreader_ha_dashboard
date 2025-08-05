local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local HAClient = require("ha_client")
local logger = require("logger")
local _ = require("gettext")

local HADashboard = WidgetContainer:extend {
    name = "ha_dashboard",
    settings_file = DataStorage:getSettingsDir() .. "/ha_dashboard.lua",
}

function HADashboard:addToMainMenu(menu_items)
    menu_items.ha_dashboard = {
        text = _("Home Assistant Dashboard"),
        sorting_hint = "main",
        callback = function()
            self:open()
        end,
    }
end

function HADashboard:init()
    logger:setLevel(logger.levels.dbg) --  Set logger level to debug for detailed output

    self.loadSettings(self)
    self.ui.menu:registerToMainMenu(self)

    logger.dbg("HADashboard: initialized")
end

function HADashboard:cleanup()
    logger.dbg("HADashboard: cleaned up")
end

function HADashboard:loadSettings()
    logger.dbg("HADashboard: Looking for settings file at " .. self.settings_file)

    self.settings = LuaSettings:open(self.settings_file)
    if next(self.settings.data) == nil then
        logger.dbg("HADashboard: No settings file found, using default settings")
        self.updated = true
        self.settings.data = require("settings")
    else
        logger.dbg("HADashboard: Settings file found, using existing settings")
    end

    logger.dbg("HADashboard: Using Home Assistant base url " .. self.settings.data.base_url)

    HAClient:useSettings(self.settings.data)
end

function HADashboard:onFlushSettings()
    if self.updated then
        self.settings:flush()
        self.updated = nil
        logger.dbg("HADashboard: Settings flushed")
    end
end

function HADashboard:open()
    logger.dbg("HADashboard: opened")
end

return HADashboard
