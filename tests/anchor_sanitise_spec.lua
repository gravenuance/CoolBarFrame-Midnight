local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

local function bar(name, target)
  return { name = name, anchorPoint = "TOPLEFT", anchorTarget = target, targetPoint = "BOTTOMLEFT" }
end

local function targets(bars)
  local result = {}
  for _, b in ipairs(bars) do result[b.name] = b.anchorTarget end
  return result
end

t.test("BreakAnchorCycles leaves acyclic data untouched", function()
  local bars = { bar("A", "UIParent"), bar("B", "A"), bar("C", "B") }
  t.eq(Logic.BreakAnchorCycles(bars), 0)
  t.eq(targets(bars), { A = "UIParent", B = "A", C = "B" })
end)

t.test("BreakAnchorCycles detaches a self-anchored bar", function()
  local bars = { bar("A", "A") }
  t.eq(Logic.BreakAnchorCycles(bars), 1)
  t.eq(bars[1], { name = "A", anchorPoint = "CENTER", anchorTarget = "UIParent", targetPoint = "CENTER" })
end)

t.test("BreakAnchorCycles breaks a three-bar loop at its first bar only", function()
  local bars = { bar("A", "B"), bar("B", "C"), bar("C", "A") }
  t.eq(Logic.BreakAnchorCycles(bars), 1)
  t.eq(targets(bars), { A = "UIParent", B = "C", C = "A" })
end)

t.test("BreakAnchorCycles keeps bars that merely hang off a loop", function()
  local bars = { bar("A", "B"), bar("B", "A"), bar("D", "A") }
  t.eq(Logic.BreakAnchorCycles(bars), 1)
  t.eq(targets(bars), { A = "UIParent", B = "A", D = "A" })
end)

t.test("BreakAnchorCycles handles two separate loops", function()
  local bars = { bar("A", "B"), bar("B", "A"), bar("C", "D"), bar("D", "C") }
  t.eq(Logic.BreakAnchorCycles(bars), 2)
  t.eq(targets(bars), { A = "UIParent", B = "A", C = "UIParent", D = "C" })
end)

t.test("BreakAnchorCycles tolerates entries without a name or target", function()
  local bars = { { anchorTarget = "A" }, { name = "A" } }
  t.eq(Logic.BreakAnchorCycles(bars), 0)
end)
