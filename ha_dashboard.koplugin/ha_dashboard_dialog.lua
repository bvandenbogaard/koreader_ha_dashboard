local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local CenterContainer = require("ui/widget/container/centercontainer")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local HAActionDialog = require("ha_action_dialog")
local HAEntitySelectionDialog = require("ha_entity_selection_dialog")
local _ = require("gettext")

local HADashboardDialog = {}
HADashboardDialog.__index = HADashboardDialog

---@class HADashboardDialog
---@field main HADashboard "Reference to the main HADashboard instance"
---@field dialog any "Dialog instance"
---@field onActionAddedCallback fun() "Callback function when an action is added"

--- Constructor for HADashboardDialog.
---@param main HADashboard "Reference to the main HADashboard instance"
---@param onActionAddedCallback function "Callback function when an action is added"
---@return HADashboardDialog
function HADashboardDialog:new(main, onActionAddedCallback)
    local obj = {
        main = main,
        dialog = nil,
        pollerFunctionObject = nil,
        pollerInterval = 30, -- Poll every 30 seconds
        onActionAddedCallback = onActionAddedCallback,
    }
    setmetatable(obj, self)
    obj:createDialog()
    return obj
end

--- Create and show the entity selection dialog.
---@return table "New instance of HAEntitySelectionDialog"
function HADashboardDialog:createDialog()
    self.menu_container = CenterContainer:new {
        dimen = Screen:getSize(),
    }

    self.dialog = Menu:new {
        title = _("Home Assistant dashboard"),
        item_table = {},
        show_parent = self.menu_container,
        is_borderless = true,
        title_bar_left_icon = "plus",
        onLeftButtonTap = function()
            HAEntitySelectionDialog:new(self.main, self.onActionAddedCallback)
        end,
        close_callback = function()
            if self.pollerFunctionObject then
                UIManager:unschedule(self.pollerFunctionObject)
            end
            UIManager:close(self.menu_container)
        end,
    }

    self.menu_container[1] = self.dialog

    UIManager:show(self.menu_container)

    local loading_msg = InfoMessage:new {
        text = _("Loading Home Assistant data..."),
        duration = 0,
    }
    UIManager:show(loading_msg)

    self.pollerFunctionObject = function()
        self:_refreshStates()
        UIManager:close(loading_msg)
    end

    UIManager:scheduleIn(0, self.pollerFunctionObject)
end

--- Load entity states asynchronously and updates the UI.
--- @private
function HADashboardDialog:_refreshStates()
    local all_states, err = self.main.client:getAllStates()

    if all_states == nil then
        local error_msg = InfoMessage:new {
            text = string.format(_("HA Dashboard offline: %s"), err or _("unknown error")),
            timeout = self.pollerInterval,
            icon = "notice-warning"
        }
        UIManager:show(error_msg)
    else
        local filtered = self:_filterStates(all_states)
        self:_updateStates(filtered)
    end

    self.pollerFunctionObject = function()
        self:_refreshStates()
    end

    UIManager:scheduleIn(self.pollerInterval, self.pollerFunctionObject)
end

function HADashboardDialog:_filterStates(all_states)
    local filtered = {}
    for _, entity in ipairs(self.main.settings.data.entities or {}) do
        if all_states[entity.id] then
            filtered[entity.id] = all_states[entity.id]
        end
    end
    return filtered
end

function HADashboardDialog:_updateStates(entity_states)
    if not self.dialog then
        return
    end

    local item_table = self:_buildEntityItems(entity_states)

    self.dialog.item_table = item_table
    self.dialog:updateItems()
    UIManager:setDirty(self.dialog, "ui")
end

--- Handle the response from the Home Assistant API.
---@private
---@param entity table "Entity data from the API"
---@return string "Formatted entity text"
function HADashboardDialog:_formatEntityText(entity)
    local name = entity.attributes and entity.attributes.friendly_name or entity.entity_id
    local state = entity.state or _("unknown")
    local unit = entity.attributes and entity.attributes.unit_of_measurement or ""
    local sep = (unit ~= "" and state ~= "unknown" and state ~= "unavailable") and " " or ""
    return string.format("%s (%s%s%s)", name, state, sep, unit)
end

--- Build the items for the entity dialog.
---@private
---@param entity_states table "Table containing entity states"
---@return table "Table of items for the entity dialog"
function HADashboardDialog:_buildEntityItems(entity_states)
    local item_table = {}

    local function findById(t, id)
        for _, v in ipairs(t) do
            if v.id == id then
                return v
            end
        end
        return nil
    end

    for _, entity in pairs(entity_states) do
        table.insert(item_table, {
            text = self:_formatEntityText(entity),
            callback = function()
                coroutine.wrap(function()
                    local entity_settings = findById(self.main.settings.data.entities, entity.entity_id)
                    if entity_settings and entity_settings.action and entity_settings.action.domain and entity_settings.action.service then
                        local service_response = self.main.client:callService(
                            entity_settings.action.domain,
                            entity_settings.action.service,
                            entity_settings.action.data
                        )

                        if type(service_response) == "table" then
                            for _, resp in ipairs(service_response) do
                                if resp.entity_id then
                                    entity_states[resp.entity_id] = resp
                                end
                            end
                        end

                        self:_updateStates(entity_states)
                    end
                end)()
            end,
            hold_callback = function()
                HAActionDialog:new({
                    entity_id = entity.id,
                    domain = entity.action.domain,
                    service = entity.action.service,
                    data = entity.action.data,
                }, self.onActionAddedCallback)
            end,
        })
    end

    return item_table
end

return HADashboardDialog
