local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

-- PlanSliderUpdate(mode, current, requested, minValue, maxValue, force) -> value, apply

t.test("refreshing shows the stored value and never applies anything", function()
  local value, apply = Logic.PlanSliderUpdate("refresh", 1.5, 1.5, 0.05, 5, true)
  t.eq(value, 1.5)
  t.eq(apply, false)
end)

t.test("a refresh ignores the requested value and shows the stored one", function()
  local value, apply = Logic.PlanSliderUpdate("refresh", 2, 4, 0.05, 5, false)
  t.eq(value, 2)
  t.eq(apply, false)
end)

t.test("a changed input is applied", function()
  local value, apply = Logic.PlanSliderUpdate("input", 1, 2.5, 0.05, 5, false)
  t.eq(value, 2.5)
  t.eq(apply, true)
end)

t.test("an unchanged input is not applied", function()
  local value, apply = Logic.PlanSliderUpdate("input", 2.5, 2.5, 0.05, 5, false)
  t.eq(value, 2.5)
  t.eq(apply, false)
end)

t.test("a forced unchanged input is applied so multi-select can unify values", function()
  local value, apply = Logic.PlanSliderUpdate("input", 2.5, 2.5, 0.05, 5, true)
  t.eq(value, 2.5)
  t.eq(apply, true)
end)

t.test("input is clamped into the slider range", function()
  local value = Logic.PlanSliderUpdate("input", 1, 9, 0.05, 5, false)
  t.eq(value, 5)
  value = Logic.PlanSliderUpdate("input", 1, -3, 0.05, 5, false)
  t.eq(value, 0.05)
end)

t.test("an input clamped back to the stored value is not applied", function()
  local value, apply = Logic.PlanSliderUpdate("input", 5, 9, 0.05, 5, false)
  t.eq(value, 5)
  t.eq(apply, false)
end)

t.test("an unbounded slider takes negative and large values as typed", function()
  local value, apply = Logic.PlanSliderUpdate("input", 0, -50, nil, nil, false)
  t.eq(value, -50)
  t.eq(apply, true)
  value = Logic.PlanSliderUpdate("input", 0, 4000, nil, nil, false)
  t.eq(value, 4000)
end)

t.test("a missing requested value changes nothing", function()
  local value, apply = Logic.PlanSliderUpdate("input", 3, nil, 0.05, 5, true)
  t.eq(value, 3)
  t.eq(apply, false)
end)
