local t = ...

-- Edit mode as wired in Core.lua, driven through the fake client's Cooldown Manager window and events.

local COMBAT, ENCOUNTER = 0, 1

local function loggedIn(savedBars)
  local client = t.newClient({ savedData = { version = 2, bars = savedBars or { { name = "customBar0" } } } })
  client.login()
  return client
end

local function barShown(client)
  return client.bars()[1]:IsShown()
end

t.test("opening the Cooldown Manager window enters edit mode and shows bars and options", function()
  local client = loggedIn()
  t.falsy(barShown(client), "bar hidden before edit mode")
  client.env.ShowUIPanel(client.env.CooldownViewerSettings)
  t.truthy(client.ns.editModeActive)
  t.truthy(barShown(client))
  t.truthy(client.ns.OptionsFrame:IsShown())
end)

t.test("closing the options frame leaves edit mode and closes the window", function()
  local client = loggedIn()
  client.slash("")
  t.truthy(client.env.CooldownViewerSettings:IsShown())
  client.ns.OptionsFrame:Hide()
  t.falsy(client.ns.editModeActive)
  t.falsy(client.env.CooldownViewerSettings:IsShown())
  t.falsy(barShown(client))
end)

t.test("/cbm in combat defers entering until combat ends", function()
  local client = loggedIn()
  client.inCombat = true
  client.slash("")
  t.falsy(client.ns.editModeActive)
  t.eq(client.lastPrint(), "|cffffd200CoolBarFrame:|r Edit mode opens when combat ends.")
  client.inCombat = false
  client.event("PLAYER_REGEN_ENABLED")
  t.truthy(client.ns.editModeActive)
  t.truthy(client.env.CooldownViewerSettings:IsShown())
end)

t.test("a second /cbm in combat cancels the pending enter", function()
  local client = loggedIn()
  client.inCombat = true
  client.slash("")
  client.slash("")
  t.eq(client.lastPrint(), "|cffffd200CoolBarFrame:|r Edit mode won't open after combat.")
  client.inCombat = false
  client.event("PLAYER_REGEN_ENABLED")
  t.falsy(client.ns.editModeActive)
  t.falsy(client.env.CooldownViewerSettings:IsShown())
end)

t.test("click-through set during combat is applied when combat ends, even mid-encounter", function()
  local client = loggedIn()
  client.inCombat = true
  client.event("ADDON_RESTRICTION_STATE_CHANGED", ENCOUNTER, 2)
  client.slash("new")
  local newBar
  for _, bar in ipairs(client.bars()) do
    if bar.name == "customBar1" then newBar = bar end
  end
  t.eq(newBar.propagateClicks, nil, "deferred in combat")
  client.inCombat = false
  client.event("PLAYER_REGEN_ENABLED")
  t.eq(newBar.propagateClicks, true)
end)

t.test("a reload during an encounter keeps edit mode closed until it ends", function()
  local client = t.newClient({ savedData = { version = 2, bars = { { name = "customBar0" } } } })
  client.restrictionStates[ENCOUNTER] = 2
  client.login()
  client.slash("")
  t.falsy(client.ns.editModeActive)
  t.falsy(client.env.CooldownViewerSettings:IsShown())
  client.restrictionStates[ENCOUNTER] = 0
  client.event("ADDON_RESTRICTION_STATE_CHANGED", ENCOUNTER, 0)
  t.truthy(client.ns.editModeActive)
end)

t.test("an activating combat restriction closes edit mode before lockdown", function()
  local client = loggedIn()
  client.slash("")
  client.event("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, 1)
  t.falsy(client.ns.editModeActive)
  t.falsy(client.env.CooldownViewerSettings:IsShown())
  t.eq(client.blockedActions, 0)
end)
