local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local CenterContainer = require("ui/widget/container/centercontainer")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local HAClient = require("ha_client")
local HAActionDialog = require("ha_action_dialog")
local _ = require("gettext")

local HAEntitySelectionDialog = {}
HAEntitySelectionDialog.__index = HAEntitySelectionDialog

---@class HAEntitySelectionDialog
---@field settings table "Settings containing base_url and token"
---@field dialog any "Dialog instance"
---@field onActionAddedCallback fun() "Callback function when an action is added"

--- Constructor for HAEntitySelectionDialog.
---@param settings table "Settings containing base_url and token"
---@param onActionAddedCallback function "Callback function when an action is added"
---@return HAEntitySelectionDialog
function HAEntitySelectionDialog:new(settings, onActionAddedCallback)
    local obj = {
        settings = settings or {},
        dialog = nil,
        onActionAddedCallback = onActionAddedCallback,
    }
    setmetatable(obj, self)
    obj:createDialog()
    return obj
end

--- Create and show the entity selection dialog.
---@return table "New instance of HAEntitySelectionDialog"
function HAEntitySelectionDialog:createDialog()
    self.menu_container = CenterContainer:new {
        dimen = Screen:getSize(),
    }
    self.haclient = HAClient:new {
        base_url = self.settings.base_url,
        token = self.settings.token,
    }

    self:_loadStatesAsync()
end

--- Load entity states asynchronously and render the UI.
--- @private
function HAEntitySelectionDialog:_loadStatesAsync()
    local loading_msg = InfoMessage:new {
        text = _("Loading Home Assistant data..."),
        duration = 0,
    }
    UIManager:show(loading_msg)

    UIManager:scheduleIn(0, function()
        coroutine.wrap(function()
            local entity_states, err = self.haclient:getAllStates()
            UIManager:close(loading_msg)

            if not entity_states then
                UIManager:show(InfoMessage:new {
                    text = string.format(_("Error loading states: %s"), err or "?"),
                    duration = 3,
                })
                return
            end

            self:_renderUI(entity_states)
        end)()
    end)
end

--- Render the UI with the given entity states.
---@private
---@param entity_states table "Table containing entity states"
function HAEntitySelectionDialog:_renderUI(entity_states)
    local item_table = self:_buildEntityItems(entity_states)

    self.dialog = Menu:new {
        title = _("Add entity"),
        subtitle = _("Please select an entity to add to the dashboard."),
        item_table = item_table,
        show_parent = self.menu_container,
        is_borderless = true,
        close_callback = function()
            UIManager:close(self.menu_container)
        end,
    }

    self.menu_container[1] = self.dialog

    UIManager:show(self.menu_container)
end

--- Handle the response from the Home Assistant API.
---@private
---@param entity table "Entity data from the API"
---@return string "Formatted entity text"
function HAEntitySelectionDialog:_formatEntityText(entity)
    local name = entity.attributes and entity.attributes.friendly_name or entity.entity_id
    local state = entity.state or _("unknown")
    local unit = entity.attributes and entity.attributes.unit_of_measurement or ""
    local sep = (unit ~= "" and state ~= "unknown" and state ~= "unavailable") and " " or ""
    return string.format("%s (%s%s%s)", name, state, sep, unit)
end

--- Build the items for the entity selection dialog.
---@private
---@param entity_states table "Table containing entity states"
---@return table "Table of items for the entity selection dialog"
function HAEntitySelectionDialog:_buildEntityItems(entity_states)
    local item_table = {}

    for _, entity in pairs(entity_states) do
        table.insert(item_table, {
            text = self:_formatEntityText(entity),
            callback = function()
                HAActionDialog:new({
                    entity_id = entity.entity_id,
                    domain = entity.entity_id:match("^(%w+)%."),
                    service = "toggle",
                    data = { entity_id = entity.entity_id },
                }, self.onActionAddedCallback)
            end,
        })
    end

    table.sort(item_table, function(a, b)
        return a.text < b.text
    end)

    return item_table
end

return HAEntitySelectionDialog
