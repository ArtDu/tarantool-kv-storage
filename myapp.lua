#!/usr/bin/env tarantool
local http_router = require('http.router')
local http_server = require('http.server')
local json = require('json')
local log = require('log')

local httpd = http_server.new('127.0.0.1', 8080, {
    log_requests = true,
    log_errors = true
})
local router = http_router.new()

box.cfg {
    listen = os.getenv("LISTEN_URI"),
    log_format = 'plain',
    log = 'app.log',
    background = true,
    pid_file = 'app.pid'
}

box.once('create', function()
    box.schema.space.create('dict')
    box.space.dict:format({
        { name = 'key', type = 'string' },
        { name = 'val', type = 'string' }
    })
    box.space.dict:create_index('primary',
            { type = 'hash', parts = { 1, 'string' } })
end)

router:route({ method = 'POST', path = '/kv' }, function(req)
    local is_valid_json, lua_table, key, val

    is_valid_json, lua_table = pcall(req.json, req)
    if is_valid_json then
        key, val = lua_table['key'], lua_table['value']
        is_valid_json = pcall(json.decode, val)
        if not is_valid_json or key == nil or type(key) ~= 'string' then
            log.info("Error: key or value invalid")
            return { status = 400 }
        end
    else
        log.info("Error: body json invalid")
        return { status = 400 }
    end

    local kv = box.space.dict:select(key)
    if kv == nil or #kv == 0 then
        box.space.dict:insert { key, val }
        log.info("Ok")
        return { status = 200 }
    else
        log.info("Error: Key already exist:" .. key)
        return { status = 409 }
    end
end)

router:route({ method = 'PUT', path = '/kv/:key' }, function(req)
    local is_valid_json, lua_table, key, val

    key = req:stash('key')
    is_valid_json, lua_table = pcall(req.json, req)
    if is_valid_json then
        val = lua_table['value']
        is_valid_json = pcall(json.decode, val)
        if not is_valid_json or type(key) ~= 'string' then
            log.info("Error: key or value invalid")
            return { status = 400 }
        end
    else
        log.info("Error: body json invalid")
        return { status = 400 }
    end

    local kv = box.space.dict:select(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found")
        return { status = 404 }
    else
        box.space.dict:update(key, { { '=', 2, val } })
        log.info("Ok")
        log.info(val)
        return { status = 200 }
    end
end)

router:route({ method = 'GET', path = '/kv/:key' }, function(req)
    local key = req:stash('key')
    local kv = box.space.dict:select(key)
    log.info(kv)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found, key: " .. key)
        return { status = 404 }
    end
    local val = kv[1][2]
    log.info("Ok, value:")
    log.info(val)
    return { status = 200, body = val }
end)

router:route({ method = 'DELETE', path = '/kv/:key' }, function(req)
    local key = req:stash('key')
    local kv = box.space.dict:select(key)
    log.info(kv)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found, key: " .. key)
        return { status = 404 }
    end
    box.space.dict:delete(key)
    log.info("Ok")
    return { status = 200 }
end)

httpd:set_router(router)
httpd:start()
