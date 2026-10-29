local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

local function defaultBar(name)
  return {
    name         = name,
    icons        = {},
    scale        = 1,
    padding      = 0,
    isHorizontal = true,
    anchorPoint  = "CENTER",
    anchorTarget = "UIParent",
    targetPoint  = "CENTER",
    offsetX      = 0,
    offsetY      = 0,
    absoluteX    = 0,
    absoluteY    = 0,
  }
end

-- NewBarSettings / MergeBarDefaults

t.test("NewBarSettings returns the complete default bar", function()
  t.eq(Logic.NewBarSettings("customBar7"), defaultBar("customBar7"))
end)

t.test("NewBarSettings returns independent tables", function()
  local a, b = Logic.NewBarSettings("a"), Logic.NewBarSettings("b")
  a.icons[1] = 42
  t.eq(b.icons, {})
end)

t.test("MergeBarDefaults fills every missing field of a partial bar", function()
  local bar = Logic.MergeBarDefaults({ name = "customBar1", scale = 2 })
  local expected = defaultBar("customBar1")
  expected.scale = 2
  t.eq(bar, expected)
end)

t.test("MergeBarDefaults keeps user values, including false and zero", function()
  local bar = Logic.MergeBarDefaults({
    name = "b", isHorizontal = false, padding = 0, offsetX = -5.5, anchorTarget = "customBar0", icons = { 7, 9 },
  })
  t.eq(bar.isHorizontal, false)
  t.eq(bar.padding, 0)
  t.eq(bar.offsetX, -5.5)
  t.eq(bar.anchorTarget, "customBar0")
  t.eq(bar.icons, { 7, 9 })
end)

t.test("MergeBarDefaults replaces values of the wrong type", function()
  local bar = Logic.MergeBarDefaults({ name = "b", scale = "big", icons = "none", isHorizontal = 1 })
  t.eq(bar.scale, 1)
  t.eq(bar.icons, {})
  t.eq(bar.isHorizontal, true)
end)

t.test("MergeBarDefaults raises a zero, negative or NaN scale to the 0.05 minimum", function()
  t.eq(Logic.MergeBarDefaults({ name = "b", scale = 0 }).scale, 0.05)
  t.eq(Logic.MergeBarDefaults({ name = "b", scale = -2 }).scale, 0.05)
  t.eq(Logic.MergeBarDefaults({ name = "b", scale = 0 / 0 }).scale, 0.05)
  t.eq(Logic.MergeBarDefaults({ name = "b", scale = 0.05 }).scale, 0.05)
end)

t.test("MergeBarDefaults leaves a complete bar unchanged", function()
  local complete = defaultBar("b")
  complete.scale = 1.5
  complete.icons = { 1, 2, 3 }
  local expected = defaultBar("b")
  expected.scale = 1.5
  expected.icons = { 1, 2, 3 }
  t.eq(Logic.MergeBarDefaults(complete), expected)
end)

-- MigrateDB(db, migrations, currentVersion) -> status, err

t.test("the shipped migration upgrades schema 1 data to complete bars", function()
  local db = { version = 1, bars = { { name = "customBar0", scale = 2 }, { name = "customBar1", icons = { 5 } } } }
  local status = Logic.MigrateDB(db, Logic.MIGRATIONS, Logic.SCHEMA_VERSION)
  t.eq(status, "migrated")
  t.eq(db.version, 2)
  local first = defaultBar("customBar0")
  first.scale = 2
  local second = defaultBar("customBar1")
  second.icons = { 5 }
  t.eq(db.bars, { first, second })
end)

t.test("the shipped migration detaches anchor loops", function()
  local db = {
    version = 1,
    bars = {
      { name = "A", anchorTarget = "B", anchorPoint = "TOP", targetPoint = "BOTTOM" },
      { name = "B", anchorTarget = "A", anchorPoint = "TOP", targetPoint = "BOTTOM" },
    },
  }
  Logic.MigrateDB(db, Logic.MIGRATIONS, Logic.SCHEMA_VERSION)
  t.eq(db.bars[1].anchorTarget, "UIParent")
  t.eq(db.bars[2].anchorTarget, "A")
end)

t.test("a migration keeps one backup of the pre-migration bars", function()
  local db = { version = 1, bars = { { name = "customBar0", scale = 2 } } }
  Logic.MigrateDB(db, Logic.MIGRATIONS, Logic.SCHEMA_VERSION)
  t.eq(db.backup, { version = 1, bars = { { name = "customBar0", scale = 2 } } })
end)

t.test("current data is left alone and gets no backup", function()
  local db = { version = 2, bars = { { name = "customBar0", scale = 2 } } }
  t.eq(Logic.MigrateDB(db, Logic.MIGRATIONS, 2), "current")
  t.eq(db, { version = 2, bars = { { name = "customBar0", scale = 2 } } })
end)

t.test("data from a newer version is never touched", function()
  local db = { version = 9, bars = { { name = "customBar0" } } }
  t.eq(Logic.MigrateDB(db, Logic.MIGRATIONS, 2), "newer")
  t.eq(db, { version = 9, bars = { { name = "customBar0" } } })
end)

t.test("unversioned data is treated as schema 1", function()
  local db = { bars = { { name = "customBar0" } } }
  t.eq(Logic.MigrateDB(db, Logic.MIGRATIONS, Logic.SCHEMA_VERSION), "migrated")
  t.eq(db.version, 2)
  t.eq(db.bars, { defaultBar("customBar0") })
end)

t.test("a missing bars list becomes an empty list", function()
  local db = { version = 2 }
  Logic.MigrateDB(db, Logic.MIGRATIONS, 2)
  t.eq(db.bars, {})
end)

t.test("a failing migration restores the bars and keeps the old version", function()
  local migrations = {
    [1] = function(db)
      db.bars[1].scale = 99
      error("boom")
    end,
  }
  local db = { version = 1, bars = { { name = "customBar0", scale = 2 } } }
  local status, err = Logic.MigrateDB(db, migrations, 2)
  t.eq(status, "failed")
  t.truthy(tostring(err):find("boom", 1, true))
  t.eq(db.version, 1)
  t.eq(db.bars, { { name = "customBar0", scale = 2 } })
end)

t.test("a missing migration step fails instead of stamping the new version", function()
  local db = { version = 1, bars = {} }
  t.eq(Logic.MigrateDB(db, {}, 2), "failed")
  t.eq(db.version, 1)
end)

t.test("migrations run in order from the saved version", function()
  local ran = {}
  local migrations = {
    [1] = function() ran[#ran + 1] = "1->2" end,
    [2] = function() ran[#ran + 1] = "2->3" end,
  }
  local db = { version = 2, bars = {} }
  t.eq(Logic.MigrateDB(db, migrations, 3), "migrated")
  t.eq(ran, { "2->3" })
  t.eq(db.version, 3)
end)
