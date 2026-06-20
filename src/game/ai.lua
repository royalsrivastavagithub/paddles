local entities = require("src.game.entities")

local ai = {}
local reactionTimer = 0
local targetOffset = 0

function ai.reset()
    reactionTimer = 0
    targetOffset = (math.random() * 2 - 1) * 0.4
end

function ai.update(paddle, ball, difficulty, dt, arenaH, playerDy)
    local coming = ball.dx > 0

    if not coming then
        reactionTimer = 0
        local mult = difficulty == "medium" and 0.5 or 0.4
        moveTowardCenter(paddle, arenaH, mult)
        return
    end

    if difficulty == "easy" then
        reactionTimer = reactionTimer + dt
        if reactionTimer < 0.15 then
            paddle.dy = 0
            return
        end
        local ballY = ball.y + ball.height / 2
        local targetY = ballY + (math.random() - 0.5) * paddle.height * 0.35
        local diff = targetY - (paddle.y + paddle.height / 2)
        local moveSpeed = paddle.speed * 0.65
        if math.abs(diff) > paddle.height * 0.12 then
            paddle.dy = (diff > 0 and 1 or -1) * moveSpeed
        else
            paddle.dy = 0
        end
    elseif difficulty == "medium" then
        if reactionTimer == 0 then
            targetOffset = (math.random() * 2 - 1) * 0.45
        end
        reactionTimer = 1
        local predictedY = predictBallArrival(ball, paddle.x, arenaH)
        if predictedY then
            local offset = targetOffset
            local targetPaddleY = predictedY - (paddle.height / 2) * (offset + 1)
            local diff = targetPaddleY - paddle.y
            local moveSpeed = paddle.speed * 0.7
            if math.abs(diff) > 8 then
                paddle.dy = entities.clamp(diff / 40, -1, 1) * moveSpeed
            else
                paddle.dy = 0
            end
        end
    else
        if reactionTimer == 0 then
            targetOffset = (math.random() > 0.5 and 0.7 or -0.7)
        end
        reactionTimer = 1
        local predictedY = predictBallArrival(ball, paddle.x, arenaH)
        if predictedY then
            local offset = calculateAimOffset(playerDy)
            local targetPaddleY = predictedY - (paddle.height / 2) * (offset + 1)
            local diff = targetPaddleY - paddle.y
            local moveSpeed = paddle.speed * 0.95
            if math.abs(diff) > 4 then
                paddle.dy = entities.clamp(diff / 25, -1, 1) * moveSpeed
            else
                paddle.dy = 0
            end
        end
    end
end

function moveTowardCenter(paddle, arenaH, speedMult)
    local center = arenaH / 2 - paddle.height / 2
    local diff = center - paddle.y
    if math.abs(diff) > 20 then
        paddle.dy = (diff > 0 and 1 or -1) * paddle.speed * speedMult
    else
        paddle.dy = 0
    end
end

function predictBallArrival(ball, paddleX, arenaH)
    if ball.dx <= 0 then return nil end
    local time = (paddleX - ball.x) / ball.dx
    if time <= 0 then return nil end
    local y = ball.y + ball.height / 2 + ball.dy * time
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

function calculateAimOffset(playerDy)
    if math.abs(playerDy) > 30 then
        return playerDy < 0 and 0.6 or -0.6
    else
        if math.random() < 0.3 then
            targetOffset = (math.random() > 0.5 and 0.8 or -0.8) * (0.7 + math.random() * 0.3)
        end
        return targetOffset
    end
end

return ai
