--[[
    This file is responsbile for directly communicating with the NUI
    It contains functions that will send over data through SendNUIMessage
]] --
Bindings = {}

-- used to wait for the NUI to be ready
local nuiReady = false
Citizen.CreateThread(function()
    Events.addHandler(Events.global, 'ready', function() nuiReady = true end)
end)
function Bindings.Wait() while not nuiReady do Citizen.Wait(1) end end

-- menu related bindings
function Bindings.createMenu(menu)
    local uid = createUid()
    menu.id = uid
    menu.buttons = {}
    -- if menu.open == nil then menu.open = false end

    SendNUIMessage({type = 'menu_create', payload = menu})
    return uid
end
function Bindings.updateMenu(partial)
    SendNUIMessage({type = 'menu_update', payload = partial})
end
function Bindings.destroyButton(mid)
    SendNUIMessage({type = 'menu_destroy', payload = {id = mid}})
end

-- button related bindings
function Bindings.createButton(button)
    local uid = createUid()
    button.id = uid

    SendNUIMessage({type = 'button_create', payload = button})
    return uid
end
function Bindings.updateButton(partial)
    SendNUIMessage({type = 'button_update', payload = partial})
end
function Bindings.destroyButton(bid)
    SendNUIMessage({type = 'button_destroy', payload = {id = bid}})
end

-- misc bindings
function Bindings.sendAction(action)
    SendNUIMessage({type = 'action', action = action})
end
-- sends to the UI that the lua client is ready
function Bindings.sendReady() SendNUIMessage({type = 'ready'}) end
