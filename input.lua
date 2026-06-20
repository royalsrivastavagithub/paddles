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

function input.isP1Up()
    return love.keyboard.isDown("w") or isGamepadDown(1, "dpup") or isGamepadDown(1, "leftstickup")
end

function input.isP1Down()
    return love.keyboard.isDown("s") or isGamepadDown(1, "dpdown") or isGamepadDown(1, "leftstickdown")
end

function input.isP2Up()
    if love.keyboard.isDown("up") then return true end
    if splitMode and #gamepads >= 1 then
        return isGamepadDown(1, "y") or getRightStickY(1) < -0.5
    end
    return isGamepadDown(2, "dpup") or isGamepadDown(2, "leftstickup")
end

function input.isP2Down()
    if love.keyboard.isDown("down") then return true end
    if splitMode and #gamepads >= 1 then
        return isGamepadDown(1, "a") or getRightStickY(1) > 0.5
    end
    return isGamepadDown(2, "dpdown") or isGamepadDown(2, "leftstickdown")
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

function getRightStickY(index)
    if index <= #gamepads then
        return gamepads[index]:getGamepadAxis("righty")
    end
    return 0
end

return input
