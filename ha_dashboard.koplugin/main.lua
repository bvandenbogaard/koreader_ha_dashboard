local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local InfoMessage = require("ui/widget/infomessage")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local HADashboardDialog = require("ha_dashboard_dialog")
local HASettingsDialog = require("ha_settings_dialog")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local _ = require("gettext")

--- Home Assistant Dashboard plugin for Koreader.
--- Provides a dashboard interface to interact with Home Assistant entities and actions.
---@class HADashboard : WidgetContainer
---@field settings_file string "Path to the settings file"
local HADashboard = WidgetContainer:extend {
    name = "ha_dashboard",
    settings_file = DataStorage:getSettingsDir() .. "/ha_dashboard.lua",
}

--- Add the dashboard to the main menu.
---@param menu_items table "Table to add menu items to"
function HADashboard:addToMainMenu(menu_items)
    menu_items.ha_dashboard = {
        text = _("Home Assistant Dashboard"),
        sorting_hint = "main",
        callback = function()
            self:open(false)
        end,
    }
    menu_items.ha_dashboard_settings = {
        text = _("Home Assistant Dashboard settings"),
        sorting_hint = "main",
        callback = function()
            self:open(true)
        end,
    }
end

--- Initialize the HADashboard plugin.
function HADashboard:init()
    logger:setLevel(logger.levels.info) --  Set logger level to info for detailed output

    self.loadSettings(self)
    self.ui.menu:registerToMainMenu(self)

    logger.dbg("HADashboard: initialized")
end

--- Clean up the dashboard resources.
function HADashboard:cleanup()
    logger.dbg("HADashboard: cleaned up")
end

--- Load the settings from the settings file.
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

--- Flush the settings to the file if they have been updated.
function HADashboard:onFlushSettings()
    if self.updated then
        self.settings:flush()
        self.updated = nil
        logger.info("HADashboard: Settings flushed")
    end
end

--- Open the Home Assistant Dashboard.
--- @param settings boolean "If true, open the settings dialog instead of the dashboard"
function HADashboard:open(settings)
    logger.dbg("HADashboard: opened")

    local function onSettingsUpdated(base_url, token, settings_are_valid)
        self.settings.data.base_url = base_url
        self.settings.data.settings_are_valid = settings_are_valid
        self.settings.data.token = token
        self.updated = true
        self:onFlushSettings()

        logger.info("HADashboard: Settings updated")
    end

    local function onActionAdded(entity_id, domain, service, data)
        print("HADashboard: Action added for entity_id: " .. entity_id)
        table.insert(self.settings.data.entities, {
            id = entity_id,
            action = {
                domain = domain,
                service = service,
                data = data,
            }
        })
        self.updated = true
        self:onFlushSettings()

        logger.info("HADashboard: Action added")
    end

    local function openSettings()
        HASettingsDialog:new({
                base_url = self.settings.data.base_url,
                token = self.settings.data.token
            },
            onSettingsUpdated)
    end

    if self.show_welcome_message or not self.settings.data.settings_are_valid then
        local welcome_text

        if self.show_welcome_message then
            welcome_text = _("Welcome to the Home Assistant Dashboard!\n"
                .. "Please set your Home Assistant URL and token in the settings dialog.")
            self.show_welcome_message = false
        elseif not self.settings.data.settings_are_valid then
            welcome_text = _("Welcome to the Home Assistant Dashboard!\n"
                .. "Please confirm your Home Assistant URL and token in the settings dialog.")
        end

        local welcome_msg = InfoMessage:new {
            text = welcome_text,
            dismiss_callback = openSettings
        }
        UIManager:show(welcome_msg)
    elseif settings then
        openSettings()
    else
        HADashboardDialog:new(self.settings.data, onActionAdded)
    end
end

return HADashboard
