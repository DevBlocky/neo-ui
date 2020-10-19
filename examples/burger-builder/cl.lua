Neo = nil
sm = nil

local selectedSauces = {}
local function initMenuSauces()
    -- create the sauces menu
    local menuSauces = Neo.createMenu(sm, config.menuTitle, 'Sauce Selection')
    Neo.updateMenu(sm, menuSauces, {right = true}) -- make the menu right-aligned

    local btns = {}
    for _, sauce in ipairs(config.sauces) do
        -- create a button with the sauce as the name
        local btn = Neo.createButton(sm, sauce)
        -- make the button unchecked
        Neo.updateButton(sm, btn, {check = false})
        -- add the button to the sauces menu
        Neo.pushMenuButtons(sm, menuSauces, btn)

        -- save the button along with the sauce
        btns[btn] = sauce
    end

    Neo.on(sm, 'buttonCheck', function(menu, button, checked)
        -- only use this menu
        if menu ~= menuSauces then return end

        if checked then
            -- if it is now checked, then insert into selected sauces
            table.insert(selectedSauces, btns[button])
        else
            -- otherwise remove from selected sauces
            for i = 1, #selectedSauces do
                if selectedSauces[i] == btns[button] then
                    table.remove(selectedSauces, i)
                    break
                end
            end
        end
    end)

    return menuSauces
end
local function initMenuMain()
    -- create the main menu
    local menuMain =
        Neo.createMenu(sm, config.menuTitle, 'The Creation Station')
    Neo.updateMenu(sm, menuMain, {right = true}) -- make the menu right-aligned

    -- create main menu buttons
    local btnBun = Neo.createButton(sm, 'Bun Selection')
    Neo.updateButton(sm, btnBun, {
        list = config.buns, -- setting 'list' to an array will make it a list button
        desc = 'Only high quality buns to provide a medium for the innerds'
    })

    local btnPatty = Neo.createButton(sm, 'Patty Style')
    Neo.updateButton(sm, btnPatty, {
        list = config.patties,
        desc = 'Choose which one of our all-american prime beef patties to use'
    })

    -- this will be bound to another menu where you can select your sauces
    local btnSauces = Neo.createButton(sm, 'Sauce Station')
    Neo.updateButton(sm, btnSauces, {
        chevron = true, -- adds the 3 arrows at the end of the button
        desc = 'Select none, one, or many sauces to put onto the patty'
    })

    local btnLettuce = Neo.createButton(sm, 'Lettuce?')
    Neo.updateButton(sm, btnLettuce, {
        check = true, -- setting 'check' to true will make it a checked checkbox
        desc = 'This vegetable cuts through the rich flavor providing some needed crunch'
    })

    local btnTomato = Neo.createButton(sm, 'Tomatoes?')
    Neo.updateButton(sm, btnTomato, {
        check = false, -- setting 'check' to false will make it an unchecked checkbox
        desc = 'Salted and Peppered fresh tomatoes go great with an all American classic!'
    })

    local btnOnions = Neo.createButton(sm, 'Onions?')
    Neo.updateButton(sm, btnOnions, {
        check = true,
        desc = 'Would you like raw onions put onto your burger?'
    })

    local btnBuild = Neo.createButton(sm, {'Build', 'your Burger!'})
    Neo.updateButton(sm, btnBuild, {
        textTemplate = '<span class="red">{0}</span> {1}', -- you can setup templates for text (notice how the text field is an array)
        desc = 'Have our skilled chefs create your perfect burger!',
        descTemplate = '<i class="fas fa-exclamation-triangle"></i> <span style="color:rgb(31, 100, 249)">{0}</span>' -- desc can have a template too!
    })

    -- this will add buttons to an existing menu
    -- instead of a table, you could also push a single button
    Neo.pushMenuButtons(sm, menuMain, {
        btnBun, btnPatty, btnSauces, btnLettuce, btnTomato, btnOnions, btnBuild
    })

    -- bind the menu to the button so that when you press the button
    -- it'll automagically open the menu
    local menuSauces = initMenuSauces()
    Neo.bindMenuToButton(sm, menuSauces, btnSauces)

    Neo.on(sm, 'buttonSelect', function(menu, button)
        -- must be the main menu and the build button
        if menu ~= menuMain or button ~= btnBuild then return end

        -- get all of the information
        local bun = config.buns[Neo.getListIndex(sm, btnBun)]
        local patty = config.patties[Neo.getListIndex(sm, btnPatty)]
        local lettuce = Neo.isButtonChecked(sm, btnLettuce)
        local tomato = Neo.isButtonChecked(sm, btnTomato)
        local onions = Neo.isButtonChecked(sm, btnOnions)
        -- the sauce selection is already in 'selectedSauces'

        print(bun, patty, lettuce, tomato, onions)
    end)

    return menuMain
end
local function initNeo()
    -- get the neo namespace object
    Neo = exports['neo-ui']:get()
    -- this portion must be run in a thread, or it will throw an error
    -- you can call this whatever you want, I just use 'sm' because in the main code this is the state manager
    sm = Neo.init()

    local menuMain = initMenuMain()
    return menuMain
end

Citizen.CreateThread(function()
    -- initializes neo's data
    -- this is moved to a function so that it can be reinitialized with neo-ui starting
    local menuMain = initNeo()

    -- command to open and close the menu
    RegisterCommand('buildburger', function()
        if Neo.getOpenMenu(sm) == nil then -- this sm doesn't have a menu open
            Neo.openMenu(sm, menuMain)
        else -- there is a menu open in the sm
            Neo.closeCurrentMenu(sm)
        end
    end)

    -- event handler will destroy the neo object when this resource is stopped
    -- if you don't do this, there will be memory leaks and side effects
    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= GetCurrentResourceName() then return end
        Neo.destroy(sm)
    end)
end)
