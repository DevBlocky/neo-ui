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
    for i = 1, #events do
        local h = events[i]
        if h.name == name and h.handler == handler then
            table.remove(events, i)
            i = i - 1
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

-- listens for events from the NUI
RegisterNUICallback('message', function(payload, cb)
    if payload.type == 'ready' then
        Events.emit(Events.global, 'ready')
    elseif payload.type == 'open' then
        Events.emit(Events.global, 'menuOpen', payload.menu)
    elseif payload.type == 'close' then
        Events.emit(Events.global, 'menuClose', payload.menu)
    elseif payload.type == 'select' then
        Events.emit(Events.global, 'buttonSelect', payload.menu, payload.button)
    elseif payload.type == 'move' then
        Events.emit(Events.global, 'buttonHover', payload.menu, payload.button,
                    payload.index)
    elseif payload.type == 'check_update' then
        Events.emit(Events.global, 'buttonCheck', payload.menu, payload.button,
                    payload.checked)
    elseif payload.type == 'list_move' then
        Events.emit(Events.global, 'buttonListMove', payload.menu,
                    payload.button, payload.index)
    end
    -- print(json.encode(payload))
    cb('OK')
end)
