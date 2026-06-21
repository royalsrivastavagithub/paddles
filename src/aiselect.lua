local aiselect = {}
local sound = require("src.sound")

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local difficulties = {"Random", "Easy", "Medium", "Hard", "God"}
local difficultiesKey = {"random", "easy", "medium", "hard", "god"}
local p1Index = 1
local p2Index = 1
local selectedItem = 1
local prevSelectedItem = 1
local items = {"P1 Difficulty", "P2 Difficulty", "Start Game", "Back"}
local _fontCache = {}
local _lastUs = nil
local function _font(path, size)
    local us = _G.settingsData.uiScale or 1.0
    if us ~= _lastUs then _fontCache = {}; _lastUs = us end
    local k = path .. size
    if not _fontCache[k] then _fontCache[k] = love.graphics.newFont(path, math.floor(size * us)) end
    return _fontCache[k]
end

function aiselect.enter()
    p1Index = 1
    p2Index = 1
    selectedItem = 1
    prevSelectedItem = 1
end

function aiselect.exit()
end

function aiselect.update(dt)
end

function aiselect.draw()
    local titleFont = _font("assets/fonts/font.ttf", 36)
    local itemFont = _font("assets/fonts/font.ttf", 28)
    local detailFont = _font("assets/fonts/font.ttf", 22)
    local bg = _G.settingsData.bgColor or {r=0, g=0, b=0}
    local sel = _G.settingsData.selectedColor or {r=1, g=1, b=0}
    local mc = _G.settingsData.menuColor or {r=1, g=1, b=1}

    love.graphics.setColor(bg.r, bg.g, bg.b)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    love.graphics.setFont(titleFont)
    love.graphics.setColor(sel.r, sel.g, sel.b)
    local title = "Bot vs Bot - Select Difficulties"
    love.graphics.print(title, (WINDOW_WIDTH - titleFont:getWidth(title)) / 2, 60)

    love.graphics.setFont(itemFont)
    local yPos = 180
    for i, item in ipairs(items) do
        local color = (i == selectedItem) and sel or mc
        love.graphics.setColor(color.r, color.g, color.b)

        local prefix = (i == selectedItem) and "> " or "  "
        local text = prefix .. item

        if i == 1 then
            text = text .. ": " .. difficulties[p1Index]
        elseif i == 2 then
            text = text .. ": " .. difficulties[p2Index]
        end

        love.graphics.print(text, (WINDOW_WIDTH - itemFont:getWidth(text)) / 2, yPos)
        yPos = yPos + 55
    end


end

function aiselect.keypressed(key)
    if key == "up" then
        local old = selectedItem
        selectedItem = math.max(1, selectedItem - 1)
        if selectedItem ~= old then sound.playHighlight() end
    elseif key == "down" then
        local old = selectedItem
        selectedItem = math.min(#items, selectedItem + 1)
        if selectedItem ~= old then sound.playHighlight() end
    elseif key == "left" then
        if selectedItem == 1 then
            p1Index = p1Index - 1
            if p1Index < 1 then p1Index = #difficulties end
        elseif selectedItem == 2 then
            p2Index = p2Index - 1
            if p2Index < 1 then p2Index = #difficulties end
        end
    elseif key == "right" then
        if selectedItem == 1 then
            p1Index = p1Index + 1
            if p1Index > #difficulties then p1Index = 1 end
        elseif selectedItem == 2 then
            p2Index = p2Index + 1
            if p2Index > #difficulties then p2Index = 1 end
        end
    elseif key == "return" or key == " " then
        sound.playEnter()
        if selectedItem == 3 then
            startGame("aivsai", {p1 = difficultiesKey[p1Index], p2 = difficultiesKey[p2Index]})
        elseif selectedItem == 4 then
            backToMenu()
        end
    elseif key == "escape" then
        sound.playEscape()
        backToMenu()
    end
end

function aiselect.gamepadpressed(joystick, button)
    if button == "dpup" then
        local old = selectedItem
        selectedItem = math.max(1, selectedItem - 1)
        if selectedItem ~= old then sound.playHighlight() end
    elseif button == "dpdown" then
        local old = selectedItem
        selectedItem = math.min(#items, selectedItem + 1)
        if selectedItem ~= old then sound.playHighlight() end
    elseif button == "dpleft" then
        if selectedItem == 1 then
            p1Index = p1Index - 1
            if p1Index < 1 then p1Index = #difficulties end
        elseif selectedItem == 2 then
            p2Index = p2Index - 1
            if p2Index < 1 then p2Index = #difficulties end
        end
    elseif button == "dpright" then
        if selectedItem == 1 then
            p1Index = p1Index + 1
            if p1Index > #difficulties then p1Index = 1 end
        elseif selectedItem == 2 then
            p2Index = p2Index + 1
            if p2Index > #difficulties then p2Index = 1 end
        end
    elseif button == "a" then
        sound.playEnter()
        if selectedItem == 3 then
            startGame("aivsai", {p1 = difficultiesKey[p1Index], p2 = difficultiesKey[p2Index]})
        elseif selectedItem == 4 then
            backToMenu()
        end
    elseif button == "b" or button == "start" then
        sound.playEscape()
        backToMenu()
    end
end

function aiselect.mousepressed(x, y, button)
    if button ~= 1 then return end

    local yPos = 180
    for i, _ in ipairs(items) do
        local itemHeight = 28
        if y >= yPos and y <= yPos + itemHeight then
            selectedItem = i
            sound.playEnter()
            if i == 3 then
                startGame("aivsai", {p1 = difficultiesKey[p1Index], p2 = difficultiesKey[p2Index]})
            elseif i == 4 then
                backToMenu()
            end
            return
        end
        yPos = yPos + 55
    end
end

function aiselect.mousemoved(x, y)
    local yPos = 180
    for i, _ in ipairs(items) do
        if y >= yPos and y <= yPos + 28 then
            if i ~= selectedItem then
                selectedItem = i
                sound.playHighlight()
            end
            return
        end
        yPos = yPos + 55
    end
end

return aiselect
