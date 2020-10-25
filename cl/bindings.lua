--[[
    This file is responsbile for directly communicating with the NUI
    It contains functions that will send over data through SendNUIMessage
]] --
Bindings = {}

local messageQueue = {}
local function postNUI(payload)
    table.insert(messageQueue, payload)
end

-- menu related bindings
function Bindings.createMenu(menu)
    local uid = createUid()
    menu.id = uid
    menu.buttons = {}
    -- if menu.open == nil then menu.open = false end

    postNUI({type = 'menu_create', payload = menu})
    return uid
end
function Bindings.updateMenu(partial)
    postNUI({type = 'menu_update', payload = partial})
end
function Bindings.destroyMenu(mid)
    postNUI({type = 'menu_destroy', payload = {id = mid}})
end

-- button related bindings
function Bindings.createButton(button)
    local uid = createUid()
    button.id = uid

    postNUI({type = 'button_create', payload = button})
    return uid
end
function Bindings.updateButton(partial)
    postNUI({type = 'button_update', payload = partial})
end
function Bindings.destroyButton(bid)
    postNUI({type = 'button_destroy', payload = {id = bid}})
end

-- misc bindings
function Bindings.sendAction(action)
    postNUI({type = 'action', action = action})
end
-- sends to the UI that the lua client is ready
function Bindings.sendReady()
    -- this must be sent immediately since the thread below relies on it
    SendNUIMessage({type = 'ready'})
end

local function shouldSend()
    local state = GetResourceState(GetCurrentResourceName())
    return state == 'started' or state == 'starting'
end
Citizen.CreateThread(function()
    local nuiReady = false
    Events.addHandler(Events.global, 'ready', function() nuiReady = true end)

    -- wait for the NUI to load
    while not nuiReady do Citizen.Wait(0) end

    while true do
        if #messageQueue > 0 and shouldSend() then
            for _, m in ipairs(messageQueue) do
                SendNUIMessage(m)
            end
            messageQueue = {}
        end
        Citizen.Wait(0)
    end
end)
