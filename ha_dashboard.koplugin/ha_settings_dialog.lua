local MultiInputDialog = require("ui/widget/multiinputdialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local HAClient = require("ha_client")

local _ = require("gettext")

local HASettingsDialog = {}
HASettingsDialog.__index = HASettingsDialog

function HASettingsDialog:new(settings, onSettingsUpdatedCallback)
    local obj = {
        settings = settings or {},
        dialog = nil,
        onSettingsUpdatedCallback = onSettingsUpdatedCallback,
    }
    setmetatable(obj, self)
    obj:createDialog()
    return obj
end

function HASettingsDialog:createDialog()
    self.dialog = MultiInputDialog:new {
        title = _("Home Assistant settings"),
        fields = {
            {
                description = _("Home Assistant URL"),
                text = self.settings.base_url or "",
                hint = "http://homeassistant.local:8123",
            },
            {
                description = _("Long-lived access token"),
                text = self.settings.token or "",
                hint = "",
                height = 300,
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
                    text = _("Test settings"),
                    id = "test",
                    callback = function()
                        self:testSettings()
                    end,
                },
                {
                    text = _("Use settings"),
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

function HASettingsDialog:testSettings()
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
        local result, err = client:getAPIStatus()

        UIManager:close(test_msg)

        if result then
            local success_msg = InfoMessage:new {
                text = _("Settings are correct!"),
            }
            UIManager:show(success_msg)
        else
            local error_msg = InfoMessage:new {
                text = _("Test failed: ") .. (err or "unknown error"),
            }
            UIManager:show(error_msg)
        end
    end)
end

function HASettingsDialog:useSettings()
    local base_url, token, valid = self:validateFields()
    if not valid then return end

    UIManager:close(self.dialog)
    if self.onSettingsUpdatedCallback then
        self.onSettingsUpdatedCallback(base_url, token)
    end
end

return HASettingsDialog
