-- playdate.sound: sample players, file players, and a synth.
--
-- Playbit's sampleplayer and fileplayer work but only look for ".wav" and
-- ignore repeatCount. Its synth is all errors. A synth is the one a game needs
-- most, because it makes a noise without shipping any audio files, so this
-- builds waveforms into a buffer by hand and hands it to Love.

local warn = require("shim.warn")
local compat = require("shim.compat")

local sound = playdate.sound

sound.kWaveSine = "sine"
sound.kWaveSquare = "square"
sound.kWaveSawtooth = "sawtooth"
sound.kWaveTriangle = "triangle"
sound.kWaveNoise = "noise"
sound.kWavePOPhase = "sine"
sound.kWavePODigital = "square"
sound.kWavePOVosim = "square"

sound.kFormat8bitMono = 0
sound.kFormat8bitStereo = 1
sound.kFormat16bitMono = 2
sound.kFormat16bitStereo = 3

local SAMPLE_RATE = 44100

function sound.getSampleRate()
  return SAMPLE_RATE
end

function sound.getCurrentTime()
  return love.timer.getTime()
end

function sound.resetTime() end

-- Finding audio files ---------------------------------------------------------

-- The SDK takes a path with or without an extension. Playbit always appends
-- ".wav", which fails for anything else, so look for what is actually there.
local extensions = { "", ".wav", ".ogg", ".mp3" }

local function resolveAudioPath(path)
  for i = 1, #extensions do
    local candidate = path .. extensions[i]
    if compat.fileExists(candidate) then
      return candidate
    end
  end
  return nil
end

-- A player for a file that is not there. Every method works, nothing sounds.
local silentMeta = {}
silentMeta.__index = function()
  return function()
    return false
  end
end

local function silentPlayer(path)
  warn.note("no audio file at '" .. tostring(path) .. "', so it will stay silent")
  return setmetatable({}, silentMeta)
end

-- Sample and file players --------------------------------------------------------

local function buildPlayer()
  local meta = {}
  meta.__index = meta

  local function wrap(source)
    local self = setmetatable({}, meta)
    self.data = source
    self._volume = 1
    return self
  end

  function meta:play(repeatCount, rate)
    if rate then
      self.data:setPitch(rate)
    end
    -- 0 means loop for ever. Anything else, Love can only do once, so a count
    -- above 1 plays once and says why.
    if repeatCount == 0 then
      self.data:setLooping(true)
    else
      self.data:setLooping(false)
      if repeatCount and repeatCount > 1 then
        warn.note("play() with a repeat count above 1 only plays once here; 0 loops for ever")
      end
    end
    self.data:stop()
    self.data:play()
    return true
  end

  function meta:playAt(when, vol)
    if vol then
      self:setVolume(vol)
    end
    return self:play()
  end

  function meta:stop()
    self.data:stop()
  end

  function meta:pause()
    self.data:pause()
  end

  function meta:isPlaying()
    return self.data:isPlaying()
  end

  function meta:setVolume(left, right)
    self._volume = left
    self.data:setVolume(left)
  end

  function meta:getVolume()
    return self._volume, self._volume
  end

  function meta:setRate(rate)
    self.data:setPitch(rate)
  end

  function meta:getRate()
    return self.data:getPitch()
  end

  function meta:getLength()
    return self.data:getDuration()
  end

  function meta:setLoopRange() end
  function meta:setFinishCallback(fn)
    self._finishCallback = fn
  end
  function meta:setOffset(seconds)
    self.data:seek(seconds)
  end
  function meta:getOffset()
    return self.data:tell()
  end

  function meta:copy()
    return wrap(self.data:clone())
  end

  return meta, wrap
end

local sampleplayerMeta, wrapSample = buildPlayer()
local fileplayerMeta, wrapFile = buildPlayer()

local sampleplayer = {}
sound.sampleplayer = sampleplayer
sampleplayer.meta = sampleplayerMeta
sampleplayer.__index = sampleplayerMeta

function sampleplayer.new(pathOrSample)
  if type(pathOrSample) == "table" then
    return wrapSample(love.audio.newSource(pathOrSample.data, "static"))
  end
  local found = resolveAudioPath(pathOrSample)
  if not found then
    return silentPlayer(pathOrSample)
  end
  return wrapSample(love.audio.newSource(found, "static"))
end

-- A sample is the raw audio; a sampleplayer is the thing that plays it.
local sample = {}
sound.sample = sample

local sampleMeta = {}
sampleMeta.__index = sampleMeta
sample.meta = sampleMeta
sample.__index = sampleMeta

function sample.new(path)
  local self = setmetatable({}, sampleMeta)
  if type(path) == "number" then
    self.data = love.sound.newSoundData(math.floor(SAMPLE_RATE * path), SAMPLE_RATE, 16, 1)
    return self
  end
  local found = resolveAudioPath(path)
  if not found then
    warn.note("no audio file at '" .. tostring(path) .. "', so it will stay silent")
    self.data = love.sound.newSoundData(2, SAMPLE_RATE, 16, 1)
    return self
  end
  self.data = love.sound.newSoundData(found)
  return self
end

function sampleMeta:getLength()
  return self.data:getDuration()
end

function sampleMeta:getSampleRate()
  return self.data:getSampleRate()
end

function sampleMeta:play(repeatCount, rate)
  local player = sampleplayer.new(self)
  player:play(repeatCount, rate)
  return player
end

warn.fill("playdate.sound.sample:", sampleMeta, {
  "getSubSample", "load", "decompress", "getFormat", "save", "playAt",
})

local fileplayer = {}
sound.fileplayer = fileplayer
fileplayer.meta = fileplayerMeta
fileplayer.__index = fileplayerMeta

function fileplayer.new(path, bufferSize)
  local found = resolveAudioPath(path)
  if not found then
    return silentPlayer(path)
  end
  return wrapFile(love.audio.newSource(found, "stream"))
end

-- Synth -----------------------------------------------------------------------

-- Note names to frequencies. A4 is 440 Hz and every semitone is the twelfth
-- root of two away from the next.
local noteOffsets = { C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11 }

local function midiToFrequency(midi)
  return 440 * 2 ^ ((midi - 69) / 12)
end

local function noteToFrequency(note)
  if type(note) == "number" then
    -- A bare number under 128 is a MIDI note on the Playdate, above that it is
    -- already a frequency.
    if note < 128 then
      return midiToFrequency(note)
    end
    return note
  end
  local letter, accidental, octave = string.match(note, "^(%a)([#b]?)(%-?%d+)$")
  if not letter then
    warn.note("could not read the note name '" .. tostring(note) .. "', using A4")
    return 440
  end
  local semitone = noteOffsets[string.upper(letter)] or 0
  if accidental == "#" then
    semitone = semitone + 1
  elseif accidental == "b" then
    semitone = semitone - 1
  end
  local midi = (tonumber(octave) + 1) * 12 + semitone
  return midiToFrequency(midi)
end

local function waveSample(waveform, phase)
  if waveform == sound.kWaveSquare then
    if phase < 0.5 then
      return 1
    end
    return -1
  elseif waveform == sound.kWaveSawtooth then
    return phase * 2 - 1
  elseif waveform == sound.kWaveTriangle then
    if phase < 0.5 then
      return phase * 4 - 1
    end
    return 3 - phase * 4
  elseif waveform == sound.kWaveNoise then
    return math.random() * 2 - 1
  end
  return math.sin(phase * 2 * math.pi)
end

-- Building 44100 samples a second is not free, so keep each note around.
local toneCache = {}

-- Attack, decay, sustain, release: how loud the note is over its life. It
-- rises over the attack, falls to the sustain level over the decay, holds
-- there, then fades out over the release. A plucked string is a fast attack
-- and a long release; an organ is all sustain. The Playdate shapes this
-- continuously; here the shape is drawn into the samples when the note is
-- built, which sounds the same for a note of a known length.
--
-- Whatever the game asks for, a note always gets a tiny ramp at each end,
-- because a waveform that starts or stops at full height clicks.
local MIN_RAMP = 0.004

local function envelopeAt(seconds, length, adsr)
  local attack = math.max(adsr.attack, MIN_RAMP)
  local decay = adsr.decay
  local sustain = adsr.sustain
  local release = math.max(adsr.release, MIN_RAMP)

  -- A short note cannot hold every stage, so squeeze them to fit.
  local total = attack + decay + release
  if total > length then
    local squeeze = length / total
    attack = attack * squeeze
    decay = decay * squeeze
    release = release * squeeze
  end

  local level
  if seconds < attack then
    level = seconds / attack
  elseif seconds < attack + decay then
    level = 1 - (1 - sustain) * ((seconds - attack) / decay)
  else
    level = sustain
  end

  local fromEnd = length - seconds
  if fromEnd < release then
    level = level * (fromEnd / release)
  end

  if level < 0 then
    return 0
  end
  return level
end

sound.shimEnvelopeAt = envelopeAt

local function buildTone(waveform, frequency, length, adsr)
  local key = table.concat({
    waveform,
    string.format("%.2f", frequency),
    string.format("%.3f", length),
    string.format("%.3f", adsr.attack),
    string.format("%.3f", adsr.decay),
    string.format("%.3f", adsr.sustain),
    string.format("%.3f", adsr.release),
  }, ":")
  if toneCache[key] then
    return toneCache[key]
  end

  local count = math.floor(SAMPLE_RATE * length)
  if count < 2 then
    count = 2
  end
  local data = love.sound.newSoundData(count, SAMPLE_RATE, 16, 1)

  for i = 0, count - 1 do
    local phase = (frequency * i / SAMPLE_RATE) % 1
    local level = envelopeAt(i / SAMPLE_RATE, length, adsr)
    data:setSample(i, waveSample(waveform, phase) * level * 0.7)
  end

  toneCache[key] = data
  return data
end

local synth = {}
sound.synth = synth

local synthMeta = {}
synthMeta.__index = synthMeta
synth.meta = synthMeta
synth.__index = synthMeta

function synth.new(waveform)
  local self = setmetatable({}, synthMeta)
  self.waveform = waveform or sound.kWaveSine
  self.volume = 1
  self._source = nil
  -- The SDK's own starting shape: straight on, straight off.
  self.adsr = { attack = 0, decay = 0, sustain = 1, release = 0 }
  return self
end

-- playNote(pitch, volume, length). pitch is a frequency, a MIDI number, or a
-- note name like "C4". length is in seconds and defaults to a short beep.
function synthMeta:playNote(pitch, volume, length, when)
  local frequency = noteToFrequency(pitch)
  length = length or 0.2
  volume = volume or self.volume

  local data = buildTone(self.waveform, frequency, length, self.adsr)
  local source = love.audio.newSource(data, "static")
  source:setVolume(volume)
  source:play()
  self._source = source
  return source
end

function synthMeta:playMIDINote(note, volume, length, when)
  return self:playNote(midiToFrequency(note), volume, length, when)
end

function synthMeta:stop()
  if self._source then
    self._source:stop()
  end
end

function synthMeta:noteOff()
  self:stop()
end

function synthMeta:isPlaying()
  return self._source ~= nil and self._source:isPlaying()
end

function synthMeta:setVolume(volume)
  self.volume = volume
end

function synthMeta:getVolume()
  return self.volume
end

function synthMeta:setWaveform(waveform)
  self.waveform = waveform
end

function synthMeta:copy()
  local other = synth.new(self.waveform)
  other.volume = self.volume
  other:setADSR(self.adsr.attack, self.adsr.decay, self.adsr.sustain, self.adsr.release)
  return other
end

function synthMeta:setADSR(attack, decay, sustain, release)
  self.adsr.attack = attack or 0
  self.adsr.decay = decay or 0
  self.adsr.sustain = sustain or 1
  self.adsr.release = release or 0
end

function synthMeta:getADSR()
  return self.adsr.attack, self.adsr.decay, self.adsr.sustain, self.adsr.release
end

function synthMeta:setAttack(seconds)
  self.adsr.attack = seconds or 0
end

function synthMeta:setDecay(seconds)
  self.adsr.decay = seconds or 0
end

function synthMeta:setSustain(level)
  self.adsr.sustain = level or 1
end

function synthMeta:setRelease(seconds)
  self.adsr.release = seconds or 0
end

-- Legato means a new note takes over without restarting the envelope. Notes
-- here are built one at a time, so there is nothing to carry over.
function synthMeta:setLegato() end

warn.fill("playdate.sound.synth:", synthMeta, {
  "setParameter", "setFrequencyModulator", "setAmplitudeMod",
})

function sound.playingSources()
  return {}
end

warn.fill("playdate.sound.", sound, {
  "addEffect", "removeEffect", "getHeadphoneState", "setOutputsActive",
})

return sound
