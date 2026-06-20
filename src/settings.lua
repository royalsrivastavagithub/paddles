local settings = {}
local input = require("src.input")

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

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
local scrollOffset = 0
local stickTimer = 0
local stickDelay = 0.2
local visibleRange = 13
local dragIndex = nil

local function buildItems()
    items = {
        { label = "P1 Sensitivity",   type = "slider", value = 1.0, min = 0.5, max = 2.0, step = 0.1, key = "p1Sensitivity" },
        { label = "P2 Sensitivity",   type = "slider", value = 1.0, min = 0.5, max = 2.0, step = 0.1, key = "p2Sensitivity" },
        { label = "Ball Speed",       type = "slider", value = 1.0, min = 0.5, max = 5.0, step = 0.1, key = "ballSpeed" },
        { label = "Winning Score",    type = "cycle",  value = 7,   options = {3, 5, 7, 11, 21, 0}, key = "winningScore" },
        { label = "Fullscreen",       type = "toggle", value = false, key = "fullscreen" },
        { label = "Split Controller", type = "toggle", value = false, key = "splitController" },
    }
    for _, group in ipairs(colorGroups) do
        table.insert(items, { label = "--- " .. group.label .. " ---", type = "header" })
        for _, ch in ipairs(channels) do
            table.insert(items, { label = ch:upper(), type = "slider", value = 1, min = 0, max = 1, step = 0.01, key = group.key, channel = ch })
        end
    end
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
        if item.key == "fullscreen" then
            if item.value then love.window.setFullscreen(true, "desktop")
            else love.window.setFullscreen(false); love.window.setMode(1280, 720) end
        elseif item.key == "splitController" then
            input.setSplitMode(item.value)
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
    scrollOffset = 0
    stickTimer = 0
    dragIndex = nil
    for _, item in ipairs(items) do
        if item.key and item.channel then
            local color = _G.settingsData[item.key]
            if color then item.value = color[item.channel] end
        elseif item.key then
            local val = _G.settingsData[item.key]
            if val ~= nil then item.value = val end
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

function settings.update(dt)
    stickTimer = math.max(0, stickTimer - dt)
    if stickTimer > 0 then return end

    local jsticks = love.joystick.getJoysticks()
    if #jsticks < 1 then return end

    local gp = jsticks[1]
    local ly = gp:getGamepadAxis("lefty")
    local lx = gp:getGamepadAxis("leftx")

    if ly < -0.5 then selectedIndex = math.max(1, selectedIndex - 1); scrollToSelected(); stickTimer = stickDelay
    elseif ly > 0.5 then selectedIndex = math.min(#items, selectedIndex + 1); scrollToSelected(); stickTimer = stickDelay
    elseif lx < -0.5 then adjustSetting("left"); stickTimer = stickDelay * 0.5
    elseif lx > 0.5 then adjustSetting("right"); stickTimer = stickDelay * 0.5 end
end

function settings.draw()
    local titleFont = love.graphics.newFont("assets/fonts/font.ttf", 40)
    local itemFont = love.graphics.newFont("assets/fonts/font.ttf", 22)

    love.graphics.setFont(titleFont)
    local mc = _G.settingsData.menuColor or {r=1, g=1, b=1}
    love.graphics.setColor(mc.r, mc.g, mc.b)
    local title = "Settings"
    love.graphics.print(title, (WINDOW_WIDTH - titleFont:getWidth(title)) / 2, 40)

    love.graphics.setFont(itemFont)
    local selC = _G.settingsData.selectedColor or {r=1, g=1, b=0}

    for i, item in ipairs(items) do
        local y = 115 + (i - 1 - scrollOffset) * 45
        if y < 80 or y > 710 then end

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
                    if item.value == 0 then valStr = "∞" end
                    display = item.label .. ": " .. valStr
                elseif item.type == "slider" then
                    local valDisplay = string.format("%.2f", item.value)
                    if item.key == "ballSpeed" and item.value >= item.max then
                        valDisplay = valDisplay .. "  Are you crazy?!"
                    end
                    display = item.label .. ": " .. valDisplay
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
        end
    end
end

function settings.keypressed(key)
    if key == "up" then selectedIndex = math.max(1, selectedIndex - 1); scrollToSelected()
    elseif key == "down" then selectedIndex = math.min(#items, selectedIndex + 1); scrollToSelected()
    elseif key == "left" or key == "right" then adjustSetting(key)
    elseif key == "return" or key == " " then
        local item = items[selectedIndex]
        if item.type == "action" and item.action == "back" then backToMenu()
        elseif item.type == "toggle" then item.value = not item.value; applyItem(item)
        elseif item.type == "cycle" then cycleItem(item, 1); applyItem(item) end
    elseif key == "escape" then backToMenu() end
end

function settings.gamepadpressed(joystick, button)
    if button == "dpup" then selectedIndex = math.max(1, selectedIndex - 1); scrollToSelected()
    elseif button == "dpdown" then selectedIndex = math.min(#items, selectedIndex + 1); scrollToSelected()
    elseif button == "dpleft" then adjustSetting("left")
    elseif button == "dpright" then adjustSetting("right")
    elseif button == "a" then
        local item = items[selectedIndex]
        if item.type == "action" and item.action == "back" then backToMenu()
        elseif item.type == "toggle" then item.value = not item.value; applyItem(item)
        elseif item.type == "cycle" then cycleItem(item, 1); applyItem(item) end
    elseif button == "b" then backToMenu() end
end

function settings.mousepressed(x, y, button)
    if button ~= 1 then return end
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
                    elseif item.type == "action" and item.action == "back" then backToMenu()
                elseif item.type == "toggle" then item.value = not item.value; applyItem(item)
                elseif item.type == "cycle" then cycleItem(item, 1); applyItem(item) end
                return
            end
        end
    end
end

function settings.mousemoved(x, y)
    for i, item in ipairs(items) do
        if item.type ~= "header" then
            local itemY = 115 + (i - 1 - scrollOffset) * 45
            if y >= itemY and y <= itemY + 35 then
                selectedIndex = i
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
end

function settings.wheelmoved(y)
    if y > 0 then
        selectedIndex = math.max(1, selectedIndex - 1)
    elseif y < 0 then
        selectedIndex = math.min(#items, selectedIndex + 1)
    end
    scrollToSelected()
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
