local menu = require("menu")
local game = require("game")
local settings = require("settings")
local input = require("input")

local state = nil
local gameMode = nil
local difficulty = nil
local settingsData = {}

function love.load()
    love.window.setTitle("PONG")
    math.randomseed(os.time())

    settingsData = {
        difficulty = "medium",
        paddleSpeed = 1.0,
        ballSpeed = 1.0,
        fullscreen = false,
        winningScore = 7,
    }

    input.load()
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
    end
end

function love.draw()
    if state == "menu" then
        menu.draw()
    elseif state == "playing" then
        game.draw()
    elseif state == "settings" then
        settings.draw()
    end
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

function love.mousepressed(x, y, button)
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
    switchState("playing")
end

function startSettings()
    switchState("settings")
end

function backToMenu()
    switchState("menu")
end
