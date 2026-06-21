local entities = {}

local ARENA_WIDTH = 1280
local ARENA_HEIGHT = 720

entities.PADDLE_WIDTH = 15
entities.PADDLE_HEIGHT = 100
entities.PADDLE_SPEED = 400
entities.PADDLE_OFFSET = 50
entities.BALL_SIZE = 15
entities.BALL_SPEED = 350
entities.BALL_SPEED_INCREASE = 1.02
entities.SPEED_INCREASE_INTERVAL = 5
entities.SPEED_INCREASE_AMOUNT = 15

function entities.newPaddle(x, y, speedMult)
    return {
        x = x,
        y = y,
        width = entities.PADDLE_WIDTH,
        height = entities.PADDLE_HEIGHT,
        speed = entities.PADDLE_SPEED * speedMult,
        score = 0,
        dy = 0,
        dead = false,
        minAngle = math.rad(0),
        maxAngle = math.rad(65),
    }
end

function entities.newBall()
    return {
    x = ARENA_WIDTH / 2 - entities.BALL_SIZE / 2,
    y = ARENA_HEIGHT / 2 - entities.BALL_SIZE / 2,
        width = entities.BALL_SIZE,
        height = entities.BALL_SIZE,
        dx = 0,
        dy = 0,
        speed = entities.BALL_SPEED,
    }
end

function entities.resetPositions(p1, p2, ball, arenaW, arenaH)
    p1.y = arenaH / 2 - entities.PADDLE_HEIGHT / 2
    p2.y = arenaH / 2 - entities.PADDLE_HEIGHT / 2
    ball.x = arenaW / 2 - entities.BALL_SIZE / 2
    ball.y = arenaH / 2 - entities.BALL_SIZE / 2
    ball.dx = 0
    ball.dy = 0
end

function entities.movePaddle(paddle, dt, arenaH)
    paddle.y = paddle.y + paddle.dy * dt
    paddle.y = entities.clamp(paddle.y, 0, arenaH - paddle.height)
end

function entities.updateBall(ball, p1, p2, dt, arenaW, arenaH)
    local prevX = ball.x
    local prevY = ball.y
    ball.x = ball.x + ball.dx * dt
    ball.y = ball.y + ball.dy * dt

    local wallHit = false
    if ball.y <= 0 then
        ball.y = 0
        ball.dy = -ball.dy
        wallHit = true
        local newSpeed = math.min(entities.MAX_BALL_SPEED, ball.speed * entities.BALL_SPEED_INCREASE)
        local factor = newSpeed / ball.speed
        ball.speed = newSpeed
        ball.dx = ball.dx * factor
        ball.dy = ball.dy * factor
    elseif ball.y + ball.height >= arenaH then
        ball.y = arenaH - ball.height
        ball.dy = -ball.dy
        wallHit = true
        local newSpeed = math.min(entities.MAX_BALL_SPEED, ball.speed * entities.BALL_SPEED_INCREASE)
        local factor = newSpeed / ball.speed
        ball.speed = newSpeed
        ball.dx = ball.dx * factor
        ball.dy = ball.dy * factor
    end

    local hitP2 = false
    local hitP1 = false
    if ball.dx < 0 then
        if entities.checkCollision(ball, p1) then
            ball.x = p1.x + p1.width
            entities.reflectBall(ball, p1, 1)
            hitP1 = true
        elseif prevX > p1.x + p1.width and ball.x < p1.x + p1.width then
            local ballY1 = math.min(prevY, ball.y)
            local ballY2 = math.max(prevY + ball.height, ball.y + ball.height)
            if ballY1 < p1.y + p1.height and ballY2 > p1.y then
                ball.x = p1.x + p1.width
                entities.reflectBall(ball, p1, 1)
                hitP1 = true
            end
        end
    else
        if not p2.dead and entities.checkCollision(ball, p2) then
            ball.x = p2.x - ball.width
            entities.reflectBall(ball, p2, -1)
            hitP2 = true
        elseif not p2.dead and prevX + ball.width < p2.x and ball.x + ball.width > p2.x then
            local ballY1 = math.min(prevY, ball.y)
            local ballY2 = math.max(prevY + ball.height, ball.y + ball.height)
            if ballY1 < p2.y + p2.height and ballY2 > p2.y then
                ball.x = p2.x - ball.width
                entities.reflectBall(ball, p2, -1)
                hitP2 = true
            end
        end
    end

    if ball.x + ball.width < 0 then
        return "right_score", hitP2, hitP1, wallHit
    elseif ball.x > arenaW then
        return "left_score", hitP2, hitP1, wallHit
    end
    return nil, hitP2, hitP1, wallHit
end

function entities.checkCollision(a, b)
    return a.x < b.x + b.width and a.x + a.width > b.x and a.y < b.y + b.height and a.y + a.height > b.y
end

function entities.reflectBall(ball, paddle, dir)
    local ballCenter = ball.y + ball.height / 2
    local paddleCenter = paddle.y + paddle.height / 2
    local offset = (ballCenter - paddleCenter) / (paddle.height / 2)
    offset = entities.clamp(offset, -1, 1)

    local angle = (paddle.minAngle + math.abs(offset) * (paddle.maxAngle - paddle.minAngle)) * (offset >= 0 and 1 or -1)
    angle = angle + math.rad(math.random(-3, 3))
    ball.speed = math.min(entities.MAX_BALL_SPEED, ball.speed * entities.BALL_SPEED_INCREASE)

    ball.dx = dir * math.cos(angle) * ball.speed
    ball.dy = math.sin(angle) * ball.speed
end

function entities.setAngleRange(paddle, diff)
    local angles = {
        god    = 75,
        hard   = 65,
        medium = 55,
        easy   = 45,
    }
    paddle.minAngle = math.rad(0)
    paddle.maxAngle = math.rad(angles[diff] or 65)
end

function entities.clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

return entities
