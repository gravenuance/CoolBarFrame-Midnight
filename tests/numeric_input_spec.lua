local t = ...

local Logic = t.newNamespace("CoolBarLogic.lua").Logic

t.test("ParseNumber accepts integers", function()
  t.eq(Logic.ParseNumber("42"), 42)
  t.eq(Logic.ParseNumber("0"), 0)
end)

t.test("ParseNumber accepts negative numbers", function()
  t.eq(Logic.ParseNumber("-50"), -50)
  t.eq(Logic.ParseNumber("-0.5"), -0.5)
end)

t.test("ParseNumber accepts decimals", function()
  t.eq(Logic.ParseNumber("1.25"), 1.25)
  t.eq(Logic.ParseNumber(".5"), 0.5)
  t.eq(Logic.ParseNumber("3."), 3)
end)

t.test("ParseNumber ignores surrounding whitespace and a leading plus", function()
  t.eq(Logic.ParseNumber("  12 "), 12)
  t.eq(Logic.ParseNumber("+7"), 7)
end)

t.test("ParseNumber rejects non-numeric text", function()
  t.eq(Logic.ParseNumber(""), nil)
  t.eq(Logic.ParseNumber("-"), nil)
  t.eq(Logic.ParseNumber("."), nil)
  t.eq(Logic.ParseNumber("abc"), nil)
  t.eq(Logic.ParseNumber("1.2.3"), nil)
  t.eq(Logic.ParseNumber("5 5"), nil)
end)

t.test("ParseNumber rejects forms tonumber would accept", function()
  t.eq(Logic.ParseNumber("0x10"), nil)
  t.eq(Logic.ParseNumber("1e3"), nil)
  t.eq(Logic.ParseNumber("inf"), nil)
  t.eq(Logic.ParseNumber("nan"), nil)
end)

t.test("ParseNumber rejects non-string input", function()
  t.eq(Logic.ParseNumber(nil), nil)
  t.eq(Logic.ParseNumber(5), nil)
end)
