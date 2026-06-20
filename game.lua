local input = require("input")
local colors = require("colors")

local game = {}

local WINDOW_WIDTH = 1280
local WINDOW_HEIGHT = 720

local PADDLE_WIDTH = 15
local PADDLE_HEIGHT = 100
local PADDLE_SPEED = 400
local PADDLE_OFFSET = 50

local BALL_SIZE = 15
local BALL_SPEED = 350
local BALL_SPEED_INCREASE = 1.02
local MAX_BALL_SPEED = 2000
local SPEED_INCREASE_INTERVAL = 5
local SPEED_INCREASE_AMOUNT = 15

local WINNING_SCORE = 7

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
local aiReactionTimer = 0
local aiTargetOffset = 0

local scoreFont = nil
local messageFont = nil

function game.enter(m, d, sd)
    mode = m
    difficulty = d
    settingsData = sd or {}
    WINNING_SCORE = settingsData.winningScore or 7

    local p1s = settingsData.p1Sensitivity or 1.0
    local p2s = settingsData.p2Sensitivity or 1.0

    paddle1 = newPaddle(PADDLE_OFFSET, WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2, p1s)
    paddle2 = newPaddle(WINDOW_WIDTH - PADDLE_OFFSET - PADDLE_WIDTH, WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2, p2s)

    ball = newBall()
    state = "serve"
    servePhase = "waiting"
    serveP1Ready = false
    serveP2Ready = false
    serveTimer = serveDelay
    paused = false
    pauseSelection = 1
    pauseStickTimer = 0
    speedTimer = 0
    aiReactionTimer = 0
    aiTargetOffset = (math.random() * 2 - 1) * 0.4

    scoreFont = love.graphics.newFont("font.ttf", 48)
    messageFont = love.graphics.newFont("font.ttf", 36)
end

function game.exit()
end

function newPaddle(x, y, speedMult)
    return {
        x = x,
        y = y,
        width = PADDLE_WIDTH,
        height = PADDLE_HEIGHT,
        speed = PADDLE_SPEED * speedMult,
        score = 0,
        dy = 0,
    }
end

function newBall()
    return {
        x = WINDOW_WIDTH / 2 - BALL_SIZE / 2,
        y = WINDOW_HEIGHT / 2 - BALL_SIZE / 2,
        width = BALL_SIZE,
        height = BALL_SIZE,
        dx = 0,
        dy = 0,
        speed = BALL_SPEED,
    }
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
                if math.abs(ly) > 0.5 then
                    serveP1Ready = true
                end
                if math.abs(ry) > 0.5 then
                    serveP2Ready = true
                end
                if serveP1Ready and serveP2Ready then
                    startCountdown()
                end
            end
        end
        return
    end

    if state == "gameover" then return end

    speedTimer = speedTimer + dt
    if speedTimer >= SPEED_INCREASE_INTERVAL then
        speedTimer = 0
        ball.speed = math.min(ball.speed + SPEED_INCREASE_AMOUNT, MAX_BALL_SPEED)
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

    paddle1.y = paddle1.y + paddle1.dy * dt
    paddle1.y = clamp(paddle1.y, 0, WINDOW_HEIGHT - paddle1.height)
end

function updatePaddle2(dt)
    if mode == "singleplayer" then
        updateAI(dt)
    else
        if input.isP2Up() then
            paddle2.dy = -paddle2.speed
        elseif input.isP2Down() then
            paddle2.dy = paddle2.speed
        else
            paddle2.dy = 0
        end
    end

    paddle2.y = paddle2.y + paddle2.dy * dt
    paddle2.y = clamp(paddle2.y, 0, WINDOW_HEIGHT - paddle2.height)
end

function updateAI(dt)
    local ballComingTowardAI = ball.dx > 0

    if not ballComingTowardAI then
        aiReactionTimer = 0
        if difficulty == "easy" then
            moveTowardCenter(dt, 0.3)
        else
            moveTowardCenter(dt, 0.5)
        end
        return
    end

    if difficulty == "easy" then
        aiReactionTimer = aiReactionTimer + dt
        local reactionTime = 0.4
        if aiReactionTimer < reactionTime then
            paddle2.dy = 0
            return
        end
        local ballY = ball.y + ball.height / 2
        local targetY = ballY + (math.random() - 0.5) * paddle2.height * 0.8
        local diff = targetY - (paddle2.y + paddle2.height / 2)
        local moveSpeed = paddle2.speed * 0.4
        if math.abs(diff) > paddle2.height * 0.3 then
            paddle2.dy = (diff > 0 and 1 or -1) * moveSpeed
        else
            paddle2.dy = 0
        end
    elseif difficulty == "medium" then
        if aiReactionTimer == 0 then
            aiTargetOffset = (math.random() * 2 - 1) * 0.45
        end
        aiReactionTimer = 1
        local predictedY = predictBallArrival()
        if predictedY then
            local offset = aiTargetOffset
            local targetPaddleY = predictedY - (paddle2.height / 2) * (offset + 1)
            local diff = targetPaddleY - paddle2.y
            local moveSpeed = paddle2.speed * 0.7
            if math.abs(diff) > 8 then
                paddle2.dy = clamp(diff / 40, -1, 1) * moveSpeed
            else
                paddle2.dy = 0
            end
        end
    else
        if aiReactionTimer == 0 then
            aiTargetOffset = (math.random() > 0.5 and 0.7 or -0.7)
        end
        aiReactionTimer = 1
        local predictedY = predictBallArrival()
        if predictedY then
            local offset = calculateAimOffset()
            local targetPaddleY = predictedY - (paddle2.height / 2) * (offset + 1)
            local diff = targetPaddleY - paddle2.y
            local moveSpeed = paddle2.speed * 0.95
            if math.abs(diff) > 4 then
                paddle2.dy = clamp(diff / 25, -1, 1) * moveSpeed
            else
                paddle2.dy = 0
            end
        end
    end
end

function moveTowardCenter(dt, speedMult)
    local center = WINDOW_HEIGHT / 2 - paddle2.height / 2
    local diff = center - paddle2.y
    if math.abs(diff) > 20 then
        paddle2.dy = (diff > 0 and 1 or -1) * paddle2.speed * speedMult
    else
        paddle2.dy = 0
    end
end

function predictBallArrival()
    if ball.dx <= 0 then return nil end
    local time = (paddle2.x - ball.x) / ball.dx
    if time <= 0 then return nil end
    local y = ball.y + ball.height / 2 + ball.dy * time
    local arenaH = WINDOW_HEIGHT
    if y < 0 then y = -y end
    if y > arenaH then
        local bounces = math.floor(y / arenaH)
        if bounces % 2 == 0 then
            y = y % arenaH
        else
            y = arenaH - (y % arenaH)
        end
    end
    return y
end

function calculateAimOffset()
    local playerVel = paddle1.dy
    if math.abs(playerVel) > 30 then
        if playerVel < 0 then
            return 0.6
        else
            return -0.6
        end
    else
        if math.random() < 0.3 then
            aiTargetOffset = (math.random() > 0.5 and 0.8 or -0.8) * (0.7 + math.random() * 0.3)
        end
        return aiTargetOffset
    end
end

function updateBall(dt)
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
    elseif ball.y + ball.height >= WINDOW_HEIGHT then
        ball.y = WINDOW_HEIGHT - ball.height
        ball.dy = -ball.dy
    end

    if ball.dx < 0 then
        if checkCollision(ball, paddle1) then
            ball.x = paddle1.x + paddle1.width
            reflectBall(paddle1)
        end
    else
        if checkCollision(ball, paddle2) then
            ball.x = paddle2.x - ball.width
            reflectBall(paddle2)
        end
    end

    if ball.x + ball.width < 0 then
        paddle2.score = paddle2.score + 1
        checkWin()
    elseif ball.x > WINDOW_WIDTH then
        paddle1.score = paddle1.score + 1
        checkWin()
    end
end

function checkCollision(a, b)
    return a.x < b.x + b.width and a.x + a.width > b.x and a.y < b.y + b.height and a.y + a.height > b.y
end

function reflectBall(paddle)
    local ballCenter = ball.y + ball.height / 2
    local paddleCenter = paddle.y + paddle.height / 2
    local offset = (ballCenter - paddleCenter) / (paddle.height / 2)
    offset = clamp(offset, -1, 1)

    local maxAngle = math.rad(65)
    local angle = offset * maxAngle

    ball.speed = math.min(ball.speed * BALL_SPEED_INCREASE, MAX_BALL_SPEED)

    local dir = 1
    if paddle == paddle2 then dir = -1 end

    ball.dx = dir * math.cos(angle) * ball.speed
    ball.dy = math.sin(angle) * ball.speed
end

function startCountdown()
    servePhase = "countdown"
    serveTimer = 3.0
end

function serveBall()
    ball.x = WINDOW_WIDTH / 2 - BALL_SIZE / 2
    ball.y = WINDOW_HEIGHT / 2 - BALL_SIZE / 2
    ball.speed = BALL_SPEED * (settingsData.ballSpeed or 1.0)

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
        resetPositions()
        state = "serve"
        servePhase = "waiting"
        serveP1Ready = false
        serveP2Ready = false
        serveTimer = serveDelay
    end
end

function resetPositions()
    paddle1.y = WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2
    paddle2.y = WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2
    ball.x = WINDOW_WIDTH / 2 - BALL_SIZE / 2
    ball.y = WINDOW_HEIGHT / 2 - BALL_SIZE / 2
    ball.dx = 0
    ball.dy = 0
end

function game.draw()
    love.graphics.setBackgroundColor(0, 0, 0)

    local sc = colors.get(settingsData.selectedColor or "yellow")
    local p1c = colors.get(settingsData.paddle1Color or "white")
    local p2c = colors.get(settingsData.paddle2Color or "white")
    local bc = colors.get(settingsData.ballColor or "white")
    local sc = colors.get(settingsData.scoreColor or "white")

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("line", 2, 2, WINDOW_WIDTH - 4, WINDOW_HEIGHT - 4)

    love.graphics.setColor(sc[1], sc[2], sc[3])
    love.graphics.setFont(scoreFont)
    local p1Text = tostring(paddle1.score)
    local p2Text = tostring(paddle2.score)
    love.graphics.print(p1Text, WINDOW_WIDTH / 2 - 100 - scoreFont:getWidth(p1Text) / 2, 30)
    love.graphics.print(p2Text, WINDOW_WIDTH / 2 + 100 - scoreFont:getWidth(p2Text) / 2, 30)

    love.graphics.setColor(0.4, 0.4, 0.4)
    for i = 0, WINDOW_HEIGHT, 25 do
        love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, i, 4, 12)
    end

    love.graphics.setColor(p1c[1], p1c[2], p1c[3])
    love.graphics.rectangle("fill", paddle1.x, paddle1.y, paddle1.width, paddle1.height)

    love.graphics.setColor(p2c[1], p2c[2], p2c[3])
    love.graphics.rectangle("fill", paddle2.x, paddle2.y, paddle2.width, paddle2.height)

    love.graphics.setColor(bc[1], bc[2], bc[3])
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
                love.graphics.setColor(sc[1], sc[2], sc[3])
                love.graphics.print(tostring(cd), (WINDOW_WIDTH - scoreFont:getWidth(tostring(cd))) / 2, WINDOW_HEIGHT / 2 + 10)
            end
        end
    end

    if state == "gameover" then
        love.graphics.setFont(messageFont)
        love.graphics.setColor(sc[1], sc[2], sc[3])
        local winner = "Player 1 Wins!"
        if paddle2.score > paddle1.score then
            if mode == "singleplayer" then
                winner = "AI Wins!"
            else
                winner = "Player 2 Wins!"
            end
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
        love.graphics.setColor(sc[1], sc[2], sc[3])
        local msg = "PAUSED"
        love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 - 80)

        for i, item in ipairs(pauseItems) do
            local y = WINDOW_HEIGHT / 2 - 20 + (i - 1) * 50
            if i == pauseSelection then
                love.graphics.setColor(sc[1], sc[2], sc[3])
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
        if key == "up" then
            pauseSelection = math.max(1, pauseSelection - 1)
        elseif key == "down" then
            pauseSelection = math.min(#pauseItems, pauseSelection + 1)
        elseif key == "return" or key == " " then
            if pauseSelection == 1 then
                paused = false
            else
                backToMenu()
            end
        elseif key == "escape" then
            paused = false
        end
        return
    end

    if state == "serve" and servePhase == "waiting" then
        if mode == "singleplayer" then
            startCountdown()
        else
            if key == "w" or key == "s" then
                serveP1Ready = true
            elseif key == "up" or key == "down" then
                serveP2Ready = true
            end
            if serveP1Ready and serveP2Ready then
                startCountdown()
            end
        end
        return
    end

    if key == "escape" then
        if state == "gameover" then
            backToMenu()
        elseif state ~= "serve" then
            paused = true
            pauseSelection = 1
        end
        return
    end

    if state == "gameover" and (key == "return" or key == " ") then
        backToMenu()
    end
end

function game.gamepadpressed(joystick, button)
    if paused then
        if button == "dpup" then
            pauseSelection = math.max(1, pauseSelection - 1)
        elseif button == "dpdown" then
            pauseSelection = math.min(#pauseItems, pauseSelection + 1)
        elseif button == "a" then
            if pauseSelection == 1 then
                paused = false
            else
                backToMenu()
            end
        elseif button == "b" or button == "start" then
            paused = false
        end
        return
    end

    if state == "serve" and servePhase == "waiting" then
        if mode == "singleplayer" then
            startCountdown()
        else
            local jsticks = love.joystick.getJoysticks()
            if settingsData.splitController and #jsticks >= 1 then
                if isSplitP1Ready(joystick, button) then
                    serveP1Ready = true
                end
                if isSplitP2Ready(joystick, button) then
                    serveP2Ready = true
                end
            else
                if joystick == jsticks[1] or #jsticks == 1 then
                    serveP1Ready = true
                elseif joystick == jsticks[2] then
                    serveP2Ready = true
                end
            end
            if serveP1Ready and serveP2Ready then
                startCountdown()
            end
        end
        return
    end

    if button == "start" then
        if state == "gameover" then
            backToMenu()
        elseif state ~= "serve" then
            paused = true
            pauseSelection = 1
        end
        return
    end

    if state == "gameover" and button == "a" then
        backToMenu()
    end
end

function isSplitP1Ready(joystick, button)
    return button == "dpup" or button == "dpdown"
end

function isSplitP2Ready(joystick, button)
    return button == "y" or button == "a"
end

function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

return game
