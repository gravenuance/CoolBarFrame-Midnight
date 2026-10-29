local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

-- Enum.AddOnRestrictionType / State values from the client API documentation.
local COMBAT, ENCOUNTER, CHALLENGE_MODE, MAP = 0, 1, 2, 4
local INACTIVE, ACTIVATING, ACTIVE = 0, 1, 2
local BLOCKING = { [COMBAT] = true, [ENCOUNTER] = true }

-- PlanEditMode(active, requested, blocked) -> newActive, deferred

t.test("requesting the state we are already in changes nothing", function()
  local active, deferred = Logic.PlanEditMode(false, false, false)
  t.eq(active, false)
  t.eq(deferred, false)
  active, deferred = Logic.PlanEditMode(true, true, false)
  t.eq(active, true)
  t.eq(deferred, false)
end)

t.test("a close request while already closed stays closed (CDM hidden after desync)", function()
  local active = Logic.PlanEditMode(false, false, true)
  t.eq(active, false)
end)

t.test("entering edit mode succeeds when nothing blocks it", function()
  local active, deferred = Logic.PlanEditMode(false, true, false)
  t.eq(active, true)
  t.eq(deferred, false)
end)

t.test("entering edit mode while blocked is deferred, not applied", function()
  local active, deferred = Logic.PlanEditMode(false, true, true)
  t.eq(active, false)
  t.eq(deferred, true)
end)

t.test("leaving edit mode is always allowed, even while blocked", function()
  local active, deferred = Logic.PlanEditMode(true, false, true)
  t.eq(active, false)
  t.eq(deferred, false)
end)

t.test("repeating a request is idempotent", function()
  local active = Logic.PlanEditMode(false, true, false)
  active = Logic.PlanEditMode(active, true, false)
  t.eq(active, true)
  active = Logic.PlanEditMode(active, false, false)
  active = Logic.PlanEditMode(active, false, false)
  t.eq(active, false)
end)

-- ApplyRestrictionEvent(restrictions, kind, state, inactiveState)

t.test("an activating or active restriction is recorded as restricted", function()
  local restrictions = {}
  Logic.ApplyRestrictionEvent(restrictions, COMBAT, ACTIVATING, INACTIVE)
  t.eq(restrictions[COMBAT], true)
  Logic.ApplyRestrictionEvent(restrictions, ENCOUNTER, ACTIVE, INACTIVE)
  t.eq(restrictions[ENCOUNTER], true)
end)

t.test("an inactive state clears only that restriction kind", function()
  local restrictions = { [COMBAT] = true, [ENCOUNTER] = true }
  Logic.ApplyRestrictionEvent(restrictions, COMBAT, INACTIVE, INACTIVE)
  t.eq(restrictions[COMBAT], false)
  t.eq(restrictions[ENCOUNTER], true)
end)

-- IsBlocked(restrictions, inCombat, blockingKinds)

t.test("combat lockdown alone blocks", function()
  t.truthy(Logic.IsBlocked({}, true, BLOCKING))
end)

t.test("an activating combat restriction blocks before lockdown starts", function()
  t.truthy(Logic.IsBlocked({ [COMBAT] = true }, false, BLOCKING))
  t.truthy(Logic.IsBlocked({ [ENCOUNTER] = true }, false, BLOCKING))
end)

t.test("restriction kinds that are not combat-like do not block", function()
  t.falsy(Logic.IsBlocked({ [MAP] = true, [CHALLENGE_MODE] = true }, false, BLOCKING))
end)

t.test("nothing active and no lockdown does not block", function()
  t.falsy(Logic.IsBlocked({ [COMBAT] = false, [ENCOUNTER] = false }, false, BLOCKING))
end)
