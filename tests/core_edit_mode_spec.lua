local t = ...

-- Edit mode as wired in Core.lua, driven through the fake client's Cooldown Manager window and events.

local COMBAT = 0

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

t.test("an activating combat restriction closes edit mode before lockdown", function()
  local client = loggedIn()
  client.slash("")
  client.event("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, 1)
  t.falsy(client.ns.editModeActive)
  t.falsy(client.env.CooldownViewerSettings:IsShown())
  t.eq(client.blockedActions, 0)
end)
