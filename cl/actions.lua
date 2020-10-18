--[[
    This file is responsible for sending actions, or key presses, to the UI backend and global
    The actual handler for this is pretty advanced
]] --
-- used to store action states, like if the user is holding down "up"
local actionStates = {}
local function registerAction(action, key, desc, frontendSound, canHold)
    actionStates[action] = nil
    RegisterCommand('+_neo' .. action, function()
        actionStates[action] = {
            time = GetGameTimer(),
            captured = false,
            hold = false,

            -- based on the function parameters
            sound = frontendSound,
            canHold = canHold
        }
    end)
    RegisterCommand('-_neo' .. action, function() actionStates[action] = nil end)
    RegisterKeyMapping('+_neo' .. action, desc, 'keyboard', key)

    -- remove chat suggestions, because these clog up suggestions lol
    TriggerEvent('chat:removeSuggestion', '/+_neo' .. action)
    TriggerEvent('chat:removeSuggestion', '/-_neo' .. action)
end
-- all of the actions of the menu (or keybindings)
registerAction('sel', 'numpad5', 'NeoUI Select', 'SELECT', false)
registerAction('back', 'numpad0', 'NeoUI Back', 'BACK', false)
registerAction('up', 'numpad8', 'NeoUI Up', 'NAV_UP_DOWN', true)
registerAction('down', 'numpad2', 'NeoUI Down', 'NAV_UP_DOWN', true)
registerAction('left', 'numpad4', 'NeoUI Left', 'NAV_LEFT_RIGHT', true)
registerAction('right', 'numpad6', 'NeoUI Right', 'NAV_LEFT_RIGHT', true)

-- captures all the action events and sends them to the NUI
function captureActions()
    local timer = GetGameTimer()
    for action, state in pairs(actionStates) do
        local sendEv = false
        -- this was just pressed
        if not state.captured then
            sendEv = true
            state.captured = true
        end

        -- this handles resending UI events for holding the button
        if state.canHold and (timer - state.time) > (state.hold and 100 or 450) then
            sendEv = true
            state.time = timer
            state.hold = true
        end

        -- send the event to the NUI page and plays sound
        if sendEv then
            if state.sound then
                PlaySoundFrontend(-1, state.sound,
                                  'HUD_FRONTEND_DEFAULT_SOUNDSET')
            end
            Bindings.sendAction(action)
            Events.emit(Events.global, 'action', action)
        end
    end
end

-- thread that captures actions when menu is open
Citizen.CreateThread(function()
    -- events which detect whether a menu is open or closed
    local numOpenMenus = 0
    Events.addHandler(Events.global, 'menuOpen', function()
        -- remove untracked actions
        if numOpenMenus == 0 then actions = {} end
        numOpenMenus = numOpenMenus + 1
    end)
    Events.addHandler(Events.global, 'menuClose',
                      function() numOpenMenus = numOpenMenus - 1 end)

    while true do
        if numOpenMenus > 0 then captureActions() end

        Citizen.Wait(0)
    end
end)
