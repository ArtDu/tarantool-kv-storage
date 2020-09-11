#!/usr/bin/env tarantool
local http_router = require('http.router')
local http_server = require('http.server')
local json = require('json')
local log = require('log')

local httpd = http_server.new(
        os.getenv("SERVER_IP"),
        os.getenv("SERVER_PORT"), {
            log_requests = true,
            log_errors = true
        })
local router = http_router.new()

box.cfg {
    listen = os.getenv("LISTEN_URI"),
    log_format = 'plain',
    log = 'app.log',
    background = true,
    memtx_memory = 128 * 1024 *1024,
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

function isKeyValCorrect(key, val)
    local ok, err
    ok, err = pcall(json.decode, val)
    if key == nil or type(key) ~= 'string' then
        log.info("Error: key invalid")
        log.info("Key:")
        log.info(key)
        return false
    elseif not ok or type(val) ~= 'string' then
        log.info("Error: val invalid")
        log.info("Val:")
        log.info(val)
        log.info(err)
        return false
    end
    return true
end

function isJsonPostCorrect(req)
    local ok, kv, key, val

    ok, kv = pcall(req.json, req)
    if ok then
        key, val = kv['key'], kv['value']
        if not isKeyValCorrect(key, val) then
            return false
        end
    else
        log.info("Error: body json invalid")
        log.info(kv)
        return false
    end
    return true, key, val
end

function isJsonPutCorrect(req)
    local ok, kv, key, val

    ok, kv = pcall(req.json, req)
    if ok then
        key, val = req:stash('key'), kv['value']
        if not isKeyValCorrect(key, val) then
            return false
        end
    else
        log.info("Error: body json invalid")
        return false
    end
    return true, key, val
end

router:route({ method = 'POST', path = '/kv' }, function(req)
    local ok, key, val = isJsonPostCorrect(req)
    if not ok then
        return { status = 400 }
    end

    kv = box.space.dict:get(key)
    if kv == nil or #kv == 0 then
        box.space.dict:insert { key, val }
        log.info("Ok, key, val:")
        log.info(key)
        log.info(val)
        return { status = 200 }
    else
        log.info("Error: Key already exist:")
        log.info(key)
        return { status = 409 }
    end
end)

router:route({ method = 'PUT', path = '/kv/:key' }, function(req)
    local ok, key, val = isJsonPutCorrect(req)
    if not ok then
        return { status = 400 }
    end

    kv = box.space.dict:get(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found")
        return { status = 404 }
    else
        box.space.dict:update(key, { { '=', 2, val } })
        log.info("Ok, new value:")
        log.info(val)
        return { status = 200 }
    end
end)

router:route({ method = 'GET', path = '/kv/:key' }, function(req)
    local key, val, kv
    key = req:stash('key')

    kv = box.space.dict:get(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found, key: " .. key)
        return { status = 404 }
    end
    val = kv[1][2]
    log.info("Ok, value:")
    log.info(val)
    return { status = 200, body = val }
end)

router:route({ method = 'DELETE', path = '/kv/:key' }, function(req)
    local key, kv

    key = req:stash('key')
    kv = box.space.dict:get(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found, key: " .. key)
        return { status = 404 }
    end

    box.space.dict:delete(key)
    log.info("Ok, key: " .. key)
    return { status = 200 }
end)

httpd:set_router(router)
httpd:start()
