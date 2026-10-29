local _, CBM = ...

local Logic = CBM.Logic

-------------------------------------------------
-- DESIGN TOKENS
-------------------------------------------------

-- Every size and colour of the options frame is defined here; widgets never use literals.
local UI = {
  FRAME_WIDTH    = 380,
  FRAME_CHROME   = 28, -- Blizzard's title bar above the inset (24) plus its bottom edge (4)
  INSET_SIDES    = 10, -- Blizzard's inset border, left (4) plus right (6)
  PAD            = 12,
  HEADER_HEIGHT  = 16,
  ROW_HEIGHT     = 24,
  ROW_GAP        = 6,
  SECTION_GAP    = 14,
  LABEL_WIDTH    = 92,
  CONTROL_GAP    = 6,
  EDIT_WIDTH     = 56,
  EDIT_HEIGHT    = 22,
  SQUARE_BUTTON  = 24,
  BUTTON_WIDTH   = 120,
  BUTTON_HEIGHT  = 24,
  SWAP_WIDTH     = 140,
  CELL           = 18,
  CELL_GAP       = 4,
  VIEWER_GAP     = 48, -- clears the Cooldown Manager window's side tabs
  DEFAULT_X      = 300,
  DEFAULT_Y      = -300,
  DISABLED_ALPHA = 0.5,
  HINT_SIZE      = 24,
}
UI.CONTENT_WIDTH = UI.FRAME_WIDTH - UI.INSET_SIDES - UI.PAD * 2
UI.GRID_SIZE = UI.CELL * 3 + UI.CELL_GAP * 2

local COLORS = {
  cell       = { 0.12, 0.12, 0.12, 1 },
  cellBorder = { 0.6, 0.6, 0.6, 1 },
  cellHover  = { 1, 1, 1, 0.25 },
}

local POINT_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local POINT_NAMES = {
  TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right",
  LEFT = "Left", CENTER = "Center", RIGHT = "Right",
  BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right",
}

-------------------------------------------------
-- FRAME SHELL
-------------------------------------------------

local Options = CreateFrame("Frame", "CoolBarFrameOptions", UIParent, "ButtonFrameTemplate")
CBM.OptionsFrame = Options
Options.options = {}

ButtonFrameTemplate_HidePortrait(Options)
ButtonFrameTemplate_HideAttic(Options)
ButtonFrameTemplate_HideButtonBar(Options)
Options:SetTitle("CoolBarFrame")

Options:SetToplevel(true)
Options:SetFrameStrata("HIGH")
Options:SetClampedToScreen(true)
Options:SetMovable(true)
Options:EnableMouse(true)
Options:RegisterForDrag("LeftButton")
Options:SetSize(UI.FRAME_WIDTH, 100)
Options:Hide()
tinsert(UISpecialFrames, Options:GetName())

hooksecurefunc(Options, "Hide", function()
  CBM.SetEditMode(false)
end)

Options:SetScript("OnDragStart", function(frame)
  frame.userPlaced = true
  frame:StartMoving()
end)
Options:SetScript("OnDragStop", function(frame)
  frame:StopMovingOrSizing()
end)

-- Until the user drags it, the frame sits beside the Cooldown Manager window.
local function PositionFrame()
  if Options.userPlaced then return end
  Options:ClearAllPoints()
  if CooldownViewerSettings and CooldownViewerSettings:IsShown() then
    Options:SetPoint("TOPLEFT", CooldownViewerSettings, "TOPRIGHT", UI.VIEWER_GAP, 0)
  else
    Options:SetPoint("TOPLEFT", UIParent, "TOPLEFT", UI.DEFAULT_X, UI.DEFAULT_Y)
  end
end

-- Core skips refreshing a hidden options frame, so catch up when it opens.
Options:HookScript("OnShow", function()
  PositionFrame()
  Options:UpdateOptions()
end)

local content = CreateFrame("Frame", nil, Options)
content:SetPoint("TOPLEFT", Options.Inset, "TOPLEFT", UI.PAD, -UI.PAD)
content:SetPoint("TOPRIGHT", Options.Inset, "TOPRIGHT", -UI.PAD, -UI.PAD)

local actions = CreateFrame("Frame", nil, Options)
actions:SetHeight(UI.BUTTON_HEIGHT)
actions:SetPoint("BOTTOMLEFT", Options.Inset, "BOTTOMLEFT", UI.PAD, UI.PAD)
actions:SetPoint("BOTTOMRIGHT", Options.Inset, "BOTTOMRIGHT", -UI.PAD, UI.PAD)

local barLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
barLabel:SetHeight(UI.HEADER_HEIGHT)
barLabel:SetJustifyH("LEFT")

local status = Options:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
status:SetPoint("TOPLEFT", Options.Inset, "TOPLEFT", UI.PAD, -UI.PAD)
status:SetText("Create or select a bar.")

-------------------------------------------------
-- BAR ACCESS
-------------------------------------------------

local function IsSelected(bar)
  return CBM.selectedBars[bar.settings.name] ~= nil
end

-- Writes one option to the bar being edited, or to every selected bar for multi-bar options.
local function ApplyOption(option, value, multi)
  if multi then
    for bar in CBM.BarFramePool:EnumerateActive() do
      if IsSelected(bar) then
        bar.settings[option] = value
        CBM.UpdateBar(bar)
      end
    end
  else
    local bar = CBM.GetFocusedBar()
    if bar then
      bar.settings[option] = value
      CBM.UpdateBar(bar)
    end
  end
  CBM.QueueUpdate("ExecuteLayout")
end

-- Gives a widget its bar-backed value; `default` is shown when no bar or no saved value exists.
local function BindOption(widget, option, default, multi)
  widget.option = option
  widget.multi = multi

  function widget:GetOptionValue()
    local bar = CBM.GetFocusedBar()
    local value = bar and bar.settings[option]
    if value == nil then return default end
    return value
  end

  function widget:SetOptionValue(value)
    ApplyOption(option, value, multi)
  end
end

-------------------------------------------------
-- SHARED CONTROLS
-------------------------------------------------

local function AttachTooltip(frame, text)
  frame:HookScript("OnEnter", function(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, text)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

local function CreateLabel(parent, text)
  local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("LEFT", parent, "LEFT", 0, 0)
  label:SetWidth(UI.LABEL_WIDTH)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

local function CreateEditBox(parent, width)
  local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  editBox:SetSize(width, UI.EDIT_HEIGHT)
  editBox:SetAutoFocus(false)
  editBox:SetMaxLetters(32)
  return editBox
end

local function SetRowEnabled(row, enabled)
  row.label:SetFontObject(enabled and "GameFontNormal" or "GameFontDisable")
  for _, control in ipairs(row.controls) do
    control:SetEnabled(enabled)
    control:SetAlpha(enabled and 1 or UI.DISABLED_ALPHA)
  end
end

-- Escape reverts the text; Enter or leaving the box commits it, but only if the user typed something,
-- so tabbing through a box never writes its value to the bars.
local function WireEditBox(editBox, commit, revert)
  editBox:HookScript("OnTextChanged", function(box, userInput)
    if userInput then box.edited = true end
  end)
  editBox:SetScript("OnEscapePressed", function(box)
    box.cancelled = true
    box:ClearFocus()
  end)
  editBox:SetScript("OnEnterPressed", function(box)
    box:ClearFocus()
  end)
  editBox:HookScript("OnEditFocusLost", function(box)
    local edited = box.edited
    box.edited = false
    if edited and not box.cancelled then
      commit(box:GetText())
    else
      revert()
    end
    box.cancelled = false
  end)
end

-------------------------------------------------
-- SLIDER ROW
-------------------------------------------------

-- config: label, option, step, zero, multi, and either min/max (fixed range) or float (range follows the value).
local function CreateSlider(parent, config)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(UI.ROW_HEIGHT)
  row.config = config
  row.label = CreateLabel(row, config.label)
  row.precision = Logic.GetRoundingPrecision(config.step)
  BindOption(row, config.option, 0, config.multi)

  local zero
  if config.zero then
    zero = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    zero:SetSize(UI.SQUARE_BUTTON, UI.SQUARE_BUTTON)
    zero:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    zero:SetText("0")
    AttachTooltip(zero, "Set to zero")
    zero:SetScript("OnClick", function()
      row:Commit(0, true)
    end)
  end

  local editBox = CreateEditBox(row, UI.EDIT_WIDTH)
  if zero then
    editBox:SetPoint("RIGHT", zero, "LEFT", -UI.CONTROL_GAP, 0)
  else
    editBox:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  end
  row.editBox = editBox

  local holder = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
  holder:SetHeight(UI.ROW_HEIGHT)
  holder:SetPoint("LEFT", row.label, "RIGHT", UI.CONTROL_GAP, 0)
  holder:SetPoint("RIGHT", editBox, "LEFT", -UI.CONTROL_GAP, 0)
  local slider = holder.Slider
  row.holder = holder
  row.slider = slider

  slider:SetValueStep(config.step)
  slider:SetObeyStepOnDrag(true)
  if config.float then
    slider:SetMinMaxValues(-config.float, config.float)
  else
    slider:SetMinMaxValues(config.min, config.max)
  end
  slider:EnableMouseWheel(true)

  row.controls = zero and { holder, editBox, zero } or { holder, editBox }

  slider:SetScript("OnValueChanged", function(_, value)
    if row.refreshing then return end
    local rounded = tonumber(string.format("%." .. row.precision .. "f", value))
    row:Commit(rounded, false)
  end)
  slider:SetScript("OnMouseWheel", function(_, direction)
    slider:SetValue(slider:GetValue() + direction * config.step)
  end)
  -- Re-centering a floating range while the thumb is held would move it under the cursor.
  slider:HookScript("OnMouseDown", function()
    row.dragging = true
  end)
  slider:HookScript("OnMouseUp", function()
    row.dragging = false
    row:Refresh()
  end)

  WireEditBox(editBox, function(text)
    local number = Logic.ParseNumber(text)
    if number then
      row:Commit(number, true)
    else
      row:Refresh()
    end
  end, function()
    row:Refresh()
  end)

  -- The user acting: clamp, write to the bar(s) when it changes anything (or `force`), then redisplay what was stored.
  function row:Commit(requested, force)
    local value, apply = Logic.PlanSliderUpdate("input", self:GetOptionValue(), requested, config.min, config.max, force)
    if apply then
      self:SetOptionValue(value)
    end
    self:Refresh()
  end

  -- Redisplays the stored value without writing anything back to the bars.
  function row:Refresh()
    local value = self:GetOptionValue()
    self.refreshing = true
    if config.float and not self.dragging then
      slider:SetMinMaxValues(value - config.float, value + config.float)
    end
    slider:SetValue(value)
    self.refreshing = false
    if not editBox:HasFocus() then
      editBox:SetText(Logic.MinimalRound(value, 3))
      editBox:SetCursorPosition(0)
    end
  end

  function row:SetControlsEnabled(enabled)
    SetRowEnabled(self, enabled)
  end

  return row
end

-------------------------------------------------
-- ANCHOR TARGET
-------------------------------------------------

local function CreateTargetBox(parent, label, option)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(UI.ROW_HEIGHT)
  row.label = CreateLabel(row, label)
  BindOption(row, option, "", false)

  local editBox = CreateEditBox(row, UI.EDIT_WIDTH)
  editBox:SetPoint("LEFT", row.label, "RIGHT", UI.CONTROL_GAP, 0)
  editBox:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.editBox = editBox
  row.controls = { editBox }
  AttachTooltip(editBox, "Name of a bar or frame")

  WireEditBox(editBox, function(text)
    row:Commit(text)
  end, function()
    row:Refresh()
  end)

  function row:Commit(text)
    text = text:match("^%s*(.-)%s*$")
    local bar = CBM.GetFocusedBar()
    if text ~= "" and text ~= self:GetOptionValue() and bar then
      if not CBM.GetFrameFromName(text) then
        CBM.Print("No frame named " .. text .. ".")
      elseif not CBM.RejectAnchorLoop(bar.settings.name, text) then
        self:SetOptionValue(text)
      end
    end
    self:Refresh()
  end

  function row:Refresh()
    if not editBox:HasFocus() then
      editBox:SetText(self:GetOptionValue())
      editBox:SetCursorPosition(0)
    end
  end

  function row:SetControlsEnabled(enabled)
    SetRowEnabled(self, enabled)
  end

  return row
end

-------------------------------------------------
-- ANCHOR POINT GRID
-------------------------------------------------

local function CreatePointGrid(parent, label, option)
  local grid = CreateFrame("Frame", nil, parent)
  grid:SetSize(UI.GRID_SIZE, UI.HEADER_HEIGHT + UI.ROW_GAP + UI.GRID_SIZE)
  BindOption(grid, option, "CENTER", false)

  grid.label = grid:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  grid.label:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, 0)
  grid.label:SetText(label)

  grid.cells = {}
  grid.controls = {}
  local selected = { NORMAL_FONT_COLOR:GetRGB() }

  for index, point in ipairs(POINT_ORDER) do
    local cell = CreateFrame("Button", nil, grid)
    cell:SetSize(UI.CELL, UI.CELL)
    local column, rowIndex = (index - 1) % 3, math.floor((index - 1) / 3)
    cell:SetPoint("TOPLEFT", grid, "TOPLEFT", column * (UI.CELL + UI.CELL_GAP),
      -(UI.HEADER_HEIGHT + UI.ROW_GAP + rowIndex * (UI.CELL + UI.CELL_GAP)))

    local border = cell:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", cell, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(unpack(COLORS.cellBorder))
    cell.fill = cell:CreateTexture(nil, "ARTWORK")
    cell.fill:SetAllPoints()
    cell.fill:SetColorTexture(unpack(COLORS.cell))
    local hover = cell:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(COLORS.cellHover))

    AttachTooltip(cell, POINT_NAMES[point])
    cell:SetScript("OnClick", function()
      grid:SetOptionValue(point)
      grid:Refresh()
    end)

    grid.cells[point] = cell
    grid.controls[#grid.controls + 1] = cell
  end

  function grid:Refresh()
    local current = self:GetOptionValue()
    for point, cell in pairs(self.cells) do
      if point == current then
        cell.fill:SetColorTexture(unpack(selected))
      else
        cell.fill:SetColorTexture(unpack(COLORS.cell))
      end
    end
  end

  function grid:SetControlsEnabled(enabled)
    SetRowEnabled(self, enabled)
  end

  return grid
end

-------------------------------------------------
-- ORIENTATION
-------------------------------------------------

local function CreateSwapper(parent, label, option, trueText, falseText)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(UI.ROW_HEIGHT)
  row.label = CreateLabel(row, label)
  BindOption(row, option, true, false)

  local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  button:SetSize(UI.SWAP_WIDTH, UI.BUTTON_HEIGHT)
  button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  AttachTooltip(button, "Swap orientation")
  row.button = button
  row.controls = { button }

  button:SetScript("OnClick", function()
    row:SetOptionValue(not row:GetOptionValue())
    row:Refresh()
  end)

  function row:Refresh()
    button:SetText(self:GetOptionValue() and trueText or falseText)
  end

  function row:SetControlsEnabled(enabled)
    SetRowEnabled(self, enabled)
  end

  return row
end

-------------------------------------------------
-- UPDATE & SETUP
-------------------------------------------------

function Options:UpdateOptions()
  local selectedCount = CBM.GetTableSize(CBM.selectedBars)
  local focused = CBM.GetFocusedBar()

  content:SetShown(focused ~= nil)
  status:SetShown(focused == nil)
  if not focused then return end

  local multi = selectedCount > 1
  barLabel:SetText(multi and (selectedCount .. " bars selected") or focused:GetName())

  for _, option in ipairs(self.options) do
    option:SetControlsEnabled(not multi or option.multi)
    option:Refresh()
  end
end

local function CreateButton(label, tooltip, anchor, callback)
  local button = CreateFrame("Button", nil, actions, "UIPanelButtonTemplate")
  button:SetSize(UI.BUTTON_WIDTH, UI.BUTTON_HEIGHT)
  button:SetPoint(anchor, actions, anchor, 0, 0)
  button:SetText(label)
  if tooltip then AttachTooltip(button, tooltip) end
  button:SetScript("OnClick", callback)
  return button
end

local function CreateShortcutHint()
  local hint = CreateFrame("Button", nil, Options, "UIPanelInfoButton")
  hint:SetPoint("TOPRIGHT", Options, "TOPRIGHT", -UI.HINT_SIZE - UI.CONTROL_GAP, -4)
  hint:SetHitRectInsets(-4, -4, -4, -4)
  hint:HookScript("OnEnter", function(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, "Shortcuts")
    GameTooltip:AddLine("Ctrl-click an icon: add or remove it", 1, 1, 1)
    GameTooltip:AddLine("Alt-click an icon, then a target: move or swap", 1, 1, 1)
    GameTooltip:AddLine("Shift-click a bar: select several", 1, 1, 1)
    GameTooltip:AddLine("Drag a handle onto another bar: anchor", 1, 1, 1)
    GameTooltip:Show()
  end)
  hint:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

function CBM.SetupOptionsUI()
  local y = 0
  -- Stacks a widget under the previous one; widgets are full content width unless they size themselves.
  local function Place(widget, height, gap)
    y = y + gap
    widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    widget:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
    y = y + height
  end
  local function PlaceHeader(text)
    local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    header:SetHeight(UI.HEADER_HEIGHT)
    header:SetJustifyH("LEFT")
    header:SetText(text)
    Place(header, UI.HEADER_HEIGHT, UI.SECTION_GAP)
  end
  local function AddOption(widget, height, gap)
    Options.options[#Options.options + 1] = widget
    Place(widget, height, gap)
  end

  barLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  barLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  y = UI.HEADER_HEIGHT

  PlaceHeader("Layout")
  AddOption(CreateSlider(content, {
    label = "Scale", option = "scale", min = 0.05, max = 5, step = 0.05, multi = true,
  }), UI.ROW_HEIGHT, UI.ROW_GAP)
  AddOption(CreateSlider(content, {
    label = "Padding", option = "padding", float = 10, step = 1, multi = true,
  }), UI.ROW_HEIGHT, UI.ROW_GAP)
  AddOption(CreateSwapper(content, "Orientation", "isHorizontal", "Horizontal", "Vertical"),
    UI.ROW_HEIGHT, UI.ROW_GAP)

  PlaceHeader("Position")
  AddOption(CreateSlider(content, {
    label = "Offset X", option = "offsetX", float = 40, step = 1, zero = true,
  }), UI.ROW_HEIGHT, UI.ROW_GAP)
  AddOption(CreateSlider(content, {
    label = "Offset Y", option = "offsetY", float = 40, step = 1, zero = true,
  }), UI.ROW_HEIGHT, UI.ROW_GAP)

  PlaceHeader("Anchor")
  AddOption(CreateTargetBox(content, "Anchor target", "anchorTarget"), UI.ROW_HEIGHT, UI.ROW_GAP)

  local barPoint = CreatePointGrid(content, "Bar point", "anchorPoint")
  local targetPoint = CreatePointGrid(content, "Target point", "targetPoint")
  Options.options[#Options.options + 1] = barPoint
  Options.options[#Options.options + 1] = targetPoint
  y = y + UI.ROW_GAP
  barPoint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
  targetPoint:SetPoint("TOPLEFT", barPoint, "TOPRIGHT", UI.SECTION_GAP * 2, 0)
  y = y + barPoint:GetHeight()

  content:SetHeight(y)

  CreateButton("New bar", nil, "LEFT", function()
    CBM.NewBar()
  end)
  CreateButton("Delete bar", "Delete the selected bars", "RIGHT", function()
    CBM.DeleteFocusedBar()
  end)
  CreateShortcutHint()

  Options:SetHeight(UI.FRAME_CHROME + UI.PAD + y + UI.PAD + UI.BUTTON_HEIGHT + UI.PAD)

  Options:UpdateOptions()
end
