local t = ...

-- Saved data the addon can't upgrade (newer schema, failed migration) is shown but never written.

local function newerData()
  return {
    version = 99,
    bars = {
      { name = "customBar0", scale = 0, anchorTarget = "customBar1", futureField = { 1, 2 } },
      { name = "customBar1", anchorTarget = "customBar0" },
    },
  }
end

local function deepCopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for k, v in pairs(value) do copy[k] = deepCopy(v) end
  return copy
end

local function loadWith(savedData, breakMigration)
  local client = t.newClient({ savedData = savedData })
  if breakMigration then
    client.ns.Logic.MIGRATIONS[1] = function() error("broken") end
  end
  client.login()
  return client
end

t.test("newer saved data is left exactly as it was after setup", function()
  local client = loadWith(newerData())
  t.eq(client.env.CoolBarDB, newerData())
end)

t.test("newer saved data still shows its bars, completed from the defaults", function()
  local client = loadWith(newerData())
  local bars = client.bars()
  t.eq(#bars, 2)
  t.eq(bars[1].settings.padding, 0)
  t.eq(bars[1].settings.scale, 0.05)
end)

t.test("edit mode does not open for newer saved data, and says why", function()
  local client = loadWith(newerData())
  client.slash("")
  t.falsy(client.ns.editModeActive)
  t.eq(client.lastPrint(), "|cffffd200CoolBarFrame:|r your saved data is from a newer version of the addon, " ..
    "so bars can't be edited.")
  client.env.ShowUIPanel(client.env.CooldownViewerSettings)
  t.falsy(client.ns.editModeActive)
  t.falsy(client.bars()[1]:IsShown())
end)

t.test("/cbm new, delete and reset change nothing in newer saved data", function()
  local client = loadWith(newerData())
  client.slash("new")
  client.slash("delete")
  client.slash("reset")
  t.eq(#client.bars(), 2)
  t.eq(client.env.CoolBarDB, newerData())
end)

t.test("a failed migration leaves the saved data as it was, loops included", function()
  local old = { version = 1, bars = deepCopy(newerData().bars) }
  local client = loadWith(deepCopy(old), true)
  t.eq(client.env.CoolBarDB, old)
  client.slash("")
  t.falsy(client.ns.editModeActive)
end)
