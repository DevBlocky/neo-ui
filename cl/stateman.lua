--[[
    State Manager namespace
    This is the main part of the Lua, handles the lifecycle of the buttons and menus
    Also caches states for dev use
]] --
SM = {
    _s = {} -- stores the menu states internally
}

-- returns true if both the button and menu exist in the sm context
local function checkSmContains(sm, menu, button)
    if menu and getValueIndex(sm.menus, menu) == nil then return false end
    if button and getValueIndex(sm.buttons, button) == nil then return false end
    return true
end
local function assertState(sm)
    -- if it's a table, just return itself
    if type(sm) == 'table' then return sm end
    return assertContainsKey(SM._s, sm, 'invalid state id provided')
end
local function assertMenu(sm, mid)
    return assertContains(sm.menus, mid, 'invalid menu id provided')
end
local function assertButton(sm, bid)
    return assertContains(sm.buttons, bid, 'invalid button id provided')
end

-- functional events used as global event handlers
local smEventHandlers = {
    ['menuOpen'] = function(sm, menu)
        if not checkSmContains(sm, menu) then return end
        Events.emit(sm.events, 'menuOpen', menu)
    end,
    ['menuClose'] = function(sm, menu)
        if not checkSmContains(sm, menu) then return end
        Events.emit(sm.events, 'menuClose', menu)
    end,
    ['action'] = function(sm, action)
        if action ~= 'back' then return end
        SM.openPreviousMenu(sm)
    end,
    ['buttonSelect'] = function(sm, menu, button)
        if not checkSmContains(sm, menu, button) then return end

        Events.emit(sm.events, 'buttonSelect', menu, button)

        -- handle binded buttons to menus
        local bindedMenu = sm.binds[button]
        if bindedMenu == nil then return end
        SM.openMenu(sm, bindedMenu, 'push')
    end,
    ['buttonHover'] = function(sm, menu, button, index)
        if not checkSmContains(sm, menu, button) then return end
        index = index + 1 -- coming from js, so convert to lua standard

        -- TODO: implement a "last button" parameter using cache
        sm.cache.menuIndices[menu] = index
        Events.emit(sm.events, 'buttonHover', menu, button, index)
    end,
    ['buttonCheck'] = function(sm, menu, button, checked)
        if not checkSmContains(sm, menu, button) then return end
        sm.cache.checks[button] = checked
        Events.emit(sm.events, 'buttonCheck', menu, button, checked)
    end,
    ['buttonListMove'] = function(sm, menu, button, index)
        if not checkSmContains(sm, menu, button) then return end
        index = index + 1 -- coming from js, so convert to lua standard
        sm.cache.listIndices[button] = index
        Events.emit(sm.events, 'buttonListMove', menu, button, index)
    end
}

-- creates a new state manager object and registers the events
function SM.init()
    -- wait for the UI to be ready
    Bindings.Wait()

    local sm = {
        id = createUid(),

        history = {}, -- a history of menus, so you can go forward and backward
        menus = {}, -- a list of all registered menus for this SM
        buttons = {}, -- a list of all registered buttons for this SM
        menuButtons = {}, -- holds menu->button[] associations
        binds = {}, -- holds binding information, so when a button is pressed it opens a menu
        _gEv = {}, -- holds global event handlers, plus their event name

        -- a cache for states that aren't directly needed for the state manager
        cache = {menuIndices = {}, listIndices = {}, checks = {}}
    }

    -- setup the handler as an event emitter
    sm.events = Events.init()

    -- register the global events declared in smEventHandlers
    for evName, fn in pairs(smEventHandlers) do
        local handler = function(...) fn(sm, ...) end
        Events.addHandler(Events.global, evName, handler)
        sm._gEv[evName] = handler
    end

    SM._s[sm.id] = sm
    return sm.id
end
function SM.destroy(sm)
    sm = assertState(sm)

    -- destroy all menu objects
    -- do this before buttons for better performance
    while #sm.menus > 0 do SM.destroyMenu(sm, sm.menus[1]) end
    -- destroy all button objects
    while #sm.buttons > 0 do SM.destroyButton(sm, sm.buttons[1]) end

    -- remove all regstered events
    for evName, fn in pairs(sm._gEv) do
        Events.removeHandler(Events.global, evName, fn)
    end

    -- let garbage collector handle this
    SM._s[sm.id] = nil
end

--[[ CREATION BINDINGS ]]

-- creates and stores a new menu object in the internal state, returning the ID
function SM.createMenu(sm, title, subtitle)
    sm = assertState(sm)
    local menu = Bindings.createMenu({title = title, subtitle = subtitle})
    table.insert(sm.menus, menu)
    return menu
end
-- creates and stores a new button object in the internal state, returning the ID
function SM.createButton(sm, text)
    sm = assertState(sm)
    local button = Bindings.createButton({text = text})
    table.insert(sm.buttons, button)
    return button
end

--[[ UPDATE BINDINGS ]]

function SM.updateMenu(sm, menu, partial)
    sm = assertState(sm)
    assertMenu(sm, menu)
    partial.id = menu
    Bindings.updateMenu(partial)
end
function SM.updateButton(sm, button, partial)
    sm = assertState(sm)
    assertButton(sm, button)
    partial.id = button
    Bindings.updateButton(partial)
end

--[[ DESTRUCTION BINDINGS ]]

-- deletes a component from the UI, prevents memory leaks
function SM.destroyMenu(sm, menu)
    sm = assertState(sm)
    assertMenu(sm, menu)

    -- go back if this is the current menu
    if SM.getOpenMenu(sm) == menu then SM.openPreviousMenu(sm) end

    -- destroy the menu
    removeAllInstances(sm.menus, menu)
    sm.menuButtons[menu] = nil
    Bindings.destroyMenu(menu)
end
function SM.destroyButton(sm, button)
    sm = assertState(sm)
    assertButton(sm, button)
    removeAllInstances(sm.buttons, button)

    -- go through each menu->button[] association and remove this button
    -- this is *probably* CPU cost effective, so the dev should use sparingly.
    for menu, btns in pairs(sm.menuButtons) do
        local l = #btns
        removeAllInstances(btns, button)
        if l > #btns then -- this menu contained this button
            SM.setMenuButtons(sm, menu, btns)
        end
    end
    Bindings.destroyButton(button)
end

--[[ EXIST CHECKS ]]

-- functions that return whether a menu or button exists in this context
function SM.menuExists(sm, menu)
    sm = assertState(sm)
    return getValueIndex(sm.menus, menu) ~= nil
end
function SM.buttonExists(sm, button)
    sm = assertState(sm)
    return getValueIndex(sm.buttons, button) ~= nil
end

--[[ EVENTS ]]

function SM.on(sm, name, handler)
    sm = assertState(sm)
    Events.addHandler(sm.events, name, handler)
end
function SM.removeListener(sm, name, handler)
    sm = assertState(sm)
    Events.removeHandler(sm.events, name, handler)
end

-- operations on the history:
-- push: adds a new value to the end of the history
-- pop: removes the last value of the history
-- splice: replaces the last value of the history
-- recreate: creates a new history, containing `v` if it isn't nil
-- returns the same history, or the newly recreated one
function performHistoryOp(history, op, v)
    if op == 'push' then
        table.insert(history, v)
    elseif op == 'pop' then
        table.remove(history, #history)
    elseif op == 'splice' then
        history[#history] = v
    elseif op == 'recreate' then
        history = v == nil and {} or {v}
    end
    return history
end

--[[ MENU OPEN/CLOSE ]]

-- opens a new menu on the UI, performing the history op specified
function SM.openMenu(sm, menu, historyOp)
    sm = assertState(sm)
    assertMenu(sm, menu)
    if not historyOp then historyOp = 'recreate' end

    -- close the last menu open in history
    if #sm.history > 0 then
        Bindings.updateMenu({id = sm.history[#sm.history], open = false})
    end

    -- perform history op then open menu
    sm.history = performHistoryOp(sm.history, historyOp, menu)
    Bindings.updateMenu({id = menu, open = true})
end
-- closes the menu at the end of the history, with the history op
function SM.closeCurrentMenu(sm, historyOp)
    sm = assertState(sm)
    if not historyOp then historyOp = 'recreate' end

    if #sm.history == 0 then return end
    local currentMenu = sm.history[#sm.history]

    -- perform history op then close menu
    sm.history = performHistoryOp(sm.history, historyOp)
    Bindings.updateMenu({id = currentMenu, open = false})
end
-- closes current menu and opens the last menu in the history
function SM.openPreviousMenu(sm)
    sm = assertState(sm)
    if #sm.history > 1 then
        SM.openMenu(sm, sm.history[#sm.history - 1], 'pop')
    else
        SM.closeCurrentMenu(sm, 'recreate')
    end
end
-- gets the currently open menu
function SM.getOpenMenu(sm)
    sm = assertState(sm)
    return sm.history[#sm.history]
end

--[[ MENU BUTTON OPERATIONS ]]

-- sets the menu's buttons, are stores them in the state
function SM.setMenuButtons(sm, menu, buttons)
    sm = assertState(sm)
    assertMenu(sm, menu)

    -- TODO: assert all buttons
    Bindings.updateMenu({id = menu, buttons = buttons})
    sm.menuButtons[menu] = buttons
end
-- pushes a list of new buttons to the state, and sets them
function SM.pushMenuButtons(sm, menu, buttons)
    sm = assertState(sm)
    assertMenu(sm, menu)
    if type(buttons) ~= 'table' then buttons = {buttons} end

    -- go through the buttons and add it to the current list
    local btns = sm.menuButtons[menu] or {}
    for _, nbtn in ipairs(buttons) do
        assertButton(sm, nbtn)
        btns[#btns + 1] = nbtn
    end

    -- set the buttons using the other function
    SM.setMenuButtons(sm, menu, btns)
end
-- removes buttons from a menu and updates
function SM.popMenuButtons(sm, menu, buttons)
    sm = assertState(sm)
    assertMenu(sm, menu)
    if type(buttons) ~= 'table' then buttons = {buttons} end

    local btns = sm.menuButtons[menu] or {}
    -- go through each given button and destroy it from the menu
    for _, btn in ipairs(buttons) do removeAllInstances(btns, btn) end

    SM.setMenuButtons(sm, menu, btns)
end
-- stores an internal state marking that button binding to another menu
function SM.bindMenuToButton(sm, menu, button)
    sm = assertState(sm)
    assertMenu(sm, menu)
    assertButton(sm, button)
    sm.binds[button] = menu
end

--[[ CACHE GETTERS ]]

function SM.getMenus(sm)
    sm = assertState(sm)
    return sm.menus
end
function SM.getAllButtons(sm)
    sm = assertState(sm)
    return sm.buttons
end
function SM.getMenuButtons(sm, menu)
    sm = assertState(sm)
    assertMenu(sm, menu)

    return sm.menuButtons[menu] or {}
end
function SM.getMenuIndex(sm, menu)
    sm = assertState(sm)
    assertMenu(sm, menu)

    local index = sm.cache.menuIndices[menu]
    if index == nil then index = 1 end
    return index
end
function SM.getMenuCurrentButton(sm, menu)
    sm = assertState(sm)
    assertMenu(sm, menu)

    local index = SM.getMenuIndex(sm, menu)
    return sm.menuButtons[menu][index]
end
function SM.getListIndex(sm, button)
    sm = assertState(sm)
    assertButton(sm, button)

    local index = sm.cache.listIndices[button]
    if index == nil then index = 1 end
    return index
end
function SM.isButtonChecked(sm, button)
    sm = assertState(sm)
    assertButton(sm, button)

    return sm.cache.checks[button] == true
end
