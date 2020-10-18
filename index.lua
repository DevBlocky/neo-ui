--[[
    This file serves as the hub for getting the global object
    to create the menus. It basically just returns the stateman.
]] --
Neo = SM

-- events for getting the global namespace
AddEventHandler('neo:get', function() TriggerEvent('neo:set', Neo) end)
exports('get', function() return Neo end)
