-- vspd_alt2.lua
-- Erzeugt Telemetrie-Sensoren:
--  - Vspd (m/s)  : Vertikalgeschwindigkeit aus "Alt"
--  - Alt2 (m)    : Relative Höhe ab Script-Start (automatischer Reset)
--
-- "Alt" muss als Telemetrie-Sensor existieren und Meter liefern.
-- Reset-Logik ohne Schalter: beim Start + bei "Restart" (Zeitluecke) wird Alt2 auf 0 gesetzt.

local AltID = 0

-- Telemetrie-IDs (frei, aber konstant lassen!)
local VSPD_ID = 0xF001
local ALT2_ID = 0xF002
local SUBID = 0
local INSTANCE = 1

-- Filterparameter (Sekunden)
local TAU_ALT  = 0.10
local TAU_VSPD = 0.22
local DEADBAND = 0.06

local MAX_ABS_VSPD = 50.0

-- Wenn zwischen run()-Aufrufen eine große Lücke ist, gilt das als (Re)Start
local RESTART_GAP = 200  -- in 1/100 s => 2.0 Sekunden

-- Zustände
local tOld = nil
local altOld = nil
local altZero = nil
local altFilt = nil
local vspdFilt = 0.0

-- Telemetrie initial einmal anlegen
local sensorsCreated = false

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function alpha_from_tau(dt_s, tau)
  if tau <= 0 then return 1.0 end
  return dt_s / (tau + dt_s)
end

local function createSensors()
  if sensorsCreated then return end
  setTelemetryValue(VSPD_ID, SUBID, INSTANCE, 0, UNIT_MPS, 2, "Vspd")
  setTelemetryValue(ALT2_ID, SUBID, INSTANCE, 0, UNIT_METER, 2, "Alt2")
  sensorsCreated = true
end

local function hardReset(tNow, altNow)
  -- Setzt Referenzen auf den aktuellen Alt-Wert => Alt2 garantiert 0.00
  createSensors()
  tOld = tNow
  altFilt = altNow
  altOld = altNow
  altZero = altNow
  vspdFilt = 0.0

  setTelemetryValue(VSPD_ID, SUBID, INSTANCE, 0, UNIT_MPS, 2, "Vspd")
  setTelemetryValue(ALT2_ID, SUBID, INSTANCE, 0, UNIT_METER, 2, "Alt2")
end

local function init()
  local fi = getFieldInfo("Alt")
  AltID = fi and fi.id or 0

  -- Zustände zurücksetzen, damit beim ersten run() sicher genullt wird
  tOld = nil
  altOld = nil
  altZero = nil
  altFilt = nil
  vspdFilt = 0.0
  sensorsCreated = false
end

local function run()
  if AltID == 0 then
    return 0
  end

  local tNow = getTime()         -- 1/100 s
  local rawAlt = getValue(AltID) -- Meter

  createSensors()

  -- erster Lauf oder Reset noch nicht gesetzt -> sofort nullen
  if not tOld then
    hardReset(tNow, rawAlt)
    return 0
  end

  local dtTicks = tNow - tOld

  -- Restart erkannt (Script war vermutlich aus / neu aktiviert) -> neu nullen
  if dtTicks > RESTART_GAP then
    hardReset(tNow, rawAlt)
    return 0
  end

  if dtTicks <= 0 then
    return 0
  end

  local dt_s = dtTicks / 100.0

  -- leichter Höhenfilter
  local aAlt = alpha_from_tau(dt_s, TAU_ALT)
  altFilt = altFilt + aAlt * (rawAlt - altFilt)

  -- relative Höhe
  local alt2 = altFilt - altZero

  -- Roh-Vspd
  local vspdRaw = (altFilt - altOld) / dt_s
  vspdRaw = clamp(vspdRaw, -MAX_ABS_VSPD, MAX_ABS_VSPD)

  -- Vspd-Filter
  local aV = alpha_from_tau(dt_s, TAU_VSPD)
  vspdFilt = vspdFilt + aV * (vspdRaw - vspdFilt)

  if math.abs(vspdFilt) < DEADBAND then
    vspdFilt = 0.0
  end

  -- Zustände aktualisieren
  tOld = tNow
  altOld = altFilt

  -- Telemetrie-Ausgabe
  local precV = 2
  local v_int = math.floor(vspdFilt * (10 ^ precV) + (vspdFilt >= 0 and 0.5 or -0.5))
  setTelemetryValue(VSPD_ID, SUBID, INSTANCE, v_int, UNIT_MPS, precV, "Vspd")

  local precA = 2
  local a_int = math.floor(alt2 * (10 ^ precA) + (alt2 >= 0 and 0.5 or -0.5))
  setTelemetryValue(ALT2_ID, SUBID, INSTANCE, a_int, UNIT_METER, precA, "Alt2")

  return 0
end

return { init = init, run = run }