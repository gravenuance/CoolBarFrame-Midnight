-- A minimal fake of the retail client, enough to load the addon's real Core.lua and CoolBarFrame.lua.
-- Mirrors the behaviour the addon relies on: frame pools reset new frames (Pools.lua), Show/HideUIPanel
-- refuse addon calls in combat lockdown (UIParentPanelManager.lua CheckProtectedFunctionsAllowed), and
-- frames anchored to secret geometry return secret values from their geometry getters.

---@diagnostic disable: undefined-global

local Client = {}

local SCREEN_W, SCREEN_H = 1920, 1080

local POINT_FRACTION = {
  TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
  LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
  BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

-- Stands in for a secret value: comparing it or doing arithmetic on it errors, like in the client.
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
Client.SECRET = SECRET

function Client.new(options)
  options = options or {}
  local client = {
    inCombat = false,
    allPanelsDisallowed = false,
    restrictionStates = {},
    keys = { shift = false, ctrl = false, alt = false },
    cursorX = 0,
    cursorY = 0,
    printed = {},
    blockedActions = 0,
    timers = {},
    events = {},
  }

  local env = setmetatable({}, { __index = _G })
  env._G = env
  client.env = env

  local Frame = {}
  Frame.__index = Frame

  local function newRegion(kind, name, parent)
    local region = setmetatable({
      kind = kind,
      name = name,
      parent = parent,
      shown = true,
      width = 0,
      height = 0,
      scale = 1,
      alpha = 1,
      points = {},
      scripts = {},
      hooks = {},
      registeredEvents = {},
    }, Frame)
    return region
  end

  local function fire(frame, script, ...)
    local handler = frame.scripts[script]
    if handler then handler(frame, ...) end
    for _, hook in ipairs(frame.hooks[script] or {}) do hook(frame, ...) end
  end
  client.fire = fire

  function Frame:GetName() return self.name end
  function Frame:SetScript(script, handler)
    self.scripts[script] = handler
    self.hooks[script] = nil
  end
  function Frame:GetScript(script) return self.scripts[script] end
  function Frame:HookScript(script, hook)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], hook)
  end
  function Frame:RegisterEvent(event)
    self.registeredEvents[event] = true
    client.events[self] = true
  end

  function Frame:IsShown() return self.shown end
  function Frame:Show()
    if self.shown then return end
    self.shown = true
    fire(self, "OnShow")
  end
  function Frame:Hide()
    if not self.shown then return end
    self.shown = false
    fire(self, "OnHide")
  end
  -- C-side in the client: a hooksecurefunc on the frame's Lua Show/Hide fields does not run.
  function Frame:SetShown(shown)
    if shown then Frame.Show(self) else Frame.Hide(self) end
  end

  function Frame:IsAnchoringSecret()
    if self.anchoringSecret then return true end
    for _, p in ipairs(self.points) do
      if p.relativeTo and p.relativeTo ~= self and p.relativeTo:IsAnchoringSecret() then return true end
    end
    return false
  end

  function Frame:DependsOn(other)
    if self == other then return true end
    for _, p in ipairs(self.points) do
      if p.relativeTo and p.relativeTo:DependsOn(other) then return true end
    end
    return false
  end

  function Frame:ClearAllPoints() self.points = {} end
  function Frame:SetPoint(point, relativeTo, relativePoint, x, y)
    if type(relativeTo) == "number" then
      relativeTo, relativePoint, x, y = nil, nil, relativeTo, relativePoint
    end
    assert(POINT_FRACTION[point], "SetPoint: bad point " .. tostring(point))
    if type(relativeTo) == "string" then relativeTo = env[relativeTo] end
    if relativeTo and relativeTo:DependsOn(self) then
      error("SetPoint: cannot anchor to a region dependent on it", 2)
    end
    for i = #self.points, 1, -1 do
      if self.points[i].point == point then table.remove(self.points, i) end
    end
    table.insert(self.points, {
      point = point,
      relativeTo = relativeTo or self.parent or env.UIParent,
      relativePoint = relativePoint or point,
      x = x or 0,
      y = y or 0,
    })
  end
  function Frame:SetAllPoints(relativeTo)
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", relativeTo, "TOPLEFT")
    self:SetPoint("BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT")
  end
  function Frame:GetPoint(index)
    local p = self.points[index or 1]
    if not p then return nil end
    if self:IsAnchoringSecret() then return p.point, p.relativeTo, p.relativePoint, SECRET, SECRET end
    return p.point, p.relativeTo, p.relativePoint, p.x, p.y
  end

  -- left, bottom, width, height from the first point, or nil for an unanchored region.
  function Frame:Rect()
    if self == env.UIParent then return 0, 0, SCREEN_W, SCREEN_H end
    local p = self.points[1]
    if not p then return nil end
    local rl, rb, rw, rh = p.relativeTo:Rect()
    if not rl then return nil end
    local rf, own = POINT_FRACTION[p.relativePoint], POINT_FRACTION[p.point]
    local ax, ay = rl + rw * rf[1] + p.x, rb + rh * rf[2] + p.y
    return ax - self.width * own[1], ay - self.height * own[2], self.width, self.height
  end

  local function geometry(frame, pick)
    if frame:IsAnchoringSecret() then return SECRET end
    local l, b, w, h = frame:Rect()
    if not l then return nil end
    return pick(l, b, w, h)
  end
  function Frame:GetLeft() return geometry(self, function(l) return l end) end
  function Frame:GetBottom() return geometry(self, function(_, b) return b end) end
  function Frame:GetRight() return geometry(self, function(l, _, w) return l + w end) end
  function Frame:GetTop() return geometry(self, function(_, b, _, h) return b + h end) end
  function Frame:GetCenter()
    if self:IsAnchoringSecret() then return SECRET, SECRET end
    local l, b, w, h = self:Rect()
    if not l then return nil end
    return l + w / 2, b + h / 2
  end
  function Frame:SetWidth(w) self.width = w end
  function Frame:SetHeight(h) self.height = h end
  function Frame:SetSize(w, h) self.width, self.height = w, h end
  function Frame:GetWidth()
    if self:IsAnchoringSecret() then return SECRET end
    return self.width
  end
  function Frame:GetHeight()
    if self:IsAnchoringSecret() then return SECRET end
    return self.height
  end
  function Frame:SetScale(scale)
    assert(type(scale) == "number" and scale > 0, "SetScale: scale must be greater than 0")
    self.scale = scale
  end
  function Frame:GetEffectiveScale() return 1 end
  function Frame:SetAlpha(alpha) self.alpha = alpha end

  function Frame:SetFrameStrata(strata) self.strata = strata end
  function Frame:SetFrameLevel(level) self.level = level end
  function Frame:SetMovable(movable) self.movable = movable end
  function Frame:EnableMouse(enabled) self.mouseEnabled = enabled end
  function Frame:SetMouseClickEnabled(enabled) self.mouseClickEnabled = enabled end
  function Frame:SetMouseMotionEnabled(enabled) self.mouseMotionEnabled = enabled end
  function Frame:SetPropagateMouseClicks(propagate)
    assert(not client.inCombat, "SetPropagateMouseClicks is restricted in combat")
    self.propagateClicks = propagate
  end

  -- Like the client, moving re-anchors the frame to UIParent at its current spot.
  function Frame:StartMoving()
    local l, b = self:GetLeft(), self:GetBottom()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", l, b)
    self.moving = true
  end
  function Frame:StopMovingOrSizing() self.moving = false end

  function Frame:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
  function Frame:CreateTexture() return newRegion("Texture", nil, self) end
  function Frame:CreateLine()
    local line = newRegion("Line", nil, self)
    line.SetThickness = function(region, thickness) region.thickness = thickness end
    line.SetStartPoint = function(region, point, x, y) region.startPoint = { point, x, y } end
    line.SetEndPoint = function(region, point, x, y) region.endPoint = { point, x, y } end
    line.points = { { point = "BOTTOMLEFT", relativeTo = self, relativePoint = "BOTTOMLEFT", x = 0, y = 0 } }
    return line
  end

  env.CreateFrame = function(kind, name, parent)
    local frame = newRegion(kind, name, parent)
    if name then env[name] = frame end
    return frame
  end

  local uiParent = newRegion("Frame", "UIParent")
  uiParent.width, uiParent.height = SCREEN_W, SCREEN_H
  env.UIParent = uiParent

  env.CreateFramePool = function(kind, parent, _, resetFunc, _, postCreate)
    local pool = { active = {}, inactive = {} }
    local reset = resetFunc or function(_, frame)
      frame:Hide()
      frame:ClearAllPoints()
    end
    function pool:Acquire()
      local frame = table.remove(self.inactive)
      local new = frame == nil
      if new then
        frame = env.CreateFrame(kind, nil, parent)
        if postCreate then postCreate(frame) end
        reset(self, frame, true)
      end
      self.active[frame] = true
      return frame, new
    end
    function pool:Release(frame)
      if not self.active[frame] then return false end
      reset(self, frame, false)
      self.active[frame] = nil
      table.insert(self.inactive, frame)
      return true
    end
    function pool:ReleaseAll()
      for frame in pairs(self.active) do self:Release(frame) end
    end
    function pool:EnumerateActive() return pairs(self.active) end
    function pool:GetNextActive() return (next(self.active)) end
    function pool:GetNumActive()
      local n = 0
      for _ in pairs(self.active) do n = n + 1 end
      return n
    end
    return pool
  end

  -- Blizzard's cooldown viewers, each with a pool of icons that carry a cooldownID.
  local function newViewer(name)
    local viewer = env.CreateFrame("Frame", name, env.UIParent)
    viewer.iconScale = 1
    viewer.tooltipsShown = true
    viewer.itemFramePool = env.CreateFramePool("Frame", viewer)
    function viewer:Layout()
      local x = 0
      for icon in self.itemFramePool:EnumerateActive() do
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
        x = x + 40
      end
    end
    return viewer
  end
  env.UtilityCooldownViewer = newViewer("UtilityCooldownViewer")
  env.EssentialCooldownViewer = newViewer("EssentialCooldownViewer")
  env.BuffIconCooldownViewer = newViewer("BuffIconCooldownViewer")

  function client.addIcon(viewer, cooldownID)
    local icon = viewer.itemFramePool:Acquire()
    icon.cooldownID = cooldownID
    icon:SetSize(40, 40)
    icon.ChargeCount = icon:CreateTexture()
    icon:Show()
    return icon
  end

  env.CooldownViewerSettings = env.CreateFrame("Frame", "CooldownViewerSettings", env.UIParent)
  env.CooldownViewerSettings:Hide()
  env.EditModeManagerFrame = env.CreateFrame("Frame", "EditModeManagerFrame", env.UIParent)
  env.EditModeManagerFrame:Hide()

  local function protectedAllowed()
    if client.inCombat then
      client.blockedActions = client.blockedActions + 1
      return false
    end
    return true
  end
  env.ShowUIPanel = function(frame)
    if not frame or frame:IsShown() then return end
    if not protectedAllowed() then return end
    if client.allPanelsDisallowed then return end
    frame:Show()
  end
  env.HideUIPanel = function(frame)
    if not frame or not frame:IsShown() then return end
    if not protectedAllowed() then return end
    frame:Hide()
  end

  env.Enum = {
    AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4 },
    AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
  }
  env.C_RestrictedActions = {
    GetAddOnRestrictionState = function(kind) return client.restrictionStates[kind] or 0 end,
  }
  env.InCombatLockdown = function() return client.inCombat end
  env.C_Timer = {
    After = function(_, callback) table.insert(client.timers, callback) end,
  }
  env.C_ClassTalents = { GetActiveConfigID = function() return 1 end }
  env.GetCursorPosition = function() return client.cursorX, client.cursorY end
  env.GetMouseFoci = function() return { client.mouseFocus } end
  env.GetScreenWidth = function() return SCREEN_W end
  env.GetScreenHeight = function() return SCREEN_H end
  env.IsShiftKeyDown = function() return client.keys.shift end
  env.IsControlKeyDown = function() return client.keys.ctrl end
  env.IsAltKeyDown = function() return client.keys.alt end
  env.issecretvalue = function(value) return rawequal(value, SECRET) end
  env.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
    table.insert(client.printed, table.concat(parts, " "))
  end
  env.tinsert = table.insert
  env.wipe = function(t)
    for k in pairs(t) do t[k] = nil end
    return t
  end
  env.SlashCmdList = {}
  env.UISpecialFrames = {}
  local function hooksecurefunc(target, name, hook)
    if type(target) == "string" then
      target, name, hook = env, target, name
    end
    local original = assert(target[name], "hooksecurefunc: no " .. tostring(name))
    target[name] = function(...)
      local results = { original(...) }
      hook(...)
      return unpack(results)
    end
  end
  env.hooksecurefunc = hooksecurefunc
  env.CoolBarDB = options.savedData

  -- CoolBarOptions.lua needs Blizzard's templates; its edit-mode wiring (Hide -> SetEditMode(false)) is copied here.
  local ns = {}
  client.ns = ns
  local optionsFrame = env.CreateFrame("Frame", "CoolBarFrameOptions", env.UIParent)
  optionsFrame:Hide()
  optionsFrame.refreshes = 0
  function optionsFrame:UpdateOptions() self.refreshes = self.refreshes + 1 end
  ns.SetupOptionsUI = function() end

  local root = options.root or "."
  local function load(file)
    local chunk = assert(loadfile(root .. "/" .. file))
    setfenv(chunk, env)
    chunk("CoolBarFrame", ns)
  end
  load("CoolBarLogic.lua")
  load("Core.lua")
  ns.OptionsFrame = optionsFrame
  hooksecurefunc(optionsFrame, "Hide", function() ns.SetEditMode(false) end)
  load("CoolBarFrame.lua")

  function client.event(event, ...)
    for frame in pairs(client.events) do
      if frame.registeredEvents[event] then fire(frame, "OnEvent", event, ...) end
    end
  end

  function client.runTimers()
    local timers = client.timers
    client.timers = {}
    for _, callback in ipairs(timers) do callback() end
  end

  -- Runs the addon's deferred OnUpdate work, like the next frame would.
  function client.nextFrame()
    client.runTimers()
    local updateFrame = ns.UpdateFrame
    if updateFrame:IsShown() then fire(updateFrame, "OnUpdate", 0) end
  end

  function client.login()
    client.event("ADDON_LOADED", "CoolBarFrame")
    client.event("PLAYER_ENTERING_WORLD", true, false)
    client.nextFrame()
  end

  function client.slash(text)
    env.SlashCmdList.CoolBar(text)
  end

  function client.lastPrint()
    return client.printed[#client.printed]
  end

  function client.bars()
    local list = {}
    for bar in ns.BarFramePool:EnumerateActive() do list[#list + 1] = bar end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
  end

  return client
end

return Client
