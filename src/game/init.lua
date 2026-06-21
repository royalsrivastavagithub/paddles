local input = require("src.input")
local entities = require("src.game.entities")
local ai = require("src.game.ai")
local sound = require("src.sound")

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
local godLosePhase = nil
local godLoseTimer = 0
local totalLives = 0
local remainingLives = 0
local aiDiff1 = nil
local aiDiff2 = nil

local ballTrail = {}
local paddle1Trail = {}
local paddle2Trail = {}

local function getTrailLen()
    local v = settingsData.trail
    if type(v) == "boolean" then return v and 6 or 0 end
    return v or 0
end

local function pushTrail(trail, x, y, w, h)
    local maxLen = getTrailLen()
    if maxLen == 0 then return end
    table.insert(trail, 1, {x = x, y = y, w = w, h = h})
    while #trail > maxLen do table.remove(trail) end
end

local function resetTrails()
    for _, t in ipairs({ballTrail, paddle1Trail, paddle2Trail}) do
        for i = #t, 1, -1 do table.remove(t) end
    end
end

function game.enter(m, d, sd)
    mode = m
    difficulty = d
    settingsData = sd or {}
    WINNING_SCORE = settingsData.winningScore or 7

    local p1s = settingsData.p1Sensitivity or 1.0
    local p2s = settingsData.p2Sensitivity or 1.0

    if mode == "singleplayer" then
        p2s = 1.0
    elseif mode == "aivsai" then
        p1s = 1.0
        p2s = 1.0
    end

    entities.MAX_BALL_SPEED = settingsData.maxBallSpeed or 1200

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
    godLosePhase = nil
    godLoseTimer = 0
    totalLives = settingsData.paddleLives or 0
    remainingLives = totalLives
    aiDiff1 = nil
    aiDiff2 = nil
    ai.reset()
    resetTrails()

    if mode == "singleplayer" then
        entities.setAngleRange(paddle2, difficulty)
    elseif mode == "aivsai" then
        aiDiff1 = d.p1 or "easy"
        aiDiff2 = d.p2 or "easy"
        entities.setAngleRange(paddle1, aiDiff1)
        entities.setAngleRange(paddle2, aiDiff2)
        serveBall()
    end

    local us = settingsData.uiScale or 1.0
    scoreFont = love.graphics.newFont("assets/fonts/font.ttf", math.floor(48 * us))
    messageFont = love.graphics.newFont("assets/fonts/font.ttf", math.floor(36 * us))
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
                    local old = pauseSelection
                    pauseSelection = math.max(1, pauseSelection - 1)
                    if pauseSelection ~= old then sound.playHighlight() end
                    pauseStickTimer = 0.2
                elseif y > 0.5 then
                    local old = pauseSelection
                    pauseSelection = math.min(#pauseItems, pauseSelection + 1)
                    if pauseSelection ~= old then sound.playHighlight() end
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

    if state == "gameover" then
        if godLosePhase then
            godLoseTimer = godLoseTimer - dt
            if godLoseTimer <= 0 then
                if godLosePhase == 1 then
                    godLosePhase = 2
                    godLoseTimer = 3
                elseif godLosePhase == 2 then
                    godLosePhase = 3
                    godLoseTimer = 3
                else
                    love.event.quit()
                end
            end
        end
        return
    end

    speedTimer = speedTimer + dt
    if speedTimer >= entities.SPEED_INCREASE_INTERVAL then
        speedTimer = 0
        ball.speed = math.min(entities.MAX_BALL_SPEED, ball.speed + entities.SPEED_INCREASE_AMOUNT)
    end

    updatePaddle1(dt)
    updatePaddle2(dt)
    updateBall(dt)

    local trailLen = getTrailLen()
    if trailLen > 0 then
        pushTrail(paddle1Trail, paddle1.x, paddle1.y, paddle1.width, paddle1.height)
        pushTrail(paddle2Trail, paddle2.x, paddle2.y, paddle2.width, paddle2.height)
        pushTrail(ballTrail, ball.x, ball.y, ball.width, ball.height)
    end
end

function updatePaddle1(dt)
    if mode == "aivsai" then
        ai.update(paddle1, ball, aiDiff1 or "easy", dt, WINDOW_HEIGHT, paddle2.dy, true)
    elseif settingsData.mouseControl then
        local screenW, screenH = love.graphics.getDimensions()
        local scale = math.min(screenW / 1280, screenH / 720)
        local offsetY = (screenH - 720 * scale) / 2
        local mouseY = (love.mouse.getY() - offsetY) / scale
        paddle1.y = entities.clamp(mouseY - paddle1.height / 2, 0, WINDOW_HEIGHT - paddle1.height)
        paddle1.dy = 0
    elseif input.isP1Up() then
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
        ai.update(paddle2, ball, difficulty, dt, WINDOW_HEIGHT, paddle1.dy, false)
    elseif mode == "aivsai" then
        ai.update(paddle2, ball, aiDiff2 or "easy", dt, WINDOW_HEIGHT, paddle1.dy, false)
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
    local result, hitP2, hitP1, wallHit = entities.updateBall(ball, paddle1, paddle2, dt, WINDOW_WIDTH, WINDOW_HEIGHT)

    if hitP1 then sound.playPaddle1(); sound.playBallBounce() end
    if hitP2 then sound.playPaddle2(); sound.playBallBounce() end
    if wallHit then sound.playBallBounce() end

    if result == "right_score" then
        paddle2.score = paddle2.score + 1
        sound.playScore()
        if mode == "singleplayer" and difficulty == "god" and totalLives > 0 then
            remainingLives = totalLives
        end
        checkWin()
    elseif result == "left_score" then
        paddle1.score = paddle1.score + 1
        sound.playScore()
        checkWin()
    end

    if mode == "singleplayer" and difficulty == "god" and totalLives > 0 and hitP1 and remainingLives > 0 then
        remainingLives = remainingLives - 1
        if remainingLives <= 0 then
            startPaddleDeath()
        end
    end
end

function startPaddleDeath()
    state = "gameover"
    sound.playLose()
    godLosePhase = 1
    godLoseTimer = 3
end

function startGodLose()
    godLosePhase = 1
    godLoseTimer = 3
end

function startCountdown()
    servePhase = "countdown"
    serveTimer = 3.0
end

function serveBall()
    resetTrails()
    ball.x = WINDOW_WIDTH / 2 - entities.BALL_SIZE / 2
    ball.y = WINDOW_HEIGHT / 2 - entities.BALL_SIZE / 2
    local mult = settingsData.ballSpeed
    if type(mult) == "string" then
        local speedMap = {Slow = 0.5, Normal = 1.0, Fast = 2.0}
        mult = speedMap[mult] or 1.0
    end
    ball.speed = entities.BALL_SPEED * (mult or 1.0)

    local dir = -1
    if paddle1.score + paddle2.score == 0 then
        if math.random() < 0.5 then dir = 1 end
    elseif paddle2.score > paddle1.score then
        dir = 1
    end

    ball.dx = dir * ball.speed
    ball.dy = 0
    state = "playing"
end

function checkWin()
    if WINNING_SCORE > 0 and (paddle1.score >= WINNING_SCORE or paddle2.score >= WINNING_SCORE) then
        state = "gameover"
        if mode == "singleplayer" then
            if paddle2.score > paddle1.score then
                sound.playLose()
            else
                sound.playWin()
            end
        else
            sound.playWin()
        end
    else
        entities.resetPositions(paddle1, paddle2, ball, WINDOW_WIDTH, WINDOW_HEIGHT)
        if remainingLives > 0 then
            paddle2.dead = false
        end
        if mode == "aivsai" then
            serveBall()
        else
            state = "serve"
            servePhase = "waiting"
            serveP1Ready = false
            serveP2Ready = false
            serveTimer = serveDelay
        end
    end
end

function game.draw()
    local sel = settingsData.selectedColor or {r=1, g=1, b=0}
    local p1c = settingsData.paddle1Color or {r=1, g=1, b=1}
    local p2c = settingsData.paddle2Color or {r=1, g=1, b=1}
    local bc = settingsData.ballColor or {r=1, g=1, b=1}
    local sc = settingsData.scoreColor or {r=1, g=1, b=1}

    local bg = settingsData.bgColor or {r=0, g=0, b=0}
    love.graphics.setColor(bg.r, bg.g, bg.b)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    if state == "gameover" and godLosePhase then
        love.graphics.setFont(messageFont)
        love.graphics.setColor(sel.r, sel.g, sel.b)
        local msgs = {"WTF", "no way maan !", "i am out"}
        local msg = msgs[godLosePhase]
        love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 - 50)
        if paused then
            love.graphics.setColor(bg.r, bg.g, bg.b, 180)
            love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
            love.graphics.setFont(messageFont)
            love.graphics.setColor(sel.r, sel.g, sel.b)
            local pmsg = "PAUSED"
            love.graphics.print(pmsg, (WINDOW_WIDTH - messageFont:getWidth(pmsg)) / 2, WINDOW_HEIGHT / 2 - 80)
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
        return
    end

    love.graphics.setFont(scoreFont)
    if difficulty == "god" then
        love.graphics.setColor(sc.r, sc.g, sc.b)
        local p2Text = "EZ: " .. paddle2.score
        love.graphics.print(p2Text, WINDOW_WIDTH / 2 + 100 - scoreFont:getWidth(p2Text) / 2, 30)
        if paddle2.dead then
            local p1Text = tostring(paddle1.score)
            love.graphics.print(p1Text, WINDOW_WIDTH / 2 - 100 - scoreFont:getWidth(p1Text) / 2, 30)
        end
    else
        love.graphics.setColor(sc.r, sc.g, sc.b)
        local p1Text = tostring(paddle1.score)
        local p2Text = tostring(paddle2.score)
        love.graphics.print(p1Text, WINDOW_WIDTH / 2 - 100 - scoreFont:getWidth(p1Text) / 2, 30)
        love.graphics.print(p2Text, WINDOW_WIDTH / 2 + 100 - scoreFont:getWidth(p2Text) / 2, 30)
    end

    if mode == "singleplayer" and difficulty == "god" and totalLives > 0 then
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.setFont(scoreFont)
        local livesText = remainingLives .. "/" .. totalLives
        love.graphics.print(livesText, WINDOW_WIDTH - scoreFont:getWidth(livesText) - 20, 30)
    end

    love.graphics.setColor(0.4, 0.4, 0.4)
    for i = 0, WINDOW_HEIGHT, 25 do
        love.graphics.rectangle("fill", WINDOW_WIDTH / 2 - 2, i, 4, 12)
    end

    local trailLen = getTrailLen()
    if trailLen > 0 then
        for i, t in ipairs(paddle1Trail) do
            local alpha = 1 - (i - 1) / trailLen
            love.graphics.setColor(p1c.r, p1c.g, p1c.b, alpha * 0.3)
            love.graphics.rectangle("fill", t.x, t.y, t.w, t.h)
        end
        if not paddle2.dead then
            for i, t in ipairs(paddle2Trail) do
                local alpha = 1 - (i - 1) / trailLen
                love.graphics.setColor(p2c.r, p2c.g, p2c.b, alpha * 0.3)
                love.graphics.rectangle("fill", t.x, t.y, t.w, t.h)
            end
        end
        for i, t in ipairs(ballTrail) do
            local alpha = 1 - (i - 1) / trailLen
            love.graphics.setColor(bc.r, bc.g, bc.b, alpha * 0.3)
            love.graphics.rectangle("fill", t.x, t.y, t.w, t.h)
        end
    end
    love.graphics.setColor(p1c.r, p1c.g, p1c.b)
    love.graphics.rectangle("fill", paddle1.x, paddle1.y, paddle1.width, paddle1.height)
    if not paddle2.dead then
        love.graphics.setColor(p2c.r, p2c.g, p2c.b)
        love.graphics.rectangle("fill", paddle2.x, paddle2.y, paddle2.width, paddle2.height)
    end
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
        if difficulty == "god" then
            local msg = "Bot Win!"
            love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 - 50)
            local sub = "Press any key to continue"
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(sub, (WINDOW_WIDTH - messageFont:getWidth(sub)) / 2, WINDOW_HEIGHT / 2 + 20)
        else
            local winner = "Player Wins!"
            if paddle2.score > paddle1.score then
                winner = mode == "singleplayer" and "Bot Win" or "Player 2 Wins!"
            end
            love.graphics.print(winner, (WINDOW_WIDTH - messageFont:getWidth(winner)) / 2, WINDOW_HEIGHT / 2 - 50)
            local msg = "Press any key to continue"
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(msg, (WINDOW_WIDTH - messageFont:getWidth(msg)) / 2, WINDOW_HEIGHT / 2 + 20)
        end
    end

    if paused then
        love.graphics.setColor(bg.r, bg.g, bg.b, 180)
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
        if key == "up" then
            local old = pauseSelection
            pauseSelection = math.max(1, pauseSelection - 1)
            if pauseSelection ~= old then sound.playHighlight() end
        elseif key == "down" then
            local old = pauseSelection
            pauseSelection = math.min(#pauseItems, pauseSelection + 1)
            if pauseSelection ~= old then sound.playHighlight() end
        elseif key == "return" or key == " " then
            sound.playEnter()
            if pauseSelection == 1 then paused = false; love.mouse.setVisible(false) else backToMenu() end
        elseif key == "escape" then
            sound.playEscape()
            paused = false; love.mouse.setVisible(false)
        end
        return
    end

    if state == "serve" and servePhase == "waiting" then
        if mode == "singleplayer" then
            if key == "escape" then
                sound.playEscape()
                backToMenu()
                return
            end
            startCountdown()
        else
            if key == "w" or key == "s" then serveP1Ready = true
            elseif key == "up" or key == "down" then serveP2Ready = true end
            if serveP1Ready and serveP2Ready then startCountdown() end
        end
        return
    end

    if state == "gameover" then
        if key == "escape" or key == "return" or key == " " then
            sound.playEscape()
            if difficulty == "god" and paddle1.score > paddle2.score then
                startGodLose()
            else
                backToMenu()
            end
        end
        return
    end

    if key == "escape" then
        if state ~= "serve" then paused = true; pauseSelection = 1; love.mouse.setVisible(true) end
        return
    end
end

function game.gamepadpressed(joystick, button)
    if paused then
        if button == "dpup" then
            local old = pauseSelection
            pauseSelection = math.max(1, pauseSelection - 1)
            if pauseSelection ~= old then sound.playHighlight() end
        elseif button == "dpdown" then
            local old = pauseSelection
            pauseSelection = math.min(#pauseItems, pauseSelection + 1)
            if pauseSelection ~= old then sound.playHighlight() end
        elseif button == "a" then
            sound.playEnter()
            if pauseSelection == 1 then paused = false; love.mouse.setVisible(false) else backToMenu() end
        elseif button == "b" or button == "start" then
            sound.playEscape()
            paused = false; love.mouse.setVisible(false)
        end
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

    if state == "gameover" then
        if button == "start" or button == "a" then
            sound.playEscape()
            if difficulty == "god" and paddle1.score > paddle2.score then
                startGodLose()
            else
                backToMenu()
            end
        end
        return
    end

    if button == "start" and state ~= "serve" then
        paused = true; pauseSelection = 1; love.mouse.setVisible(true)
        return
    end
end

return game
