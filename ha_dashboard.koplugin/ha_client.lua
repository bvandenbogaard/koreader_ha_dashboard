local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")

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

function HAClient:getAPIStatus()
    logger.info("HAClient: Checking the availability of the Home Assitant API")
    local url = string.format("%s/api/", self.base_url)
    local response = {}
    local _, status = http.request {
        url = url,
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. self.token
        },
        sink = ltn12.sink.table(response),
    }

    if status == 200 then
        local resp_str = table.concat(response)
        local ok, resp_json = pcall(json.decode, resp_str)
        if ok and type(resp_json) == "table" then
            return resp_json
        else
            logger.err("HAClient: Failed to parse JSON or response invalid")
            return nil, "Invalid response"
        end
    else
        logger.err("HAClient: Failed to get a health check")
        return nil, "Failed to get a health check"
    end
end

function HAClient:getAllStates()
    logger.info("HAClient: Getting all states")
    local url = string.format("%s/api/states", self.base_url)
    local response = {}
    local _, status = http.request {
        url = url,
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. self.token
        },
        sink = ltn12.sink.table(response)
    }

    if status == 200 then
        local resp_str = table.concat(response)
        local ok, resp_json = pcall(json.decode, resp_str)
        if ok and type(resp_json) == "table" then
            local states_by_id = {}
            for _, entity in ipairs(resp_json) do
                if entity.entity_id then
                    states_by_id[entity.entity_id] = entity
                end
            end
            return states_by_id
        else
            logger.err("HAClient: Failed to parse JSON or response invalid")
            return nil, "Invalid response"
        end
    else
        logger.err("HAClient: Failed to get all states")
        return nil, "Failed to get all entity states"
    end
end

function HAClient:getStateByEntityId(entity_id)
    logger.info("HAClient: Getting state for entity id: " .. entity_id)
    local url = string.format("%s/api/states/%s", self.base_url, entity_id)
    local response = {}
    local _, status = http.request {
        url = url,
        method = "GET",
        headers = {
            ["Authorization"] = "Bearer " .. self.token
        },
        sink = ltn12.sink.table(response)
    }
    if status == 200 then
        local resp_str = table.concat(response)
        local ok, resp_json = pcall(json.decode, resp_str)
        if ok then
            return resp_json
        else
            logger.err("HAClient: Failed to parse JSON response")
            return nil, "Failed to parse JSON"
        end
    else
        logger.err("HAClient: Failed to get state: " .. (status or "nil"))
        return nil, "Failed to get state"
    end
end

function HAClient:callService(domain, service, data)
    logger.info(string.format("HAClient: Calling service '%s.%s' with data: %s", domain, service, json.encode(data)))
    local url = string.format("%s/api/services/%s/%s", self.base_url, domain, service)
    local body = data and json.encode(data) or "{}"
    local response = {}
    local _, status = http.request {
        url = url,
        method = "POST",
        headers = {
            ["Authorization"] = "Bearer " .. self.token,
            ["Content-Length"] = tostring(#body),
            ["Content-Type"] = "application/json"
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response)
    }
    if status == 200 then
        local resp_str = table.concat(response)
        local ok, resp_json = pcall(json.decode, resp_str)
        if ok then
            return resp_json
        else
            logger.err("HAClient: Failed to parse JSON response")
            return nil, "Failed to parse JSON"
        end
    else
        logger.err("HAClient: Failed to call service: " .. (status or "nil"))
        return nil, "Failed to call service"
    end
end

return HAClient
