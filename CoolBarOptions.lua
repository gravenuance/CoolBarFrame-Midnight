local _, CBM = ...

local WINDOW_WIDTH, WINDOW_HEIGHT = 300, 450
local WINDOW_PADDING = 20
local ZERO_BUTTON_WIDTH = 25

local sliderTypes = {
  absolute = 0,
  floating = 1,
}

CBM.OptionsFrame = CreateFrame("Frame", "CBMOptionsFrame", UIParent)
local Options = CBM.OptionsFrame

Options:SetToplevel(true)
Options:SetFrameStrata("HIGH")
Options.options = {}
Options:Hide()

hooksecurefunc(Options, "Hide", function()
  if CBM.editModeActive and CBM.ToggleEditMode then
    CBM.ToggleEditMode()
  end
end)

local backdrop = Options:CreateTexture("ARTWORK")
backdrop:SetAllPoints()
backdrop:SetColorTexture(0, 0, 0, .8)

Options:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 300, -300)
Options:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
tinsert(UISpecialFrames, Options:GetName())

Options:EnableMouse(true)
Options:SetMovable(true)
Options:RegisterForDrag("LeftButton")
Options:SetScript("OnMouseDown", function(self, btn)
  if btn == "LeftButton" then self:StartMoving() end
end)
Options:SetScript("OnMouseUp", function(self, btn)
  if btn == "LeftButton" then self:StopMovingOrSizing() end
end)

local titleText = Options:CreateFontString(nil, "ARTWORK", "GameFontNormal")
titleText:SetPoint("TOP", Options, 0, -6)
local fontPath, _, fontFlags = titleText:GetFont()
titleText:SetFont(fontPath, 18, fontFlags)
Options.titleText = titleText

local closebutton = CreateFrame("Button", "$parentButtonClose", Options, "UIPanelButtonTemplate")
closebutton:SetText("Close")
closebutton:SetSize(80, 20)
closebutton:SetPoint("BOTTOM", 0, 10)
closebutton:SetScript("OnClick", function()
  if CBM.ToggleEditMode then
    CBM.ToggleEditMode()
  else
    Options:Hide()
  end
end)

-- Help window
local HELP_FRAME_WIDTH, HELP_FRAME_HEIGHT = 250, 230
local HELP_FRAME_PADDING = 10

local helpWindow = CreateFrame("Frame", "$parentHelpFrame", Options)
helpWindow:SetPoint("TOPLEFT", Options, "TOPRIGHT", 10, 0)
helpWindow:SetSize(HELP_FRAME_WIDTH, HELP_FRAME_HEIGHT)
helpWindow:Hide()

helpWindow.backdrop = helpWindow:CreateTexture("ARTWORK")
helpWindow.backdrop:SetAllPoints()
helpWindow.backdrop:SetColorTexture(0, 0, 0, .8)

helpWindow.titleText = helpWindow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
helpWindow.titleText:SetPoint("TOP", helpWindow, "TOP", 0, -6)
helpWindow.titleText:SetText("Info")
helpWindow.titleText:SetFont(fontPath, 18, fontFlags)

helpWindow.textContent = helpWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
helpWindow.textContent:SetPoint("TOPLEFT", helpWindow, "TOPLEFT", HELP_FRAME_PADDING, -30)
helpWindow.textContent:SetSize(HELP_FRAME_WIDTH - HELP_FRAME_PADDING * 2, HELP_FRAME_HEIGHT - 30)
helpWindow.textContent:SetFont(fontPath, 12, fontFlags)
helpWindow.textContent:SetJustifyH("LEFT")
helpWindow.textContent:SetJustifyV("TOP")
helpWindow.textContent:SetWordWrap(true)
helpWindow.textContent:SetText([[/cbm - Toggle config mode]])

local helpButton = CreateFrame("Button", "$parentHelpButton", Options, "MainHelpPlateButton")
helpButton:ClearAllPoints()
helpButton:SetPoint("CENTER", Options, "TOPRIGHT", -8, -8)
helpButton:SetScript("OnClick", function()
  if helpWindow:IsVisible() then
    helpWindow:Hide()
  else
    helpWindow:Show()
  end
end)

-- Update notification
local updateNotification = CreateFrame("Frame", "$parentUpdateNotification", Options)
Options.updateNotification = updateNotification
updateNotification:SetPoint("BOTTOM", Options, "TOP", 0, 10)
updateNotification:SetSize(WINDOW_WIDTH, 40)
updateNotification.backdrop = updateNotification:CreateTexture("ARTWORK")
updateNotification.backdrop:SetAllPoints()
updateNotification.backdrop:SetColorTexture(0, 0, 0, .8)
updateNotification:Hide()

updateNotification.textContent = updateNotification:CreateFontString(nil, "OVERLAY", "GameFontNormal")
updateNotification.textContent:SetPoint("TOPLEFT", updateNotification, "TOPLEFT", HELP_FRAME_PADDING, -
  HELP_FRAME_PADDING)
updateNotification.textContent:SetFont(fontPath, 12, fontFlags)
updateNotification.textContent:SetJustifyH("LEFT")
updateNotification.textContent:SetJustifyV("TOP")
updateNotification.textContent:SetWordWrap(true)

function updateNotification:SetWindowSize(size)
  self:SetHeight(size)
  self.textContent:SetSize(HELP_FRAME_WIDTH - HELP_FRAME_PADDING * 2, size - HELP_FRAME_PADDING * 2)
end

updateNotification.closeButton = CreateFrame("Button", "$parentCloseButton", updateNotification,
  "UIPanelCloseButtonNoScripts")
updateNotification.closeButton:SetPoint("TOPRIGHT", updateNotification, "TOPRIGHT", -2, -2)
updateNotification.closeButton:SetScript("OnClick", function()
  updateNotification:Hide()
end)

-- Hint text
local hint = CreateFrame("Frame", "$parentHint", Options)
Options.hint = hint
hint:SetPoint("TOP", Options, "BOTTOM", 0, -10)
hint:SetSize(WINDOW_WIDTH, 40)
hint.backdrop = hint:CreateTexture("ARTWORK")
hint.backdrop:SetAllPoints()
hint.backdrop:SetColorTexture(0, 0, 0, .8)
hint:Hide()

hint.text = hint:CreateFontString(nil, "ARTWORK", "GameFontNormal")
hint.text:SetPoint("TOP", hint, "TOP", 0, -8)
hint.text:SetSize(WINDOW_WIDTH - 16, 24)
hint.text:SetJustifyH("LEFT")
hint.text:SetJustifyV("TOP")
hint.text:SetWordWrap(true)
hint.text:SetText("Ctrl + Left Click an icon to add or remove it from this bar.")

-------------------------------------------------
-- ACTIVE BARS HELPERS
-------------------------------------------------

local function GetActiveBarsForMulti()
  local bars = {}

  if CBM and CBM.selectedBars then
    for bar in CBM.BarFramePool:EnumerateActive() do
      if CBM.selectedBars[bar.settings.name] then
        table.insert(bars, bar)
      end
    end
    if CBM.GetTableSize(bars) >= 2 then
      return bars
    end
  end

  local focused = CBM.GetFocusedBar and CBM.GetFocusedBar()
  if focused then
    return { focused }
  end

  return nil
end

local function GetPrimaryBar()
  local focused = CBM.GetFocusedBar()
  if focused then
    return focused
  end

  if CBM and CBM.selectedBars then
    for bar in CBM.BarFramePool:EnumerateActive() do
      if CBM.selectedBars[bar.settings.name] then
        return bar
      end
    end
  end

  return nil
end

-------------------------------------------------
-- SLIDERS
-------------------------------------------------

local function SliderIsScale(self)
  local n = self:GetName() or ""
  return n:find("ScaleSliderContainer", 1, true)
end

local function SliderIsPadding(self)
  local n = self:GetName() or ""
  return n:find("PaddingSliderContainer", 1, true)
end

function Options:CreateSlider(name, type, min, max, step, zeroButton)
  local slider = CreateFrame("Frame", name .. "SliderContainer", self)
  slider:SetSize(WINDOW_WIDTH - WINDOW_PADDING * 2, 30)

  slider.type = type
  if type == sliderTypes.floating then
    slider.float = min
  else
    slider.minValue = min
    slider.maxValue = max
  end

  slider.sliderMode = true

  local sliderContainer = CreateFrame("Frame", "$parentSliderContainer", slider)
  sliderContainer:SetPoint("BOTTOMLEFT", slider, 0, 2)
  sliderContainer:SetSize(slider:GetWidth() - (zeroButton and (ZERO_BUTTON_WIDTH + WINDOW_PADDING / 2) or 0), 30)

  local sliderTrack = CreateFrame("Frame", name .. "Slider", sliderContainer)
  sliderTrack.tex = sliderTrack:CreateTexture("ARTWORK")
  sliderTrack.tex:SetAllPoints()
  sliderTrack.tex:SetColorTexture(.2, .2, .2, .5)
  sliderTrack:SetSize(sliderContainer:GetWidth(), 10)
  sliderTrack:SetPoint("BOTTOMLEFT", sliderContainer, 0, 2)

  local handle = CreateFrame("Frame", name .. "Handle", sliderTrack)
  handle.tex = handle:CreateTexture("ARTWORK")
  handle.tex:SetAllPoints()
  handle.tex:SetColorTexture(.5, .5, .5)
  handle:SetSize(10, 18)
  handle:SetPoint("CENTER", sliderTrack, "CENTER", 0, 0)
  handle.precision = CBM.GetRoundingPrecision and CBM.GetRoundingPrecision(step) or 0

  sliderContainer:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and slider.sliderMode then
      handle.isMoving = true
    elseif button == "RightButton" and not handle.isMoving then
      slider:ToggleSliderMode()
    end
  end)

  sliderContainer:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      handle.isMoving = false
      if slider.type == sliderTypes.floating then
        slider:FloatingRecenter()
      end
    end
  end)

  sliderContainer:SetScript("OnMouseWheel", function(self, direction)
    slider:SetValue(slider:GetOptionValue() + (direction * (step or 1)), true)
  end)

  sliderContainer:SetScript("OnUpdate", function(self)
    if not handle.isMoving then return end

    local left, width = sliderTrack:GetLeft(), sliderTrack:GetWidth()

    -- Early exit if we don't have valid dimensions
    if not left or width <= 0 then return end

    local scale = sliderTrack:GetEffectiveScale()
    local x = GetCursorPosition() / scale

    -- Calculate position relative to track, clamped to bounds
    local pos = x - left
    if pos < 0 then pos = 0 end
    if pos > width then pos = width end

    handle:SetPoint("CENTER", sliderTrack, "LEFT", pos, 0)

    -- Update value for absolute sliders
    if slider.type == sliderTypes.absolute then
      local newValue = slider.minValue + (pos / width) * (slider.maxValue - slider.minValue)
      newValue = tonumber(string.format("%." .. handle.precision .. "f", newValue))

      if newValue ~= slider:GetOptionValue() then
        slider:SetValue(newValue, false)
      end
    elseif slider.type == sliderTypes.floating then
      local newValue = slider.minValue + (pos / width) * (slider.maxValue - slider.minValue)
      newValue = tonumber(string.format("%." .. handle.precision .. "f", newValue))

      if newValue ~= slider:GetOptionValue() then
        slider:SetValue(newValue, false)
      end
    end
  end)

  sliderContainer.titleText = sliderContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sliderContainer.titleText:SetPoint("TOPLEFT", sliderContainer, "TOPLEFT", 0, 0)
  sliderContainer.titleText:SetText(name)

  sliderContainer.valueText = sliderContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  sliderContainer.valueText:SetPoint("BOTTOMRIGHT", sliderTrack, "TOPRIGHT", 0, 6)
  sliderContainer.valueText:SetText("0")

  local editBox = CreateFrame("EditBox", name .. "EditBox", slider, "InputBoxTemplate")
  slider.editBox = editBox
  editBox:SetSize(60, 30)
  editBox:ClearAllPoints()
  editBox:SetPoint("BOTTOM", slider, "BOTTOM", 2, 0)
  editBox:SetText("0")
  editBox:SetAutoFocus(false)
  editBox:SetPropagateMouseClicks(true)

  local function CommitText(self)
    local number = CBM.Logic.ParseNumber(self:GetText())
    if number then
      slider:SetValue(number, true)
    else
      self:SetText(slider:GetOptionValue())
    end
  end

  editBox:SetScript("OnEditFocusLost", CommitText)

  editBox:SetScript("OnEnterPressed", function(self)
    CommitText(self)
    self:ClearFocus()
  end)

  editBox:Hide()

  if zeroButton then
    slider.zeroButton = CreateFrame("Button", "$parentZeroButton", slider, "UIPanelButtonTemplate")
    slider.zeroButton:SetText("0")
    slider.zeroButton:SetSize(ZERO_BUTTON_WIDTH, ZERO_BUTTON_WIDTH)
    slider.zeroButton:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    slider.zeroButton:SetPropagateMouseClicks(false)
    slider.zeroButton:SetScript("OnClick", function()
      slider:SetValue(0, true)
    end)
  end

  function slider:GetOptionValue()
    -- Single-bar read, like old CMI
    local bar = GetPrimaryBar()
    if not bar or not self.option then return 0 end
    return bar.settings[self.option] or 0
  end

  function slider:SetOptionValue(value)
    if not self.option then return end
    if SliderIsScale(self) or SliderIsPadding(self) then
      -- Multi-edit scale and padding
      local bars = GetActiveBarsForMulti()
      if not bars then return end
      for _, bar in ipairs(bars) do
        bar.settings[self.option] = value
        if CBM.UpdateBar then
          CBM.UpdateBar(bar)
        end
      end
    else
      -- Single-bar for everything else
      local bar = GetPrimaryBar()
      if not bar then return end
      bar.settings[self.option] = value
      if CBM.UpdateBar then
        CBM.UpdateBar(bar)
      end
    end
  end

  function slider:BindOption(option)
    self.option = option
  end

  function slider:SetValue(value, setHandle)
    if not value then return end
    value = tonumber(value)

    if self.type == sliderTypes.absolute then
      if value < self.minValue then value = self.minValue end
      if value > self.maxValue then value = self.maxValue end
    end

    if value == self:GetOptionValue() and not setHandle then
      return
    end
    self:SetOptionValue(value)
    sliderContainer.valueText:SetText(value)
    slider.editBox:SetText(value)

    if setHandle and self.type == sliderTypes.absolute then
      local width = sliderTrack:GetWidth()
      local pos = (value - self.minValue) / (self.maxValue - self.minValue) * width
      handle:SetPoint("CENTER", sliderTrack, "LEFT", pos, 0)
    elseif setHandle and self.type == sliderTypes.floating and not handle.isMoving then
      self:FloatingRecenter(value)
    end
  end

  function slider:FloatingRecenter(value)
    value = value or self:GetOptionValue()
    self.minValue = value - self.float
    self.maxValue = value + self.float

    local width = sliderTrack:GetWidth()
    local pos = (value - self.minValue) / (self.maxValue - self.minValue) * width
    handle:SetPoint("CENTER", sliderTrack, "LEFT", pos, 0)
  end

  function slider:ToggleSliderMode()
    if self.sliderMode then
      sliderTrack:Hide()
      sliderContainer.valueText:Hide()
      sliderContainer:SetPropagateMouseClicks(true)
      editBox:Show()
      editBox:SetFocus()
    else
      editBox:Hide()
      sliderContainer.valueText:Show()
      sliderContainer:SetPropagateMouseClicks(false)
      sliderTrack:Show()
    end
    self.sliderMode = not self.sliderMode
  end

  slider:Show()
  return slider
end

-------------------------------------------------
-- TEXTBOX / ANCHOR SELECT / SWAPPER / BUTTON
-------------------------------------------------

function Options:CreateTextBox(name)
  local textBox = CreateFrame("Frame", name .. "TextBoxContainer", Options)
  textBox:SetSize(WINDOW_WIDTH - WINDOW_PADDING * 2, 40)

  local editBox = CreateFrame("EditBox", name .. "EditBox", textBox, "InputBoxTemplate")
  textBox.editBox = editBox
  editBox:SetSize(150, 40)
  editBox:ClearAllPoints()
  editBox:SetPoint("BOTTOM", textBox, "BOTTOM", 0, -10)
  editBox:SetAutoFocus(false)
  editBox:SetCursorPosition(0)

  textBox.titleText = textBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  textBox.titleText:SetPoint("TOPLEFT", textBox, "TOPLEFT", 0, 0)
  textBox.titleText:SetText(name)

  editBox:SetScript("OnEditFocusLost", function(self)
    self:SetValueFromInput()
  end)

  editBox:SetScript("OnEnterPressed", function(self)
    self:SetValueFromInput()
  end)

  function editBox:SetValueFromInput()
    local val = self:GetText()
    textBox:SetValue(val)
    local bar = GetPrimaryBar()
    if bar and CBM.UpdateBar then
      CBM.UpdateBar(bar)
    end
  end

  function textBox:GetOptionValue()
    local bar = GetPrimaryBar()
    if not bar or not self.option then return "" end
    return bar.settings[self.option] or ""
  end

  function textBox:SetOptionValue(value)
    local bar = GetPrimaryBar()
    if not bar or not self.option then return end
    bar.settings[self.option] = value
  end

  function textBox:BindOption(option)
    self.option = option
  end

  function textBox:SetValue(newAnchor)
    if not newAnchor or newAnchor == "" then return end

    if CBM.GetFrameFromName and not CBM.GetFrameFromName(newAnchor) then
      self.editBox:SetText(self:GetOptionValue())
      return
    end

    local bar = GetPrimaryBar()
    if bar and CBM.RejectAnchorLoop(bar.settings.name, newAnchor) then
      self.editBox:SetText(self:GetOptionValue())
      return
    end

    self.editBox:SetText(newAnchor)
    self.editBox:SetCursorPosition(0)
    self:SetOptionValue(newAnchor)
  end

  textBox:Show()
  return textBox
end

function Options:CreateButton(name, callback)
  local button = CreateFrame("Button", name .. "Button", Options, "UIPanelButtonTemplate")
  button:SetText(name)
  button:SetSize(120, 26)
  button:SetScript("OnClick", callback)
  return button
end

function Options:CreateAnchorSelect(name)
  local width = (WINDOW_WIDTH - 180) / 2
  local points = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER" }

  local selector = CreateFrame("Frame", name .. "Selector", Options)
  selector:SetSize(width, 60)

  selector.titleText = selector:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  selector.titleText:SetPoint("TOP", selector, "TOP", 0, 0)
  selector.titleText:SetText(name)

  selector.pointContainer = CreateFrame("Frame", name .. "PointContainer", selector)
  selector.pointContainer:SetSize(width, width)
  selector.pointContainer:SetPoint("BOTTOM", selector, "BOTTOM", 0, -20)

  selector.points = {}

  for _, point in pairs(points) do
    local a = CreateFrame("Frame", name .. "Selector" .. point, selector)
    selector.points[point] = a
    a.value = point
    a.selected = false

    a.tex = a:CreateTexture("ARTWORK")
    a.tex:SetAllPoints()
    a.tex:SetColorTexture(.5, .5, .5)
    a:SetSize(14, 14)
    a:SetPoint(point, selector.pointContainer, point, 0, 0)
    a:EnableMouse(true)

    a:SetScript("OnEnter", function()
      if a.selected then return end
      a.tex:SetColorTexture(.3, .3, .3)
    end)

    a:SetScript("OnLeave", function()
      if a.selected then return end
      a.tex:SetColorTexture(.5, .5, .5)
    end)

    a:SetScript("OnMouseDown", function(self, button)
      if a.selected or button ~= "LeftButton" then return end
      selector:SetValue(a.value)
      local bar = GetPrimaryBar()
      if bar and CBM.UpdateBar then
        CBM.UpdateBar(bar)
      end
    end)
  end

  function selector:GetOptionValue()
    local bar = GetPrimaryBar()
    if not bar or not self.option then return "CENTER" end
    return bar.settings[self.option] or "CENTER"
  end

  function selector:SetOptionValue(value)
    local bar = GetPrimaryBar()
    if not bar or not self.option then return end
    bar.settings[self.option] = value
  end

  function selector:BindOption(option)
    self.option = option
  end

  function selector:SetValue(value)
    for p, a in pairs(self.points) do
      if a.selected then
        a.selected = false
        a.tex:SetColorTexture(.5, .5, .5)
      end
      if p == value then
        a.selected = true
        a.tex:SetColorTexture(0, .5, .5)
      end
    end
    self:SetOptionValue(value)
  end

  selector:Show()
  return selector
end

function Options:CreateSwapper(label, trueText, falseText)
  local width, height = WINDOW_WIDTH - WINDOW_PADDING * 2, 30
  local padding = 5

  local swapper = CreateFrame("Frame", label .. "Swapper", Options)
  swapper:SetSize(width, height)

  swapper.labelText = swapper:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  swapper.labelText:SetPoint("LEFT", swapper, "LEFT", 0, 0)
  swapper.labelText:SetSize(width / 2 - padding, height)
  swapper.labelText:SetJustifyH("RIGHT")
  swapper.labelText:SetText(label .. ":")

  swapper.button = CreateFrame("Button", "$parentButton", swapper, "UIPanelButtonTemplate")
  swapper.button:SetSize(width / 2 - padding, height - padding)
  swapper.button:SetPoint("RIGHT", swapper, "RIGHT", 0, 0)
  swapper.button:SetPropagateMouseClicks(false)

  function swapper:GetOptionValue()
    local bar = GetPrimaryBar()
    if not bar or not self.option then return true end
    if bar.settings[self.option] == nil then return true end
    return bar.settings[self.option]
  end

  function swapper:SetOptionValue(value)
    local bar = GetPrimaryBar()
    if not bar or not self.option then return end
    bar.settings[self.option] = value
  end

  function swapper:BindOption(option)
    self.option = option
  end

  function swapper:SetValue(value)
    self:SetOptionValue(value)
    swapper.button:SetText(value and trueText or falseText)
  end

  swapper.button:SetScript("OnClick", function()
    swapper:SetValue(not swapper:GetOptionValue())
    local bar = GetPrimaryBar()
    if bar and CBM.UpdateBar then
      CBM.UpdateBar(bar)
    end
  end)

  swapper:Show()
  return swapper
end

-------------------------------------------------
-- UPDATE & SETUP
-------------------------------------------------

function Options:UpdateOptions()
  local bars  = GetActiveBarsForMulti()
  local count = CBM.GetTableSize and CBM.GetTableSize(bars) or (bars and #bars or 0)
  local multi = bars and count > 1

  if not bars then
    for _, option in pairs(Options.options) do option:Hide() end
    Options.titleText:SetText("Create or select a bar.")
    Options.hint:Hide()
    return
  end

  local focusedBar = bars and bars[1]

  if focusedBar and focusedBar.displayedIcons and #focusedBar.displayedIcons > 0 then
    Options.hint:Show()
  else
    Options.hint:Hide()
  end

  for _, option in pairs(Options.options) do
    option:Show()

    local name      = option:GetName() or ""
    local isScale   = name:find("ScaleSliderContainer", 1, true)
    local isPadding = name:find("PaddingSliderContainer", 1, true)

    if multi and not (isScale or isPadding) then
      option:EnableMouse(false)
      option:SetAlpha(0.3)
    else
      option:EnableMouse(true)
      option:SetAlpha(1)
    end

    if option.SetValue and option.GetOptionValue then
      option:SetValue(option:GetOptionValue(), true)
    end
  end

  if multi then
    Options.titleText:SetText("Multi-bar: Padding & Scale")
  elseif focusedBar then
    Options.titleText:SetText(focusedBar:GetName() .. " Options")
  end
end

function CBM.SetupOptionsUI()
  local scaleSlider = Options:CreateSlider("Scale", sliderTypes.absolute, .001, 5, .05)
  tinsert(Options.options, scaleSlider)
  scaleSlider:BindOption("scale")
  scaleSlider:SetPoint("TOP", titleText, "BOTTOM", 0, -10)

  local offsetXSlider = Options:CreateSlider("Offset X", sliderTypes.floating, 40, nil, nil, true)
  tinsert(Options.options, offsetXSlider)
  offsetXSlider:BindOption("offsetX")
  offsetXSlider:SetPoint("TOP", scaleSlider, "BOTTOM", 0, -10)

  local offsetYSlider = Options:CreateSlider("Offset Y", sliderTypes.floating, 40, nil, nil, true)
  tinsert(Options.options, offsetYSlider)
  offsetYSlider:BindOption("offsetY")
  offsetYSlider:SetPoint("TOP", offsetXSlider, "BOTTOM", 0, -10)

  local paddingSlider = Options:CreateSlider("Padding", sliderTypes.floating, 10)
  tinsert(Options.options, paddingSlider)
  paddingSlider:BindOption("padding")
  paddingSlider:SetPoint("TOP", offsetYSlider, "BOTTOM", 0, -10)

  local orientationSwapper = Options:CreateSwapper("Orientation", "Horizontal", "Vertical")
  tinsert(Options.options, orientationSwapper)
  orientationSwapper:BindOption("isHorizontal")
  orientationSwapper:SetPoint("TOP", paddingSlider, "BOTTOM", 0, -10)

  local anchorTextBox = Options:CreateTextBox("Anchor Target")
  tinsert(Options.options, anchorTextBox)
  anchorTextBox:BindOption("anchorTarget")
  anchorTextBox:SetPoint("TOP", orientationSwapper, "BOTTOM", 0, -10)

  local anchorTargetSelect = Options:CreateAnchorSelect("Anchor Point")
  tinsert(Options.options, anchorTargetSelect)
  anchorTargetSelect:BindOption("anchorPoint")
  anchorTargetSelect:SetPoint("TOPLEFT", anchorTextBox, "BOTTOMLEFT", 0, -10)

  local targetPointSelect = Options:CreateAnchorSelect("Target Point")
  tinsert(Options.options, targetPointSelect)
  targetPointSelect:BindOption("targetPoint")
  targetPointSelect:SetPoint("TOPRIGHT", anchorTextBox, "BOTTOMRIGHT", 0, -10)

  local newBarButton = Options:CreateButton("New Bar", function()
    if CBM.NewBar then CBM.NewBar() end
  end)
  newBarButton:SetPoint("TOPLEFT", anchorTargetSelect, "BOTTOMLEFT", 0, -30)

  local deleteBarButton = Options:CreateButton("Delete Bar", function()
    if CBM.DeleteFocusedBar then CBM.DeleteFocusedBar() end
  end)
  deleteBarButton:SetPoint("TOPRIGHT", targetPointSelect, "BOTTOMRIGHT", 0, -30)

  if CBM.updateMessage then
    local notif = Options.updateNotification
    notif:Show()
    notif.textContent:SetText(CBM.updateMessage)
    notif:SetWindowSize(CBM.updateLength or 40)
  end

  if not (CBM.GetFocusedBar and CBM.GetFocusedBar()) then
    Options:UpdateOptions()
  end
end
