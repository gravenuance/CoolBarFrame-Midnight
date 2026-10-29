local t = ...

-- Dragging from one bar's anchor handle to another bar's handle (CoolBarFrame.lua handle scripts).

local function twoBars()
  local client = t.newClient({ savedData = { version = 2, bars = {
    { name = "customBar0" },
    { name = "customBar1", offsetX = 200 },
  } } })
  client.login()
  client.slash("")
  local bars = client.bars()
  return client, bars[1], bars[2]
end

t.test("releasing over empty space after crossing another handle does not anchor", function()
  local client, bar0, bar1 = twoBars()
  local from, over = bar0.anchorPoints.TOP, bar1.anchorPoints.BOTTOM
  client.fire(from, "OnMouseDown", "LeftButton")
  client.fire(over, "OnEnter")
  client.fire(over, "OnLeave")
  client.fire(from, "OnMouseUp", "LeftButton")
  t.eq(bar0.settings.anchorTarget, "UIParent")
  t.eq(bar0.anchorDrag, nil, "anchor line released")
end)

t.test("releasing over another bar's handle anchors to it", function()
  local client, bar0, bar1 = twoBars()
  local from, over = bar0.anchorPoints.TOP, bar1.anchorPoints.BOTTOM
  client.fire(from, "OnMouseDown", "LeftButton")
  client.fire(over, "OnEnter")
  client.fire(from, "OnMouseUp", "LeftButton")
  t.eq(bar0.settings.anchorTarget, "customBar1")
  t.eq(bar0.settings.anchorPoint, "TOP")
  t.eq(bar0.settings.targetPoint, "BOTTOM")
end)

t.test("releasing with no target set stops the anchor line", function()
  local client, bar0 = twoBars()
  client.fire(bar0.anchorPoints.TOP, "OnMouseDown", "LeftButton")
  client.fire(bar0.anchorPoints.TOP, "OnMouseUp", "LeftButton")
  t.eq(bar0.anchorDrag, nil)
end)

t.test("releasing with a modifier held stops the anchor line without anchoring", function()
  local client, bar0, bar1 = twoBars()
  local from, over = bar0.anchorPoints.TOP, bar1.anchorPoints.BOTTOM
  client.fire(from, "OnMouseDown", "LeftButton")
  client.fire(over, "OnEnter")
  client.keys.shift = true
  client.fire(from, "OnMouseUp", "LeftButton")
  t.eq(bar0.anchorDrag, nil)
  t.eq(bar0.settings.anchorTarget, "UIParent")
end)
