local input = require("input")

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
local MAX_BALL_SPEED = 800

local WINNING_SCORE = 7

local mode = nil
local difficulty = nil
local settingsData = {}

local paddle1 = {}
local paddle2 = {}

local ball = {}

local state = nil
local serveTimer = 0
local serveDelay = 1.0
local paused = false
local pauseSelection = 1
local pauseItems = {"Resume", "Quit to Menu"}

local scoreFont = nil
local messageFont = nil

function game.enter(m, d, sd)
    mode = m
    difficulty = d
    settingsData = sd or {}
    WINNING_SCORE = settingsData.winningScore or 7

    local ps = settingsData.paddleSpeed or 1.0

    paddle1 = newPaddle(PADDLE_OFFSET, WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2, ps)
    if mode == "singleplayer" then
        local aiSpeed = ps
        if difficulty == "easy" then aiSpeed = aiSpeed * 0.5 end
        paddle2 = newPaddle(WINDOW_WIDTH - PADDLE_OFFSET - PADDLE_WIDTH, WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2, aiSpeed)
    else
        paddle2 = newPaddle(WINDOW_WIDTH - PADDLE_OFFSET - PADDLE_WIDTH, WINDOW_HEIGHT / 2 - PADDLE_HEIGHT / 2, ps)
    end

    ball = newBall()
    state = "serve"
    serveTimer = serveDelay
    paused = false
    pauseSelection = 1

    scoreFont = love.graphics.newFont(48)
    messageFont = love.graphics.newFont(36)
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
    if paused then return end

    if state == "serve" then
        serveTimer = serveTimer - dt
        if serveTimer <= 0 then
            serveBall()
        end
        return
    end

    if state == "gameover" then return end

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
    local reactionDelay, accuracy, speedMult

    if difficulty == "easy" then
        reactionDelay = 0.3
        accuracy = 0.65
        speedMult = 0.5
    elseif difficulty == "hard" then
        reactionDelay = 0.05
        accuracy = 0.95
        speedMult = 0.95
    else
        reactionDelay = 0.15
        accuracy = 0.8
        speedMult = 0.75
    end

    local paddleCenter = paddle2.y + paddle2.height / 2
    local ballCenter = ball.y + ball.height / 2
    local diff = ballCenter - paddleCenter

    if math.abs(diff) > paddle2.height * (1 - accuracy) then
        local target = paddle2.y + diff * accuracy
        local moveSpeed = paddle2.speed * speedMult
        if target < paddle2.y then
            paddle2.dy = -moveSpeed
        elseif target > paddle2.y then
            paddle2.dy = moveSpeed
        else
            paddle2.dy = 0
        end
    else
        paddle2.dy = 0
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
            ball.dx = -ball.dx
            ball.dy = calculateReflection(ball, paddle1)
            ball.speed = math.min(ball.speed * BALL_SPEED_INCREASE, MAX_BALL_SPEED)
            normalizeBallSpeed()
        end
    else
        if checkCollision(ball, paddle2) then
            ball.x = paddle2.x - ball.width
            ball.dx = -ball.dx
            ball.dy = calculateReflection(ball, paddle2)
            ball.speed = math.min(ball.speed * BALL_SPEED_INCREASE, MAX_BALL_SPEED)
            normalizeBallSpeed()
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

function calculateReflection(ballObj, paddle)
    local ballCenter = ballObj.y + ballObj.height / 2
    local paddleCenter = paddle.y + paddle.height / 2
    local offset = (ballCenter - paddleCenter) / (paddle.height / 2)
    offset = clamp(offset, -1, 1)
    return offset * 200
end

function normalizeBallSpeed()
    local currentSpeed = math.sqrt(ball.dx * ball.dx + ball.dy * ball.dy)
    if currentSpeed > 0 then
        local ratio = ball.speed / currentSpeed
        ball.dx = ball.dx * ratio
        ball.dy = ball.dy * ratio
    end
end

function serveBall()
    ball.x = WINDOW_WIDTH / 2 - BALL_SIZE / 2
    ball.y = WINDOW_HEIGHT / 2 - BALL_SIZE / 2
    ball.speed = BALL_SPEED * (settingsData.ballSpeed or 1.0)

    local angle = math.rad(math.random(-45, 45))
    local dir = 1
    if math.random() < 0.5 then dir = -1 end

    ball.dx = math.cos(angle) * ball.speed * dir
    ball.dy = math.sin(angle) * ball.speed

    state = "playing"
end

function checkWin()
    if paddle1.score >= WINNING_SCORE or paddle2.score >= WINNING_SCORE then
        state = "gameover"
    else
        state = "serve"
        serveTimer = serveDelay
    end
end

function game.draw()
    love.graphics.setBackgroundColor(0, 0, 0)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(scoreFont)
    local p1Text = tostring(paddle1.score)
    local p2Text = tostring(paddle2.score)
    love.graphics.print(p1Text, WINDOW_WIDTH / 2 - 100 - scoreFont:getWidth(p1Text) / 2, 30)
    love.graphics.print(p2Text, WINDOW_WIDTH / 2 + 100 - scoreFont:getWidth(p2Text) / 2, 30)

    love.graphics.setColor(0.5, 0.5, 0.5)
    for i = 0, WINDOW_HEIGHT, 20 do
        love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, i, 4, 10)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", paddle1.x, paddle1.y, paddle1.width, paddle1.height)
    love.graphics.rectangle("fill", paddle2.x, paddle2.y, paddle2.width, paddle2.height)
    love.graphics.rectangle("fill", ball.x, ball.y, ball.width, ball.height)

    if state == "serve" then
        love.graphics.setFont(messageFont)
        love.graphics.setColor(1, 1, 1)
        local msg = "Press any key or button to serve..."
        love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 + 50)
    end

    if state == "gameover" then
        love.graphics.setFont(messageFont)
        love.graphics.setColor(1, 1, 0)
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
        love.graphics.setColor(1, 1, 0)
        local msg = "PAUSED"
        love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 - 80)

        for i, item in ipairs(pauseItems) do
            local y = WINDOW_HEIGHT / 2 - 20 + (i - 1) * 50
            if i == pauseSelection then
                love.graphics.setColor(1, 1, 0)
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

    if key == "escape" then
        if state == "gameover" then
            backToMenu()
        else
            paused = true
            pauseSelection = 1
        end
        return
    end

    if state == "serve" then
        serveTimer = 0
    end

    if state == "gameover" and (key == "return" or key == " ") then
        backToMenu()
    end
end

function game.gamepadpressed(joystick, button)
    if paused then
        if button == "dpup" or button == "leftstickup" then
            pauseSelection = math.max(1, pauseSelection - 1)
        elseif button == "dpdown" or button == "leftstickdown" then
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

    if button == "start" then
        if state == "gameover" then
            backToMenu()
        else
            paused = true
            pauseSelection = 1
        end
        return
    end

    if state == "serve" then
        serveTimer = 0
    end

    if state == "gameover" and button == "a" then
        backToMenu()
    end
end

function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

return game
