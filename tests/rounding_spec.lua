local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

-- MinimalRound(number, maxDecimals): round, then drop trailing decimal zeros only.

t.test("MinimalRound keeps integer values with trailing zeros", function()
  t.eq(Logic.MinimalRound(10, 2), 10)
  t.eq(Logic.MinimalRound(-50, 2), -50)
  t.eq(Logic.MinimalRound(100, 2), 100)
  t.eq(Logic.MinimalRound(120, 0), 120)
end)

t.test("MinimalRound rounds to the requested decimals", function()
  t.eq(Logic.MinimalRound(123.456789, 2), 123.46)
  t.eq(Logic.MinimalRound(0.5, 2), 0.5)
  t.eq(Logic.MinimalRound(2.5004, 2), 2.5)
  t.eq(Logic.MinimalRound(-3.14159, 3), -3.142)
end)

t.test("MinimalRound handles zero and non-numbers", function()
  t.eq(Logic.MinimalRound(0, 2), 0)
  t.eq(Logic.MinimalRound(nil, 2), 0)
  t.eq(Logic.MinimalRound("x", 2), 0)
end)

-- TrimRound(number, compare): snap to the integer (or `compare`) when within .001.

t.test("TrimRound snaps values that are almost integers", function()
  t.eq(Logic.TrimRound(4.0004), 4)
  t.eq(Logic.TrimRound(-7.9996), -8)
end)

t.test("TrimRound keeps real fractions", function()
  t.eq(Logic.TrimRound(4.25), 4.25)
end)

t.test("TrimRound snaps to a given comparison value", function()
  t.eq(Logic.TrimRound(2.0004, 2), 2)
  t.eq(Logic.TrimRound(2.5, 2), 2.5)
  t.eq(Logic.TrimRound("x", 3), 3)
  t.eq(Logic.TrimRound(nil), 0)
end)

-- GetRoundingPrecision(step): decimals needed to represent the step.

t.test("GetRoundingPrecision counts decimals of a step", function()
  t.eq(Logic.GetRoundingPrecision(1), 0)
  t.eq(Logic.GetRoundingPrecision(0.5), 1)
  t.eq(Logic.GetRoundingPrecision(0.05), 2)
  t.eq(Logic.GetRoundingPrecision(nil), 0)
end)
