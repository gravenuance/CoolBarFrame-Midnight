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
