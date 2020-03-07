local tasks = require"tasks"
setmetatable(_ENV, {__index = tasks})

tests = {}
function tests.add(f)
	assert(type(f) == "function")
	table.insert(tests, f)
end

function tasks_start_with_state_ready()
	local ta = task_t:new(function() end)
	local tb = task_t:new(function() end)
	local por = par_or(ta, tb)
	local pand = par_and(ta, tb)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(por.state == "ready")
	assert(pand.state == "ready")
end
tests.add(tasks_start_with_state_ready)

function emit_without_await_does_nothing()
	local x = 0
	local function fa() await(1) x = 1 end
	local ta = task_t:new(fa)
	ta()
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
end
tests.add(emit_without_await_does_nothing)

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
tests.add(emit_unblocks_await)

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
tests.add(inner_task_blocks_outer_task)

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
tests.add(outer_task_kills_inner_task)

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
tests.add(task_no_wait_execution)

function par_or_finishes_with_either()
	for i = 1, 2 do
		local x = 0
		local ta = task_t:new(function() await(1) end)
		local tb = task_t:new(function() await(2) end)
		local tc = task_t:new(function() par_or(ta, tb)() x = 1 end)
		tc()
		assert(x == 0, "i = " .. i)
		assert(ta.state == "alive", "i = " .. i)
		assert(tb.state == "alive", "i = " .. i)
		assert(tc.state == "alive", "i = " .. i)
		emit(i)
		assert(x == 1, "i = " .. i)
		assert(ta.state == "dead", "i = " .. i)
		assert(tb.state == "dead", "i = " .. i)
		assert(tc.state == "dead", "i = " .. i)
	end
end
tests.add(par_or_finishes_with_either)

function par_and_finishes_with_both()
	-- ta finishes first
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() par_and(ta, tb)() x = 1 end)
	tc()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	emit(2)
	assert(x == 1)
	assert(tb.state == "dead")
	assert(tc.state == "dead")

	-- tb finishes first
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() par_and(ta, tb)() x = 1 end)
	tc()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	emit(1)
	assert(x == 1)
	assert(tb.state == "dead")
	assert(tc.state == "dead")
end
tests.add(par_and_finishes_with_both)

function nested_par_or()
	-- ta finishes first
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() await(3) end)
	local td = task_t:new(function() par_or(ta, par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- tb finishes first
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() await(3) end)
	td = task_t:new(function() par_or(ta, par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(2)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
end
tests.add(nested_par_or)

function nested_par_and()
	-- ta finishes first
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() await(3) end)
	local td = task_t:new(function() par_and(ta, par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(3)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- ta finishes last
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() await(3) end)
	td = task_t:new(function() par_and(ta, par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(3)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
end
tests.add(nested_par_and)

function par_and_in_par_or()
	-- ta finishes first
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() await(3) end)
	local td = task_t:new(function() par_or(ta, par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- par_and finishes first
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() await(3) end)
	td = task_t:new(function() par_or(ta, par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(3)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
end
tests.add(par_and_in_par_or)

function par_or_in_par_and()
	-- ta finishes first
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() await(3) end)
	local td = task_t:new(function() par_and(ta, par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- ta finishes last
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() await(3) end)
	td = task_t:new(function() par_and(ta, par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(3)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
end
tests.add(par_and_in_par_or)

function three_nested_ors()
	for i = 1, 4 do
		local x = 0
		local ta = task_t:new(function() await(1) end)
		local tb = task_t:new(function() await(2) end)
		local tc = task_t:new(function() await(3) end)
		local td = task_t:new(function() await(4) end)
		local te = task_t:new(function() par_or(ta, par_or(tb, par_or(tc, td)))() x = 1 end)
		te()
		assert(x == 0)
		assert(ta.state == "alive")
		assert(tb.state == "alive")
		assert(tc.state == "alive")
		assert(td.state == "alive")
		assert(te.state == "alive")
		emit(i)
		assert(x == 1)
		assert(ta.state == "dead")
		assert(tb.state == "dead")
		assert(tc.state == "dead")
		assert(td.state == "dead")
		assert(te.state == "dead")
	end
end
tests.add(three_nested_ors)

function three_nested_ands()
	-- Outer first
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() await(3) end)
	local td = task_t:new(function() await(4) end)
	local te = task_t:new(function() par_and(ta, par_and(tb, par_and(tc, td)))() x = 1 end)
	te()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(3)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(4)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "dead")

	-- Inner first
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() await(3) end)
	td = task_t:new(function() await(4) end)
	te = task_t:new(function() par_and(ta, par_and(tb, par_and(tc, td)))() x = 1 end)
	te()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(4)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "dead")
	assert(te.state == "alive")
	emit(3)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "alive")
	emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "dead")

	-- Middle first
	x = 0
	ta = task_t:new(function() await(1) end)
	tb = task_t:new(function() await(2) end)
	tc = task_t:new(function() await(3) end)
	td = task_t:new(function() await(4) end)
	te = task_t:new(function() par_and(ta, par_and(tb, par_and(tc, td)))() x = 1 end)
	te()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(3)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	assert(te.state == "alive")
	emit(4)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "dead")
end
tests.add(three_nested_ands)

function par_or_three_tasks()
	for i = 1, 3 do
		local x = 0
		local ta = task_t:new(function() await(1) end)
		local tb = task_t:new(function() await(2) end)
		local tc = task_t:new(function() await(3) end)
		local td = task_t:new(function() par_or(ta, tb, tc)() x = 1 end)
		td()
		assert(x == 0)
		assert(ta.state == "alive")
		assert(tb.state == "alive")
		assert(tc.state == "alive")
		assert(td.state == "alive")
		emit(i)
		assert(x == 1)
		assert(ta.state == "dead")
		assert(tb.state == "dead")
		assert(tc.state == "dead")
		assert(td.state == "dead")
	end
end
tests.add(par_or_three_tasks)

function par_and_three_tasks()
	local x = 0
	local ta = task_t:new(function() await(1) end)
	local tb = task_t:new(function() await(2) end)
	local tc = task_t:new(function() await(3) end)
	local td = task_t:new(function() par_and(ta, tb, tc)() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	emit(3)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
end
tests.add(par_and_three_tasks)

function par_or_function_parameter()
	local x, y = 0, 0
	local function fx() x = 1 await(1) end
	local function fy() y = 2 await(1) end
	local p = par_or(fx, fy)
	p()
	assert(x == 1)
	assert(y == 2)
	p:kill()
end
tests.add(par_or_function_parameter)

function par_and_function_parameter()
	local x, y = 0, 0
	local function fx() x = 1 await(1) end
	local function fy() y = 2 await(1) end
	local p = par_and(fx, fy)
	p()
	assert(x == 1)
	assert(y == 2)
	p:kill()
end
tests.add(par_and_function_parameter)

function independent_subtask()
    local function fa() await(1) end
    local ta = task_t:new(fa)
    local function fb() ta(false, true) end
    local tb = task_t:new(fb)
    tb()
    assert(ta.state == "alive")
    assert(tb.state == "alive")
    tb:kill()
    assert(ta.state == "alive")
    assert(tb.state == "dead")
    ta:kill()
    assert(ta.state == "dead")

    function fa() await(1) end
    ta = task_t:new(fa)
    function fb() ta(true, true) end
    tb = task_t:new(fb)
    tb()
    assert(ta.state == "alive")
    assert(tb.state == "dead")
    ta:kill()
    assert(ta.state == "dead")
end
tests.add(independent_subtask)

function disown_subtask()
    local function fa() await(1) end
    local ta = task_t:new(fa)
    local function fb() ta(true) ta:disown() end
    local tb = task_t:new(fb)
    tb()
    assert(ta.state == "alive")
    assert(tb.state == "dead")
    ta:kill()
    assert(ta.state == "dead")
end
tests.add(disown_subtask)

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
local failed = 0
-- Run the tests
for index, func in ipairs(tests) do
	io.stdout:write(string.format("%s (%d/%d): ", fname[func], index, test_count))
	local c = coroutine.create(func)
	local success, message = coroutine.resume(c)
	if success then
		print("OK")
	else
		failed = failed + 1
		print("FAILED")
		print(debug.traceback(c, message))
	end
end

print("-------------------------------------------")
if failed == 0 then
	print("All tests were successfull")
else
	print(failed .. " tests failed")
end
