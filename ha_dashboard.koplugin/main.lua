local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local InfoMessage = require("ui/widget/infomessage")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local HASettingsDialog = require("ha_settings_dialog")
local UIManager = require("ui/uimanager")
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
    logger:setLevel(logger.levels.info) --  Set logger level to info for detailed output

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
        self.show_welcome_message = true
    else
        logger.dbg("HADashboard: Settings file found, using existing settings")
    end

    logger.dbg("HADashboard: Using Home Assistant base url " .. self.settings.data.base_url)
end

function HADashboard:onFlushSettings()
    if self.updated then
        self.settings:flush()
        self.updated = nil
        logger.info("HADashboard: Settings flushed")
    end
end

function HADashboard:open()
    logger.dbg("HADashboard: opened")

    local function onSettingsUpdated(base_url, token, settings_are_valid)
        self.settings.data.base_url = base_url
        self.settings.data.settings_are_valid = settings_are_valid
        self.settings.data.token = token
        self.updated = true
        self:onFlushSettings()

        logger.info("HADashboard: Settings updated")
    end

    if self.show_welcome_message then
        local welcome_msg = InfoMessage:new {
            text = _("Welcome to the Home Assistant Dashboard!\n"
                .. "Please set your Home Assistant URL and token in the settings dialog."),
            dismiss_callback = function()
                HASettingsDialog:new({
                        base_url = self.settings.data.base_url,
                        token = self.settings.data.token
                    },
                    onSettingsUpdated)
                self.show_welcome_message = false
            end
        }
        UIManager:show(welcome_msg)
    elseif not self.settings.data.settings_are_valid then
        local welcome_msg = InfoMessage:new {
            text = _("Welcome to the Home Assistant Dashboard!\n"
                .. "Please confirm your Home Assistant URL and token in the settings dialog."),
            dismiss_callback = function()
                HASettingsDialog:new({
                        base_url = self.settings.data.base_url,
                        token = self.settings.data.token
                    },
                    onSettingsUpdated)
            end
        }
        UIManager:show(welcome_msg)
    else
        HASettingsDialog:new({
                base_url = self.settings.data.base_url,
                token = self.settings.data.token
            },
            onSettingsUpdated)
    end
end

return HADashboard
