local _, CBM = ...

local currentBarAnchorTarget
local currentBarTargetPoint

CBM.callbacks = CBM.callbacks or {}

local function GetOffsets(...)
  if CBM.callbacks.GetOffsets then
    return CBM.callbacks.GetOffsets(...)
  end
  local _, _, _, x, y = ...
  return x or 0, y or 0
end

local function GetFrameFromName(name)
  if CBM.callbacks.GetFrameFromName then
    return CBM.callbacks.GetFrameFromName(name)
  end
  return _G[name]
end

local function SafeSetFocus(bar, modifier)
  if CBM.callbacks.SetFocus then
    CBM.callbacks.SetFocus(bar, modifier)
  end
end

local function SafeUpdateBar(bar)
  if CBM.callbacks.UpdateBar then
    CBM.callbacks.UpdateBar(bar)
  end
end

local function SafeUpdateOptions()
  if CBM.callbacks.UpdateOptions then
    CBM.callbacks.UpdateOptions()
  end
end

-- Utility: trimRound, minimalRound are assumed to exist on CBM
local function trimRound(number, compare)
  if CBM.trimRound then
    return CBM.trimRound(number, compare)
  end
  return number
end

local function minimalRound(number, maxDecimals)
  if CBM.minimalRound then
    return CBM.minimalRound(number, maxDecimals)
  end
  return number
end

local function IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value)
end

function CBM.InitBarFrame(bar)
  bar:SetFrameStrata("MEDIUM")
  bar:SetFrameLevel(2)

  -- drag data
  local initRelativeX, initRelativeY
  local initDetachedX, initDetachedY
  local finalDetachedX, finalDetachedY

  bar:SetMovable(true)
  bar:EnableMouse(true)
  CBM.SetPropagateClicks(bar, true)

  bar:SetScript("OnMouseDown", function(self, button)
    local mf = GetMouseFoci and GetMouseFoci() or {}
    local isFocusedFrame = self == mf[1]

    if button ~= "LeftButton" or not isFocusedFrame then return end
    -- Skip drag if modifier keys are held (for icon operations)
    if IsAltKeyDown() then
      SafeSetFocus(self, false)
      if not CBM.PendingMoveID then
        return
      end
      if bar.displayedIcons and #bar.displayedIcons ~= 0 then
        return
      end
      CBM.MoveIconToOtherBar(nil, "LeftButton")
      return
    end

    if IsControlKeyDown() then
      return
    end

    -- Skip if already moving
    if self.isMoving then return end

    -- Capture initial positions BEFORE any SafeSetFocus calls (which can trigger UpdateBar and reposition)
    initRelativeX, initRelativeY = GetOffsets(bar:GetPoint())
    local scale = bar.anchorLine:GetEffectiveScale() or 1
    bar.dragFrame.initX, bar.dragFrame.initY = GetCursorPosition()
    bar.dragFrame.initX = bar.dragFrame.initX / scale
    bar.dragFrame.initY = bar.dragFrame.initY / scale

    -- Handle multi-select with Shift (after position capture)
    local useShift = IsShiftKeyDown() and not IsControlKeyDown() and not IsAltKeyDown()
    if useShift then
      SafeSetFocus(self, true)
      return
    end

    -- Focus bar on click (without multi-select)
    SafeSetFocus(self, false)

    -- The drop maths needs the bar's position, which is secret while it hangs off secret geometry.
    if CBM.HasSecretGeometry(self) then return end

    self:StartMoving()
    initDetachedX, initDetachedY = GetOffsets(bar:GetPoint())
    self.isMoving = true
    bar.dragFrame:Show()
  end)

  bar:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and self.isMoving then
      finalDetachedX, finalDetachedY = GetOffsets(bar:GetPoint())
      self:StopMovingOrSizing(self)
      self.isMoving = false

      local dx, dy = finalDetachedX - initDetachedX, finalDetachedY - initDetachedY
      if self.parkedFor then
        -- Only the screen position moves; the offsets from the missing target stay for when it returns.
        self.settings.absoluteX = self.settings.absoluteX + dx
        self.settings.absoluteY = self.settings.absoluteY + dy
      else
        self.settings.offsetX = initRelativeX + dx
        self.settings.offsetY = initRelativeY + dy
      end

      self:SetBarPoint(minimalRound, 2)
      SafeUpdateOptions()
      self:SetAnchorLine()
    end
  end)

  bar:SetScript("OnHide", function(self)
    if self.isMoving then
      bar.StopMovingOrSizing(self)
      self.isMoving = false
    end
  end)

  bar.dragFrame = CreateFrame("Frame")
  bar.dragFrame:Hide()
  bar.dragFrame:SetScript("OnUpdate", function(self)
    if not bar.isMoving then
      self:Hide()
      return
    end

    local x, y = GetCursorPosition()
    local scale = bar.anchorLine:GetEffectiveScale() or 1
    x = x / scale
    y = y / scale

    if bar.settings.anchorTarget then
      local anchorTarget = GetFrameFromName(bar.settings.anchorTarget)
      if anchorTarget and not CBM.HasSecretGeometry(anchorTarget) then
        -- Get absolute screen position of bar's anchor point
        local barAnchorX, barAnchorY
        if bar.settings.anchorPoint == "CENTER" then
          barAnchorX, barAnchorY = bar:GetCenter()
        elseif bar.settings.anchorPoint == "TOP" then
          barAnchorX = bar:GetCenter()
          barAnchorY = bar:GetTop()
        elseif bar.settings.anchorPoint == "BOTTOM" then
          barAnchorX = bar:GetCenter()
          barAnchorY = bar:GetBottom()
        elseif bar.settings.anchorPoint == "LEFT" then
          barAnchorX = bar:GetLeft()
          barAnchorY = select(2, bar:GetCenter())
        elseif bar.settings.anchorPoint == "RIGHT" then
          barAnchorX = bar:GetRight()
          barAnchorY = select(2, bar:GetCenter())
        elseif bar.settings.anchorPoint == "TOPLEFT" then
          barAnchorX = bar:GetLeft()
          barAnchorY = bar:GetTop()
        elseif bar.settings.anchorPoint == "TOPRIGHT" then
          barAnchorX = bar:GetRight()
          barAnchorY = bar:GetTop()
        elseif bar.settings.anchorPoint == "BOTTOMLEFT" then
          barAnchorX = bar:GetLeft()
          barAnchorY = bar:GetBottom()
        elseif bar.settings.anchorPoint == "BOTTOMRIGHT" then
          barAnchorX = bar:GetRight()
          barAnchorY = bar:GetBottom()
        end

        -- Get absolute screen position of anchor target's anchor point
        local targetAnchorX, targetAnchorY
        if bar.settings.targetPoint == "CENTER" then
          targetAnchorX, targetAnchorY = anchorTarget:GetCenter()
        elseif bar.settings.targetPoint == "TOP" then
          targetAnchorX = anchorTarget:GetCenter()
          targetAnchorY = anchorTarget:GetTop()
        elseif bar.settings.targetPoint == "BOTTOM" then
          targetAnchorX = anchorTarget:GetCenter()
          targetAnchorY = anchorTarget:GetBottom()
        elseif bar.settings.targetPoint == "LEFT" then
          targetAnchorX = anchorTarget:GetLeft()
          targetAnchorY = select(2, anchorTarget:GetCenter())
        elseif bar.settings.targetPoint == "RIGHT" then
          targetAnchorX = anchorTarget:GetRight()
          targetAnchorY = select(2, anchorTarget:GetCenter())
        elseif bar.settings.targetPoint == "TOPLEFT" then
          targetAnchorX = anchorTarget:GetLeft()
          targetAnchorY = anchorTarget:GetTop()
        elseif bar.settings.targetPoint == "TOPRIGHT" then
          targetAnchorX = anchorTarget:GetRight()
          targetAnchorY = anchorTarget:GetTop()
        elseif bar.settings.targetPoint == "BOTTOMLEFT" then
          targetAnchorX = anchorTarget:GetLeft()
          targetAnchorY = anchorTarget:GetBottom()
        elseif bar.settings.targetPoint == "BOTTOMRIGHT" then
          targetAnchorX = anchorTarget:GetRight()
          targetAnchorY = anchorTarget:GetBottom()
        end

        if barAnchorX and barAnchorY and targetAnchorX and targetAnchorY then
          -- Calculate offset from bar anchor point to target anchor point
          local offsetX = (targetAnchorX - barAnchorX)
          local offsetY = (targetAnchorY - barAnchorY)

          bar.anchorLine:SetEndPoint(
            bar.settings.anchorPoint,
            offsetX, offsetY
          )
          return
        end
      end
    end

    -- Fallback: cursor-delta preview if no anchorTarget
    bar.anchorLine:SetEndPoint(
      bar.settings.anchorPoint,
      bar.dragFrame.initX - x,
      bar.dragFrame.initY - y
    )
  end)

  local tex = bar:CreateTexture("ARTWORK")
  tex:SetAllPoints()
  tex:SetColorTexture(.5, .5, .5)
  tex:SetAlpha(0.5)
  bar.tex = tex

  function bar:GetName()
    return self.name
  end

  -- Create anchor handles
  bar.anchorPoints = {}

  for _, point in pairs({ "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT", "CENTER" }) do
    local handle = CreateFrame("Frame", nil, bar)
    bar.anchorPoints[point] = handle

    handle:SetPoint("CENTER", bar, point)
    handle:SetWidth(8)
    handle:SetHeight(8)

    local handleTex = handle:CreateTexture("ARTWORK")
    handleTex:SetAllPoints()
    handleTex:SetColorTexture(1, .5, 0, .4)

    handle:EnableMouse(true)

    handle:SetScript("OnEnter", function()
      handleTex:SetColorTexture(1, 0, 0, 1)
      currentBarAnchorTarget = bar
      currentBarTargetPoint = point
    end)

    handle:SetScript("OnLeave", function()
      handleTex:SetColorTexture(1, .5, 0, .4)
      if currentBarAnchorTarget == bar then
        currentBarAnchorTarget = nil
      end
      currentBarTargetPoint = nil
    end)

    handle:SetScript("OnMouseDown", function(self, button)
      if button ~= "LeftButton" then return end
      if CBM.IsModifierKeyDown() then
        return
      end
      SafeSetFocus(bar, false)
      if CBM.HasSecretGeometry(bar) then return end
      bar.anchorDrag = point
      bar.anchorLine:SetStartPoint(point, 0, 0)
      bar.anchorLine:SetEndPoint(point, 0, 0)
      bar.anchorLine.absoluteX = bar.anchorLine:GetLeft()
      bar.anchorLine.absoluteY = bar.anchorLine:GetBottom()
    end)

    handle:SetScript("OnUpdate", function(self)
      if bar.anchorDrag ~= point then return end
      local x, y = GetCursorPosition()
      local scale = bar.anchorLine:GetEffectiveScale() or 1
      x = x / scale
      y = y / scale
      bar.anchorLine:SetEndPoint(point, x - bar.anchorLine.absoluteX, y - bar.anchorLine.absoluteY)
    end)

    handle:SetScript("OnMouseUp", function(self, button)
      if button ~= "LeftButton" then return end
      -- Stop the line first, or every early return below leaves it following the cursor.
      local dragging = bar.anchorDrag == point
      bar.anchorDrag = nil

      if not dragging -- the press was refused, but the release still comes to this handle
          or not currentBarAnchorTarget
          or CBM.IsModifierKeyDown()
          or currentBarAnchorTarget == bar
          or not currentBarTargetPoint
          or CBM.RejectAnchorTarget(bar.settings.name, currentBarAnchorTarget.settings.name)
      then
        currentBarAnchorTarget = nil
        bar:SetAnchorLine()
        return
      end

      bar.settings.anchorPoint = point
      bar.settings.anchorTarget = currentBarAnchorTarget.name
      bar.settings.targetPoint = currentBarTargetPoint

      currentBarAnchorTarget = nil
      SafeUpdateBar(bar)
      SafeUpdateOptions()
    end)
  end

  -- anchor line
  local l = bar:CreateLine()
  bar.anchorLine = l
  l:SetThickness(3)
  l:SetColorTexture(0, 0, 1)

  function bar:SetAnchorLine()
    -- The line's end is the bar's offset, which is secret while the bar hangs off secret geometry.
    local hasSecretGeometry = CBM.HasSecretGeometry(self)
    self.anchorLine:SetShown(not hasSecretGeometry)
    if hasSecretGeometry then return end
    self.anchorLine:SetStartPoint(self.settings.anchorPoint, 0, 0)
    local X, Y = GetOffsets(self:GetPoint())
    self.anchorLine:SetEndPoint(self.settings.anchorPoint, -X, -Y)
  end

  local DEFAULT_ICON_HEIGHT = 38 -- still used only for empty bar

  function bar:AddIcon(icon)
    local isFirst = #self.displayedIcons == 0
    local isHorizontal = self.settings.isHorizontal

    local anchorPoint = isFirst and "TOPLEFT" or (isHorizontal and "LEFT" or "TOP")
    local anchorTarget = isFirst and self or self.displayedIcons[#self.displayedIcons]
    local targetPoint = isFirst and "TOPLEFT" or (isHorizontal and "RIGHT" or "BOTTOM")
    local padding = isFirst and 0 or self.settings.padding

    -- Base size from Masque/Blizzard; secret while the icon hangs off secret geometry.
    local width, height = icon:GetWidth(), icon:GetHeight()
    local baseW = (not IsSecret(width) and width > 0) and width or DEFAULT_ICON_HEIGHT
    local baseH = (not IsSecret(height) and height > 0) and height or DEFAULT_ICON_HEIGHT

    -- Normalize utility icons a bit.
    local source = CBM.iconKind[icon]
    local sourceScale = 0.8
    local chargeScale = 2
    if source == "UTILITY" then
      sourceScale = 1.35
      chargeScale = 1.35
    elseif source == "BUFF" then
      sourceScale = 1
      chargeScale = 1
    end

    local appliedScale = (self.settings.scale or 1) * sourceScale
    local targetChargeScale = (self.settings.scale or 1) * chargeScale

    icon:SetAlpha(0.8)
    icon:SetScale(appliedScale)
    -- ChargeCount is a child of icon, so its effective size is chargeScale * appliedScale; divide out the parent's scale so it lands on targetChargeScale.
    if icon.ChargeCount then
      icon.ChargeCount:SetScale(targetChargeScale / appliedScale)
    end
    icon:ClearAllPoints()
    icon:SetPoint(anchorPoint, anchorTarget, targetPoint, padding, 0)

    tinsert(self.displayedIcons, icon)

    -- Use scaled width/height for bar size.
    local scaledW = baseW * appliedScale
    local scaledH = baseH * appliedScale
    local count = #self.displayedIcons

    local longDim = (scaledW * count + self.settings.padding * (count - 1))
    local shortDim = scaledH

    self:SetWidth(isHorizontal and longDim or shortDim)
    self:SetHeight(isHorizontal and shortDim or longDim)
  end

  function bar:SetBarPoint(roundAlg, roundArg)
    local settings = self.settings
    local anchorTarget = GetFrameFromName(settings.anchorTarget)

    if roundAlg then
      if type(roundAlg) ~= "function" then
        roundAlg = trimRound
      end
      settings.offsetX = roundAlg(settings.offsetX, roundArg)
      settings.offsetY = roundAlg(settings.offsetY, roundArg)
    end

    local point, relativePoint, x, y, usesSavedTarget = CBM.Logic.PlanBarPlacement(
      settings, anchorTarget ~= nil, GetScreenWidth(), GetScreenHeight(), self:GetWidth(), self:GetHeight())

    self:ClearAllPoints()
    self:SetPoint(point, usesSavedTarget and anchorTarget or UIParent, relativePoint, x, y)
    self.parkedFor = not usesSavedTarget and settings.anchorTarget or nil -- the missing target's name

    -- A missing target is placed temporarily; the saved anchor and position stay for when it exists.
    if usesSavedTarget and not CBM.HasSecretGeometry(self) then
      local left, bottom = self:GetLeft(), self:GetBottom()
      if left and bottom then
        settings.absoluteX, settings.absoluteY = left, bottom
      end
    end
  end

  function bar:UpdateFocused()
    local isSelected = CBM.selectedBars and CBM.selectedBars[self.settings.name]

    self:SetFrameLevel(isSelected and 4 or 3)

    if isSelected then
      self.tex:SetColorTexture(0, .5, 0)
    else
      self.tex:SetColorTexture(.5, .5, .5)
    end
  end

  function bar:ResetLayout()
    if self.displayedIcons then
      wipe(self.displayedIcons)
    else
      self.displayedIcons = {}
    end
  end
end
