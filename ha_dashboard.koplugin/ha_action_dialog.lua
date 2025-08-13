local MultiInputDialog = require("ui/widget/multiinputdialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local json = require("json")

local _ = require("gettext")

local HAActionDialog = {}
HAActionDialog.__index = HAActionDialog

---@class HAActionDialog
---@field settings table "Settings for the dialog"
---@field dialog any "Dialog instance"
---@field onActionAddedCallback function "Callback function when an action is added"

--- Constructor for HAActionDialog.
---@param settings table "Settings containing entity_id, domain, service, and data"
---@param onActionAddedCallback function "Callback function to be called when an action is added"
---@return HAActionDialog "New instance of HAActionDialog"
function HAActionDialog:new(settings, onActionAddedCallback)
    local obj = {
        settings = settings or {},
        dialog = nil,
        onActionAddedCallback = onActionAddedCallback,
    }
    print(onActionAddedCallback)
    setmetatable(obj, self)
    obj:createDialog()
    return obj
end

--- Create and show the action dialog.
function HAActionDialog:createDialog()
    self.dialog = MultiInputDialog:new {
        title = _("Action settings"),
        fields = {
            {
                description = _("Entity ID"),
                text = self.settings.entity_id or "",
                hint = "light.living_room, switch.kitchen",
            },
            {
                description = _("Domain"),
                text = self.settings.domain or "",
                hint = "light, switch",
            },
            {
                description = _("Service"),
                text = self.settings.service or "",
                hint = "turn_on, turn_off, toggle",
            },
            {
                description = _("Data"),
                text = json.encode(self.settings.data) or "",
                hint = "{\"entity_id\":\"light.living_room\"}",
            }
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(self.dialog)
                    end,
                },
                {
                    text = _("Save"),
                    callback = function()
                        self:useSettings()
                    end,
                },
            },
        },
    }

    UIManager:show(self.dialog)
    self.dialog:onShowKeyboard()
end

--- Validate the fields in the dialog.
---@return string|nil "Entity ID"
---@return string|nil "Domain"
---@return string|nil "Service"
---@return number|nil "Data"
---@return boolean "True if all fields are valid, false otherwise"
function HAActionDialog:validateFields()
    local fields = self.dialog:getFields()
    local data = nil
    if fields[1] == "" or fields[2] == "" or fields[3] == "" then
        local required_msg = InfoMessage:new {
            text = _("Please fill in all fields."),
        }
        UIManager:show(required_msg)
        return nil, nil, nil, nil, false
    end
    if fields[4] ~= "" then
        local ok, result = pcall(function()
            return json.decode(fields[4])
        end)

        if ok then
            data = result
        else
            local required_msg = InfoMessage:new {
                text = _("Unable to read the data as JSON, please check the data field for errors."),
            }
            UIManager:show(required_msg)
            return nil, nil, nil, nil, false
        end
    end
    return fields[1], fields[2], fields[3], data, true
end

--- Use the settings from the dialog to add an action.
function HAActionDialog:useSettings()
    local entity_id, domain, service, data, valid = self:validateFields()
    if not valid then return end

    UIManager:close(self.dialog)

    print("HADashboard: Action added for entity_id: " .. entity_id)
    if self.onActionAddedCallback then
        print("HADashboard: Calling onActionAddedCallback")
        self.onActionAddedCallback(entity_id, domain, service, data)
    end
end

return HAActionDialog
