local colors = require("colors")

local settings = {}

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local colorKeys = {"menuColor", "paddle1Color", "paddle2Color", "ballColor", "scoreColor"}
local colorItemLabel = {menuColor = "Menu Text", paddle1Color = "Paddle 1", paddle2Color = "Paddle 2", ballColor = "Ball", scoreColor = "Scoreboard"}

local items = {
    { label = "P1 Sensitivity",      type = "slider",  value = 1.0, min = 0.5, max = 2.0, step = 0.1,        key = "p1Sensitivity" },
    { label = "P2 Sensitivity",      type = "slider",  value = 1.0, min = 0.5, max = 2.0, step = 0.1,        key = "p2Sensitivity" },
    { label = "Ball Speed",          type = "slider",  value = 1.0, min = 0.5, max = 5.0, step = 0.1,        key = "ballSpeed" },
    { label = "Winning Score",       type = "cycle",   value = 7,   options = {3, 5, 7, 11, 21, 0},           key = "winningScore" },
    { label = "Fullscreen",          type = "toggle",  value = false,                                           key = "fullscreen" },
    { label = "Split Controller",    type = "toggle",  value = false,                                           key = "splitController" },
    { label = "Menu Text Color",     type = "color",   value = "white", options = colors.names(),               key = "menuColor" },
    { label = "Selected Color",      type = "color",   value = "yellow", options = colors.names(),              key = "selectedColor" },
    { label = "Paddle 1 Color",      type = "color",   value = "white", options = colors.names(),               key = "paddle1Color" },
    { label = "Paddle 2 Color",      type = "color",   value = "white", options = colors.names(),               key = "paddle2Color" },
    { label = "Ball Color",          type = "color",   value = "white", options = colors.names(),               key = "ballColor" },
    { label = "Scoreboard Color",    type = "color",   value = "white", options = colors.names(),               key = "scoreColor" },
    { label = "Back",                type = "action",  action = "back" },
}

local selectedIndex = 1
local stickTimer = 0
local stickDelay = 0.2

function settings.enter()
    selectedIndex = 1
    stickTimer = 0
    for _, item in ipairs(items) do
        if item.key then
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
            _G.settingsData[item.key] = item.value
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

    if ly < -0.5 then
        selectedIndex = math.max(1, selectedIndex - 1)
        stickTimer = stickDelay
    elseif ly > 0.5 then
        selectedIndex = math.min(#items, selectedIndex + 1)
        stickTimer = stickDelay
    elseif lx < -0.5 then
        adjustSetting("left")
        stickTimer = stickDelay * 0.5
    elseif lx > 0.5 then
        adjustSetting("right")
        stickTimer = stickDelay * 0.5
    end
end

function settings.draw()
    local titleFont = love.graphics.newFont("font.ttf", 40)
    local itemFont = love.graphics.newFont("font.ttf", 22)

    love.graphics.setFont(titleFont)
    local mc = colors.get(_G.settingsData.menuColor or "white")
    love.graphics.setColor(mc[1], mc[2], mc[3])
    local title = "Settings"
    love.graphics.print(title, (WINDOW_WIDTH - titleFont:getWidth(title)) / 2, 40)

    love.graphics.setFont(itemFont)
    local sc = colors.get(_G.settingsData.selectedColor or "yellow")

    for i, item in ipairs(items) do
        local y = 115 + (i - 1) * 45

        if i == selectedIndex then
            love.graphics.setColor(sc[1], sc[2], sc[3])
        else
            love.graphics.setColor(1, 1, 1)
        end

        local display = item.label
        if item.type == "cycle" then
            local valStr = tostring(item.value)
            if item.value == 0 then valStr = "∞" end
            display = item.label .. ": " .. valStr
        elseif item.type == "color" then
            local c = colors.get(item.value)
            display = item.label .. ": " .. item.value:sub(1, 1):upper() .. item.value:sub(2)
            if i == selectedIndex then
                love.graphics.setColor(sc[1], sc[2], sc[3])
            else
                love.graphics.setColor(c[1], c[2], c[3])
            end
        elseif item.type == "slider" then
            local valDisplay = tostring(item.value)
            if item.value >= item.max then
                valDisplay = valDisplay .. "  Are you crazy?!"
            end
            display = item.label .. ": " .. valDisplay
        elseif item.type == "toggle" then
            display = item.label .. ": " .. (item.value and "ON" or "OFF")
        end

        if i == selectedIndex then
            love.graphics.setColor(sc[1], sc[2], sc[3])
            love.graphics.print("> " .. display, 160, y)
        else
            if item.type == "color" then
                local c = colors.get(item.value)
                love.graphics.setColor(c[1], c[2], c[3])
            else
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.print(display, 160, y)
        end

        if item.type == "slider" and i == selectedIndex then
            local barX = 620
            local barY = y + 5
            local barW = 350
            local barH = 10
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", barX, barY, barW, barH)
            love.graphics.setColor(1, 1, 1)
            local fill = (item.value - item.min) / (item.max - item.min)
            love.graphics.rectangle("fill", barX, barY, barW * fill, barH)
        end
    end
end

function settings.keypressed(key)
    if key == "up" then
        selectedIndex = math.max(1, selectedIndex - 1)
    elseif key == "down" then
        selectedIndex = math.min(#items, selectedIndex + 1)
    elseif key == "left" or key == "right" then
        adjustSetting(key)
    elseif key == "return" or key == " " then
        local item = items[selectedIndex]
        if item.type == "action" then
            if item.action == "back" then
                backToMenu()
            end
        elseif item.type == "toggle" then
            item.value = not item.value
        elseif item.type == "cycle" or item.type == "color" then
            cycleItem(item, 1)
        end
    elseif key == "escape" then
        backToMenu()
    end
end

function settings.gamepadpressed(joystick, button)
    if button == "dpup" then
        selectedIndex = math.max(1, selectedIndex - 1)
    elseif button == "dpdown" then
        selectedIndex = math.min(#items, selectedIndex + 1)
    elseif button == "dpleft" then
        adjustSetting("left")
    elseif button == "dpright" then
        adjustSetting("right")
    elseif button == "a" then
        local item = items[selectedIndex]
        if item.type == "action" then
            if item.action == "back" then
                backToMenu()
            end
        elseif item.type == "toggle" then
            item.value = not item.value
        elseif item.type == "cycle" or item.type == "color" then
            cycleItem(item, 1)
        end
    elseif button == "b" then
        backToMenu()
    end
end

function settings.mousepressed(x, y, button)
    if button == 1 then
        for i, item in ipairs(items) do
            local itemY = 115 + (i - 1) * 45
            if y >= itemY and y <= itemY + 35 then
                selectedIndex = i
                if item.type == "action" then
                    if item.action == "back" then
                        backToMenu()
                    end
                elseif item.type == "toggle" then
                    item.value = not item.value
                elseif item.type == "cycle" or item.type == "color" then
                    cycleItem(item, 1)
                end
                return
            end
        end
    end
end

function adjustSetting(dir)
    local item = items[selectedIndex]
    if item.type == "slider" then
        if dir == "left" then
            item.value = math.max(item.min, item.value - item.step)
        elseif dir == "right" then
            item.value = math.min(item.max, item.value + item.step)
        end
    elseif item.type == "cycle" or item.type == "color" then
        if dir == "left" then
            cycleItem(item, -1)
        elseif dir == "right" then
            cycleItem(item, 1)
        end
    elseif item.type == "toggle" then
        item.value = not item.value
    end
end

function cycleItem(item, dir)
    for i, opt in ipairs(item.options) do
        if opt == item.value then
            local nextIdx = ((i - 1 + dir) % #item.options) + 1
            item.value = item.options[nextIdx]
            return
        end
    end
    item.value = item.options[1]
end

return settings
