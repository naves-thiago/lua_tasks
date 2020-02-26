local tasks = require"tasks"
setmetatable(_ENV, {__index = tasks})

tests = {}

function emit_without_await_does_nothing()
	local x = 0
	local function fa() await(1) x = 1 end
	local ta = task_t:new(fa)
	ta()
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
end
table.insert(tests, emit_without_await_does_nothing)

function emit_unblocks_await()
	local x = 0
	local function fa() await(1) x = 1 end
	local ta = task_t:new(fa)
	ta()
	assert(x == 0)
	assert(ta.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
end
table.insert(tests, emit_unblocks_await)

function inner_task_blocks_outer_task()
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() ta() x = 1 end)
	tb()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
end
table.insert(tests, inner_task_blocks_outer_task)

function outer_task_kills_inner_task()
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() ta() x = 1 end)
	tb()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	tb:kill()
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
end
table.insert(tests, outer_task_kills_inner_task)

function task_no_wait_execution()
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() ta(true) await(2) x = 1 end)
	tb()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	emit(2)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
end
table.insert(tests, task_no_wait_execution)

------------------------------------------------------

-- Get function names
local fname = {}
for _, f in ipairs(tests) do
	fname[f] = true
end
for name, f in pairs(_ENV) do
	if fname[f] then
		fname[f] = name
	end
end

-- Check command line args
if #arg > 0 then
	local t = {}
	for _, name in ipairs(arg) do
		local f = _ENV[name]
		if type(f) == "function" then
			table.insert(t, f)
		end
	end
	tests = t
end

local test_count = #tests
-- Run the tests
for index, func in ipairs(tests) do
	io.stdout:write(string.format("%s (%d/%d): ", fname[func], index, test_count))
	local c = coroutine.create(func)
	local success, message = coroutine.resume(c)
	if success then
		print("OK")
	else
		print("FAILED")
		print(debug.traceback(c, message))
	end
end

--[[
function fa() print("ta ini") await(1) print("ta fim") end
ta = task_t:new(fa, "A")
function fb() print("tb ini") await(2) print("tb fim") end
tb = task_t:new(fb, "B")
function fc() print("tc ini") await(3) print("tc fim") end
tc = task_t:new(fc, "C")
function fd() print("td ini") await(4) print("td fim") end
td = task_t:new(fd, "D")
function fe() print("te ini") par_or(par_and(td, tc), par_or(ta, tb))() print("te fim") await(5) print("te fim 2") end
te = task_t:new(fe, "E")
te()
--]]
