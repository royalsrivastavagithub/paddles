local colors = {
    white   = {1, 1, 1},
    yellow  = {1, 1, 0},
    red     = {1, 0, 0},
    green   = {0.2, 1, 0.2},
    blue    = {0.2, 0.5, 1},
    cyan    = {0, 1, 1},
    magenta = {1, 0, 1},
    orange  = {1, 0.6, 0},
}

local names = {"white", "yellow", "red", "green", "blue", "cyan", "magenta", "orange"}

function colors.get(name)
    return colors[name] or colors.white
end

function colors.names()
    return names
end

return colors
