local addonName, CBM = ...

-------------------------------------------------
-- STATE
-------------------------------------------------

local iconBarMap = {} -- cooldownID -> bar frame
local idIconMap = {}  -- cooldownID -> icon frame

local setupDone = false -- hooks and option widgets exist; set on the first PLAYER_ENTERING_WORLD
local fullRemap
local queuedFunctions
local queuedClickFunctions

CBM.editModeActive = false
--CBM.focusedBar = nil

CBM.PendingMoveID = nil -- cooldownID we want to move
local pendingMoveBar    -- bar frame we are moving from
local pendingMoveIndex

local selectedBars = {} -- set of bar.name -> bar for shift-multi-select
CBM.selectedBars = selectedBars

local DEFAULT_ICON_HEIGHT = 38

-- Blizzard cooldown viewers as icon sources
local defaultBars = {
  UtilityCooldownViewer,
  EssentialCooldownViewer,
  BuffIconCooldownViewer,
}

-------------------------------------------------
-- SAVED VARIABLES
-------------------------------------------------

CoolBarDB = CoolBarDB or {
  version = CBM.Logic.SCHEMA_VERSION,
  bars = {}, -- account-wide bar structures, no per-spec icon lists
}

-------------------------------------------------
-- FRAME POOL
-------------------------------------------------

CBM.BarFramePool = CreateFramePool(
  "Frame",       -- 1. frameType
  UIParent,      -- 2. parent
  nil,           -- 3. template
  nil,           -- 4. resetFunc: the default hides the frame and clears its anchors on release
  nil,           -- 5. forbidden: must stay nil, addons cannot create forbidden frames
  function(frame) -- 6. postCreate: runs once per newly created frame, not on every Acquire
    CBM.InitBarFrame(frame)
  end
)

-------------------------------------------------
-- CALLBACKS FOR BAR MODULE
-------------------------------------------------

CBM.callbacks = CBM.callbacks or {}

function CBM.IsModifierKeyDown()
  return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

function CBM.GetTableSize(t)
  if not t then return 0 end
  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end
  return count
end

function CBM.GetOffsets(_, _, _, xOfs, yOfs)
  return xOfs, yOfs
end

CBM.minimalRound = CBM.Logic.MinimalRound
CBM.trimRound = CBM.Logic.TrimRound
CBM.GetRoundingPrecision = CBM.Logic.GetRoundingPrecision

function CBM.GetFrameFromName(name)
  local globalFrame = _G[name]
  if globalFrame and globalFrame.GetName then
    return globalFrame
  end
  if CBM.BarFramePool.GetFrameByName then
    return CBM.BarFramePool:GetFrameByName(name)
  end
  return nil
end

-- The options frame refreshes itself when shown, so a hidden one skips the work.
function CBM.RefreshOptions()
  if CBM.OptionsFrame:IsShown() then
    CBM.OptionsFrame:UpdateOptions()
  end
end

function CBM.Print(text)
  print("|cffffd200CoolBarFrame:|r " .. text)
end

local function GetSavedAnchorTarget(name)
  for _, settings in ipairs(CoolBarDB.bars) do
    if settings.name == name then return settings.anchorTarget end
  end
end

-- True (after telling the user why) when anchoring barName to targetName would make a bar depend on itself.
function CBM.RejectAnchorLoop(barName, targetName)
  if not CBM.Logic.WouldCreateAnchorCycle(barName, targetName, GetSavedAnchorTarget) then
    return false
  end
  if barName == targetName then
    CBM.Print(barName .. " can't anchor to itself.")
  else
    CBM.Print(barName .. " can't anchor to " .. targetName .. ": it would loop.")
  end
  return true
end

function CBM.GetFocusedBar()
  for _, selected in pairs(selectedBars) do
    if selected then
      return selected
    end
  end
end

function CBM.SetFocus(bar, useShift)
  -- Multi-select toggle when Shift is held and a bar is clicked
  if useShift and bar then
    if selectedBars[bar.settings.name] then
      selectedBars[bar.settings.name] = nil
    else
      selectedBars[bar.settings.name] = bar
    end
  else
    wipe(selectedBars)
    if bar then
      selectedBars[bar.settings.name] = bar
    end
  end

  for customBar in CBM.BarFramePool:EnumerateActive() do
    customBar:UpdateFocused()
  end

  CBM.RefreshOptions()
end

function CBM.UpdateBar(bar)
  bar = bar or CBM.GetFocusedBar()
  if not bar then return end

  local s = bar.settings

  -- Check if anchor settings have changed. A bar parked for a missing target sits on a temporary
  -- screen anchor, so only a new target counts; when the same target is back its saved offsets win.
  local anchorChanged
  if bar.parkedFor then
    anchorChanged = bar.parkedFor ~= s.anchorTarget
  else
    local currentAnchor, currentTarget, currentTargetPoint = bar:GetPoint()
    anchorChanged = (currentAnchor ~= s.anchorPoint)
        or (currentTarget and currentTarget:GetName() ~= s.anchorTarget)
        or (currentTargetPoint ~= s.targetPoint)
  end

  -- Save old position if anchor changed
  local oldLeft, oldBottom
  if anchorChanged then
    oldLeft = bar:GetLeft()
    oldBottom = bar:GetBottom()
  end

  -- Apply bar point (without rounding if anchor changed, with rounding otherwise)
  bar:SetBarPoint(anchorChanged and nil or CBM.trimRound)

  -- Recalculate and apply offsets if anchor changed
  if oldLeft then
    s.offsetX = s.offsetX + (oldLeft - bar:GetLeft())
    s.offsetY = s.offsetY + (oldBottom - bar:GetBottom())
    bar:SetBarPoint(CBM.trimRound)

    CBM.RefreshOptions()
  end

  bar:SetAnchorLine()
end

CBM.callbacks.SetFocus                  = CBM.SetFocus
CBM.callbacks.UpdateBar                 = CBM.UpdateBar
CBM.callbacks.UpdateOptions             = CBM.RefreshOptions
CBM.callbacks.GetOffsets                = CBM.GetOffsets
CBM.callbacks.GetFrameFromName          = CBM.GetFrameFromName
CBM.callbacks.GetTableSize              = CBM.GetTableSize
CBM.callbacks.IsModifierKeyDown         = CBM.IsModifierKeyDown

-------------------------------------------------
-- BAR POOL HELPERS
-------------------------------------------------

CBM.BarFramePool.GetFirstAvailableIndex = function(self)
  local digits = {}
  local max = -1

  for b in self:EnumerateActive() do
    local name = b.name or ""
    -- Extract trailing number from the bar name (e.g. "customBar12" -> "12")
    local n = name:match("(%d+)$")
    n = n and tonumber(n) or nil

    if n then
      if n > max then max = n end
      digits[n] = true
    end
  end

  local i = 0
  while i <= max do
    if not digits[i] then
      return i
    end
    i = i + 1
  end

  return max + 1
end

CBM.BarFramePool.GetFrameByName         = function(self, name)
  for b in self:EnumerateActive() do
    if b.name == name then return b end
  end
  return nil
end

-------------------------------------------------
-- EDIT MODE / ICON CLICKING
-------------------------------------------------

-- Restriction kinds under which opening Blizzard UI from addon code is unsafe.
local BLOCKING_RESTRICTIONS = {
  [Enum.AddOnRestrictionType.Combat] = true,
  [Enum.AddOnRestrictionType.Encounter] = true,
}
local restrictions = {}         -- restriction kind -> true from "activating" until inactive
local pendingEditMode = false   -- an enter request waiting for combat/encounter to end
local deferredClicks = setmetatable({}, { __mode = "k" }) -- frame -> propagate, postponed past combat
local hookedFrames = setmetatable({}, { __mode = "k" })   -- Blizzard frames we already hooked

-- Why saved data is shown read-only (newer schema or a failed migration), or nil when it can be edited.
local readOnlyReason

-- True (after telling the user why) when the saved data must not be changed.
local function RefuseReadOnly()
  if not readOnlyReason then return false end
  CBM.Print(readOnlyReason .. ", so bars can't be edited.")
  return true
end

-- No restriction event arrives after a /reload mid-encounter, so the current state is read on load.
local function ReadRestrictions()
  local getState = C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState
  if type(getState) ~= "function" then return end
  for kind in pairs(BLOCKING_RESTRICTIONS) do
    CBM.Logic.ApplyRestrictionEvent(restrictions, kind, getState(kind), Enum.AddOnRestrictionState.Inactive)
  end
end

local function IsEditModeBlocked()
  return CBM.Logic.IsBlocked(restrictions, InCombatLockdown(), BLOCKING_RESTRICTIONS)
end

-- SetPropagateMouseClicks is a restricted function, so it waits for combat to end.
function CBM.SetPropagateClicks(frame, propagate)
  if InCombatLockdown() then
    deferredClicks[frame] = propagate
    return
  end
  frame:SetPropagateMouseClicks(propagate)
end

local function FlushDeferredClicks()
  for frame, propagate in pairs(deferredClicks) do
    deferredClicks[frame] = nil
    frame:SetPropagateMouseClicks(propagate)
  end
end

-- Returns true when Blizzard's window stayed open while leaving, so edit mode resumes once unblocked.
local function ApplyEditMode(active)
  CBM.editModeActive = active

  -- Blizzard's window goes through the UI panel manager; calling its methods or events from here would taint its code.
  -- It opens first so the options frame can sit beside it.
  local settings = CooldownViewerSettings
  if settings and settings:IsShown() ~= active then
    if active then
      ShowUIPanel(settings)
    elseif not InCombatLockdown() then -- in lockdown HideUIPanel refuses and blames the addon
      HideUIPanel(settings)
    end
  end

  -- The panel manager can refuse either way; edit mode is only on while the window really is open.
  local suspended = false
  if settings and settings:IsShown() ~= active then
    suspended = settings:IsShown()
    active = false
    CBM.editModeActive = false
  end

  for bar in CBM.BarFramePool:EnumerateActive() do
    bar:SetShown(active)
  end
  CBM.OptionsFrame:SetShown(active)

  CBM.ToggleDefaultIconClicks()
  return suspended
end

-- Returns true when edit mode waits for combat/encounter to end.
function CBM.SetEditMode(requested)
  if requested and RefuseReadOnly() then requested = false end
  local active, deferred = CBM.Logic.PlanEditMode(CBM.editModeActive, requested, IsEditModeBlocked())
  if active ~= CBM.editModeActive then
    deferred = ApplyEditMode(active)
  end
  -- Set last: the window and options frame hooks re-enter SetEditMode while ApplyEditMode runs.
  pendingEditMode = deferred
  return deferred
end

-- Blizzard's window is the source of truth for whether edit mode is wanted.
local function SyncEditModeWithViewerSettings()
  local settings = CooldownViewerSettings
  CBM.SetEditMode(settings ~= nil and settings:IsShown())
end

local function ResumeAfterBlock()
  if not InCombatLockdown() then FlushDeferredClicks() end
  if IsEditModeBlocked() then return end
  if pendingEditMode then
    CBM.SetEditMode(true)
  end
end

function CBM.EnableDefaultBarClicks(defaultBar)
  if EditModeManagerFrame:IsShown() then return end

  for icon in defaultBar.itemFramePool:EnumerateActive() do
    CBM.SetPropagateClicks(icon, true)
    if not hookedFrames[icon] then
      hookedFrames[icon] = true
      icon:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if IsControlKeyDown() then
          CBM.AddOrRemoveIcon(self, button)
        elseif IsAltKeyDown() then
          CBM.MoveIconToOtherBar(self, button)
        end
      end)
    end
  end

  CBM.ToggleDefaultIconClicks(defaultBar)
end

local function ToggleViewerIconClicks(viewer)
  for icon in viewer.itemFramePool:EnumerateActive() do
    icon:SetMouseClickEnabled(CBM.editModeActive)
    icon:SetMouseMotionEnabled(viewer.tooltipsShown)
  end
end

function CBM.ToggleDefaultIconClicks(defaultBar)
  if defaultBar then
    ToggleViewerIconClicks(defaultBar)
    return
  end
  for _, viewer in pairs(defaultBars) do
    ToggleViewerIconClicks(viewer)
  end
end

-------------------------------------------------
-- ICON MAPPING / LAYOUT
-------------------------------------------------
local VIEWER_KIND = {
  [UtilityCooldownViewer]   = "UTILITY",
  [EssentialCooldownViewer] = "ESSENTIAL",
  [BuffIconCooldownViewer]  = "BUFF",
}

-- Per-icon bookkeeping lives here, not in fields on Blizzard's frames.
local iconViewer = setmetatable({}, { __mode = "k" }) -- icon -> the viewer that owns it
CBM.iconKind = setmetatable({}, { __mode = "k" })     -- icon -> VIEWER_KIND of its viewer
local iconHome = setmetatable({}, { __mode = "k" }) -- icon -> {point, relativeTo, relativePoint, x, y} as Blizzard last placed it

-- Runs right after Blizzard lays a viewer out, before ExecuteLayout moves icons onto custom bars.
local function CaptureIconHomes(defaultBar)
  for icon in defaultBar.itemFramePool:EnumerateActive() do
    local point, relativeTo, relativePoint, x, y = icon:GetPoint(1)
    if relativeTo == defaultBar then
      local home = iconHome[icon]
      if not home then
        home = {}
        iconHome[icon] = home
      end
      home[1], home[2], home[3], home[4], home[5] = point, relativeTo, relativePoint, x, y
    end
  end
end

local function RestoreIcon(icon)
  if not icon then return end
  local viewer = iconViewer[icon]
  icon:SetScale(viewer and viewer.iconScale or 1)
  icon:SetAlpha(1)
  if icon.ChargeCount then
    icon.ChargeCount:SetScale(1)
  end
  -- Re-laying the viewer out ourselves would run Blizzard's code tainted, so put the icon back by hand.
  local home = iconHome[icon]
  if home then
    icon:ClearAllPoints()
    icon:SetPoint(home[1], home[2], home[3], home[4], home[5])
  end
end

function CBM.UpdateIDIconMap()
  if fullRemap then return end

  for _, defaultBar in pairs(defaultBars) do
    for icon in defaultBar.itemFramePool:EnumerateActive() do
      if icon.cooldownID then
        idIconMap[icon.cooldownID] = icon
        iconViewer[icon] = defaultBar
        CBM.iconKind[icon] = VIEWER_KIND[defaultBar]
      end
    end
  end
end

function CBM.RelayoutBars()
  CBM.UpdateIDIconMap()
  CBM.ExecuteLayout()
end

function CBM.ExecuteLayout()
  for customBar in CBM.BarFramePool:EnumerateActive() do
    customBar:ResetLayout()
    if customBar.settings.icons then
      for _, id in ipairs(customBar.settings.icons) do
        local icon = idIconMap[id]
        if icon and id == icon.cooldownID then
          customBar:AddIcon(icon)
          iconBarMap[id] = customBar
        else
          idIconMap[id] = nil
        end
      end
    end
  end

  CBM.RefreshOptions()
end

function CBM.AddOrRemoveIcon(icon, button)
  if button ~= "LeftButton"
      or not CBM.editModeActive
      or not IsControlKeyDown()
  then
    return
  end

  local count = CBM.GetTableSize(selectedBars)
  if (count == 1) then
    if not icon.cooldownID then
      print("Icon data not initialized.")
      return
    end

    local id = icon.cooldownID
    local bar = iconBarMap[id]
    if bar then
      -- removing
      RestoreIcon(idIconMap[id])
      iconBarMap[id] = nil
      for i, iconID in ipairs(bar.settings.icons) do
        if iconID == id then
          table.remove(bar.settings.icons, i)
          break
        end
      end
      CBM.RelayoutBars()
    else
      bar = CBM.GetFocusedBar()
      if bar then
        bar.settings.icons = bar.settings.icons or {}
        tinsert(bar.settings.icons, id)
        CBM.ExecuteLayout()
      end
    end
  elseif count > 1 then
    for bar in CBM.BarFramePool:EnumerateActive() do
      if selectedBars[bar.settings.name] then
        for _, id in ipairs(bar.settings.icons) do
          RestoreIcon(idIconMap[id])
          iconBarMap[id] = nil
        end
        wipe(bar.settings.icons)
      end
    end
    CBM.RelayoutBars()
  else
    return
  end

  CBM.RefreshOptions()
end

function CBM.MoveIconToOtherBar(icon, button)
  if button ~= "LeftButton" or not CBM.editModeActive or not IsAltKeyDown() then
    return
  end

  local count = CBM.GetTableSize(selectedBars)
  if count ~= 1 then
    return
  end

  -- STEP 1: arm swap/move (must have a real icon)
  if not CBM.PendingMoveID then
    if not icon or not icon.cooldownID then
      print("Icon data not initialized.")
      return
    end

    local id  = icon.cooldownID
    local src = iconBarMap[id]

    if not src or not src.settings or not src.settings.icons then
      print("This icon is not on any custom bar yet.")
      return
    end

    local srcIndex
    for i, iconID in ipairs(src.settings.icons) do
      if iconID == id then
        srcIndex = i
        break
      end
    end

    if not srcIndex then
      print("Could not resolve source slot for icon.")
      return
    end

    CBM.PendingMoveID = id
    pendingMoveBar    = src
    pendingMoveIndex  = srcIndex
    return
  end

  -- STEP 2: perform swap/move
  local moveID      = CBM.PendingMoveID
  local moveSrc     = pendingMoveBar
  local moveIdx     = pendingMoveIndex

  CBM.PendingMoveID = nil
  pendingMoveBar    = nil
  pendingMoveIndex  = nil

  if not moveID or not moveSrc or not moveSrc.settings or not moveSrc.settings.icons then
    print("No valid source for swap.")
    return
  end

  -- Destination resolution:
  --  a) If we have an icon on the second click, try to use its bar/slot.
  --  b) If icon is nil (e.g. empty button), use the focused bar, and treat as "no specific slot" (append).
  local dst, dstIndex, id, src
  if icon and icon.cooldownID then
    id  = icon.cooldownID
    src = iconBarMap[id]

    if src and src.settings and src.settings.icons then
      for i, iconID in ipairs(src.settings.icons) do
        if iconID == id then
          dstIndex = i
          break
        end
      end
    end

    dst = src
  else
    dst      = CBM.GetFocusedBar and CBM.GetFocusedBar() or CBM.focusedBar
    dstIndex = nil
  end

  if not dst then
    print("No valid destination bar.")
    return
  end

  -- Cancel if second click is effectively the same slot/bar as the source
  if icon and id == moveID and src == moveSrc then
    print("Swap cancelled.")
    return
  end

  -- Case 1: swap with an existing icon in that slot
  if dstIndex and dst.settings and dst.settings.icons and dst.settings.icons[dstIndex] then
    local otherID = dst.settings.icons[dstIndex]
    if otherID and otherID ~= moveID then
      local otherBar                                                       = dst
      local otherIndex                                                     = dstIndex

      otherBar.settings.icons[otherIndex], moveSrc.settings.icons[moveIdx] =
          moveSrc.settings.icons[moveIdx], otherBar.settings.icons[otherIndex]

      CBM.ExecuteLayout()
      CBM.RefreshOptions()
      return
    end
  end

  -- Case 2: move into an empty slot or append
  table.remove(moveSrc.settings.icons, moveIdx)

  dst.settings.icons = dst.settings.icons or {}
  if dstIndex and not dst.settings.icons[dstIndex] then
    dst.settings.icons[dstIndex] = moveID
  else
    table.insert(dst.settings.icons, moveID)
  end

  CBM.ExecuteLayout()
  CBM.RefreshOptions()
end

-------------------------------------------------
-- BAR CREATION / SETUP
-------------------------------------------------
---
CBM.multiDragLeader = nil
CBM.multiDragDeltaX = 0
CBM.multiDragDeltaY = 0

function CBM.CreateNewBar(name, settings)
  name = name or ("customBar" .. CBM.BarFramePool:GetFirstAvailableIndex())

  local bar = CBM.BarFramePool:Acquire()

  if settings then
    bar.settings = settings
    bar.settings.name = name
  else
    bar.settings = CBM.Logic.NewBarSettings(name)
    tinsert(CoolBarDB.bars, bar.settings)
  end

  bar.name = name
  bar:ResetLayout()

  bar:SetWidth(DEFAULT_ICON_HEIGHT)
  bar:SetHeight(DEFAULT_ICON_HEIGHT)

  if not settings then
    bar:SetBarPoint(true)
  end

  C_Timer.After(0, function()
    bar:SetAnchorLine()
  end)

  -- Bars restored from saved data are placed and focused together by SetupBars once all of them exist.
  if not settings then
    CBM.SetFocus(bar, false)
  end

  if CBM.editModeActive then bar:Show() end
  return bar
end

function CBM.NewBar()
  CBM.CreateNewBar()
  CBM.RefreshOptions()
end

function CBM.DeleteFocusedBar()
  local count = CBM.GetTableSize(selectedBars)
  if count < 1 then
    return
  end
  for bar in CBM.BarFramePool:EnumerateActive() do
    if selectedBars[bar.settings.name] then
      CBM.BarFramePool:Release(bar)

      for i, barSettings in ipairs(CoolBarDB.bars) do
        if barSettings.name == bar.settings.name then
          if barSettings.icons then
            for _, iconID in pairs(barSettings.icons) do
              RestoreIcon(idIconMap[iconID])
              iconBarMap[iconID] = nil
            end
          end
          table.remove(CoolBarDB.bars, i)
          break
        end
      end
    else
      local s = bar.settings
      for name in pairs(selectedBars) do
        if s.anchorTarget == name then
          s.anchorPoint  = "CENTER"
          s.anchorTarget = "UIParent"
          s.targetPoint  = "CENTER"
          CBM.UpdateBar(bar)
        end
      end
    end
  end

  CBM.RefreshOptions()

  -- Focus the next available bar, or clear focus if none exist
  wipe(selectedBars)
  local nextBar = CBM.BarFramePool:GetNextActive()
  if nextBar then
    CBM.SetFocus(nextBar, false)
  end
  CBM.RelayoutBars()
end

-------------------------------------------------
-- CLASS/SPEC RELOAD HOOKS
-------------------------------------------------

local function SetupBars()
  CBM.BarFramePool:ReleaseAll()
  wipe(iconBarMap)

  local lastBar
  local bars = readOnlyReason and CBM.Logic.ReadOnlyBars(CoolBarDB.bars) or CoolBarDB.bars
  for _, barData in ipairs(bars) do
    lastBar = CBM.CreateNewBar(barData.name, CBM.Logic.MergeBarDefaults(barData))
  end

  -- A bar can be anchored to a later bar, so every bar must exist before any is placed.
  for bar in CBM.BarFramePool:EnumerateActive() do
    bar:SetBarPoint()
  end

  CBM.SetFocus(lastBar, false)
  CBM.QueueUpdate("ExecuteLayout")
end

local function ResetBars()
  if not setupDone then return end

  CBM.SetFocus(nil, false)
  SetupBars()
  fullRemap = true

  CBM.RefreshOptions()
end

-------------------------------------------------
-- QUEUED UPDATES
-------------------------------------------------

queuedFunctions = {
  UpdateIDIconMap = false,
  ExecuteLayout   = false,
}

queuedClickFunctions = {
  [UtilityCooldownViewer]   = false,
  [EssentialCooldownViewer] = false,
  [BuffIconCooldownViewer]  = false,
}

function CBM.QueueUpdate(fnName)
  queuedFunctions[fnName] = true
  CBM.UpdateFrame:Show()
end

function CBM.QueueClickFunction(defaultBar)
  queuedClickFunctions[defaultBar] = true
  CBM.UpdateFrame:Show()
end

CBM.UpdateFrame = CreateFrame("Frame")
CBM.UpdateFrame:Hide()
CBM.UpdateFrame:SetScript("OnUpdate", function(self, elapsed)
  CBM.UpdateFrame:Hide()

  for bar, update in pairs(queuedClickFunctions) do
    if update then CBM.EnableDefaultBarClicks(bar) end
    queuedClickFunctions[bar] = false
  end

  if queuedFunctions.UpdateIDIconMap then
    CBM.UpdateIDIconMap()
    queuedFunctions.UpdateIDIconMap = false
  end

  if queuedFunctions.ExecuteLayout then
    CBM.ExecuteLayout()
    queuedFunctions.ExecuteLayout = false
  end
end)

-------------------------------------------------
-- EVENTS / SLASH
-------------------------------------------------

CBM.EventFrame = CreateFrame("Frame")
CBM.EventFrame:RegisterEvent("ADDON_LOADED")
CBM.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
CBM.EventFrame:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
CBM.EventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
CBM.EventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
CBM.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

CBM.EventFrame:SetScript("OnEvent", function(self, event, ...)
  if self[event] then self[event](self, event, ...) end
end)

-- Fires before a restriction is enforced and after it ends, so closing Blizzard's window here is still allowed.
function CBM.EventFrame:ADDON_RESTRICTION_STATE_CHANGED(_, kind, state)
  CBM.Logic.ApplyRestrictionEvent(restrictions, kind, state, Enum.AddOnRestrictionState.Inactive)
  if IsEditModeBlocked() then
    if CBM.editModeActive then CBM.SetEditMode(false) end
  else
    ResumeAfterBlock()
  end
end

function CBM.EventFrame:PLAYER_REGEN_ENABLED()
  ResumeAfterBlock()
end

function CBM.EventFrame:ADDON_LOADED(_, addon)
  if addon ~= addonName then return end

  local status, err = CBM.Logic.MigrateDB(CoolBarDB, CBM.Logic.MIGRATIONS, CBM.Logic.SCHEMA_VERSION)
  if status == "newer" then
    readOnlyReason = "your saved data is from a newer version of the addon"
    CBM.Print(readOnlyReason .. "; bars are shown but it is left untouched.")
  elseif status == "failed" then
    readOnlyReason = "your saved data could not be migrated"
    CBM.Print("failed to migrate saved data (" .. tostring(err) .. "); bars are shown but it is left as it was.")
  else
    local loopsRemoved = CBM.Logic.BreakAnchorCycles(CoolBarDB.bars)
    if loopsRemoved > 0 then
      CBM.Print(loopsRemoved .. " bar anchor loop(s) in saved data were detached from their targets.")
    end
  end

  SLASH_CoolBar1 = "/cbm"
  SlashCmdList.CoolBar = function(msg)
    msg = string.lower(msg or "")
    local arg = msg:match("^(%S+)")
    if not arg or arg == "" then
      local cancelling = pendingEditMode
      local requested = not (CBM.editModeActive or pendingEditMode)
      if not CBM.SetEditMode(requested) then
        if cancelling then CBM.Print("Edit mode won't open after combat.") end
      elseif requested then
        CBM.Print("Edit mode opens when combat ends.")
      else
        CBM.Print("Addons can't close the Cooldown Manager window in combat; press Escape to close it.")
      end
    elseif (arg == "new" or arg == "delete" or arg == "reset") and RefuseReadOnly() then
      return
    elseif arg == "new" then
      CBM.NewBar()
    elseif arg == "delete" then
      CBM.DeleteFocusedBar()
    elseif arg == "reset" then
      local bar = CBM.BarFramePool and CBM.BarFramePool:GetFrameByName("customBar0")
      if bar and bar.settings then
        bar.settings.offsetX = 0
        bar.settings.offsetY = 0
        if CBM.UpdateBar then
          CBM.UpdateBar(bar)
        end
      end
    else
      print("Cooldown Bar Manager commands")
      print("  /cbm - Toggle config mode.")
      print("  /cbm new - Create a new bar.")
      print("  /cbm delete - Delete the focused bar.")
      print("  /cbm reset - Reset customBar0 to 0,0.")
    end
  end
end

-- PLAYER_ENTERING_WORLD fires on every loading screen; hooks and option widgets must exist exactly once.
local function SetupOnce()
  if setupDone then return end
  setupDone = true

  CBM.SetupOptionsUI()

  if CooldownViewerSettings then
    CooldownViewerSettings:HookScript("OnShow", SyncEditModeWithViewerSettings)
    CooldownViewerSettings:HookScript("OnHide", SyncEditModeWithViewerSettings)
  end

  for _, defaultBar in pairs(defaultBars) do
    hooksecurefunc(defaultBar, "Layout", function()
      CaptureIconHomes(defaultBar)
      if fullRemap then fullRemap = false end
      CBM.QueueUpdate("UpdateIDIconMap")
      CBM.QueueUpdate("ExecuteLayout")
      CBM.QueueClickFunction(defaultBar)
    end)

    hooksecurefunc(defaultBar, "Show", function()
      CBM.QueueUpdate("ExecuteLayout")
    end)

    hooksecurefunc(defaultBar, "Hide", function()
      CBM.QueueUpdate("ExecuteLayout")
    end)
  end
end

function CBM.EventFrame:PLAYER_ENTERING_WORLD()
  ReadRestrictions()
  SetupOnce()
  SetupBars()

  CBM.RefreshOptions()

  CBM.UpdateIDIconMap()

  for _, defaultBar in pairs(defaultBars) do
    CaptureIconHomes(defaultBar)
    CBM.EnableDefaultBarClicks(defaultBar)
  end

  SyncEditModeWithViewerSettings()
end

function CBM.EventFrame:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
  C_Timer.After(.01, ResetBars)
end

function CBM.EventFrame:TRAIT_CONFIG_UPDATED(_, configID)
  if configID ~= C_ClassTalents.GetActiveConfigID() then return end
  C_Timer.After(.01, ResetBars)
end
