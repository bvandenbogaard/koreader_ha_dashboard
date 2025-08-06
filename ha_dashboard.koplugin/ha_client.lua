local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")
local _ = require("gettext")

local HAClient = {}
HAClient.__index = HAClient

function HAClient:new(settings)
    local obj = {
        base_url = settings.base_url,
        token = settings.token,
    }
    setmetatable(obj, self)
    return obj
end

function HAClient:_request(method, path, useToken, body)
    local url = string.format("%s%s", self.base_url, path)
    local response = {}
    local headers = {}

    if useToken then
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

function HAClient:getAPIStatus()
    logger.info("HAClient: Checking the availability of the Home Assistant API")
    local status, body = self:_request("GET", "/api/", true)
    return self:_handle_response(status, body)
end

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

function HAClient:getStateByEntityId(entity_id)
    logger.info("HAClient: Getting state for entity id: " .. entity_id)
    local status, body = self:_request("GET", "/api/states/" .. entity_id, true)
    return self:_handle_response(status, body)
end

function HAClient:callService(domain, service, data)
    logger.info(string.format("HAClient: Calling service '%s.%s' with data: %s", domain, service, json.encode(data)))
    local body = data and json.encode(data) or "{}"
    local status, resp_body = self:_request("POST", string.format("/api/services/%s/%s", domain, service), true, body)
    return self:_handle_response(status, resp_body)
end

return HAClient
