local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

local function savedSettings()
  return {
    name = "customBar1",
    anchorPoint = "TOPLEFT",
    anchorTarget = "customBar2",
    targetPoint = "BOTTOMRIGHT",
    offsetX = 12,
    offsetY = -34,
    absoluteX = 500,
    absoluteY = 300,
  }
end

-- PlanBarPlacement(settings, targetExists, screenW, screenH, barW, barH)
--   -> point, relativePoint, x, y, usesSavedTarget

t.test("a bar whose target exists is placed from its saved anchor", function()
  local settings = savedSettings()
  local point, relativePoint, x, y, usesSavedTarget = Logic.PlanBarPlacement(settings, true, 1920, 1080, 100, 40)
  t.eq(point, "TOPLEFT")
  t.eq(relativePoint, "BOTTOMRIGHT")
  t.eq(x, 12)
  t.eq(y, -34)
  t.eq(usesSavedTarget, true)
end)

t.test("a bar whose target is missing is parked at its last screen position", function()
  local point, relativePoint, x, y, usesSavedTarget =
      Logic.PlanBarPlacement(savedSettings(), false, 1920, 1080, 100, 40)
  t.eq(point, "CENTER")
  t.eq(relativePoint, "CENTER")
  -- centre offset = absolute left/bottom minus (screen - bar) / 2: 500 - 910, 300 - 520
  t.eq(x, -410)
  t.eq(y, -220)
  t.eq(usesSavedTarget, false)
end)

t.test("a missing target never rewrites the saved anchor", function()
  local settings = savedSettings()
  Logic.PlanBarPlacement(settings, false, 1920, 1080, 100, 40)
  t.eq(settings, savedSettings())
end)
