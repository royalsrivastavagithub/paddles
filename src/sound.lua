local sound = {}

local SAMPLE_RATE = 44100
local AMPLITUDE = 0.3

local function generateSoundData(waveType, frequency, duration)
    local numSamples = math.max(1, math.floor(duration * SAMPLE_RATE))
    local data = love.sound.newSoundData(numSamples, SAMPLE_RATE, 16, 1)

    for i = 0, data:getSampleCount() - 1 do
        local t = i / SAMPLE_RATE
        local sample
        if waveType == "sine" then
            sample = math.sin(2 * math.pi * frequency * t)
        elseif waveType == "square" then
            sample = math.sin(2 * math.pi * frequency * t) > 0 and 1 or -1
        end
        data:setSample(i, sample * AMPLITUDE)
    end
    return data
end

local function generateTwoTone(freq1, freq2, duration)
    local half = math.floor(duration * SAMPLE_RATE / 2)
    local total = half * 2
    local data = love.sound.newSoundData(total, SAMPLE_RATE, 16, 1)

    for i = 0, data:getSampleCount() - 1 do
        local t = i / SAMPLE_RATE
        local freq = i < half and freq1 or freq2
        local sample = math.sin(2 * math.pi * freq * t)
        data:setSample(i, sample * AMPLITUDE)
    end
    return data
end

local highlightSource
local enterSource
local escapeSource
local paddle1Source
local paddle2Source
local scoreSource
local winSource
local loseSource

local function generateThreeTone(freqs, durationEach)
    local segSamples = math.floor(durationEach * SAMPLE_RATE)
    local total = segSamples * #freqs
    local data = love.sound.newSoundData(total, SAMPLE_RATE, 16, 1)
    for i = 0, data:getSampleCount() - 1 do
        local seg = math.floor(i / segSamples)
        local localI = i - seg * segSamples
        local t = localI / SAMPLE_RATE
        local sample = math.sin(2 * math.pi * freqs[seg + 1] * t)
        data:setSample(i, sample * AMPLITUDE)
    end
    return data
end

local function enabled()
    return not _G.settingsData or _G.settingsData.soundEnabled ~= false
end

function sound.load()
    local highlightData = generateSoundData("square", 1000, 0.06)
    highlightSource = love.audio.newSource(highlightData)

    local enterData = generateTwoTone(1500, 2000, 0.16)
    enterSource = love.audio.newSource(enterData)

    local escapeData = generateTwoTone(2000, 1500, 0.16)
    escapeSource = love.audio.newSource(escapeData)

    local c5 = 523.25
    local f5 = c5 * math.pow(2, 5 / 12)
    local p1Data = generateSoundData("sine", c5, 0.12)
    local p2Data = generateSoundData("sine", f5, 0.12)
    paddle1Source = love.audio.newSource(p1Data)
    paddle2Source = love.audio.newSource(p2Data)

    local scoreData = generateSoundData("sine", 600, 0.1)
    scoreSource = love.audio.newSource(scoreData)

    local winData = generateThreeTone({523, 659, 784}, 0.08)
    winSource = love.audio.newSource(winData)

    local loseData = generateThreeTone({784, 659, 523}, 0.08)
    loseSource = love.audio.newSource(loseData)
end

function sound.playHighlight()
    if not enabled() then return end
    if highlightSource then
        highlightSource:stop()
        highlightSource:play()
    end
end

function sound.playEnter()
    if not enabled() then return end
    if enterSource then
        enterSource:stop()
        enterSource:play()
    end
end

function sound.playEscape()
    if not enabled() then return end
    if escapeSource then
        escapeSource:stop()
        escapeSource:play()
    end
end

function sound.playPaddle1()
    if not enabled() then return end
    if paddle1Source then
        paddle1Source:stop()
        paddle1Source:play()
    end
end

function sound.playPaddle2()
    if not enabled() then return end
    if paddle2Source then
        paddle2Source:stop()
        paddle2Source:play()
    end
end

function sound.playScore()
    if not enabled() then return end
    if scoreSource then
        scoreSource:stop()
        scoreSource:play()
    end
end

function sound.playWin()
    if not enabled() then return end
    if winSource then
        winSource:stop()
        winSource:play()
    end
end

function sound.playLose()
    if not enabled() then return end
    if loseSource then
        loseSource:stop()
        loseSource:play()
    end
end

local ballWaveTypes = {"sine", "square", "sawtooth"}

function sound.playBallBounce()
    if not enabled() then return end
    local freq = 3000 + math.random() * 3000
    local waveType = ballWaveTypes[math.random(#ballWaveTypes)]
    local numSamples = math.max(1, math.floor(0.05 * SAMPLE_RATE))
    local data = love.sound.newSoundData(numSamples, SAMPLE_RATE, 16, 1)

    for i = 0, data:getSampleCount() - 1 do
        local t = i / SAMPLE_RATE
        local sample
        if waveType == "sine" then
            sample = math.sin(2 * math.pi * freq * t)
        elseif waveType == "square" then
            sample = math.sin(2 * math.pi * freq * t) > 0 and 1 or -1
        elseif waveType == "sawtooth" then
            sample = 2 * (t * freq % 1) - 1
        end
        data:setSample(i, sample * (AMPLITUDE * 0.6))
    end

    local source = love.audio.newSource(data)
    source:play()
end

return sound
