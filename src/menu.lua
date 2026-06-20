local menu = {}

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local items = {
    { label = "Singleplayer", action = "singleplayer" },
    { label = "Multiplayer",   action = "multiplayer" },
    { label = "Bot vs Bot",      action = "aivsai" },
    { label = "Settings",      action = "settings" },
    { label = "Exit",          action = "exit" },
}

local difficultyItems = {
    { label = "Easy",   action = "easy" },
    { label = "Medium", action = "medium" },
    { label = "Hard",   action = "hard" },
    { label = "God",    action = "god" },
    { label = "Back",   action = "back" },
}

local selectedIndex = 1
local showingDifficulty = false
local difficultySelectedIndex = 1
local stickTimer = 0
local stickDelay = 0.2

function menu.load()
end

function menu.enter()
    selectedIndex = 1
    difficultySelectedIndex = 1
    showingDifficulty = false
    stickTimer = 0
end

function menu.exit()
end

function menu.update(dt)
    stickTimer = math.max(0, stickTimer - dt)
    if stickTimer > 0 then return end

    local jsticks = love.joystick.getJoysticks()
    if #jsticks < 1 then return end

    local y = jsticks[1]:getGamepadAxis("lefty")
    if y < -0.5 then
        if showingDifficulty then
            difficultySelectedIndex = math.max(1, difficultySelectedIndex - 1)
        else
            selectedIndex = math.max(1, selectedIndex - 1)
        end
        stickTimer = stickDelay
    elseif y > 0.5 then
        if showingDifficulty then
            difficultySelectedIndex = math.min(#difficultyItems, difficultySelectedIndex + 1)
        else
            selectedIndex = math.min(#items, selectedIndex + 1)
        end
        stickTimer = stickDelay
    end
end

function menu.draw()
    local mc = _G.settingsData.menuColor or {r=1, g=1, b=1}
    local sc = _G.settingsData.selectedColor or {r=1, g=1, b=0}

    local us = _G.settingsData.uiScale or 1.0
    local font = love.graphics.newFont("assets/fonts/font.ttf", math.floor(64 * us))
    love.graphics.setFont(font)
    love.graphics.setColor(mc.r, mc.g, mc.b)
    local titleW = font:getWidth("paddles")
    love.graphics.print("paddles", (WINDOW_WIDTH - titleW) / 2, 100)

    if showingDifficulty then
        drawMenuItems(difficultyItems, difficultySelectedIndex, 300, mc, sc)
    else
        drawMenuItems(items, selectedIndex, 300, mc, sc)
    end

    local footerFont = love.graphics.newFont("assets/fonts/font.ttf", math.floor(24 * us))
    love.graphics.setFont(footerFont)
    love.graphics.setColor(mc.r, mc.g, mc.b)
    love.graphics.print("Created by : Royal Srivastava", 20, WINDOW_HEIGHT - 40)
    local versionText = "pong v0.9"
    local versionWidth = footerFont:getWidth(versionText)
    love.graphics.print(versionText, WINDOW_WIDTH - versionWidth - 20, WINDOW_HEIGHT - 40)
end

function drawMenuItems(list, selectedIdx, startY, menuColor, selectedColor)
    local us = _G.settingsData.uiScale or 1.0
    local font = love.graphics.newFont("assets/fonts/font.ttf", math.floor(36 * us))
    love.graphics.setFont(font)

    for i, item in ipairs(list) do
        if i == selectedIdx then
            love.graphics.setColor(selectedColor.r, selectedColor.g, selectedColor.b)
            love.graphics.print("> " .. item.label, (WINDOW_WIDTH - font:getWidth("> " .. item.label)) / 2, startY + (i - 1) * 60)
        else
            love.graphics.setColor(menuColor.r, menuColor.g, menuColor.b)
            love.graphics.print(item.label, (WINDOW_WIDTH - font:getWidth(item.label)) / 2, startY + (i - 1) * 60)
        end
    end
end

function menu.keypressed(key)
    if showingDifficulty then
        if key == "up" then difficultySelectedIndex = math.max(1, difficultySelectedIndex - 1)
        elseif key == "down" then difficultySelectedIndex = math.min(#difficultyItems, difficultySelectedIndex + 1)
        elseif key == "return" or key == " " then handleDifficultyAction(difficultyItems[difficultySelectedIndex].action)
        elseif key == "escape" then showingDifficulty = false end
    else
        if key == "up" then selectedIndex = math.max(1, selectedIndex - 1)
        elseif key == "down" then selectedIndex = math.min(#items, selectedIndex + 1)
        elseif key == "return" or key == " " then handleMainAction(items[selectedIndex].action)
        elseif key == "escape" then love.event.quit() end
    end
end

function menu.gamepadpressed(joystick, button)
    if showingDifficulty then
        if button == "dpup" then difficultySelectedIndex = math.max(1, difficultySelectedIndex - 1)
        elseif button == "dpdown" then difficultySelectedIndex = math.min(#difficultyItems, difficultySelectedIndex + 1)
        elseif button == "a" then handleDifficultyAction(difficultyItems[difficultySelectedIndex].action)
        elseif button == "b" then showingDifficulty = false end
    else
        if button == "dpup" then selectedIndex = math.max(1, selectedIndex - 1)
        elseif button == "dpdown" then selectedIndex = math.min(#items, selectedIndex + 1)
        elseif button == "a" then handleMainAction(items[selectedIndex].action)
        elseif button == "b" or button == "start" then love.event.quit() end
    end
end

function menu.mousemoved(x, y)
    if showingDifficulty then
        local idx = hitTestMenuItems(difficultyItems, 300, y)
        if idx then difficultySelectedIndex = idx end
    else
        local idx = hitTestMenuItems(items, 300, y)
        if idx then selectedIndex = idx end
    end
end

function menu.mousepressed(x, y, button)
    if button ~= 1 then return end
    if showingDifficulty then
        local idx = hitTestMenuItems(difficultyItems, 300, y)
        if idx then difficultySelectedIndex = idx; handleDifficultyAction(difficultyItems[idx].action) end
    else
        local idx = hitTestMenuItems(items, 300, y)
        if idx then selectedIndex = idx; handleMainAction(items[idx].action) end
    end
end

function hitTestMenuItems(list, startY, mouseY)
    for i = 1, #list do
        local itemY = startY + (i - 1) * 60
        if mouseY >= itemY - 20 and mouseY <= itemY + 40 then return i end
    end
end

function handleMainAction(action)
    if action == "singleplayer" then showingDifficulty = true; difficultySelectedIndex = 1
    elseif action == "multiplayer" then startGame("multiplayer", nil)
    elseif action == "aivsai" then startAISelect()
    elseif action == "settings" then startSettings()
    elseif action == "exit" then love.event.quit() end
end

function handleDifficultyAction(action)
    if action == "back" then showingDifficulty = false else startGame("singleplayer", action) end
end

return menu
