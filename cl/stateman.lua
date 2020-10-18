--[[
    State Manager namespace
    This is the main part of the Lua, handles the lifecycle of the buttons and menus
    Also caches states for dev use
]] --
SM = {}

-- gets an object's index from its `id`
local function getValueIndex(table, value)
    for i = 1, #table do if table[i] == value then return i end end
    return nil
end
local function removeAllInstances(tb, value)
    local i = 1
    while i <= tb do
        if tb[i] == value then
            table.remove(tb, i)
        else
            i = i + 1
        end
    end
end
-- this will thorw an error if a table does not include a value
local function assertContains(table, value, errMsg)
    if getValueIndex(table, value) ~= nil then return end
    for i = 1, #table do if table[i] == value then return end end
    error('assert failure: ' .. (errMsg or 'table does not contain value'))
end
-- returns true if both the button and menu exist in the sm context
local function checkSmContains(sm, menu, button)
    if menu and getValueIndex(sm.menus, menu) == nil then return false end
    if button and getValueIndex(sm.buttons, button) == nil then return false end
    return true
end

local invMIDMsg = 'invalid menu id provided'
local invBIDMsg = 'invalid button id provided'

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
        Events.emit(sm.events, 'buttonCheck')
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

    return sm
end

--[[ CREATION BINDINGS ]]

-- creates and stores a new menu object in the internal state, returning the ID
function SM.createMenu(sm, title, subtitle)
    local menu = Bindings.createMenu({title = title, subtitle = subtitle})
    table.insert(sm.menus, menu)
    return menu
end
-- creates and stores a new button object in the internal state, returning the ID
function SM.createButton(sm, text)
    local button = Bindings.createButton({text = text})
    table.insert(sm.buttons, button)
    return button
end

--[[ UPDATE BINDINGS ]]

function SM.updateMenu(sm, menu, partial)
    assertContains(sm.menus, menu, invMIDMsg)
    partial.id = menu
    Bindings.updateMenu(partial)
end
function SM.updateButton(sm, button, partial)
    assertContains(sm.buttons, button, invBIDMsg)
    partial.id = button
    Bindings.updateButton(partial)
end

--[[ DESTRUCTION BINDINGS ]]

-- deletes a component from the UI, prevents memory leaks
function SM.destroyMenu(sm, menu)
    assertContains(sm.menus, menu, invMIDMsg)
    removeAllInstances(sm.menus, menu)
    sm.menuButtons[menu] = nil
    Bindings.destroyMenu(menu)
end
function SM.destroyButton(sm, button)
    assertContains(sm.buttons, button, invBIDMsg)
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
function SM.menuExists(sm, menu) return getValueIndex(sm.menus, menu) ~= nil end
function SM.buttonExists(sm, button)
    return getValueIndex(sm.buttons, button) ~= nil
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
    assertContains(sm.menus, menu, invMIDMsg)
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
    if not historyOp then historyOp = 'recreate' end

    if #sm.history == 0 then return end
    local currentMenu = sm.history[#sm.history]

    -- perform history op then close menu
    sm.history = performHistoryOp(sm.history, historyOp)
    Bindings.updateMenu({id = currentMenu, open = false})
end
-- closes current menu and opens the last menu in the history
function SM.openPreviousMenu(sm)
    if #sm.history > 1 then
        SM.openMenu(sm, sm.history[#sm.history - 1], 'pop')
    else
        SM.closeCurrentMenu(sm, 'recreate')
    end
end
-- gets the currently open menu
function SM.getOpenMenu(sm) return sm.history[#sm.history] end

--[[ MENU BUTTON OPERATIONS ]]

-- sets the menu's buttons, are stores them in the state
function SM.setMenuButtons(sm, menu, buttons)
    assertContains(sm.menus, menu, invMIDMsg)

    Bindings.updateMenu({id = menu, buttons = buttons})
    sm.menuButtons[menu] = buttons
end
-- pushes a list of new buttons to the state, and sets them
function SM.pushMenuButtons(sm, menu, buttons)
    assertContains(sm.menus, menu, invMIDMsg)
    if type(buttons) ~= 'table' then buttons = {buttons} end

    -- go through the buttons and add it to the current list
    local btns = sm.menuButtons[menu] or {}
    for _, nbtn in ipairs(buttons) do
        assertContains(sm.buttons, nbtn, invBIDMsg)
        btns[#btns + 1] = nbtn
    end

    -- set the buttons using the other function
    SM.setMenuButtons(sm, menu, btns)
end
-- removes buttons from a menu and updates
function SM.popMenuButtons(sm, menu, buttons)
    assertContains(sm.menus, menu, invMIDMsg)
    if type(buttons) ~= 'table' then buttons = {buttons} end

    local btns = sm.menuButtons[menu] or {}
    -- go through each given button and destroy it from the menu
    for _, btn in ipairs(buttons) do removeAllInstances(btns, btn) end

    SM.setMenuButtons(sm, menu, btns)
end
-- stores an internal state marking that button binding to another menu
function SM.bindMenuToButton(sm, menu, button)
    assertContains(sm.menus, menu, invMIDMsg)
    assertContains(sm.buttons, button, invBIDMsg)
    sm.binds[button] = menu
end

--[[ CACHE GETTERS ]]

function SM.getMenus(sm)
    return sm.menus
end
function SM.getAllButtons(sm)
    return sm.buttons
end
function SM.getMenuButtons(sm, menu)
    assertContains(sm.menus, menu, invMIDMsg)

    return sm.menuButtons[menu] or {}
end
function SM.getMenuIndex(sm, menu)
    assertContains(sm.menus, menu, invMIDMsg)

    local index = sm.cache.menuIndices[menu]
    if index == nil then index = 1 end
    return index
end
function SM.getMenuCurrentButton(sm, menu)
    assertContains(sm.menus, menu, invMIDMsg)

    local index = SM.getMenuIndex(sm, menu)
    return sm.menuButtons[menu][index]
end
function SM.getListIndex(sm, button)
    assertContains(sm.buttons, button, invBIDMsg)

    local index = sm.cache.listIndices[button]
    if index == nil then index = 1 end
    return index
end
function SM.isButtonChecked(sm, button)
    assertContains(sm.buttons, button, invBIDMsg)
    return sm.cache.checks[button] == true
end
