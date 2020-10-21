--[[
    This namespace serves as a general purpose event emitter
    It also initializes a global event emitter and handles events from the UI
]] --
Events = {}

-- initializes an events object
function Events.init() return {} end
-- adds a handler to an evnets object
function Events.addHandler(events, name, handler)
    name = string.lower(name)
    table.insert(events, {name = name, handler = handler})
end
-- removes all event handlers with the same name and handler
function Events.removeHandler(events, name, handler)
    name = string.lower(name)

    -- remove all matching items from the list
    local i = 1
    while i <= #events do
        local h = events[i]
        if h.name == name and h.handler == handler then
            table.remove(events, i)
        else
            i = i + 1
        end
    end
end
-- causes an emission of an event, basically calling all event handlers
function Events.emit(events, name, ...)
    name = string.lower(name)
    for _, h in ipairs(events) do if h.name == name then h.handler(...) end end
end

-- use the Events object as a global event handler
Events.global = Events.init()

-- tells the NUI that the lua client is ready
-- this is for when the NUI loads before the lua client
Citizen.CreateThread(function() Bindings.sendReady() end)

--[[ HANDLES EVENTS COMING FROM THE JS CLIENT ]]

-- event schema
-- [js_ev_name] = {name = client_name, params = params_to_pass_in_order}
local events = {
    ['ready'] = {name = "ready", params = {}},
    ['open'] = {name = "menuOpen", params = {"menu"}},
    ['close'] = {name = "menuClose", params = {"menu"}},
    ['select'] = {name = "buttonSelect", params = {"menu", "button"}},
    ['move'] = {name = "buttonHover", params = {"menu", "button", "index"}},
    ['check_update'] = {
        name = "buttonCheck",
        params = {"menu", "button", "checked"}
    },
    ['list_move'] = {
        name = "buttonListMove",
        params = {"menu", "button", "index"}
    }
}
RegisterNUICallback('message', function(payload, cb)
    local schema = events[payload.type]
    -- we're not setup to handle this event
    if not schema then return cb('unk_ev') end

    -- insert all params into the table in order of their name in the schema
    local params = {}
    for _, p in ipairs(schema.params) do table.insert(params, payload[p]) end
    print(json.encode(params))

    -- send out the event with the unpacked params
    Events.emit(Events.global, schema.name, table.unpack(params))
    cb('OK')
end)
