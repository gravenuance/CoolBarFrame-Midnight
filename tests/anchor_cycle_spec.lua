local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

-- anchors maps bar name -> the name its saved anchorTarget points at.
local function lookup(anchors)
  return function(name) return anchors[name] end
end

t.test("anchoring a bar to itself is a cycle", function()
  t.truthy(Logic.WouldCreateAnchorCycle("A", "A", lookup({})))
end)

t.test("direct two-bar loop is a cycle", function()
  -- B already hangs off A; anchoring A to B closes the loop.
  t.truthy(Logic.WouldCreateAnchorCycle("A", "B", lookup({ B = "A" })))
end)

t.test("three-bar loop is a cycle", function()
  -- C -> B -> A already; A -> C would give A -> C -> B -> A.
  t.truthy(Logic.WouldCreateAnchorCycle("A", "C", lookup({ C = "B", B = "A" })))
end)

t.test("long chain ending at the bar is a cycle", function()
  local anchors = { E = "D", D = "C", C = "B", B = "A" }
  t.truthy(Logic.WouldCreateAnchorCycle("A", "E", lookup(anchors)))
end)

t.test("a chain ending at a non-bar frame is not a cycle", function()
  t.falsy(Logic.WouldCreateAnchorCycle("A", "C", lookup({ C = "B", B = "UIParent" })))
end)

t.test("anchoring to UIParent or an unrelated frame is not a cycle", function()
  t.falsy(Logic.WouldCreateAnchorCycle("A", "UIParent", lookup({})))
  t.falsy(Logic.WouldCreateAnchorCycle("A", "PlayerFrame", lookup({ B = "A" })))
end)

t.test("a loop that does not include the bar still terminates", function()
  -- B <-> C loop exists already; A joining it from outside must not hang.
  t.falsy(Logic.WouldCreateAnchorCycle("A", "B", lookup({ B = "C", C = "B" })))
end)
