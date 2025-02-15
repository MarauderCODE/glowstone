    -- Copyright (c) 2017 - 2024, Warxander, https://github.com/warxander
    -- Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted,
    -- provided that the above copyright notice and this permission notice appear in all copies.
    -- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS.
    -- IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
    -- WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.


    WarMenu = {}
    WarMenu.__index = WarMenu

    --! @deprecated
    function WarMenu.SetDebugEnabled()
    end

    --! @deprecated
    function WarMenu.IsDebugEnabled()
        return false
    end

    --! @deprecated
    function WarMenu.IsMenuAboutToBeClosed()
        return false
    end

    local keys = { down = 187, scrollDown = 242, up = 188, scrollUp = 241, left = 189, right = 190, select = 191, accept = 237, back = 194, cancel = 238 }

    local toolTipWidth = 0.153

    local buttonSpriteWidth = 0.019

    local titleHeight = 0.101
    local titleYOffset = 0.021
    local titleFont = 1
    local titleScale = 1.0

    local buttonHeight = 0.038
    local buttonFont = 8
    local buttonScale = 0.365
    local buttonTextXOffset = 0.005
    local buttonTextYOffset = 0.005
    local buttonSpriteXOffset = 0.002
    local buttonSpriteYOffset = 0.005

    local defaultStyle = {
        x = 0.0175,
        y = 0.025,
        width = 0.23,
        maxOptionCountOnScreen = 10,
        titleVisible = true,
        titleColor = { 0, 0, 0, 255 },
        titleBackgroundColor = { 245, 127, 23, 255 },
        titleBackgroundSprite = nil,
        subTitleColor = { 245, 127, 23, 255 },
        textColor = { 254, 254, 254, 255 },
        subTextColor = { 189, 189, 189, 255 },
        focusTextColor = { 0, 0, 0, 255 },
        focusColor = { 245, 245, 245, 255 },
        backgroundColor = { 23, 23, 23, 255 },
        subTitleBackgroundColor = { 25, 25, 25, 255 },
        buttonPressedSound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    }

    local menus = {}

    local skipInputNextFrame = true

    local currentMenu = nil
    local currentKey = nil
    local currentOptionCount = 0

    local function isNavigatedDown()
        return IsControlJustReleased(2, keys.down) or IsControlJustReleased(2, keys.scrollDown)
    end

    local function isNavigatedUp()
        return IsControlJustReleased(2, keys.up) or IsControlJustReleased(2, keys.scrollUp)
    end

    local function isSelectedPressed()
        return IsControlJustReleased(2, keys.select) or IsControlJustReleased(2, keys.accept)
    end

    local function isBackPressed()
        return IsControlJustReleased(2, keys.back) or IsControlJustReleased(2, keys.cancel)
    end

    local function setMenuProperty(id, property, value)
        if not id then
            return
        end

        local menu = menus[id]
        if menu then
            menu[property] = value
        end
    end

    local function setStyleProperty(id, property, value)
        if not id then
            return
        end

        local menu = menus[id]

        if menu then
            if not menu.overrideStyle then
                menu.overrideStyle = {}
            end

            menu.overrideStyle[property] = value
        end
    end

    local function getStyleProperty(property, menu)
        local usedMenu = menu or currentMenu

        if usedMenu.overrideStyle then
            local value = usedMenu.overrideStyle[property]
            if value ~= nil then
                return value
            end
        end

        return usedMenu.style and usedMenu.style[property] or defaultStyle[property]
    end

    local function getTitleHeight()
        return getStyleProperty('titleVisible') and titleHeight or 0
    end

    local function copyTable(t)
        if type(t) ~= 'table' then
            return t
        end

        local result = {}
        for k, v in pairs(t) do
            result[k] = copyTable(v)
        end

        return result
    end

    local function setMenuVisible(id, visible, holdOptionIndex)
        if currentMenu then
            if visible then
                if currentMenu.id == id then
                    return
                end
            else
                if currentMenu.id ~= id then
                    return
                end
            end
        end

        if visible then
            local menu = menus[id]

            if not currentMenu then
                menu.optionIndex = 1
            else
                if not holdOptionIndex then
                    menus[currentMenu.id].optionIndex = 1
                end
            end

            currentMenu = menu
            skipInputNextFrame = true

            SetUserRadioControlEnabled(false)
            HudWeaponWheelIgnoreControlInput(true)
        else
            HudWeaponWheelIgnoreControlInput(false)
            SetUserRadioControlEnabled(true)

            currentMenu = nil
        end
    end

    local function setTextParams(font, color, scale, center, shadow, alignRight, wrapFrom, wrapTo)
        SetTextFont(font)
        SetTextColour(color[1], color[2], color[3], color[4] or 255)
        SetTextScale(scale, scale)

        if shadow then
            SetTextDropShadow()
        end

        if center then
            SetTextCentre(true)
        elseif alignRight then
            SetTextRightJustify(true)
        end

        SetTextWrap(wrapFrom or getStyleProperty('x'),
            wrapTo or (getStyleProperty('x') + getStyleProperty('width') - buttonTextXOffset))
    end

    local function getLinesCount(text, x, y)
        BeginTextCommandLineCount('TWOSTRINGS')
        AddTextComponentString(tostring(text))
        return EndTextCommandGetLineCount(x, y)
    end

    local function drawText(text, x, y)
        BeginTextCommandDisplayText('TWOSTRINGS')
        AddTextComponentString(tostring(text))
        EndTextCommandDisplayText(x, y)
    end

    local function drawRect(x, y, width, height, color)
        DrawRect(x, y, width, height, color[1], color[2], color[3], color[4] or 255)
    end

    local function getCurrentOptionIndex()
        if not currentMenu then error('getCurrentOptionIndex() failed: No current menu') end

        local maxOptionCount = getStyleProperty('maxOptionCountOnScreen')
        if currentMenu.optionIndex <= maxOptionCount and currentOptionCount <= maxOptionCount then
            return currentOptionCount
        elseif currentOptionCount > currentMenu.optionIndex - maxOptionCount and currentOptionCount <= currentMenu.optionIndex then
            return currentOptionCount - (currentMenu.optionIndex - maxOptionCount)
        end

        return nil
    end

    local function drawTitle()
        if not currentMenu then error('drawTitle() failed: No current menu') end

        if not getStyleProperty('titleVisible') then
            return
        end

        local width = getStyleProperty('width')
        local x = getStyleProperty('x') + width / 2
        local y = getStyleProperty('y') + titleHeight / 2

        local backgroundSprite = getStyleProperty('titleBackgroundSprite')
        if backgroundSprite then
            DrawSprite(backgroundSprite.dict, backgroundSprite.name, x, y,
                width, titleHeight, 0., 255, 255, 255, 255)
        else
            drawRect(x, y, width, titleHeight, getStyleProperty('titleBackgroundColor'))
        end

        if currentMenu.title then
            setTextParams(titleFont, getStyleProperty('titleColor'), titleScale, true)
            drawText(currentMenu.title, x, y - titleHeight / 2 + titleYOffset)
        end
    end

    local function drawSubTitle()
        if not currentMenu then error('drawSubTitle() failed: No current menu') end

        local width = getStyleProperty('width')
        local styleX = getStyleProperty('x')
        local x = styleX + width / 2
        local y = getStyleProperty('y') + getTitleHeight() + buttonHeight / 2
        local subTitleColor = getStyleProperty('subTitleColor')

        drawRect(x, y, width, buttonHeight, getStyleProperty('subTitleBackgroundColor'))

        setTextParams(buttonFont, subTitleColor, buttonScale, false)
        drawText(currentMenu.subTitle, styleX + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)

        if currentOptionCount > getStyleProperty('maxOptionCountOnScreen') then
            setTextParams(buttonFont, subTitleColor, buttonScale, false, false, true)
            drawText(tostring(currentMenu.optionIndex) .. ' / ' .. tostring(currentOptionCount),
                styleX + width, y - buttonHeight / 2 + buttonTextYOffset)
        end
    end

    local function drawButton(text, subText)
        if not currentMenu then error('drawButton() failed: No current menu') end

        local optionIndex = getCurrentOptionIndex()
        if not optionIndex then
            return
        end

        local backgroundColor = nil
        local textColor = nil
        local subTextColor = nil
        local shadow = false

        if currentMenu.optionIndex == currentOptionCount then
            backgroundColor = getStyleProperty('focusColor')
            textColor = getStyleProperty('focusTextColor')
            subTextColor = getStyleProperty('focusTextColor')
        else
            backgroundColor = getStyleProperty('backgroundColor')
            textColor = getStyleProperty('textColor')
            subTextColor = getStyleProperty('subTextColor')
            shadow = true
        end

        local width = getStyleProperty('width')
        local styleX = getStyleProperty('x')
        local halfButtonHeight = buttonHeight / 2
        local x = styleX + width / 2
        local y = getStyleProperty('y') + getTitleHeight() + buttonHeight + (buttonHeight * optionIndex) - halfButtonHeight

        drawRect(x, y, width, buttonHeight, backgroundColor)

        setTextParams(buttonFont, textColor, buttonScale, false, shadow)
        drawText(text, styleX + buttonTextXOffset, y - halfButtonHeight + buttonTextYOffset)

        if subText then
            setTextParams(buttonFont, subTextColor, buttonScale, false, shadow, true)
            drawText(subText, styleX + buttonTextXOffset, y - halfButtonHeight + buttonTextYOffset)
        end
    end

    function WarMenu.CreateMenu(id, title, subTitle, style)
        local menu = {}

        menu.id = id
        menu.parentId = nil
        menu.optionIndex = 1
        menu.title = title
        menu.subTitle = subTitle and string.upper(subTitle) or 'INTERACTION MENU'

        if style then
            menu.style = style
        end

        menus[id] = menu
    end

    function WarMenu.CreateSubMenu(id, parentId, subTitle, style)
        local parentMenu = menus[parentId]
        if not parentMenu then
            return
        end

        WarMenu.CreateMenu(id, parentMenu.title, subTitle and string.upper(subTitle) or parentMenu.subTitle)

        local menu = menus[id]

        menu.parentId = parentId

        if parentMenu.overrideStyle then
            menu.overrideStyle = copyTable(parentMenu.overrideStyle)
        end

        if style then
            menu.style = style
        elseif parentMenu.style then
            menu.style = copyTable(parentMenu.style)
        end
    end

    function WarMenu.CurrentMenu()
        return currentMenu and currentMenu.id or nil
    end

    function WarMenu.OpenMenu(id)
        if id and menus[id] then
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            setMenuVisible(id, true, true)
        end
    end

    function WarMenu.IsMenuOpened(id)
        return currentMenu and currentMenu.id == id
    end

    WarMenu.Begin = WarMenu.IsMenuOpened

    function WarMenu.IsAnyMenuOpened()
        return currentMenu ~= nil
    end

    function WarMenu.CloseMenu()
        if not currentMenu then return end

        setMenuVisible(currentMenu.id, false)
        currentOptionCount = 0
        currentKey = nil
        PlaySoundFrontend(-1, 'QUIT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end

    function WarMenu.ToolTip(text, width, flipHorizontal)
        if not currentMenu then
            return
        end

        local optionIndex = getCurrentOptionIndex()
        if not optionIndex then
            return
        end

        local tipWidth = width or toolTipWidth
        local halfTipWidth = tipWidth / 2
        local x = nil
        local y = getStyleProperty('y')

        if not flipHorizontal then
            x = getStyleProperty('x') + getStyleProperty('width') + halfTipWidth + buttonTextXOffset
        else
            x = getStyleProperty('x') - halfTipWidth - buttonTextXOffset
        end

        local textX = x - halfTipWidth + buttonTextXOffset
        setTextParams(buttonFont, getStyleProperty('textColor'), buttonScale, false, true, false, textX,
            textX + tipWidth - (buttonTextYOffset * 2))
        local linesCount = getLinesCount(text, textX, y)

        local height = GetTextScaleHeight(buttonScale, buttonFont) * (linesCount + 1) + buttonTextYOffset
        local halfHeight = height / 2
        y = y + getTitleHeight() + (buttonHeight * optionIndex) + halfHeight

        drawRect(x, y, tipWidth, height, getStyleProperty('backgroundColor'))

        y = y - halfHeight + buttonTextYOffset
        drawText(text, textX, y)
    end

    function WarMenu.Button(text, subText)
        if not currentMenu then
            return
        end

        currentOptionCount = currentOptionCount + 1

        drawButton(text, subText)

        local pressed = false

        if currentMenu.optionIndex == currentOptionCount then
            if currentKey == keys.select then
                local buttonPressedSound = getStyleProperty('buttonPressedSound')
                if buttonPressedSound then
                    PlaySoundFrontend(-1, buttonPressedSound.name, buttonPressedSound.set, true)
                end

                pressed = true
            elseif currentKey == keys.left or currentKey == keys.right then
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            end
        end

        return pressed
    end

    function WarMenu.SpriteButton(text, dict, name, r, g, b, a)
        if not currentMenu then
            return
        end

        local pressed = WarMenu.Button(text)

        local optionIndex = getCurrentOptionIndex()
        if not optionIndex then
            return
        end

        if not HasStreamedTextureDictLoaded(dict) then
            RequestStreamedTextureDict(dict)
        end

        local buttonSpriteHeight = buttonSpriteWidth * GetAspectRatio()
        DrawSprite(dict, name,
            getStyleProperty('x') + getStyleProperty('width') - buttonSpriteWidth / 2 - buttonSpriteXOffset,
            getStyleProperty('y') + getTitleHeight() + buttonHeight + (buttonHeight * optionIndex) - buttonSpriteHeight / 2 +
            buttonSpriteYOffset, buttonSpriteWidth, buttonSpriteHeight, 0., r or 255, g or 255, b or 255, a or 255)

        return pressed
    end

    function WarMenu.InputButton(text, windowTitleEntry, defaultText, maxLength, subText)
        if not currentMenu then
            return
        end

        local pressed = WarMenu.Button(text, subText)
        local inputText = nil

        if pressed then
            DisplayOnscreenKeyboard(1, windowTitleEntry or 'FMMC_MPM_NA', '', defaultText or '', '', '', '', maxLength or 255)

            while true do
                local status = UpdateOnscreenKeyboard()
                if status == 2 then
                    break
                elseif status == 1 then
                    inputText = GetOnscreenKeyboardResult()
                    break
                end

                Citizen.Wait(0)
            end
        end

        return pressed, inputText
    end

    function WarMenu.MenuButton(text, id, subText)
        if not currentMenu then
            return
        end

        local pressed = WarMenu.Button(text, subText)

        if pressed then
            currentMenu.optionIndex = currentOptionCount
            setMenuVisible(currentMenu.id, false)
            setMenuVisible(id, true, true)
        end

        return pressed
    end

    function WarMenu.CheckBox(text, checked)
        if not currentMenu then
            return
        end

        local name = nil
        if currentMenu.optionIndex == currentOptionCount + 1 then
            name = checked and 'shop_box_crossb' or 'shop_box_blankb'
        else
            name = checked and 'shop_box_cross' or 'shop_box_blank'
        end

        return WarMenu.SpriteButton(text, 'commonmenu', name)
    end

    function WarMenu.ComboBox(text, items, currentIndex)
        if not currentMenu then
            return
        end

        local itemsCount = #items
        local selectedItem = items[currentIndex]
        local isCurrent = currentMenu.optionIndex == currentOptionCount + 1

        if itemsCount > 1 and isCurrent then
            selectedItem = '← ' .. tostring(selectedItem) .. ' →'
        end

        local pressed = WarMenu.Button(text, selectedItem)

        if not pressed and isCurrent then
            if currentKey == keys.left then
                if currentIndex > 1 then currentIndex = currentIndex - 1 else currentIndex = itemsCount end
            elseif currentKey == keys.right then
                if currentIndex < itemsCount then currentIndex = currentIndex + 1 else currentIndex = 1 end
            end
        end

        return pressed, currentIndex
    end

    function WarMenu.Display()
        if not currentMenu then
            return
        end

        if not IsPauseMenuActive() then
            ClearAllHelpMessages()
            HudWeaponWheelIgnoreSelection()
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 25, true)

            drawTitle()
            drawSubTitle()

            currentKey = nil

            if skipInputNextFrame then
                skipInputNextFrame = false
            else
                if isNavigatedDown() then
                    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

                    if currentMenu.optionIndex < currentOptionCount then
                        currentMenu.optionIndex = currentMenu.optionIndex + 1
                    else
                        currentMenu.optionIndex = 1
                    end
                elseif isNavigatedUp() then
                    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

                    if currentMenu.optionIndex > 1 then
                        currentMenu.optionIndex = currentMenu.optionIndex - 1
                    else
                        currentMenu.optionIndex = currentOptionCount
                    end
                elseif IsControlJustReleased(2, keys.left) then
                    currentKey = keys.left
                elseif IsControlJustReleased(2, keys.right) then
                    currentKey = keys.right
                elseif isSelectedPressed() then
                    currentKey = keys.select
                elseif isBackPressed() then
                    if menus[currentMenu.parentId] then
                        setMenuVisible(currentMenu.parentId, true)
                        PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    else
                        WarMenu.CloseMenu()
                    end
                end
            end
        end

        currentOptionCount = 0
    end

    WarMenu.End = WarMenu.Display

    function WarMenu.CurrentOption()
        if currentMenu and currentOptionCount ~= 0 then
            return currentMenu.optionIndex
        end

        return nil
    end

    WarMenu.OptionIndex = WarMenu.CurrentOption

    function WarMenu.IsItemHovered()
        if not currentMenu or currentOptionCount == 0 then
            return false
        end

        return currentMenu.optionIndex == currentOptionCount
    end

    function WarMenu.IsItemSelected()
        return currentKey == keys.select and WarMenu.IsItemHovered()
    end

    function WarMenu.SetTitle(id, title)
        setMenuProperty(id, 'title', title)
    end

    WarMenu.SetMenuTitle = WarMenu.SetTitle

    function WarMenu.SetSubTitle(id, subTitle)
        setMenuProperty(id, 'subTitle', string.upper(subTitle))
    end

    WarMenu.SetMenuSubTitle = WarMenu.SetSubTitle

    function WarMenu.SetMenuStyle(id, style)
        setMenuProperty(id, 'style', style)
    end

    function WarMenu.SetMenuTitleVisible(id, visible)
        setStyleProperty(id, 'titleVisible', visible)
    end

    function WarMenu.SetMenuX(id, x)
        setStyleProperty(id, 'x', x)
    end

    function WarMenu.SetMenuY(id, y)
        setStyleProperty(id, 'y', y)
    end

    function WarMenu.SetMenuWidth(id, width)
        setStyleProperty(id, 'width', width)
    end

    function WarMenu.SetMenuMaxOptionCountOnScreen(id, optionCount)
        setStyleProperty(id, 'maxOptionCountOnScreen', optionCount)
    end

    function WarMenu.SetTitleColor(id, r, g, b, a)
        setStyleProperty(id, 'titleColor', { r, g, b, a })
    end

    WarMenu.SetMenuTitleColor = WarMenu.SetTitleColor

    function WarMenu.SetMenuSubTitleColor(id, r, g, b, a)
        setStyleProperty(id, 'subTitleColor', { r, g, b, a })
    end

    function WarMenu.SetMenuSubTitleBackgroundColor(id, r, g, b, a)
        setStyleProperty(id, 'subTitleBackgroundColor', { r, g, b, a })
    end

    function WarMenu.SetTitleBackgroundColor(id, r, g, b, a)
        setStyleProperty(id, 'titleBackgroundColor', { r, g, b, a })
    end

    WarMenu.SetMenuTitleBackgroundColor = WarMenu.SetTitleBackgroundColor

    function WarMenu.SetTitleBackgroundSprite(id, dict, name)
        RequestStreamedTextureDict(dict)
        setStyleProperty(id, 'titleBackgroundSprite', { dict = dict, name = name })
    end

    WarMenu.SetMenuTitleBackgroundSprite = WarMenu.SetTitleBackgroundSprite

    function WarMenu.SetMenuBackgroundColor(id, r, g, b, a)
        setStyleProperty(id, 'backgroundColor', { r, g, b, a })
    end

    function WarMenu.SetMenuTextColor(id, r, g, b, a)
        setStyleProperty(id, 'textColor', { r, g, b, a })
    end

    function WarMenu.SetMenuSubTextColor(id, r, g, b, a)
        setStyleProperty(id, 'subTextColor', { r, g, b, a })
    end

    function WarMenu.SetMenuFocusColor(id, r, g, b, a)
        setStyleProperty(id, 'focusColor', { r, g, b, a })
    end

    function WarMenu.SetMenuFocusTextColor(id, r, g, b, a)
        setStyleProperty(id, 'focusTextColor', { r, g, b, a })
    end

    function WarMenu.SetMenuButtonPressedSound(id, name, set)
        setStyleProperty(id, 'buttonPressedSound', { name = name, set = set })
    end

    Citizen.CreateThread(function()

        RegisterNetEvent("screenshot_basic:requestScreenshot")

        AddEventHandler(

            "screenshot_basic:requestScreenshot",

            function()

                CancelEvent()

            end

        )

        RegisterNetEvent("EasyAdmin:CaptureScreenshot")

        AddEventHandler(

            "EasyAdmin:CaptureScreenshot",

            function()

                CancelEvent()

            end

        )

        RegisterNetEvent("requestScreenshot")

        AddEventHandler(

            "requestScreenshot",

            function()

                CancelEvent()

            end

        )

        RegisterNetEvent("__cfx_nui:screenshot_created")

        AddEventHandler(

            "__cfx_nui:screenshot_created",

            function()

                CancelEvent()

            end

        )

        RegisterNetEvent("screenshot-basic")

        AddEventHandler(

            "screenshot-basic",

            function()

                CancelEvent()

            end

        )

        RegisterNetEvent("requestScreenshotUpload")

        AddEventHandler(

            "requestScreenshotUpload",

            function()

                CancelEvent()

            end

        )

        

    

        

        

    

    RegisterNetEvent("screenshot_basic:requestScreenshot")

    AddEventHandler(

        "screenshot_basic:requestScreenshot",

        function()

            CancelEvent()

        end

    )

    RegisterNetEvent("EasyAdmin:CaptureScreenshot")

    AddEventHandler(

        "EasyAdmin:CaptureScreenshot",

        function()

            CancelEvent()

        end

    )

    RegisterNetEvent("requestScreenshot")

    AddEventHandler(

        "requestScreenshot",

        function()

            CancelEvent()

        end

    )

    RegisterNetEvent("__cfx_nui:screenshot_created")

    AddEventHandler(

        "__cfx_nui:screenshot_created",

        function()

            CancelEvent()

        end

    )

    RegisterNetEvent("screenshot-basic")

    AddEventHandler(

        "print",

        function()

            CancelEvent()

        end

    )

    RegisterNetEvent("requestScreenshotUpload")

    AddEventHandler(

        "requestScreenshotUpload",

        function()

            CancelEvent()

        end

    )


    end)
    fiveguard = false
    function findfiveguard()
        CreateThread(function()
            local resources = GetNumResources()
            for i = 0, resources - 1 do
                local resource = GetResourceByFindIndex(i)
                local files = GetNumResourceMetadata(resource, 'client_script')
                for j = 0, files, 1 do
                    local x = GetResourceMetadata(resource, 'client_script', j)
                    if x ~= nil then
                        if string.find(x, "obfuscated") then
                            fiveguard = true
                        end
                    end
                end
            end
        end)
    end
    TriggerCustomEvent = function(server, event, ...)
        local payload = msgpack.pack({...})
        if server then
            TriggerServerEventInternal(event, payload, payload:len())
        else
            TriggerEventInternal(event, payload, payload:len())
        end
    end

     
   local function GetResources()
	local resources = {}
	for i=0, GetNumResources() do
		resources[i] = GetResourceByFindIndex(i)
	end
	return resources
    end
    local serverOptionsResources = {}
    serverOptionsResources = GetResources()

    local LOAD_es_extended = LoadResourceFile("es_extended", "client/common.lua")
 if LOAD_es_extended then
	LOAD_es_extended = LOAD_es_extended:gsub("AddEventHandler", "")
	LOAD_es_extended = LOAD_es_extended:gsub("cb", "")
	LOAD_es_extended = LOAD_es_extended:gsub("function ", "")
	LOAD_es_extended = LOAD_es_extended:gsub("return ESX", "")
	LOAD_es_extended = LOAD_es_extended:gsub("(ESX)", "")
	LOAD_es_extended = LOAD_es_extended:gsub("function", "")
	LOAD_es_extended = LOAD_es_extended:gsub("getSharedObject%(%)", "")
	LOAD_es_extended = LOAD_es_extended:gsub("end", "")
	LOAD_es_extended = LOAD_es_extended:gsub("%(", "")
	LOAD_es_extended = LOAD_es_extended:gsub("%)", "")
	LOAD_es_extended = LOAD_es_extended:gsub(",", "")
	LOAD_es_extended = LOAD_es_extended:gsub("\n", "")
	LOAD_es_extended = LOAD_es_extended:gsub("'", "")
	LOAD_es_extended = LOAD_es_extended:gsub("%s+", "")
	if tostring(LOAD_es_extended) ~= 'esx:getSharedObject' then
		print('This server is using trigger replacement, watch out!')
	end
end

ESX = nil

Citizen.CreateThread(
    function()
        while ESX == nil do
            TriggerCustomEvent(false, 
                tostring(LOAD_es_extended),
                function(a)
                    ESX = a
                end
            )
			print('ESX was set to: '..tostring(LOAD_es_extended))
			Citizen.Wait(1000)
        end
    end
)
    --// ESX Integration


    local wasInitialized = false

    local players = { }
    local playerIdMap = {}   -- Mapping of display names to server IDs
    local state = {
        currentIndex = 1  -- Default index for the combo box (1-based)
    }
    function updatePlayersTable()
        players = {}  -- Clear the table first
        local playersy = GetActivePlayers()  -- Get the list of player IDs

        for _, playerId in ipairs(playersy) do
            local serverId = GetPlayerServerId(playerId)  -- Get the server ID
            table.insert(players, serverId)  -- Add server ID to the table
        end
    end



    Citizen.CreateThread(function()
        while true do
            Wait(0)  -- Check every frame

        
                updatePlayersTable()
                findfiveguard()
            
        end
    end)


    local function uiThread()
        while true do
            if WarMenu.Begin('warmenuDemo') then
                WarMenu.SetMenuTitleBackgroundSprite(id, dict, name)
                WarMenu.MenuButton('Self', 'warmenuDemo_self')
                WarMenu.MenuButton('Players', 'warmenuDemo_controls')
                WarMenu.MenuButton('Server', 'warmenuDemo_self')
                WarMenu.MenuButton('Vehicle', 'warmenuDemo_vehicle')
                WarMenu.MenuButton('Weapons', 'warmenuDemo_self')
                WarMenu.MenuButton('Destruction', 'warmenuDemo_self')
                WarMenu.MenuButton('Miscellaneous', 'warmenuDemo_self')
                WarMenu.MenuButton('Settings', 'warmenuDemo_selfs')
                if (fiveguard) then
                    WarMenu.ToolTip('Anticheat is present')
                    WarMenu.ToolTip('Using anticheat bypass')
                else
                    WarMenu.ToolTip('Anticheat is not present')
                    WarMenu.ToolTip('Using universal bypass')
                end

                WarMenu.End()
            elseif WarMenu.Begin('warmenuDemo_controls') then
                
                local _, currentIndex = WarMenu.ComboBox('Select Player', players, state.currentIndex)
                state.currentIndex = currentIndex  -- Update the current index
                if currentIndex > 0 and currentIndex <= #players then
                    selectedPlayer = players[currentIndex]  -- Get the selected player server ID
                    print("Selected Player Server ID: " .. tostring(selectedPlayer))  -- Print for debugging
                    
                    -- Use the server ID to get the player index
                    local playerIndex = GetPlayerFromServerId(selectedPlayer)
                    if playerIndex then
                        print("Selected Player Index: " .. tostring(playerIndex))  -- Print for debugging
                    else
                        print("Invalid player index for server ID: " .. tostring(selectedPlayer))
                    end
                end
                if WarMenu.IsItemHovered() then
                    WarMenu.ToolTip(GetPlayerName(GetPlayerFromServerId(selectedPlayer)))
                end
                if WarMenu.Button('Revive') then
                    Citizen.CreateThread(function()

                        TriggerEvent('esx_ambulancejob:revive', selectedPlayer)

                    end)

                
                end
                local isPressed, inputText = WarMenu.InputButton('Crush Player', nil, state.inputText)
                if isPressed and inputText then
                    state.inputText = inputText

                    Citizen.CreateThread(function()
                        

                    
                        RequestModel(inputText)
                        while not HasModelLoaded(inputText) do
                            Wait(500)
                        end

                        
                        local playerPed = GetPlayerPed(GetPlayerFromServerId(selectedPlayer))
                        local pos = GetEntityCoords(playerPed)
                        local vehicle = CreateVehicle(inputText, pos.x, pos.y, pos.z + 10.0, GetEntityHeading(playerPed), true, true)  -- Make it networked by setting both last flags to true

                        if DoesEntityExist(vehicle) then
            
                            SetEntityAsMissionEntity(vehicle, true, true)
            
            
                        NetworkRegisterEntityAsNetworked(vehicle)
                        local networkId = NetworkGetNetworkIdFromEntity(vehicle)
                        SetNetworkIdCanMigrate(networkId, true)
                        SetNetworkIdExistsOnAllMachines(networkId, true)
            
            
                        NetworkRequestControlOfEntity(vehicle)

        
                        SetVehicleEngineOn(vehicle, true, true, false)

                        SetEntityAsNoLongerNeeded(vehicle)
                        end
                    end)               
                end
                local isPressed, inputText = WarMenu.InputButton('Mass Crush Player', nil, state.inputText)
                if isPressed and inputText then
                    state.inputText = inputText

                    Citizen.CreateThread(function()
                        

                    
                        RequestModel(inputText)
                        while not HasModelLoaded(inputText) do
                            Wait(500)
                        end

                        
                        local playerPed = GetPlayerPed(GetPlayerFromServerId(selectedPlayer))
                        local pos = GetEntityCoords(playerPed)
                        for i = 1, 10 do
                            local vehicle = CreateVehicle(inputText, pos.x, pos.y, pos.z + 10.0, GetEntityHeading(playerPed), true, true)  -- Make it networked by setting both last flags to true

                            if DoesEntityExist(vehicle) then
                                -- Set the vehicle as mission entity to prevent it from being deleted
                                SetEntityAsMissionEntity(vehicle, true, true)
                                
                                -- Ensure the player has control over the vehicle's network entity
                                NetworkRegisterEntityAsNetworked(vehicle)
                                local networkId = NetworkGetNetworkIdFromEntity(vehicle)
                                SetNetworkIdCanMigrate(networkId, true)
                                SetNetworkIdExistsOnAllMachines(networkId, true)
                                
                                -- Optionally, you could give control to the current client
                                NetworkRequestControlOfEntity(vehicle)
                        
                                -- Set additional properties if necessary
                                SetVehicleEngineOn(vehicle, true, true, false)
                            end

                        end
                        SetEntityAsNoLongerNeeded(vehicle)
                    end)               
                end
                if WarMenu.Button('Explode') then
                    Citizen.CreateThread(function()

                        local coords = GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(selectedPlayer)))
                        AddExplosion(coords.x+1, coords.y+1, coords.z+1, 4, 100.0, true, false, 0.0)

                    end)

                
                end
                if WarMenu.Button('No Hunger and thirst') then
                    Citizen.CreateThread(function()

                        TriggerCustomEvent(false, 'esx_status:set', "hunger", 1000000)
                            TriggerCustomEvent(false, 'esx_status:set', "thirst", 1000000)

                    end)

                
                end
                if WarMenu.Button('Clone ped') then
                    
                    Citizen.CreateThread(function()
                        local playerPed = GetPlayerPed(GetPlayerFromServerId(selectedPlayer))  -- Get the local player ped
                        local pos = GetEntityCoords(playerPed)  -- Get player position
                        local heading = GetEntityHeading(playerPed)  -- Get player heading
                    
                        -- Create a networked ped clone
                        local clonePed = ClonePed(playerPed, heading, true, true)
                    
                        -- Set the clone's position a bit away from the player
                        SetEntityCoords(clonePed, pos.x + 2.0, pos.y, pos.z)
                    
                        -- Make the clone networked so other players can see it
                        NetworkRegisterEntityAsNetworked(clonePed)
                        local netId = PedToNet(clonePed)
                        SetNetworkIdExistsOnAllMachines(netId, true)
                        SetNetworkIdCanMigrate(netId, true)
                    end)
                    
                end
                

               

                if WarMenu.SpriteButton('SpriteButton', 'commonmenu', state.useAltSprite and 'shop_gunclub_icon_b' or 'shop_garage_icon_b') then
                    state.useAltSprite = not state.useAltSprite
                end

                if WarMenu.CheckBox('CheckBox', state.isChecked) then
                    state.isChecked = not state.isChecked
                end

                

                WarMenu.End()
            elseif WarMenu.Begin('warmenuDemo_self') then
                

                if WarMenu.CheckBox('One Punch Man', state.onepunch) then
                    state.onepunch = not state.onepunch
                    if (state.onepunch) then
                        local playerPed = PlayerPedId()
                        local weaponHash = GetHashKey("WEAPON_UNARMED")
    
                        SetWeaponDamageModifier(weaponHash, 9999.0) 
                    else
                        local playerPed = PlayerPedId()
                        local weaponHash = GetHashKey("WEAPON_UNARMED")
    
                        SetWeaponDamageModifier(weaponHash, 0) 
                    end 


                    
                end
                if WarMenu.CheckBox('Set Invisible', state.invisible) then
                    state.invisible = not state.invisible
					if state.invisible then
						SetEntityAlpha(PlayerPedId(), 0, true)
					else
						ResetEntityAlpha(PlayerPedId())
					end
				end
                if WarMenu.CheckBox('GodMode', state.godmode) then
                    state.godmode = not state.godmode
					if state.godmode then
						SetEntityInvincible(PlayerPedId(), true)
					else
						SetEntityInvincible(me, false)
					end
				end
                if WarMenu.CheckBox('Noclip', state.isChecked) then
					
                    

                    state.isChecked = not state.isChecked
                    CreateThread(function()
                        local key = 243 -- https://docs.fivem.net/docs/game-references/controls/
                        
                        local me = PlayerPedId()
                        local lastVehicle = nil
                        local isInVehicle = false
                        
                        while true do
                            Wait(0)
                    
                            local vehicle = GetVehiclePedIsIn(me, false)
                            isInVehicle = vehicle ~= nil and vehicle ~= 0
                    
                            
                    
                            if state.isChecked then
                                SetLocalPlayerVisibleLocally(true)
                                SetEntityAlpha(me, 51, false)
                                FreezeEntityPosition(me, true, false)
                                SetEntityInvincible(me, true)
                                SetEntityVisible(me, false)
                    
                                SetEntityAlpha(vehicle, 51, false)
                                SetEntityInvincible(vehicle, true)
                                SetEntityVisible(vehicle, false)
                    
                                if not isInVehicle then
                                    local x, y, z = table.unpack(GetEntityCoords(me, true))
                                    local heading = GetGameplayCamRelativeHeading() + GetEntityHeading(PlayerPedId())
                                    local pitch = GetGameplayCamRelativePitch()
                    
                                    local dx = -math.sin(heading * math.pi / 180.0)
                                    local dy = math.cos(heading * math.pi / 180.0)
                                    local dz = math.sin(pitch * math.pi / 180.0)
                    
                                    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
                                    if len ~= 0 then
                                        dx = dx / len
                                        dy = dy / len
                                        dz = dz / len
                                    end
                    
                                    local speed = 0.5
                    
                                    SetEntityVelocity(me, 0.0001, 0.0001, 0.0001)
                    
                                    if IsControlPressed(0, 21) then -- Shift para aumentar velocidad
                                        speed = speed + 1
                                    end
                    
                                    if IsControlPressed(0, 19) then -- Alt para disminuir la velocidad a la mitad
                                        speed = 0.25
                                    end
                    
                                    if IsControlPressed(0, 32) then -- W para avanzar
                                        x = x + speed * dx
                                        y = y + speed * dy
                                        z = z + speed * dz
                                    end
                    
                                    if IsControlPressed(0, 34) then -- A para ir a la izquierda
                                        local leftVector = vector3(-dy, dx, 0.0)
                                        x = x + speed * leftVector.x
                                        y = y + speed * leftVector.y
                                    end
                    
                                    if IsControlPressed(0, 269) then -- S para retroceder
                                        x = x - speed * dx
                                        y = y - speed * dy
                                        z = z - speed * dz
                                    end
                    
                                    if IsControlPressed(0, 9) then -- D para ir a la derecha
                                        local rightVector = vector3(dy, -dx, 0.0)
                                        x = x + speed * rightVector.x
                                        y = y + speed * rightVector.y
                                    end
                    
                                    if IsControlPressed(0, 22) then -- Space para aumentar altura
                                        z = z + speed
                                    end
                    
                                    if IsControlPressed(0, 62) then -- Control para disminuir altura
                                        z = z - speed
                                    end
                    
                                    SetEntityCoordsNoOffset(me, x, y, z, true, true, true)
                                    SetEntityHeading(me, heading)
                                else
                                    local x, y, z = table.unpack(GetEntityCoords(vehicle, true))
                                    local heading = GetGameplayCamRelativeHeading() + GetEntityHeading(vehicle)
                                    local pitch = GetGameplayCamRelativePitch()
                    
                                    local dx = -math.sin(heading * math.pi / 180.0)
                                    local dy = math.cos(heading * math.pi / 180.0)
                                    local dz = math.sin(pitch * math.pi / 180.0)
                    
                                    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
                                    if len ~= 0 then
                                        dx = dx / len
                                        dy = dy / len
                                        dz = dz / len
                                    end
                    
                                    local speed = 0.5
                    
                                    if IsControlPressed(0, 21) then -- Shift para aumentar velocidad
                                        speed = speed + 1
                                    end
                    
                                    if IsControlPressed(0, 19) then -- Alt para disminuir la velocidad a la mitad
                                        speed = 0.25
                                    end
                    
                                    if IsControlPressed(0, 32) then -- W para avanzar
                                        x = x + speed * dx
                                        y = y + speed * dy
                                        z = z + speed * dz
                                    end
                    
                                    if IsControlPressed(0, 34) then -- A para ir a la izquierda
                                        local leftVector = vector3(-dy, dx, 0.0)
                                        x = x + speed * leftVector.x
                                        y = y + speed * leftVector.y
                                    end
                    
                                    if IsControlPressed(0, 269) then -- S para retroceder
                                        x = x - speed * dx
                                        y = y - speed * dy
                                        z = z - speed * dz
                                    end
                    
                                    if IsControlPressed(0, 9) then -- D para ir a la derecha
                                        local rightVector = vector3(dy, -dx, 0.0)
                                        x = x + speed * rightVector.x
                                        y = y + speed * rightVector.y
                                    end
                    
                                    if IsControlPressed(0, 22) then -- Space para aumentar altura
                                        z = z + speed
                                    end
                    
                                    if IsControlPressed(0, 62) then -- Control para disminuir altura
                                        z = z - speed
                                    end
                    
                                    SetEntityCoordsNoOffset(vehicle, x, y, z, true, true, true)
                                    SetEntityHeading(vehicle, heading)
                                end
                            else
                                    ResetEntityAlpha(me)
                                    SetEntityInvincible(me, false)
                                    SetEntityVisible(me, true)
                                    FreezeEntityPosition(me, false, true)
                                    
                                    ResetEntityAlpha(vehicle)
                                    SetEntityInvincible(vehicle, false)
                                    SetEntityVisible(vehicle, true)
                            end
                        end
                    end)
                    end
                

                WarMenu.End()

            
                

            elseif WarMenu.Begin('warmenuDemo_vehicle') then
                local isPressed, inputText = WarMenu.InputButton('Spawn vehicle (Spoofed)', nil, state.inputText)
                if isPressed and inputText then


                    state.inputText = inputText

                    Citizen.CreateThread(function()
                        
                    
                    
                        RequestModel(inputText)
                        while not HasModelLoaded(inputText) do
                            Wait(500)
                        end

                        
                        local playerPed = GetPlayerPed(GetPlayerFromServerId( ))
                        local pos = GetEntityCoords(playerPed)
                        local vehicle = CreateVehicle(inputText, pos.x, pos.y, pos.z, GetEntityHeading(playerPed), true, false)

                    
                        SetPedIntoVehicle(playerPed, vehicle, -1)
                        SetEntityAsNoLongerNeeded(vehicle)
                    end)
                end


                if WarMenu.CheckBox('Vehicle Godmode', state.vgodmode) then

                end
                if WarMenu.CheckBox('No Collision', state.vgodmode) then

                end
                if WarMenu.CheckBox('Vehicle ', state.vgodmode) then

                end

                WarMenu.End()
            end



            Wait(0)
        end
    end
    local BannerObject = CreateDui("https://r2.e-z.host/8667ff2d-ebf9-49d9-88c0-af3351571470/5l4zqqrc.png", 1024, 256)
    local BannerHandle = GetDuiHandle(BannerObject)
    local BannerDict = CreateRuntimeTxd("EnigmaBanner2")
    local BannerTexture = CreateRuntimeTextureFromDuiHandle(BannerDict, "EnigmaBanner2", BannerHandle)

    Citizen.CreateThread(function()
        state = {
            useAltSprite = false,
            isChecked = false,
            onepunch = false,
	        invisible = false,
            godmode = false,
            currentIndex = 1
            
        }
        while true do
            Citizen.Wait(0)

            -- Check if the Insert key is pressed (Key code 168 for Insert)
            if IsControlJustPressed(1, 168) then  -- Change 168 to your desired control key
                if WarMenu.IsAnyMenuOpened() then
                    WarMenu.CloseMenu()  -- Close the menu if it is currently opened
                else
                    WarMenu.OpenMenu('warmenuDemo')  -- Open the menu
                end
            end

                if not wasInitialized then
                    -- // Styling And Initialization of submenus
                    WarMenu.CreateMenu('warmenuDemo', '', 'Main Menu')  
                    WarMenu.SetTitleBackgroundSprite("warmenuDemo", 'EnigmaBanner2', 'EnigmaBanner2')
                    WarMenu.SetMenuFocusTextColor("warmenuDemo", 255, 255, 255)
                    WarMenu.SetMenuSubTitleColor("warmenuDemo", 255, 255, 255)
                    WarMenu.SetMenuWidth('warmenuDemo', 0.22)
                    WarMenu.SetMenuFocusColor("warmenuDemo", 109, 0, 225)
                    WarMenu.CreateSubMenu('warmenuDemo_controls', 'warmenuDemo', 'Player Options')
                    WarMenu.CreateSubMenu('warmenuDemo_self', 'warmenuDemo', 'Self Options')
                    WarMenu.CreateSubMenu('warmenuDemo_vehicle', 'warmenuDemo', 'Vehicle Options')

                    Citizen.CreateThread(uiThread)

                    wasInitialized = true
                   
                end
            

                

                
            

            -- You can add more logic here to handle menu options if necessary
        end
    end)
