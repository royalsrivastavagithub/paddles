local input = require("src.input")
local entities = require("src.game.entities")
local ai = require("src.game.ai")

local game = {}

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local mode = nil
local difficulty = nil
local settingsData = {}
local paddle1 = {}
local paddle2 = {}
local ball = {}

local state = nil
local serveTimer = 0
local serveDelay = 3.0
local servePhase = "waiting"
local serveP1Ready = false
local serveP2Ready = false
local paused = false
local pauseSelection = 1
local pauseItems = {"Resume", "Quit to Menu"}
local pauseStickTimer = 0
local speedTimer = 0
local WINNING_SCORE = 7

local scoreFont = nil
local messageFont = nil

function game.enter(m, d, sd)
    mode = m
    difficulty = d
    settingsData = sd or {}
    WINNING_SCORE = settingsData.winningScore or 7

    local p1s = settingsData.p1Sensitivity or 1.0
    local p2s = settingsData.p2Sensitivity or 1.0

    paddle1 = entities.newPaddle(entities.PADDLE_OFFSET, WINDOW_HEIGHT / 2 - entities.PADDLE_HEIGHT / 2, p1s)
    paddle2 = entities.newPaddle(WINDOW_WIDTH - entities.PADDLE_OFFSET - entities.PADDLE_WIDTH, WINDOW_HEIGHT / 2 - entities.PADDLE_HEIGHT / 2, p2s)

    ball = entities.newBall()
    state = "serve"
    servePhase = "waiting"
    serveP1Ready = false
    serveP2Ready = false
    serveTimer = serveDelay
    paused = false
    pauseSelection = 1
    pauseStickTimer = 0
    speedTimer = 0
    ai.reset()

    scoreFont = love.graphics.newFont("assets/fonts/font.ttf", 48)
    messageFont = love.graphics.newFont("assets/fonts/font.ttf", 36)
end

function game.exit()
end

function game.update(dt)
    if paused then
        pauseStickTimer = math.max(0, pauseStickTimer - dt)
        if pauseStickTimer <= 0 then
            local jsticks = love.joystick.getJoysticks()
            if #jsticks >= 1 then
                local y = jsticks[1]:getGamepadAxis("lefty")
                if y < -0.5 then
                    pauseSelection = math.max(1, pauseSelection - 1)
                    pauseStickTimer = 0.2
                elseif y > 0.5 then
                    pauseSelection = math.min(#pauseItems, pauseSelection + 1)
                    pauseStickTimer = 0.2
                end
            end
        end
        return
    end

    if state == "serve" then
        if servePhase == "countdown" then
            serveTimer = serveTimer - dt
            if serveTimer <= 0 then
                serveBall()
            end
        elseif servePhase == "waiting" and mode == "multiplayer" and settingsData.splitController then
            local jsticks = love.joystick.getJoysticks()
            if #jsticks >= 1 then
                local ly = jsticks[1]:getGamepadAxis("lefty")
                local ry = jsticks[1]:getGamepadAxis("righty")
                if math.abs(ly) > 0.5 then serveP1Ready = true end
                if math.abs(ry) > 0.5 then serveP2Ready = true end
                if serveP1Ready and serveP2Ready then startCountdown() end
            end
        end
        return
    end

    if state == "gameover" then return end

    speedTimer = speedTimer + dt
    if speedTimer >= entities.SPEED_INCREASE_INTERVAL then
        speedTimer = 0
        ball.speed = math.min(ball.speed + entities.SPEED_INCREASE_AMOUNT, entities.MAX_BALL_SPEED)
    end

    updatePaddle1(dt)
    updatePaddle2(dt)
    updateBall(dt)
end

function updatePaddle1(dt)
    if input.isP1Up() then
        paddle1.dy = -paddle1.speed
    elseif input.isP1Down() then
        paddle1.dy = paddle1.speed
    else
        paddle1.dy = 0
    end
    entities.movePaddle(paddle1, dt, WINDOW_HEIGHT)
end

function updatePaddle2(dt)
    if mode == "singleplayer" then
        ai.update(paddle2, ball, difficulty, dt, WINDOW_HEIGHT, paddle1.dy)
    else
        if input.isP2Up() then
            paddle2.dy = -paddle2.speed
        elseif input.isP2Down() then
            paddle2.dy = paddle2.speed
        else
            paddle2.dy = 0
        end
    end
    entities.movePaddle(paddle2, dt, WINDOW_HEIGHT)
end

function updateBall(dt)
    local result = entities.updateBall(ball, paddle1, paddle2, dt, WINDOW_WIDTH, WINDOW_HEIGHT)
    if result == "right_score" then
        paddle2.score = paddle2.score + 1
        checkWin()
    elseif result == "left_score" then
        paddle1.score = paddle1.score + 1
        checkWin()
    end
end

function startCountdown()
    servePhase = "countdown"
    serveTimer = 3.0
end

function serveBall()
    ball.x = WINDOW_WIDTH / 2 - entities.BALL_SIZE / 2
    ball.y = WINDOW_HEIGHT / 2 - entities.BALL_SIZE / 2
    ball.speed = entities.BALL_SPEED * (settingsData.ballSpeed or 1.0)

    local angle = math.rad(math.random(-30, 30))
    local dir = -1
    if paddle1.score + paddle2.score == 0 then
        if math.random() < 0.5 then dir = 1 end
    elseif paddle2.score > paddle1.score then
        dir = 1
    end

    ball.dx = dir * math.cos(angle) * ball.speed
    ball.dy = math.sin(angle) * ball.speed
    state = "playing"
end

function checkWin()
    if WINNING_SCORE > 0 and (paddle1.score >= WINNING_SCORE or paddle2.score >= WINNING_SCORE) then
        state = "gameover"
    else
        entities.resetPositions(paddle1, paddle2, ball, WINDOW_WIDTH, WINDOW_HEIGHT)
        state = "serve"
        servePhase = "waiting"
        serveP1Ready = false
        serveP2Ready = false
        serveTimer = serveDelay
    end
end

function game.draw()
    love.graphics.setBackgroundColor(0, 0, 0)

    local sel = settingsData.selectedColor or {r=1, g=1, b=0}
    local p1c = settingsData.paddle1Color or {r=1, g=1, b=1}
    local p2c = settingsData.paddle2Color or {r=1, g=1, b=1}
    local bc = settingsData.ballColor or {r=1, g=1, b=1}
    local sc = settingsData.scoreColor or {r=1, g=1, b=1}

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("line", 2, 2, WINDOW_WIDTH - 4, WINDOW_HEIGHT - 4)

    love.graphics.setColor(sc.r, sc.g, sc.b)
    love.graphics.setFont(scoreFont)
    local p1Text = tostring(paddle1.score)
    local p2Text = tostring(paddle2.score)
    love.graphics.print(p1Text, WINDOW_WIDTH / 2 - 100 - scoreFont:getWidth(p1Text) / 2, 30)
    love.graphics.print(p2Text, WINDOW_WIDTH / 2 + 100 - scoreFont:getWidth(p2Text) / 2, 30)

    love.graphics.setColor(0.4, 0.4, 0.4)
    for i = 0, WINDOW_HEIGHT, 25 do
        love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, i, 4, 12)
    end

    love.graphics.setColor(p1c.r, p1c.g, p1c.b)
    love.graphics.rectangle("fill", paddle1.x, paddle1.y, paddle1.width, paddle1.height)
    love.graphics.setColor(p2c.r, p2c.g, p2c.b)
    love.graphics.rectangle("fill", paddle2.x, paddle2.y, paddle2.width, paddle2.height)
    love.graphics.setColor(bc.r, bc.g, bc.b)
    love.graphics.rectangle("fill", ball.x, ball.y, ball.width, ball.height)

    if state == "serve" then
        if servePhase == "waiting" then
            love.graphics.setFont(messageFont)
            if mode == "singleplayer" then
                love.graphics.setColor(0.5, 0.5, 0.5)
                local msg = "Press any key to serve..."
                love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 + 60)
            else
                love.graphics.setColor(serveP1Ready and 0.3 or 1, serveP1Ready and 1 or 1, serveP1Ready and 0.3 or 1)
                local msg1 = "P1: " .. (serveP1Ready and "READY" or "PRESS W/S")
                love.graphics.print(msg1, (WINDOW_WIDTH - messageFont:getWidth(msg1)) / 2, WINDOW_HEIGHT / 2 + 40)
                love.graphics.setColor(serveP2Ready and 0.3 or 1, serveP2Ready and 1 or 1, serveP2Ready and 0.3 or 1)
                local msg2 = "P2: " .. (serveP2Ready and "READY" or "PRESS UP/DOWN")
                love.graphics.print(msg2, (WINDOW_WIDTH - messageFont:getWidth(msg2)) / 2, WINDOW_HEIGHT / 2 + 80)
            end
        elseif servePhase == "countdown" then
            local cd = math.ceil(serveTimer)
            if cd > 0 then
                love.graphics.setFont(scoreFont)
                love.graphics.setColor(sel.r, sel.g, sel.b)
                love.graphics.print(tostring(cd), (WINDOW_WIDTH - scoreFont:getWidth(tostring(cd))) / 2, WINDOW_HEIGHT / 2 + 10)
            end
        end
    end

    if state == "gameover" then
        love.graphics.setFont(messageFont)
        love.graphics.setColor(sel.r, sel.g, sel.b)
        local winner = "Player 1 Wins!"
        if paddle2.score > paddle1.score then
            winner = mode == "singleplayer" and "AI Wins!" or "Player 2 Wins!"
        end
        love.graphics.print(winner, (WINDOW_WIDTH - messageFont:getWidth(winner)) / 2, WINDOW_HEIGHT / 2 - 50)
        local msg = "Press Enter or A to continue"
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 + 20)
    end

    if paused then
        love.graphics.setColor(0, 0, 0, 180)
        love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        love.graphics.setFont(messageFont)
        love.graphics.setColor(sel.r, sel.g, sel.b)
        local msg = "PAUSED"
        love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 - 80)
        for i, item in ipairs(pauseItems) do
            local y = WINDOW_HEIGHT / 2 - 20 + (i - 1) * 50
            if i == pauseSelection then
                love.graphics.setColor(sel.r, sel.g, sel.b)
                love.graphics.print("> " .. item, (WINDOW_WIDTH - messageFont:getWidth("> " .. item)) / 2, y)
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.print(item, (WINDOW_WIDTH - messageFont:getWidth(item)) / 2, y)
            end
        end
    end
end

function game.keypressed(key)
    if paused then
        if key == "up" then pauseSelection = math.max(1, pauseSelection - 1)
        elseif key == "down" then pauseSelection = math.min(#pauseItems, pauseSelection + 1)
        elseif key == "return" or key == " " then
            if pauseSelection == 1 then paused = false; love.mouse.setVisible(false) else backToMenu() end
        elseif key == "escape" then paused = false; love.mouse.setVisible(false) end
        return
    end

    if state == "serve" and servePhase == "waiting" then
        if mode == "singleplayer" then startCountdown()
        else
            if key == "w" or key == "s" then serveP1Ready = true
            elseif key == "up" or key == "down" then serveP2Ready = true end
            if serveP1Ready and serveP2Ready then startCountdown() end
        end
        return
    end

    if key == "escape" then
        if state == "gameover" then backToMenu()
        elseif state ~= "serve" then paused = true; pauseSelection = 1; love.mouse.setVisible(true) end
        return
    end

    if state == "gameover" and (key == "return" or key == " ") then backToMenu() end
end

function game.gamepadpressed(joystick, button)
    if paused then
        if button == "dpup" then pauseSelection = math.max(1, pauseSelection - 1)
        elseif button == "dpdown" then pauseSelection = math.min(#pauseItems, pauseSelection + 1)
        elseif button == "a" then
            if pauseSelection == 1 then paused = false; love.mouse.setVisible(false) else backToMenu() end
        elseif button == "b" or button == "start" then paused = false; love.mouse.setVisible(false) end
        return
    end

    if state == "serve" and servePhase == "waiting" then
        if mode == "singleplayer" then startCountdown()
        else
            local jsticks = love.joystick.getJoysticks()
            if settingsData.splitController and #jsticks >= 1 then
                if button == "dpup" or button == "dpdown" then serveP1Ready = true end
                if button == "y" or button == "a" then serveP2Ready = true end
            else
                if joystick == jsticks[1] or #jsticks == 1 then serveP1Ready = true
                elseif joystick == jsticks[2] then serveP2Ready = true end
            end
            if serveP1Ready and serveP2Ready then startCountdown() end
        end
        return
    end

    if button == "start" then
        if state == "gameover" then backToMenu()
        elseif state ~= "serve" then paused = true; pauseSelection = 1; love.mouse.setVisible(true) end
        return
    end

    if state == "gameover" and button == "a" then backToMenu() end
end

return game
