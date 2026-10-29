local _, CBM = ...

-- Pure logic: no WoW API, so tests/ can load this file with a fake namespace.
local Logic = {}
CBM.Logic = Logic

-- Plain decimal numbers only; tonumber alone would also take hex, exponents, "inf" and "nan".
function Logic.ParseNumber(text)
  if type(text) ~= "string" then return nil end
  local number = text:match("^%s*([+-]?%d*%.?%d*)%s*$")
  if not number or not number:find("%d") then return nil end
  return tonumber(number)
end

-- True when anchoring barName to targetName would make barName depend on itself.
-- getAnchorTarget(name) returns the saved anchor target of a bar, or nil for any other frame.
function Logic.WouldCreateAnchorCycle(barName, targetName, getAnchorTarget)
  local seen = {}
  local current = targetName
  while current do
    if current == barName then return true end
    if seen[current] then return false end -- a loop that excludes barName cannot involve it
    seen[current] = true
    current = getAnchorTarget(current)
  end
  return false
end

-- Edit mode follows an explicit request (never a toggle). Returns the new state and whether an
-- enter request was deferred because something blocks it; leaving is always allowed.
function Logic.PlanEditMode(active, requested, blocked)
  if requested == active then return active, false end
  if requested and blocked then return active, true end
  return requested, false
end

-- restrictions[kind] mirrors ADDON_RESTRICTION_STATE_CHANGED: restricted from "activating" until inactive.
function Logic.ApplyRestrictionEvent(restrictions, kind, state, inactiveState)
  restrictions[kind] = state ~= inactiveState
end

function Logic.IsBlocked(restrictions, inCombat, blockingKinds)
  if inCombat then return true end
  for kind in pairs(blockingKinds) do
    if restrictions[kind] then return true end
  end
  return false
end

-- Where to SetPoint a bar: its saved anchor, or a temporary screen-centre placement at its last
-- known position when the target frame is missing. Never changes settings, so a target that is
-- merely not created yet keeps its saved anchor. Returns point, relativePoint, x, y, usesSavedTarget.
function Logic.PlanBarPlacement(settings, targetExists, screenW, screenH, barW, barH)
  if targetExists then
    return settings.anchorPoint, settings.targetPoint, settings.offsetX, settings.offsetY, true
  end
  return "CENTER", "CENTER",
      settings.absoluteX - (screenW - barW) / 2,
      settings.absoluteY - (screenH - barH) / 2,
      false
end

function Logic.NewBarSettings(name)
  return {
    name         = name,
    icons        = {}, -- cooldownIDs, not saved per-spec
    scale        = 1,
    padding      = 0,
    isHorizontal = true,
    anchorPoint  = "CENTER",
    anchorTarget = "UIParent",
    targetPoint  = "CENTER",
    offsetX      = 0,
    offsetY      = 0,
    absoluteX    = 0,
    absoluteY    = 0,
  }
end

-- Fills fields that are missing or of the wrong type; every valid user value stays.
function Logic.MergeBarDefaults(settings)
  for key, default in pairs(Logic.NewBarSettings(settings.name)) do
    if type(settings[key]) ~= type(default) then
      settings[key] = default
    end
  end
  return settings
end

local function DeepCopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for k, v in pairs(value) do copy[k] = DeepCopy(v) end
  return copy
end

-- Bars written by older versions may lack fields; schema 2 guarantees complete bars without loops.
local function NormalizeBars(bars)
  for index = #bars, 1, -1 do
    if type(bars[index]) == "table" then
      Logic.MergeBarDefaults(bars[index])
    else
      table.remove(bars, index)
    end
  end
  Logic.BreakAnchorCycles(bars)
end

-- MIGRATIONS[n] upgrades schema n to n + 1.
Logic.SCHEMA_VERSION = 2
Logic.MIGRATIONS = {
  [1] = function(db) NormalizeBars(db.bars) end,
}

-- Brings db forward to `current`, keeping the pre-migration bars in db.backup.
-- Returns "current", "migrated", "newer" (left untouched) or "failed" plus the error; a failed
-- migration restores the bars and keeps the old version so nothing is stamped as upgraded.
function Logic.MigrateDB(db, migrations, current)
  if type(db.bars) ~= "table" then db.bars = {} end

  local version = type(db.version) == "number" and db.version or 1 -- unversioned data predates schema 2
  if version > current then return "newer" end
  if version == current then return "current" end

  local backup = { version = version, bars = DeepCopy(db.bars) }
  for step = version, current - 1 do
    local migrate = migrations[step]
    local ok, err
    if migrate then
      ok, err = pcall(migrate, db)
    else
      ok, err = false, "no migration from schema " .. step
    end
    if not ok then
      db.bars = backup.bars
      return "failed", err
    end
  end

  db.backup = backup
  db.version = current
  return "migrated"
end

-- Detaches (to UIParent) the first bar of every anchor loop in saved bar settings; returns how many.
function Logic.BreakAnchorCycles(bars)
  local byName = {}
  for _, settings in ipairs(bars) do
    if settings.name then byName[settings.name] = settings end
  end
  local function getAnchorTarget(name)
    local settings = byName[name]
    return settings and settings.anchorTarget
  end

  local fixed = 0
  for _, settings in ipairs(bars) do
    if settings.name and Logic.WouldCreateAnchorCycle(settings.name, settings.anchorTarget, getAnchorTarget) then
      settings.anchorPoint = "CENTER"
      settings.anchorTarget = "UIParent"
      settings.targetPoint = "CENTER"
      fixed = fixed + 1
    end
  end
  return fixed
end
