local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

-- Enum.AddOnRestrictionType / State values from the client API documentation.
local COMBAT, ENCOUNTER, CHALLENGE_MODE, MAP = 0, 1, 2, 4
local INACTIVE, ACTIVATING, ACTIVE = 0, 1, 2
local BLOCKING = { [COMBAT] = true, [ENCOUNTER] = true }

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
