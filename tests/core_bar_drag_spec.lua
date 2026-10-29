local t = ...

-- Dragging a bar (CoolBarFrame.lua OnMouseDown/OnMouseUp), with its anchor target present or missing.

local function clientWithBar(settings)
  settings.name = "customBar0"
  local client = t.newClient({ savedData = { version = 2, bars = { settings } } })
  client.login()
  client.slash("")
  return client, client.bars()[1]
end

-- The client moves a frame under the cursor after StartMoving; here it is moved by dx, dy directly.
local function drag(client, bar, dx, dy)
  client.mouseFocus = bar
  client.fire(bar, "OnMouseDown", "LeftButton")
  local p = bar.points[1]
  p.x, p.y = p.x + dx, p.y + dy
  client.fire(bar, "OnMouseUp", "LeftButton")
end

local function addTarget(client, name, left, bottom)
  local frame = client.env.CreateFrame("Frame", name, client.env.UIParent)
  frame:SetSize(100, 50)
  frame:SetPoint("BOTTOMLEFT", client.env.UIParent, "BOTTOMLEFT", left, bottom)
  return frame
end

t.test("dragging an anchored bar adds the drag to its offsets from the target", function()
  local client = t.newClient({ savedData = { version = 2, bars = {
    { name = "customBar0", anchorTarget = "OtherAddonFrame", anchorPoint = "BOTTOMLEFT",
      targetPoint = "TOPLEFT", offsetX = 10, offsetY = 20 },
  } } })
  addTarget(client, "OtherAddonFrame", 200, 100)
  client.login()
  client.slash("")
  local bar = client.bars()[1]
  drag(client, bar, 30, -15)
  t.eq(bar.settings.offsetX, 40)
  t.eq(bar.settings.offsetY, 5)
  t.eq(bar:GetLeft(), 240) -- target left 200 + offset 40
end)

t.test("a bar whose target is missing stays where it is dropped", function()
  local client, bar = clientWithBar({ anchorTarget = "OtherAddonFrame", offsetX = 10, offsetY = 20,
    absoluteX = 500, absoluteY = 300 })
  t.eq(bar:GetLeft(), 500, "parked at its last screen position")
  drag(client, bar, 30, -15)
  t.eq(bar:GetLeft(), 530)
  t.eq(bar:GetBottom(), 285)
  t.eq(bar.settings.absoluteX, 530)
  t.eq(bar.settings.absoluteY, 285)
end)

t.test("dragging a bar whose target is missing keeps its saved anchor and offsets", function()
  local client, bar = clientWithBar({ anchorTarget = "OtherAddonFrame", offsetX = 10, offsetY = 20,
    absoluteX = 500, absoluteY = 300 })
  drag(client, bar, 30, -15)
  t.eq(bar.settings.anchorTarget, "OtherAddonFrame")
  t.eq(bar.settings.offsetX, 10)
  t.eq(bar.settings.offsetY, 20)
end)

t.test("anchoring a parked bar to another frame keeps it where it is on screen", function()
  local client, bar = clientWithBar({ anchorTarget = "OtherAddonFrame", offsetX = 10, offsetY = 20,
    absoluteX = 500, absoluteY = 300 })
  bar.settings.anchorTarget = "UIParent"
  client.ns.UpdateBar(bar)
  t.eq(bar:GetLeft(), 500)
  t.eq(bar:GetBottom(), 300)
  t.eq(bar.parkedFor, nil)
end)

t.test("when the missing target returns, the bar goes back to its offsets from it", function()
  local client, bar = clientWithBar({ anchorTarget = "OtherAddonFrame", anchorPoint = "BOTTOMLEFT",
    targetPoint = "BOTTOMLEFT", offsetX = 10, offsetY = 20, absoluteX = 500, absoluteY = 300 })
  drag(client, bar, 30, -15)
  addTarget(client, "OtherAddonFrame", 200, 100)
  client.ns.UpdateBar(bar)
  t.eq(bar:GetLeft(), 210)
  t.eq(bar:GetBottom(), 120)
  t.eq(bar.settings.offsetX, 10)
  t.eq(bar.settings.offsetY, 20)
end)
