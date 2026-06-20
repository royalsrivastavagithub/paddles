local history = {}
local entries = {}
local MAX_ENTRIES = 50

function history.load()
    local f = loadfile("history.dat")
    if f then
        local ok, saved = pcall(f)
        if ok and type(saved) == "table" then
            entries = saved
        end
    end
end

function history.save()
    local lines = {"return {"}
    for _, e in ipairs(entries) do
        lines[#lines+1] = string.format("  {mode=%q, difficulty=%q, winner=%q, scoreP1=%d, scoreP2=%d, date=%q},", e.mode, e.difficulty or "", e.winner, e.scoreP1, e.scoreP2, e.date)
    end
    lines[#lines+1] = "}"
    local f = io.open("history.dat", "w")
    if f then f:write(table.concat(lines, "\n")); f:close() end
end

function history.add(mode, difficulty, winner, scoreP1, scoreP2)
    table.insert(entries, {
        mode = mode,
        difficulty = difficulty or "",
        winner = winner,
        scoreP1 = scoreP1,
        scoreP2 = scoreP2,
        date = os.date("%Y-%m-%d %H:%M"),
    })
    if #entries > MAX_ENTRIES then table.remove(entries, 1) end
    history.save()
end

function history.getAll()
    return entries
end

function history.clear()
    entries = {}
    history.save()
end

history.load()
return history
