--[[
    This file serves as a hub for namespacing the other files
    It also serves as a place to get that global namespace (export and events)
]] --
Neo = {Bindings = Bindings, SM = SM, Events = Events}

-- events for getting the global namespace
AddEventHandler('neo:get', function() TriggerEvent('neo:set', Neo) end)
exports('get', function() return Neo end)
