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
