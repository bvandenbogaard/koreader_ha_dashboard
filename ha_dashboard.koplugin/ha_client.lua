local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local _ = require("gettext")

local HAClient = {}
HAClient.__index = HAClient

---@class HAClient
---@field base_url string "Base URL of the Home Assistant instance"
---@field token string "API token for authentication"

--- Constructor for HAClient.
---@param settings table "Settings containing base_url and token"
---@return HAClient "New instance of HAClient"
function HAClient:new(settings)
    local obj = {
        base_url = settings.base_url,
        token = settings.token,
    }
    setmetatable(obj, self)
    return obj
end

--- Perform an HTTP request to the Home Assistant API.
---@private
---@param method string "HTTP method (GET, POST, etc.)"
---@param path string "API endpoint path"
---@param useToken boolean|nil "Whether to use the token for authentication"
---@param body string|nil "Request body, if applicable"
---@return number "HTTP status code"
---@return string "HTTP response body"
function HAClient:_request(method, path, useToken, body)
    local url = string.format("%s%s", self.base_url, path)
    local response = {}
    local headers = {}

    if useToken and self.token then
        headers["Authorization"] = "Bearer " .. self.token
    end

    if body then
        headers["Content-Length"] = tostring(#body)
        headers["Content-Type"] = "application/json"
    end

    local params = {
        url = url,
        method = method,
        headers = headers,
        sink = ltn12.sink.table(response),
    }

    if body then
        params.source = ltn12.source.string(body)
    end

    local _, status = http.request(params)
    return status, table.concat(response)
end

--- Handle the response from the Home Assistant API.
---@private
---@param status number "HTTP status code"
---@param body string "Response body"
---@param success_callback function|nil "Optional callback for successful responses"
---@return table|nil "Parsed response data or nil if an error occurred"
---@return string|nil "Error message if an error occurred"
function HAClient:_handle_response(status, body, success_callback)
    if status == 200 then
        local ok, data = pcall(json.decode, body)
        if ok and type(data) == "table" then
            return success_callback and success_callback(data) or data
        else
            logger.err("HAClient: Failed to parse JSON or response invalid")
            return nil, _("Invalid response")
        end
    elseif status == 401 then
        logger.err("HAClient: Token not accepted, check your token")
        return nil, _("Token not accepted, check your token")
    elseif status == 403 then
        logger.err("HAClient: Unexpected API response, check your URL")
        return nil, _("Unexpected API response, check your URL")
    elseif status == 404 then
        logger.err("HAClient: API not found, check your URL")
        return nil, _("API not found, check your URL")
    else
        logger.err("HAClient: Request failed with status " .. tostring(status))
        return nil, _("Request failed with status " .. tostring(status))
    end
end

--- Check the availability of the Home Assistant host.
---@return string|nil "Host response or nil if not available"
---@return string|nil "Error message if the host is not available"
function HAClient:getHostStatus()
    logger.info("HAClient: Checking the availability of the Home Assistant host")
    local status, body = self:_request("GET", "/", false)
    if status == 200 then
        return body
    else
        logger.err("HAClient: Host response was not OK, check your URL")
        return nil, _("Host response was not OK, check your URL")
    end
end

--- Check the availability of the Home Assistant API.
---@return table|nil "API status or nil if not available"
---@return string|nil "Error message if the API is not available"
function HAClient:getAPIStatus()
    logger.info("HAClient: Checking the availability of the Home Assistant API")
    local status, body = self:_request("GET", "/api/", true)
    return self:_handle_response(status, body)
end

--- Get all states from Home Assistant.
---@return table|nil "Table of entity states indexed by entity ID or nil if not available"
---@return string|nil "Error message if the request fails"
function HAClient:getAllStates()
    logger.info("HAClient: Getting all states")
    local status, body = self:_request("GET", "/api/states", true)
    return self:_handle_response(status, body, function(data)
        local states_by_id = {}
        for _, entity in ipairs(data) do
            if entity.entity_id then
                states_by_id[entity.entity_id] = entity
            end
        end
        return states_by_id
    end)
end

--- Get the state of a specific entity by its ID.
---@param entity_id string "Entity ID to get the state for"
---@return table|nil "Entity state or nil if not available"
---@return string|nil "Error message if the request fails"
function HAClient:getStateByEntityId(entity_id)
    logger.info("HAClient: Getting state for entity id: " .. entity_id)
    local status, body = self:_request("GET", "/api/states/" .. entity_id, true)
    return self:_handle_response(status, body)
end

--- Call a service in Home Assistant.
---@param domain string "Domain of the service (e.g., 'light', 'switch')"
---@param service string "Service to call (e.g., 'turn_on', 'toggle')"
---@param data table "Data to send with the service call, if applicable"
---@return table|nil "Response from the service call or nil if not available"
---@return string|nil "Error message if the request fails"
function HAClient:callService(domain, service, data)
    logger.info(string.format("HAClient: Calling service '%s.%s' with data: %s", domain, service, json.encode(data)))
    local body = data and json.encode(data) or "{}"
    local status, resp_body = self:_request("POST", string.format("/api/services/%s/%s", domain, service), true, body)
    return self:_handle_response(status, resp_body)
end

return HAClient
