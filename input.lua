local input = {}

local gamepads = {}
local splitMode = false

function input.load()
    gamepads = love.joystick.getJoysticks()
end

function input.refresh()
    gamepads = love.joystick.getJoysticks()
end

function input.setSplitMode(enabled)
    splitMode = enabled
end

function input.getLeftY(index)
    if index <= #gamepads then
        return gamepads[index]:getGamepadAxis("lefty")
    end
    return 0
end

function input.getRightY(index)
    if index <= #gamepads then
        return gamepads[index]:getGamepadAxis("righty")
    end
    return 0
end

function input.anyPressed()
    for _, kb in ipairs({"return", " ", "up", "down", "escape", "w", "s"}) do
        if love.keyboard.isDown(kb) then return true end
    end
    for _, gp in ipairs(gamepads) do
        if gp:isGamepadDown("a", "b", "start", "dpup", "dpdown") then
            return true
        end
    end
    return false
end

function input.isP1Up()
    if love.keyboard.isDown("w") then return true end
    if #gamepads >= 1 then
        return isDpadOrStickUp(1)
    end
    return false
end

function input.isP1Down()
    if love.keyboard.isDown("s") then return true end
    if #gamepads >= 1 then
        return isDpadOrStickDown(1)
    end
    return false
end

function input.isP2Up()
    if love.keyboard.isDown("up") then return true end
    if splitMode and #gamepads >= 1 then
        return isGamepadDown(1, "y") or input.getRightY(1) < -0.5
    end
    if #gamepads >= 2 then
        return isDpadOrStickUp(2)
    end
    return false
end

function input.isP2Down()
    if love.keyboard.isDown("down") then return true end
    if splitMode and #gamepads >= 1 then
        return isGamepadDown(1, "a") or input.getRightY(1) > 0.5
    end
    if #gamepads >= 2 then
        return isDpadOrStickDown(2)
    end
    return false
end

function input.isPause()
    return love.keyboard.isDown("escape") or isAnyGamepadDown("start")
end

function isDpadOrStickUp(index)
    if index <= #gamepads then
        return gamepads[index]:isGamepadDown("dpup") or input.getLeftY(index) < -0.5
    end
    return false
end

function isDpadOrStickDown(index)
    if index <= #gamepads then
        return gamepads[index]:isGamepadDown("dpdown") or input.getLeftY(index) > 0.5
    end
    return false
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
