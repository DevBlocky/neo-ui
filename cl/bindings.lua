--[[
    This file is responsbile for directly communicating with the NUI
    It contains functions that will send over data through SendNUIMessage
]] --
Bindings = {}

local function shouldSend()
    local state = GetResourceState(GetCurrentResourceName())
    return state == 'started' or state == 'starting'
end

-- used to wait for the NUI to be ready
local nuiReady = false
Citizen.CreateThread(function()
    Events.addHandler(Events.global, 'ready', function() nuiReady = true end)
end)
function Bindings.wait() while not nuiReady do Citizen.Wait(1) end end

-- menu related bindings
function Bindings.createMenu(menu)
    if not shouldSend() then return end
    local uid = createUid()
    menu.id = uid
    menu.buttons = {}
    -- if menu.open == nil then menu.open = false end

    SendNUIMessage({type = 'menu_create', payload = menu})
    return uid
end
function Bindings.updateMenu(partial)
    if not shouldSend() then return end
    SendNUIMessage({type = 'menu_update', payload = partial})
end
function Bindings.destroyMenu(mid)
    if not shouldSend() then return end
    SendNUIMessage({type = 'menu_destroy', payload = {id = mid}})
end

-- button related bindings
function Bindings.createButton(button)
    if not shouldSend() then return end
    local uid = createUid()
    button.id = uid

    SendNUIMessage({type = 'button_create', payload = button})
    return uid
end
function Bindings.updateButton(partial)
    if not shouldSend() then return end
    SendNUIMessage({type = 'button_update', payload = partial})
end
function Bindings.destroyButton(bid)
    if not shouldSend() then return end
    SendNUIMessage({type = 'button_destroy', payload = {id = bid}})
end

-- misc bindings
function Bindings.sendAction(action)
    if not shouldSend() then return end
    SendNUIMessage({type = 'action', action = action})
end
-- sends to the UI that the lua client is ready
function Bindings.sendReady()
    if not shouldSend() then return end
    SendNUIMessage({type = 'ready'})
end
