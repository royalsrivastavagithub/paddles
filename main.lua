local menu = require("src.menu")
local game = require("src.game.init")
local settings = require("src.settings")
local input = require("src.input")
local aiselect = require("src.aiselect")
local sound = require("src.sound")

local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 720

local state = nil
local gameMode = nil
local difficulty = nil
local frameTimer = 0
settingsData = {}

function love.load()
    love.window.setTitle("Paddles")
    love.keyboard.setKeyRepeat(true)
    math.randomseed(os.time())

    settingsData = {
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
        trail = 6,
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
    loadSettings()
    settingsData.bgColor.r = math.min(0.5, settingsData.bgColor.r)
    settingsData.bgColor.g = math.min(0.5, settingsData.bgColor.g)
    settingsData.bgColor.b = math.min(0.5, settingsData.bgColor.b)
    love.window.setVSync(settingsData.vSync)
    settings.applyDisplayModeRes()

    input.load()
    sound.load()
    menu.load()
    state = "menu"
end

function love.update(dt)
    if state == "menu" then
        menu.update(dt)
    elseif state == "playing" then
        game.update(dt)
    elseif state == "settings" then
        settings.update(dt)
    elseif state == "aiselect" then
        aiselect.update(dt)
    end
end

function love.draw()
    if settingsData.maxFPS and settingsData.maxFPS > 0 then
        local limit = 1 / settingsData.maxFPS
        local now = love.timer.getTime()
        local elapsed = now - frameTimer
        if elapsed < limit then
            love.timer.sleep(limit - elapsed)
        end
        frameTimer = love.timer.getTime()
    end

    local screenW, screenH = love.graphics.getDimensions()
    local scale = math.min(screenW / VIRTUAL_WIDTH, screenH / VIRTUAL_HEIGHT)
    local offsetX = (screenW - VIRTUAL_WIDTH * scale) / 2
    local offsetY = (screenH - VIRTUAL_HEIGHT * scale) / 2

    local bg = settingsData.bgColor or {r=0, g=0, b=0}
    love.graphics.setBackgroundColor(bg.r, bg.g, bg.b)
    love.graphics.setColor(bg.r, bg.g, bg.b)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)
    love.graphics.setScissor(offsetX, offsetY, VIRTUAL_WIDTH * scale, VIRTUAL_HEIGHT * scale)

    if state == "menu" then
        menu.draw()
    elseif state == "playing" then
        game.draw()
    elseif state == "settings" then
        settings.draw()
    elseif state == "aiselect" then
        aiselect.draw()
    end

    love.graphics.pop()
    love.graphics.setScissor()
end

function love.keypressed(key)
    if state == "menu" then
        menu.keypressed(key)
    elseif state == "playing" then
        game.keypressed(key)
    elseif state == "settings" then
        settings.keypressed(key)
    elseif state == "aiselect" then
        aiselect.keypressed(key)
    end
end

function love.gamepadpressed(joystick, button)
    if state == "menu" then
        menu.gamepadpressed(joystick, button)
    elseif state == "playing" then
        game.gamepadpressed(joystick, button)
    elseif state == "settings" then
        settings.gamepadpressed(joystick, button)
    elseif state == "aiselect" then
        aiselect.gamepadpressed(joystick, button)
    end
end

function love.joystickadded(joystick)
    input.refresh()
end

function love.joystickremoved(joystick)
    input.refresh()
end

function love.mousepressed(sx, sy, button)
    local screenW, screenH = love.graphics.getDimensions()
    local scale = math.min(screenW / VIRTUAL_WIDTH, screenH / VIRTUAL_HEIGHT)
    local offsetX = (screenW - VIRTUAL_WIDTH * scale) / 2
    local offsetY = (screenH - VIRTUAL_HEIGHT * scale) / 2
    local x = (sx - offsetX) / scale
    local y = (sy - offsetY) / scale

    if state == "menu" then
        menu.mousepressed(x, y, button)
    elseif state == "settings" then
        settings.mousepressed(x, y, button)
    elseif state == "aiselect" then
        aiselect.mousepressed(x, y, button)
    end
end

function love.mousemoved(sx, sy, dx, dy, istouch)
    local screenW, screenH = love.graphics.getDimensions()
    local scale = math.min(screenW / VIRTUAL_WIDTH, screenH / VIRTUAL_HEIGHT)
    local offsetX = (screenW - VIRTUAL_WIDTH * scale) / 2
    local offsetY = (screenH - VIRTUAL_HEIGHT * scale) / 2
    local x = (sx - offsetX) / scale
    local y = (sy - offsetY) / scale

    if state == "menu" then
        menu.mousemoved(x, y)
    elseif state == "settings" then
        settings.mousemoved(x, y)
    elseif state == "aiselect" then
        aiselect.mousemoved(x, y)
    end
end

function love.mousereleased(sx, sy, button)
    if state == "settings" then
        settings.mousereleased()
    end
end

function love.wheelmoved(x, y)
    if state == "settings" then
        settings.wheelmoved(y)
    end
end

function switchState(newState)
    if state == "playing" then
        game.exit()
    elseif state == "menu" then
        menu.exit()
    elseif state == "settings" then
        settings.exit()
        saveSettings()
    end

    state = newState

    if state == "menu" or state == "settings" or state == "aiselect" then
        love.mouse.setVisible(true)
    elseif state == "playing" then
        love.mouse.setVisible(false)
    end

    if state == "menu" then
        menu.enter()
    elseif state == "playing" then
        game.enter(gameMode, difficulty, settingsData)
    elseif state == "settings" then
        settings.enter()
    elseif state == "aiselect" then
        aiselect.enter()
    end
end

function startGame(mode, diff)
    gameMode = mode
    if mode == "aivsai" then
        local pool = {"easy", "medium", "hard", "god"}
        local p1d = diff and diff.p1 or pool[math.random(#pool)]
        local p2d = diff and diff.p2 or pool[math.random(#pool)]
        if p1d == "random" then p1d = pool[math.random(#pool)] end
        if p2d == "random" then p2d = pool[math.random(#pool)] end
        difficulty = {p1 = p1d, p2 = p2d}
    else
        difficulty = diff or "medium"
    end
    input.setSplitMode(settingsData.splitController)
    switchState("playing")
end

function startSettings()
    switchState("settings")
end

function startAISelect()
    switchState("aiselect")
end

function backToMenu()
    switchState("menu")
    settings.applyDisplayModeRes()
end

function saveSettings()
    local lines = {"return {"}
    for k, v in pairs(settingsData) do
        if type(v) == "table" then
            table.insert(lines, string.format("  %s = {r=%.3f, g=%.3f, b=%.3f},", k, v.r, v.g, v.b))
        elseif type(v) == "string" then
            table.insert(lines, string.format("  %s = %q,", k, v))
        elseif type(v) == "boolean" then
            table.insert(lines, string.format("  %s = %s,", k, tostring(v)))
        else
            table.insert(lines, string.format("  %s = %s,", k, tostring(v)))
        end
    end
    table.insert(lines, "}")
    local f = io.open("settings.dat", "w")
    if f then f:write(table.concat(lines, "\n")); f:close() end
end

function loadSettings()
    local f = loadfile("settings.dat")
    if f then
        local ok, saved = pcall(f)
        if ok and saved then
            for k, v in pairs(saved) do
                settingsData[k] = v
            end
        end
    end
end
