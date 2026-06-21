local entities = require("src.game.entities")

local ai = {}

function ai.reset()
end

function ai.update(paddle, ball, difficulty, dt, arenaH, playerDy, isLeft)
    if not paddle.aiState then
        paddle.aiState = {reactionTimer = 0}
    end
    local st = paddle.aiState

    if st.lastDifficulty ~= difficulty then
        st.reactionTimer = 0
        st.fixedTargetY = nil
        st.targetOffset = nil
        st.lastDifficulty = difficulty
    end

    local coming
    if isLeft then
        coming = ball.dx < 0
    else
        coming = ball.dx > 0
    end

    if not coming then
        st.reactionTimer = 0
        st.fixedTargetY = nil
        st.sendStraight = math.random() < 0.15
        if difficulty ~= "god" then
            local mult = difficulty == "hard" and 0.5 or 0.45
            moveTowardCenter(paddle, arenaH, mult)
        else
            paddle.dy = 0
        end
        return
    end

    if difficulty == "easy" then
        local speedFactor = math.min((ball.speed - entities.BALL_SPEED) / 5000, 1)
        speedFactor = entities.clamp(speedFactor, 0, 1)

        if st.reactionTimer == 0 then
            if st.sendStraight then
                st.fixedTargetY = 0
            else
                local offsetRange = paddle.height * (0.15 + speedFactor * 0.4)
                st.fixedTargetY = (math.random() - 0.5) * offsetRange
            end
            st.moveSpeed = paddle.speed * 1.0
            st.deadZonePx = paddle.height * (0.05 + speedFactor * 0.35)
        end

        st.reactionTimer = st.reactionTimer + dt
        local reactDelay = 0.05 + speedFactor * 0.25
        if st.reactionTimer < reactDelay then
            paddle.dy = 0
            return
        end

        local ballY = ball.y + ball.height / 2
        local targetY = ballY + st.fixedTargetY
        local diff = targetY - (paddle.y + paddle.height / 2)
        if math.abs(diff) > st.deadZonePx then
            paddle.dy = entities.clamp(diff / math.max(st.deadZonePx, 1), -1, 1) * st.moveSpeed
        else
            paddle.dy = 0
        end
    elseif difficulty == "medium" then
        if st.reactionTimer == 0 then
            if st.sendStraight then
                st.fixedTargetY = 0
            else
                st.fixedTargetY = (math.random() - 0.5) * paddle.height * 0.2
            end
            st.moveSpeed = paddle.speed * 1.2
            st.deadZonePx = paddle.height * 0.08
        end
        st.reactionTimer = 1

        local ballY = ball.y + ball.height / 2
        local targetY = ballY + st.fixedTargetY
        local diff = targetY - (paddle.y + paddle.height / 2)
        if math.abs(diff) > st.deadZonePx then
            paddle.dy = entities.clamp(diff / 20, -1, 1) * st.moveSpeed
        else
            paddle.dy = 0
        end
    elseif difficulty == "hard" then
        if st.reactionTimer == 0 then
            if st.sendStraight then
                st.targetOffset = 0
            elseif math.abs(playerDy) > 30 then
                st.targetOffset = playerDy < 0 and 0.6 or -0.6
            else
                st.targetOffset = (math.random() > 0.5 and 0.7 or -0.7)
            end
            st.fixedTargetY = nil
            st.moveSpeed = paddle.speed * 1.5
            st.deadZonePx = 10
        end
        st.reactionTimer = 1

        local predictedY = predictBallArrival(ball, paddle.x, arenaH, isLeft)
        if predictedY then
            local rawTarget = predictedY - (paddle.height / 2) * (st.targetOffset + 1)
            if st.fixedTargetY == nil then
                st.fixedTargetY = rawTarget
            else
                st.fixedTargetY = st.fixedTargetY + (rawTarget - st.fixedTargetY) * math.min(1, dt * 15)
            end
            local diff = st.fixedTargetY - paddle.y
            if math.abs(diff) > st.deadZonePx then
                paddle.dy = entities.clamp(diff / 25, -1, 1) * st.moveSpeed
            else
                paddle.dy = 0
            end
        end
    else
        if st.reactionTimer == 0 then
            if st.sendStraight then
                st.aimDir = 0
            elseif math.abs(playerDy) > 30 then
                st.aimDir = playerDy < 0 and 1 or -1
            else
                st.aimDir = math.random() > 0.5 and 1 or -1
            end
        end
        st.reactionTimer = 1

        local predictedY = predictBallArrival(ball, paddle.x, arenaH, isLeft)
        if predictedY then
            paddle.y = predictedY - st.aimDir * (paddle.height / 2) - paddle.height / 2
        end
        paddle.dy = 0
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

function predictBallArrival(ball, paddleX, arenaH, isLeft)
    if isLeft then
        if ball.dx >= 0 then return nil end
    else
        if ball.dx <= 0 then return nil end
    end
    local time = (paddleX - ball.x) / ball.dx
    if time <= 0 then return nil end
    local halfBall = ball.height / 2
    local range = arenaH - ball.height
    local y = ball.y + halfBall + ball.dy * time
    y = y - halfBall
    if y < 0 then y = -y end
    if y > range then
        local bounces = math.floor(y / range)
        local rem = y % range
        if bounces % 2 == 0 then
            y = rem
        else
            y = range - rem
        end
    end
    y = y + halfBall
    return y
end

return ai
