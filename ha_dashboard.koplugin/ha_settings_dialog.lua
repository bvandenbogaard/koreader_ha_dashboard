local MultiInputDialog = require("ui/widget/multiinputdialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local HAClient = require("ha_client")

local _ = require("gettext")

local HASettingsDialog = {}
HASettingsDialog.__index = HASettingsDialog

---@class HASettingsDialog
---@field main HADashboard "Reference to the main HADashboard instance"
---@field dialog any "Dialog instance"
---@field onSettingsUpdatedCallback function "Callback function when settings are updated"

--- Constructor for HASettingsDialog.
---@param main HADashboard "Reference to the main HADashboard instance"
---@param onSettingsUpdatedCallback function "Callback function to be called when settings are updated"
---@return HASettingsDialog "New instance of HASettingsDialog"
function HASettingsDialog:new(main, onSettingsUpdatedCallback)
    local obj = {
        main = main,
        dialog = nil,
        onSettingsUpdatedCallback = onSettingsUpdatedCallback,
    }
    setmetatable(obj, self)
    obj:createDialog()
    return obj
end

--- Create and show the settings dialog.
function HASettingsDialog:createDialog()
    self.dialog = MultiInputDialog:new {
        title = _("Home Assistant settings"),
        fields = {
            {
                description = _("Home Assistant URL"),
                text = self.main.settings.data.base_url or "",
                hint = "http://homeassistant.local:8123",
            },
            {
                description = _("Long-lived access token"),
                text = self.main.settings.data.token or ""
            }
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    callback = function()
                        UIManager:close(self.dialog)
                    end,
                },
                {
                    text = _("Test and save"),
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
---@return string|nil "Home Assistant URL"
---@return string|nil "Long-lived access token"
---@return boolean "True if all fields are valid, false otherwise"
function HASettingsDialog:validateFields()
    local fields = self.dialog:getFields()
    if fields[1] == "" or fields[2] == "" then
        local required_msg = InfoMessage:new {
            text = _("Please fill in all fields."),
        }
        UIManager:show(required_msg)
        return nil, nil, false
    end
    return fields[1], fields[2], true
end

--- Use the settings from the dialog.
function HASettingsDialog:useSettings()
    local base_url, token, valid = self:validateFields()
    if not valid then return end

    local client = HAClient:new {
        base_url = base_url,
        token = token,
    }

    local test_msg = InfoMessage:new {
        text = _("Testing settings..."),
        duration = 0,
    }
    UIManager:show(test_msg)

    UIManager:scheduleIn(0, function()
        coroutine.wrap(function()
            local result, err = client:getHostStatus()
            local confirm_settings = function()
                UIManager:close(test_msg)

                local confirm_msg = ConfirmBox:new {
                    text = _("Test failed: ") .. (err or "unknown error") .. "\n" .. _("Use settings anyway?"),
                    ok_text = _("Yes"),
                    ok_callback = function()
                        UIManager:close(self.dialog)
                        if self.onSettingsUpdatedCallback then
                            self.onSettingsUpdatedCallback(base_url, token, false)
                        end
                    end,
                    cancel_text = _("No"),
                }

                UIManager:show(confirm_msg)
            end

            if result then
                result, err = client:getAPIStatus()

                if result then
                    UIManager:close(test_msg)
                    UIManager:close(self.dialog)

                    if self.onSettingsUpdatedCallback then
                        self.onSettingsUpdatedCallback(base_url, token, true)
                    end

                    local success_msg = InfoMessage:new {
                        text = _("Settings are correct and saved!")
                    }

                    UIManager:show(success_msg)
                else
                    confirm_settings()
                end
            else
                confirm_settings()
            end
        end)()
    end)
end

return HASettingsDialog
