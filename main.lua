local menu = require("menu")
local game = require("game")
local settings = require("settings")
local input = require("input")

local VIRTUAL_WIDTH = 1280
local VIRTUAL_HEIGHT = 720

local state = nil
local gameMode = nil
local difficulty = nil
settingsData = {}

local bgBall = {
    x = 640, y = 360,
    dx = 200, dy = 150,
    size = 20,
}

function love.load()
    love.window.setTitle("PONG")
    math.randomseed(os.time())

    settingsData = {
        difficulty = "medium",
        p1Sensitivity = 1.0,
        p2Sensitivity = 1.0,
        ballSpeed = 1.0,
        fullscreen = false,
        winningScore = 7,
        splitController = false,
        bgColor = {r=0, g=0, b=0},
        menuColor = {r=1, g=1, b=1},
        selectedColor = {r=1, g=1, b=0},
        paddle1Color = {r=1, g=1, b=1},
        paddle2Color = {r=1, g=1, b=1},
        ballColor = {r=1, g=1, b=1},
        scoreColor = {r=1, g=1, b=1},
    }

    input.load()
    menu.load()

    state = "menu"
end

function love.update(dt)
    local bg = settingsData.bgColor or {r=0, g=0, b=0}
    if not (bg.r == 0 and bg.g == 0 and bg.b == 0) then
        bgBall.dx = 250
        bgBall.dy = 180
    else
        bgBall.dx = 200
        bgBall.dy = 150
    end

    bgBall.x = bgBall.x + bgBall.dx * dt
    bgBall.y = bgBall.y + bgBall.dy * dt
    if bgBall.x <= 0 or bgBall.x + bgBall.size >= VIRTUAL_WIDTH then
        bgBall.dx = -bgBall.dx
        bgBall.x = math.max(0, math.min(bgBall.x, VIRTUAL_WIDTH - bgBall.size))
    end
    if bgBall.y <= 0 or bgBall.y + bgBall.size >= VIRTUAL_HEIGHT then
        bgBall.dy = -bgBall.dy
        bgBall.y = math.max(0, math.min(bgBall.y, VIRTUAL_HEIGHT - bgBall.size))
    end

    if state == "menu" then
        menu.update(dt)
    elseif state == "playing" then
        game.update(dt)
    elseif state == "settings" then
        settings.update(dt)
    end
end

function love.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local scale = math.min(screenW / VIRTUAL_WIDTH, screenH / VIRTUAL_HEIGHT)
    local offsetX = (screenW - VIRTUAL_WIDTH * scale) / 2
    local offsetY = (screenH - VIRTUAL_HEIGHT * scale) / 2

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)
    love.graphics.setScissor(offsetX, offsetY, VIRTUAL_WIDTH * scale, VIRTUAL_HEIGHT * scale)

    local bg = settingsData.bgColor or {r=0, g=0, b=0}
    love.graphics.setBackgroundColor(bg.r, bg.g, bg.b)

    if state ~= "playing" then
        love.graphics.setColor(1, 1, 1, 0.06)
        love.graphics.rectangle("fill", bgBall.x, bgBall.y, bgBall.size, bgBall.size)
    end

    if state == "menu" then
        menu.draw()
    elseif state == "playing" then
        game.draw()
    elseif state == "settings" then
        settings.draw()
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
    end
end

function love.gamepadpressed(joystick, button)
    if state == "menu" then
        menu.gamepadpressed(joystick, button)
    elseif state == "playing" then
        game.gamepadpressed(joystick, button)
    elseif state == "settings" then
        settings.gamepadpressed(joystick, button)
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
    end
end

function switchState(newState)
    if state == "playing" then
        game.exit()
    elseif state == "menu" then
        menu.exit()
    elseif state == "settings" then
        settings.exit()
    end

    state = newState

    if state == "menu" then
        menu.enter()
    elseif state == "playing" then
        game.enter(gameMode, difficulty, settingsData)
    elseif state == "settings" then
        settings.enter()
    end
end

function startGame(mode, diff)
    gameMode = mode
    difficulty = diff or settingsData.difficulty
    input.setSplitMode(settingsData.splitController)
    switchState("playing")
end

function startSettings()
    switchState("settings")
end

function backToMenu()
    switchState("menu")
    if settingsData.fullscreen then
        love.window.setFullscreen(true, "desktop")
    else
        love.window.setFullscreen(false)
        love.window.setMode(1280, 720)
    end
end
