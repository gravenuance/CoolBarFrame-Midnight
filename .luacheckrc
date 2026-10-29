-- luacheck config for CoolBarFrame (a retail World of Warcraft addon, Lua 5.1).
max_line_length = false
codes = true

-- Widget and event handlers take fixed positional arguments (self, event, ...).
unused_args = false

exclude_files = {
  ".luacheckrc",
}

stds.wow = {
  -- Written on purpose: the SavedVariable, the slash command registration, and the Escape-closes list.
  globals = {
    "CoolBarDB",
    "SLASH_CoolBar1",
    "SlashCmdList",
    "UISpecialFrames",
  },

  -- The Blizzard API and frames the addon reads, kept explicit so a typo is an error.
  read_globals = {
    -- Blizzard frames and panel helpers
    "BuffIconCooldownViewer",
    "ButtonFrameTemplate_HideAttic",
    "ButtonFrameTemplate_HideButtonBar",
    "ButtonFrameTemplate_HidePortrait",
    "CooldownViewerSettings",
    "EditModeManagerFrame",
    "EssentialCooldownViewer",
    "GameTooltip",
    "GameTooltip_SetTitle",
    "UIParent",
    "UtilityCooldownViewer",

    -- Constants and tables
    "C_ClassTalents",
    "C_RestrictedActions",
    "C_Timer",
    "Enum",
    "NORMAL_FONT_COLOR",

    -- Functions
    "CreateFrame",
    "CreateFramePool",
    "GetCursorPosition",
    "GetMouseFoci",
    "GetScreenHeight",
    "GetScreenWidth",
    "HideUIPanel",
    "InCombatLockdown",
    "IsAltKeyDown",
    "IsControlKeyDown",
    "IsShiftKeyDown",
    "ShowUIPanel",
    "hooksecurefunc",
    "tinsert",
    "wipe",
  },
}

std = "lua51+wow"

-- The test runner and specs run on a standalone Lua 5.1, so they get no WoW globals.
files["tests/"] = {
  std = "lua51",
}
