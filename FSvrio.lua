-- vspd_mps.lua
-- Telemetrie-Sensor "Vspd" (m/s) aus "Alt" (m)
-- Weniger Noise ohne starke Verzögerung:
--  - leichter IIR auf Höhe (optional)
--  - zeitkonstanter IIR auf Vspd (dt-korrekt)
-- Keine Tonerzeugung

local AltID = 0

-- Telemetrie-Sensor-ID für Vspd (konstant lassen)
local VSPD_ID = 0xF001
local VSPD_SUBID = 0
local VSPD_INSTANCE = 1

-- Zustände
local tOld = nil
local altOld = nil

local altFilt = nil
local vspdFilt = 0.0

-- Filterparameter (Sekunden)
local TAU_ALT  = 0.08   -- 0.00..0.15  (klein = kaum Lag, größer = ruhiger)
local TAU_VSPD = 0.18   -- 0.12..0.30  (klein = schneller, größer = ruhiger)

-- Deadband (m/s) gegen Zittern um 0
local DEADBAND = 0.06   -- 0.00..0.12

-- Sicherheitsnetz (optional)
local MAX_ABS_VSPD = 50.0

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- dt-korrekter 1-Pol-Filter: alpha = dt/(tau+dt)
local function alpha_from_tau(dt_s, tau)
  if tau <= 0 then return 1.0 end
  return dt_s / (tau + dt_s)
end

local function init()
  local fi = getFieldInfo("Alt")
  AltID = fi and fi.id or 0
end

local function run()
  if AltID == 0 then
    return 0
  end

  local tNow = getTime()          -- 1/100 s
  local rawAlt = getValue(AltID)  -- Meter

  if not tOld then
    tOld = tNow
    altOld = rawAlt
    altFilt = rawAlt
    vspdFilt = 0.0
    setTelemetryValue(VSPD_ID, VSPD_SUBID, VSPD_INSTANCE, 0, UNIT_MPS, 2, "Vspd")
    return 0
  end

  local dt = tNow - tOld
  if dt <= 0 then
    return 0
  end
  local dt_s = dt / 100.0

  -- optional: leichter Höhenfilter (sehr kleine Verzögerung, aber reduziert Ableitungsrauschen)
  local aAlt = alpha_from_tau(dt_s, TAU_ALT)
  altFilt = altFilt + aAlt * (rawAlt - altFilt)

  -- Roh-Vspd aus (leicht) gefilterter Höhe
  local vspdRaw = (altFilt - altOld) / dt_s
  vspdRaw = clamp(vspdRaw, -MAX_ABS_VSPD, MAX_ABS_VSPD)

  -- Vspd-Filter (das bringt den großen Noise-Gewinn)
  local aV = alpha_from_tau(dt_s, TAU_VSPD)
  vspdFilt = vspdFilt + aV * (vspdRaw - vspdFilt)

  -- Deadband
  if math.abs(vspdFilt) < DEADBAND then
    vspdFilt = 0.0
  end

  -- Update states
  tOld = tNow
  altOld = altFilt

  -- Telemetrie-Ausgabe (2 Nachkommastellen, Einheit m/s)
  local prec = 2
  local scale = 10 ^ prec
  local v_int = math.floor(vspdFilt * scale + (vspdFilt >= 0 and 0.5 or -0.5))

  setTelemetryValue(VSPD_ID, VSPD_SUBID, VSPD_INSTANCE, v_int, UNIT_MPS, prec, "Vspd")

  return 0
end

return { init = init, run = run }