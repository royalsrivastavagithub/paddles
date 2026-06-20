local input = {}

local gamepads = {}

function input.load()
    gamepads = love.joystick.getJoysticks()
end

function input.refresh()
    gamepads = love.joystick.getJoysticks()
end

function input.anyPressed()
    for _, kb in ipairs({"return", " ", "up", "down", "escape", "w", "s", "a", "d"}) do
        if love.keyboard.isDown(kb) then return true end
    end
    for _, gp in ipairs(gamepads) do
        if gp:isGamepadDown("a", "b", "start", "dpup", "dpdown", "leftstickup", "leftstickdown") then
            return true
        end
    end
    return false
end

function input.isMenuDown(action)
    if action == "up" then
        return love.keyboard.isDown("up") or isAnyGamepadDown("dpup") or isAnyGamepadDown("leftstickup")
    elseif action == "down" then
        return love.keyboard.isDown("down") or isAnyGamepadDown("dpdown") or isAnyGamepadDown("leftstickdown")
    elseif action == "confirm" then
        return love.keyboard.isDown("return") or love.keyboard.isDown(" ") or isAnyGamepadDown("a")
    elseif action == "back" then
        return love.keyboard.isDown("escape") or isAnyGamepadDown("b")
    end
    return false
end

function input.isP1Down()
    return love.keyboard.isDown("w") or isGamepadDown(1, "leftstickup") or isGamepadDown(1, "dpup")
end

function input.isP1Up()
    return love.keyboard.isDown("s") or isGamepadDown(1, "leftstickdown") or isGamepadDown(1, "dpdown")
end

function input.isP2Down()
    return love.keyboard.isDown("down") or isGamepadDown(2, "leftstickup") or isGamepadDown(2, "dpup")
end

function input.isP2Up()
    return love.keyboard.isDown("up") or isGamepadDown(2, "leftstickdown") or isGamepadDown(2, "dpdown")
end

function input.isPause()
    return love.keyboard.isDown("escape") or isAnyGamepadDown("start")
end

function isAnyGamepadDown(button)
    for _, gp in ipairs(gamepads) do
        if gp:isGamepadDown(button) then return true end
    end
    return false
end

function isGamepadDown(index, button)
    if index <= #gamepads then
        return gamepads[index]:isGamepadDown(button)
    end
    return false
end

return input
