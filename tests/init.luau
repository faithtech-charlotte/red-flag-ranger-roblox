--[[
	Tiny test runner for pure game logic. Synced to ServerStorage.Tests.

	Run from the Studio command bar (Edit mode is fine):
	  print(require(game.ServerStorage.Tests)())

	Each *.spec module returns function(t) and uses t.test / t.expect.
]]

local function deepEqual(a, b): boolean
	if typeof(a) ~= typeof(b) then
		return false
	end
	if typeof(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function expect(actual)
	local e = {}
	function e.toBe(expected)
		if actual ~= expected then
			error(`expected {tostring(expected)}, got {tostring(actual)}`, 2)
		end
	end
	function e.toEqual(expected)
		if not deepEqual(actual, expected) then
			error("tables differ", 2)
		end
	end
	function e.toBeTruthy()
		if not actual then
			error(`expected truthy, got {tostring(actual)}`, 2)
		end
	end
	function e.toBeFalsy()
		if actual then
			error(`expected falsy, got {tostring(actual)}`, 2)
		end
	end
	return e
end

return function(): string
	local passed, failed = 0, 0
	local lines = {}
	for _, spec in script:GetChildren() do
		if spec:IsA("ModuleScript") and spec.Name:match("%.spec$") then
			local suite = require(spec) :: any
			local t = {
				expect = expect,
				test = function(name: string, fn: () -> ())
					local ok, err = pcall(fn)
					if ok then
						passed += 1
					else
						failed += 1
						table.insert(lines, `  FAIL {spec.Name} > {name}: {err}`)
					end
				end,
			}
			local ok, err = pcall(suite, t)
			if not ok then
				failed += 1
				table.insert(lines, `  ERROR loading {spec.Name}: {err}`)
			end
		end
	end
	table.insert(lines, 1, `Tests: {passed} passed, {failed} failed`)
	return table.concat(lines, "\n")
end
