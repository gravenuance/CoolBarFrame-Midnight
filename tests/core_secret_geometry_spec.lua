local t = ...

-- Frames anchored to secret geometry return secret positions and sizes, which can't be compared or used in maths.

local function clientWithSecretFrame()
  local client = t.newClient({ savedData = { version = 2, bars = {
    { name = "customBar0", anchorTarget = "SecretFrame", icons = { 101 }, offsetX = 5 },
  } } })
  local frame = client.env.CreateFrame("Frame", "SecretFrame", client.env.UIParent)
  frame:SetSize(100, 50)
  frame:SetPoint("CENTER")
  frame.anchoringSecret = true
  client.addIcon(client.env.EssentialCooldownViewer, 101)
  return client
end

t.test("anchoring to a frame with secret geometry is refused with a message", function()
  local client = clientWithSecretFrame()
  client.login()
  t.truthy(client.ns.RejectAnchorTarget("customBar0", "SecretFrame"))
  t.eq(client.lastPrint(), "|cffffd200CoolBarFrame:|r customBar0 can't anchor to SecretFrame: " ..
    "its position is secret.")
end)

t.test("anchoring to a missing frame is refused, an ordinary one allowed", function()
  local client = clientWithSecretFrame()
  client.login()
  t.truthy(client.ns.RejectAnchorTarget("customBar0", "NoSuchFrame"))
  t.eq(client.lastPrint(), "|cffffd200CoolBarFrame:|r No frame named NoSuchFrame.")
  t.falsy(client.ns.RejectAnchorTarget("customBar0", "UIParent"))
end)

t.test("a saved bar anchored to secret geometry loads and lays out its icon", function()
  local client = clientWithSecretFrame()
  client.login()
  local bar = client.bars()[1]
  t.eq(#bar.displayedIcons, 1)
  client.slash("")
  t.truthy(client.ns.editModeActive)
end)

t.test("dragging a bar anchored to secret geometry leaves it and its settings alone", function()
  local client = clientWithSecretFrame()
  client.login()
  client.slash("")
  local bar = client.bars()[1]
  client.mouseFocus = bar
  client.fire(bar, "OnMouseDown", "LeftButton")
  client.fire(bar.dragFrame, "OnUpdate", 0)
  client.fire(bar, "OnMouseUp", "LeftButton")
  client.fire(bar.anchorPoints.TOP, "OnMouseDown", "LeftButton")
  client.fire(bar.anchorPoints.TOP, "OnUpdate", 0)
  client.fire(bar.anchorPoints.TOP, "OnMouseUp", "LeftButton")
  t.eq(bar.settings.offsetX, 5)
  t.eq(bar.settings.anchorTarget, "SecretFrame")
end)
