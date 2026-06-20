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
        local mult = difficulty == "easy" and 0.4 or 0.5
        moveTowardCenter(paddle, arenaH, mult)
        return
    end

    if difficulty == "easy" then
        local speedFactor = (ball.speed - entities.BALL_SPEED) / (entities.MAX_BALL_SPEED - entities.BALL_SPEED)
        speedFactor = entities.clamp(speedFactor, 0, 1)

        reactionTimer = reactionTimer + dt
        local reactDelay = 0.05 + speedFactor * 0.25
        if reactionTimer < reactDelay then
            paddle.dy = 0
            return
        end

        local ballY = ball.y + ball.height / 2
        local offsetRange = paddle.height * (0.15 + speedFactor * 0.4)
        local targetY = ballY + (math.random() - 0.5) * offsetRange
        local diff = targetY - (paddle.y + paddle.height / 2)
        local moveSpeed = paddle.speed * (0.7 - speedFactor * 0.3)
        local deadZone = paddle.height * (0.05 + speedFactor * 0.35)
        if math.abs(diff) > deadZone then
            paddle.dy = entities.clamp(diff / math.max(deadZone, 1), -1, 1) * moveSpeed
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
            if math.abs(diff) > 12 then
                paddle.dy = entities.clamp(diff / 40, -1, 1) * moveSpeed
            else
                paddle.dy = 0
            end
        end
    else
        if reactionTimer == 0 then
            if math.abs(playerDy) > 30 then
                targetOffset = playerDy < 0 and 0.6 or -0.6
            else
                targetOffset = (math.random() > 0.5 and 0.7 or -0.7)
            end
        end
        reactionTimer = 1
        local predictedY = predictBallArrival(ball, paddle.x, arenaH)
        if predictedY then
            local offset = targetOffset
            local targetPaddleY = predictedY - (paddle.height / 2) * (offset + 1)
            local diff = targetPaddleY - paddle.y
            local moveSpeed = paddle.speed * 0.9
            if math.abs(diff) > 10 then
                paddle.dy = entities.clamp(diff / 30, -1, 1) * moveSpeed
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

return ai
