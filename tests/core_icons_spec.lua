local t = ...

-- Icons moving between Blizzard's viewers and custom bars (Core.lua layout, CaptureIconHomes, RestoreIcon).

local function clientWithIcon(barSettings)
  barSettings.name = barSettings.name or "customBar0"
  local client = t.newClient({ savedData = { version = 2, bars = { barSettings } } })
  local viewer = client.env.EssentialCooldownViewer
  local icon = client.addIcon(viewer, 101)
  viewer:Layout()
  client.login()
  return client, client.bars()[1], icon, viewer
end

t.test("an icon on a bar is anchored to the bar and scaled by its viewer kind", function()
  local _, bar, icon = clientWithIcon({ icons = { 101 }, scale = 2 })
  t.eq(#bar.displayedIcons, 1)
  t.truthy(bar.displayedIcons[1] == icon)
  t.truthy(icon.points[1].relativeTo == bar, "anchored to the bar")
  t.eq(icon.scale, 1.6) -- essential icons are 0.8 of the bar scale
end)

t.test("a saved scale of 0 still lays the icon out at the minimum scale", function()
  local _, bar, icon = clientWithIcon({ icons = { 101 }, scale = 0 })
  t.eq(#bar.displayedIcons, 1, "icons on the bar")
  t.truthy(math.abs(icon.scale - 0.04) < 1e-9, "0.05 x 0.8, got " .. icon.scale)
end)

t.test("removing an icon puts it back where Blizzard last placed it, at normal size", function()
  local client, _, icon, viewer = clientWithIcon({ icons = { 101 } })
  client.slash("")
  client.keys.ctrl = true
  client.ns.AddOrRemoveIcon(icon, "LeftButton")
  t.truthy(icon.points[1].relativeTo == viewer, "anchored to its viewer")
  t.eq(icon.points[1].point, "TOPLEFT")
  t.eq(icon.points[1].x, 0)
  t.eq(icon.scale, 1)
  t.eq(icon.alpha, 1)
  t.eq(icon.ChargeCount.scale, 1)
end)
