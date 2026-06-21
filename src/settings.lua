local settings = {}
local input = require("src.input")
local sound = require("src.sound")

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local resolutionMap = {
    ["Display Native"] = { w = 0, h = 0 },
    ["720p (1280x720)"] = { w = 1280, h = 720 },
    ["1080p (1920x1080)"] = { w = 1920, h = 1080 },
    ["1440p (2560x1440)"] = { w = 2560, h = 1440 },
    ["4K (3840x2160)"] = { w = 3840, h = 2160 },
}

local function applyDisplayModeRes()
    local mode = _G.settingsData.displayMode or "Windowed"
    local resKey = _G.settingsData.resolution or "Display Native"
    local res = resolutionMap[resKey] or resolutionMap["Display Native"]
    if mode == "Windowed" then
        love.window.setFullscreen(false)
        if res.w > 0 and res.h > 0 then love.window.setMode(res.w, res.h)
        else love.window.setMode(1280, 720) end
    else
        love.window.setFullscreen(true, "desktop")
    end
end

local colorGroups = {
    { key = "bgColor",     label = "Background" },
    { key = "menuColor",   label = "Menu Text" },
    { key = "selectedColor", label = "Selected" },
    { key = "paddle1Color", label = "Paddle 1" },
    { key = "paddle2Color", label = "Paddle 2" },
    { key = "ballColor",   label = "Ball" },
    { key = "scoreColor",  label = "Scoreboard" },
}

local channels = {"r", "g", "b"}
local items = {}
local selectedIndex = 1
local prevSelectedIndex = 1
local scrollOffset = 0
local stickTimer = 0
local stickDelay = 0.2
local visibleRange = 13
local dragIndex = nil
local scrollDrag = false

local _fontCache = {}
local _lastUs = nil
local function _font(path, size)
    local us = _G.settingsData.uiScale or 1.0
    if us ~= _lastUs then _fontCache = {}; _lastUs = us end
    local k = path .. size
    if not _fontCache[k] then _fontCache[k] = love.graphics.newFont(path, math.floor(size * us)) end
    return _fontCache[k]
end

local function buildItems()
    items = {
        { label = "P1 Sensitivity",   type = "slider", value = 1.0, min = 0.5, max = 10.0, step = 0.1, key = "p1Sensitivity" },
        { label = "P2 Sensitivity",   type = "slider", value = 1.0, min = 0.5, max = 10.0, step = 0.1, key = "p2Sensitivity" },
        { label = "Ball Speed",       type = "slider", value = 1.0, min = 0.5, max = 5.0, step = 0.1, key = "ballSpeed" },
        { label = "Max Ball Speed",   type = "slider", value = 1200, min = 600, max = 5000, step = 50, key = "maxBallSpeed" },
        { label = "Winning Score",    type = "cycle",  value = 7,   options = {3, 5, 7, 11, 21, 0}, key = "winningScore" },
        { label = "Display Mode",     type = "cycle",  value = "Windowed", options = {"Windowed", "Fullscreen"}, key = "displayMode" },
        { label = "Resolution",       type = "cycle",  value = "Display Native", options = {"Display Native", "720p (1280x720)", "1080p (1920x1080)", "1440p (2560x1440)", "4K (3840x2160)"}, key = "resolution" },
        { label = "VSync",            type = "toggle", value = true,  key = "vSync" },
        { label = "Max FPS",          type = "cycle",  value = 0,     options = {0, 30, 60, 120, 144, 165, 240, 360, 480, 1024}, key = "maxFPS" },
        { label = "Split Controller", type = "toggle", value = false, key = "splitController" },
        { label = "Mouse Control",    type = "toggle", value = false, key = "mouseControl" },
        { label = "Sound",            type = "toggle", value = true,  key = "soundEnabled" },
        { label = "Font Size",        type = "slider", value = 1.0, min = 0.6, max = 1.8, step = 0.1, key = "uiScale" },

    }
    for _, group in ipairs(colorGroups) do
        table.insert(items, { label = "--- " .. group.label .. " ---", type = "header" })
        for _, ch in ipairs(channels) do
            local maxVal = group.key == "bgColor" and 0.5 or 1
            table.insert(items, { label = ch:upper(), type = "slider", value = math.min(1, maxVal), min = 0, max = maxVal, step = 0.01, key = group.key, channel = ch })
        end
    end
    table.insert(items, { label = "--- Reset ---", type = "header" })
    table.insert(items, { label = "Reset Settings", type = "action", action = "resetSettings" })
    table.insert(items, { label = "Back", type = "action", action = "back" })
end
buildItems()

local function applyItem(item)
    if not item.key then return end
    if item.channel then
        if not _G.settingsData[item.key] then _G.settingsData[item.key] = {r=0, g=0, b=0} end
        _G.settingsData[item.key][item.channel] = item.value
    else
        _G.settingsData[item.key] = item.value
        if item.key == "displayMode" or item.key == "resolution" then
            applyDisplayModeRes()
        elseif item.key == "splitController" then
            input.setSplitMode(item.value)
        elseif item.key == "vSync" then
            love.window.setVSync(item.value)
        elseif item.key == "maxFPS" then
            -- applied in love.draw via frame limiter
        end
    end
end

function scrollToSelected()
    if selectedIndex < scrollOffset + 2 then
        scrollOffset = math.max(0, selectedIndex - 2)
    elseif selectedIndex > scrollOffset + visibleRange - 3 then
        scrollOffset = math.min(#items - visibleRange, selectedIndex - visibleRange + 3)
    end
end

function settings.enter()
    selectedIndex = 1
    prevSelectedIndex = 1
    scrollOffset = 0
    stickTimer = 0
    dragIndex = nil
    buildItems()
    if type(_G.settingsData.ballSpeed) == "string" then
        local speedMap = {Slow = 0.5, Normal = 1.0, Fast = 2.0}
        _G.settingsData.ballSpeed = speedMap[_G.settingsData.ballSpeed] or 1.0
    end
    for _, item in ipairs(items) do
        if item.key and item.channel then
            local color = _G.settingsData[item.key]
            if color then
                item.value = math.min(item.max, color[item.channel])
            end
        elseif item.key then
            local val = _G.settingsData[item.key]
            if val ~= nil then
                item.value = val
            end
        end
    end
end

function settings.exit()
    for _, item in ipairs(items) do
        if item.key then
            if item.channel then
                if not _G.settingsData[item.key] then _G.settingsData[item.key] = {r=0, g=0, b=0} end
                _G.settingsData[item.key][item.channel] = item.value
            else
                _G.settingsData[item.key] = item.value
            end
        end
    end
end

function moveSelection(dir)
    local orig = selectedIndex
    local old = selectedIndex
    repeat
        selectedIndex = math.max(1, math.min(#items, selectedIndex + dir))
        if selectedIndex == old then break end
        old = selectedIndex
    until items[selectedIndex].type ~= "header"
    if selectedIndex ~= orig then sound.playHighlight() end
    scrollToSelected()
end

function settings.update(dt)
    stickTimer = math.max(0, stickTimer - dt)
    if stickTimer > 0 then return end

    local jsticks = love.joystick.getJoysticks()
    if #jsticks < 1 then return end

    local gp = jsticks[1]
    local ly = gp:getGamepadAxis("lefty")
    local lx = gp:getGamepadAxis("leftx")

    if ly < -0.5 then moveSelection(-1); stickTimer = stickDelay
    elseif ly > 0.5 then moveSelection(1); stickTimer = stickDelay
    elseif lx < -0.5 then adjustSetting("left"); stickTimer = stickDelay * 0.5
    elseif lx > 0.5 then adjustSetting("right"); stickTimer = stickDelay * 0.5 end
end

function settings.draw()
    local titleFont = _font("assets/fonts/font.ttf", 40)
    local itemFont = _font("assets/fonts/font.ttf", 22)

    love.graphics.setFont(titleFont)
    local mc = _G.settingsData.menuColor or {r=1, g=1, b=1}
    love.graphics.setColor(mc.r, mc.g, mc.b)
    local title = "Settings"
    love.graphics.print(title, (WINDOW_WIDTH - titleFont:getWidth(title)) / 2, 40)

    love.graphics.setFont(itemFont)
    local selC = _G.settingsData.selectedColor or {r=1, g=1, b=0}

    for i, item in ipairs(items) do
        local y = 115 + (i - 1 - scrollOffset) * 45


        if y >= 80 and y <= 710 then
            if item.type == "header" then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print(item.label, 160, y)
            else
                if i == selectedIndex then love.graphics.setColor(selC.r, selC.g, selC.b)
                else love.graphics.setColor(1, 1, 1) end

                local display = item.label
                if item.type == "cycle" then
                    local valStr = tostring(item.value)
                    if item.key == "winningScore" and item.value == 0 then valStr = "Infinite" end
                    if item.key == "maxFPS" and item.value == 0 then valStr = "Unlimited" end
                    display = item.label .. ": " .. valStr
                elseif item.type == "slider" then
                    display = item.label .. ": " .. string.format("%.2f", item.value)
                elseif item.type == "toggle" then
                    display = item.label .. ": " .. (item.value and "ON" or "OFF")
                end

                if i == selectedIndex then
                    love.graphics.setColor(selC.r, selC.g, selC.b)
                    love.graphics.print("> " .. display, 160, y)
                else
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(display, 160, y)
                end

                if item.type == "slider" and i == selectedIndex then
                    local barX, barY, barW, barH = 620, y + 5, 350, 10
                    love.graphics.setColor(0.3, 0.3, 0.3)
                    love.graphics.rectangle("fill", barX, barY, barW, barH)
                    love.graphics.setColor(1, 1, 1)
                    local fill = (item.value - item.min) / (item.max - item.min)
                    love.graphics.rectangle("fill", barX, barY, barW * fill, barH)

                    if item.channel then
                        local color = _G.settingsData[item.key] or {r=0, g=0, b=0}
                        love.graphics.setColor(color.r, color.g, color.b)
                        love.graphics.rectangle("fill", barX + barW + 10, barY - 4, 18, 18)
            end
        end
    end

    -- scrollbar
    local sbTop = 115
    local sbBottom = 115 + visibleRange * 45 - 10
    local sbHeight = sbBottom - sbTop
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", WINDOW_WIDTH - 15, sbTop, 8, sbHeight)
    if #items > visibleRange then
        local thumbHeight = sbHeight * visibleRange / #items
        local thumbY = sbTop + (sbHeight - thumbHeight) * scrollOffset / (#items - visibleRange)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("fill", WINDOW_WIDTH - 15, thumbY, 8, thumbHeight)
    end
end
    end
end

function settings.keypressed(key)
    if key == "up" then moveSelection(-1)
    elseif key == "down" then moveSelection(1)
    elseif key == "left" or key == "right" then adjustSetting(key)
    elseif key == "return" or key == " " then
        local item = items[selectedIndex]
        if item.type == "action" then
            if item.action == "back" then
                sound.playEscape()
                backToMenu()
            elseif item.action == "resetSettings" then
                sound.playEnter()
                resetAllSettings()
            end
        elseif item.type == "toggle" then item.value = not item.value; applyItem(item)
        elseif item.type == "cycle" then cycleItem(item, 1); applyItem(item) end
    elseif key == "escape" then sound.playEscape(); backToMenu() end
end

function settings.gamepadpressed(joystick, button)
    if button == "dpup" then moveSelection(-1)
    elseif button == "dpdown" then moveSelection(1)
    elseif button == "dpleft" then adjustSetting("left")
    elseif button == "dpright" then adjustSetting("right")
    elseif button == "a" then
        local item = items[selectedIndex]
        if item.type == "action" then
            if item.action == "back" then
                sound.playEscape()
                backToMenu()
            elseif item.action == "resetSettings" then
                sound.playEnter()
                resetAllSettings()
            end
        elseif item.type == "toggle" then item.value = not item.value; applyItem(item)
        elseif item.type == "cycle" then cycleItem(item, 1); applyItem(item) end
    elseif button == "b" then sound.playEscape(); backToMenu() end
end

function settings.mousepressed(x, y, button)
    if button ~= 1 then return end
    -- scrollbar hit
    local sbX, sbW = WINDOW_WIDTH - 15, 8
    local sbTop, sbBottom = 115, 115 + visibleRange * 45 - 10
    if x >= sbX and x <= sbX + sbW and y >= sbTop and y <= sbBottom and #items > visibleRange then
        local sbHeight = sbBottom - sbTop
        local thumbHeight = sbHeight * visibleRange / #items
        local thumbY = sbTop + (sbHeight - thumbHeight) * scrollOffset / (#items - visibleRange)
        if y >= thumbY and y <= thumbY + thumbHeight then
            scrollDrag = true
            scrollToY(y, sbTop, sbHeight, thumbHeight)
        else
            scrollToY(y, sbTop, sbHeight, thumbHeight)
        end
        return
    end
    for i, item in ipairs(items) do
        if item.type ~= "header" then
            local itemY = 115 + (i - 1 - scrollOffset) * 45
            if y >= itemY and y <= itemY + 35 then
                selectedIndex = i
                if item.type == "slider" then
                    local barX, barW = 620, 350
                    local barY = itemY + 5
                    if x >= barX and x <= barX + barW and y >= barY and y <= barY + 10 then
                        local fill = (x - barX) / barW
                        item.value = item.min + fill * (item.max - item.min)
                        item.value = math.max(item.min, math.min(item.max, item.value))
                        applyItem(item)
                        dragIndex = i
                    end
                elseif item.type == "action" then
                    if item.action == "back" then
                        sound.playEscape()
                        backToMenu()
                    elseif item.action == "resetSettings" then
                        sound.playEnter()
                        resetAllSettings()
                    end
                elseif item.type == "toggle" then item.value = not item.value; applyItem(item)
                elseif item.type == "cycle" then cycleItem(item, 1); applyItem(item) end
                return
            end
        end
    end
end

function scrollToY(y, sbTop, sbHeight, thumbHeight)
    local raw = (y - sbTop - thumbHeight / 2) / (sbHeight - thumbHeight)
    local newOffset = math.floor(raw * (#items - visibleRange) + 0.5)
    scrollOffset = math.max(0, math.min(#items - visibleRange, newOffset))
    selectedIndex = math.max(1, math.min(#items, scrollOffset + 1))
    scrollToSelected()
end

function settings.mousemoved(x, y)
    if scrollDrag then
        local sbTop, sbBottom = 115, 115 + visibleRange * 45 - 10
        local sbHeight = sbBottom - sbTop
        local thumbHeight = sbHeight * visibleRange / #items
        scrollToY(y, sbTop, sbHeight, thumbHeight)
        return
    end

    for i, item in ipairs(items) do
        if item.type ~= "header" then
            local itemY = 115 + (i - 1 - scrollOffset) * 45
            if y >= itemY and y <= itemY + 35 then
                if i ~= selectedIndex then
                    selectedIndex = i
                    sound.playHighlight()
                end
                break
            end
        end
    end

    if dragIndex then
        local item = items[dragIndex]
        if item and item.type == "slider" then
            local barX, barW = 620, 350
            local fill = (x - barX) / barW
            item.value = item.min + fill * (item.max - item.min)
            item.value = math.max(item.min, math.min(item.max, item.value))
            applyItem(item)
        end
    end
end

function settings.mousereleased()
    dragIndex = nil
    scrollDrag = false
end

function settings.wheelmoved(y)
    local old = selectedIndex
    if y > 0 then
        selectedIndex = math.max(1, selectedIndex - 1)
    elseif y < 0 then
        selectedIndex = math.min(#items, selectedIndex + 1)
    end
    while items[selectedIndex].type == "header" do
        selectedIndex = selectedIndex + (y > 0 and -1 or 1)
        selectedIndex = math.max(1, math.min(#items, selectedIndex))
    end
    if selectedIndex ~= old then sound.playHighlight() end
    scrollToSelected()
end

settings.applyDisplayModeRes = applyDisplayModeRes

function resetAllSettings()
    _G.settingsData = {
        p1Sensitivity = 1.0,
        p2Sensitivity = 1.0,
        ballSpeed = 1.0,
        maxBallSpeed = 1200,
        displayMode = "Windowed",
        resolution = "Display Native",
        winningScore = 7,
        splitController = false,
        mouseControl = false,
        soundEnabled = true,
        uiScale = 1.0,
        vSync = true,
        maxFPS = 0,
        bgColor = {r=0.05, g=0.05, b=0.05},
        menuColor = {r=1, g=1, b=1},
        selectedColor = {r=1, g=1, b=1},
        paddle1Color = {r=1, g=1, b=1},
        paddle2Color = {r=1, g=1, b=1},
        ballColor = {r=1, g=1, b=1},
        scoreColor = {r=1, g=1, b=1},
    }
    applyDisplayModeRes()
    love.window.setVSync(true)
    input.setSplitMode(false)
    saveSettings()
    settings.enter()
end

function adjustSetting(dir)
    local item = items[selectedIndex]
    if item.type == "slider" then
        if dir == "left" then item.value = math.max(item.min, item.value - item.step)
        elseif dir == "right" then item.value = math.min(item.max, item.value + item.step) end
    elseif item.type == "cycle" then
        cycleItem(item, dir == "left" and -1 or 1)
    elseif item.type == "toggle" then
        item.value = not item.value
    end
    applyItem(item)
end

function cycleItem(item, dir)
    for i, opt in ipairs(item.options) do
        if opt == item.value then
            item.value = item.options[((i - 1 + dir) % #item.options) + 1]
            return
        end
    end
    item.value = item.options[1]
end

return settings
