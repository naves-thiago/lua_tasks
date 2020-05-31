--[[
MIT License

Copyright (c) 2019 Thiago Duarte Naves (naves-thiago)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local t = require"tasks"

tests = {}
function tests.add(f)
	assert(type(f) == "function")
	table.insert(tests, f)
end

function event_await()
	local flag = false
	local e = t.event_t:new()
	e:await(function() flag = true end)
	assert(flag == false)
	e()
	assert(flag == true)

	flag = false
	e()
	assert(flag == false)
end
tests.add(event_await)

function event_listen()
	local flag = false
	local e = t.event_t:new()
	e:listen(function() flag = true end)
	assert(flag == false)
	e()
	assert(flag == true)

	flag = false
	e()
	assert(flag == true)
end
tests.add(event_listen)

function event_remove_listener()
	local flag = false
	local f = function() flag = true end
	local e = t.event_t:new()

	-- Remove before first call
	e:listen(f)
	e:remove_listener(f)
	e()
	assert(flag == false)

	e:await(f)
	e:remove_listener(f)
	e()
	assert(flag == false)

	-- Remove after first call
	e:listen(f)
	e()
	assert(flag == true)
	flag = false
	e:remove_listener(f)
	e()
	assert(flag == false)

	e:await(f)
	e()
	assert(flag == true)
	flag = false
	e:remove_listener(f)
	e()
	assert(flag == false)
end
tests.add(event_remove_listener)

function event_listener_count()
	local function l1() end
	local function l2() end
	local function a1() end
	local function a2() end
	local e = t.event_t:new()
	assert(e:listener_count() == 0)

	e:remove_listener(l1)
	assert(e:listener_count() == 0)

	e:listen(l1)
	assert(e:listener_count() == 1)

	e:await(a1)
	assert(e:listener_count() == 2)

	e:await(a2)
	assert(e:listener_count() == 3)

	e:listen(l2)
	assert(e:listener_count() == 4)

	e:await(l2) -- change listen -> await
	assert(e:listener_count() == 4)

	e:remove_listener(function() end) -- Remove non-listener
	assert(e:listener_count() == 4)

	e:remove_listener(l2)
	assert(e:listener_count() == 3)

	e:listen(a2) -- change await -> listen
	assert(e:listener_count() == 3)

	e:remove_listener(a2)
	assert(e:listener_count() == 2)

	e:remove_listener(a1)
	assert(e:listener_count() == 1)

	e:remove_listener(a1) -- Remove already removed
	assert(e:listener_count() == 1)

	e:remove_listener(l1)
	assert(e:listener_count() == 0)

	e:remove_listener(l1) -- Remove already removed when empty
	assert(e:listener_count() == 0)
end
tests.add(event_listener_count)

function event_add_listener_in_callback()
	local count_inside = 0
	local e = t.event_t:new()
	local l1_exec = false
	local l2_exec = false
	local function l2() l2_exec = true end
	local function l1()
		l1_exec = true
		e:listen(l2)
		count_inside = e:listener_count()
	end

	e:listen(l1)
	assert(e:listener_count() == 1)
	e()
	assert(l1_exec == true)
	assert(l2_exec == false)
	assert(e:listener_count() == 2)
	l1_exec = false
	e()
	assert(l1_exec == true)
	assert(l2_exec == true)
end
tests.add(event_add_listener_in_callback)

function event_add_await_in_callback()
	local count_inside = 0
	local e = t.event_t:new()
	local a1_exec = false
	local a2_exec = false
	local function a2() a2_exec = true end
	local function a1()
		a1_exec = true
		e:await(a2)
		count_inside = e:listener_count()
	end

	e:await(a1)
	assert(e:listener_count() == 1)
	e()
	assert(e:listener_count() == 1)
	assert(a1_exec == true)
	assert(a2_exec == false)
	a1_exec = false
	e()
	assert(e:listener_count() == 0)
	assert(a1_exec == false)
	assert(a2_exec == true)
end
tests.add(event_add_await_in_callback)

function tasks_start_with_state_ready()
	local ta = t.task_t:new(function() end)
	local tb = t.task_t:new(function() end)
	local por = t.par_or(ta, tb)
	local pand = t.par_and(ta, tb)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(por.state == "ready")
	assert(pand.state == "ready")
end
tests.add(tasks_start_with_state_ready)

function tasks_set_current_task()
	assert(t._scheduler.current == nil)
	local function is_curr(tsk) return t._scheduler.current == tsk end
	local a1, a2, b1, b2
	local ta, tb
	ta = t.task_t:new(function() a1 = is_curr(ta) t.await(1) a2 = is_curr(ta) end)
	assert(t._scheduler.current == nil)
	ta()
	t.emit(1)
	assert(a1)
	assert(a2)

	ta = t.task_t:new(function() a1 = is_curr(ta) t.await(1) a2 = is_curr(ta) end)
	tb = t.task_t:new(function() b1 = is_curr(tb) ta() b2 = is_curr(tb) end)
	tb()
	t.emit(1)
	assert(a1)
	assert(a2)
	assert(b1)
	assert(b2)
	assert(t._scheduler.current == nil)
end
tests.add(tasks_set_current_task)

function emit_without_await_does_nothing()
	local x = 0
	local function fa() t.await(1) x = 1 end
	local ta = t.task_t:new(fa)
	ta()
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
end
tests.add(emit_without_await_does_nothing)

function emit_unblocks_await()
	local x = 0
	local function fa() t.await(1) x = 1 end
	local ta = t.task_t:new(fa)
	ta()
	assert(x == 0)
	assert(ta.state == "alive")
	t.emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
end
tests.add(emit_unblocks_await)

function await_returns_emit_params()
	local a, b
	local function fa() a, b = t.await(1) end
	local ta = t.task_t:new(fa)
	ta()
	assert(ta.state == "alive")
	assert(a == nil)
	assert(b == nil)
	t.emit(1, 2, 3)
	assert(ta.state == "dead")
	assert(a == 2)
	assert(b == 3)
end
tests.add(await_returns_emit_params)

function task_kill_removes_await_listener()
	t._scheduler.waiting[1] = nil

	local ta = t.task_t:new(function() t.await(1) end)
	ta()
	assert(t._scheduler.waiting[1] ~= nil)
	assert(t._scheduler.waiting[1]:listener_count() == 1)

	ta:kill()
	assert(t._scheduler.waiting[1]:listener_count() == 0)
end
tests.add(task_kill_removes_await_listener)

function task_kill_unblocks_parent()
	local flag = false
	local function fa() t.await(1) end
	local ta = t.task_t:new(fa)
	local function fb() ta() flag = true end
	local tb = t.task_t:new(fb)
	tb()
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(not flag)
	ta:kill()
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(flag)
end
tests.add(task_kill_unblocks_parent)

function task_kill_ends_par_or()
	local ta = t.task_t:new(function () t.await(1) end)
	local tp = t.par_or(ta, function() t.await(2) end)
	tp()
	assert(tp.state == "alive")
	assert(ta.state == "alive")
	ta:kill()
	assert(tp.state == "dead")
	assert(ta.state == "dead")
end
tests.add(task_kill_ends_par_or)

function task_kill_counts_towards_par_and()
	local ta = t.task_t:new(function () t.await(1) end)
	local tp = t.par_and(ta, function() end)
	tp()
	assert(tp.state == "alive")
	assert(ta.state == "alive")
	ta:kill()
	assert(tp.state == "dead")
	assert(ta.state == "dead")
end
tests.add(task_kill_counts_towards_par_and)

function task_suicide_unblocks_parent()
	local flag = false
	local ta
	local function fa() t.await(1) ta:kill() t.await(2) end
	ta = t.task_t:new(fa)
	local function fb() ta() flag = true end
	local tb = t.task_t:new(fb)
	tb()
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(not flag)
	t.emit(1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(flag)
end
tests.add(task_suicide_unblocks_parent)

function task_suicide_ends_par_or()
	local ta
	local function fa() t.await(1) ta:kill() t.await(2) end
	ta = t.task_t:new(fa)
	local tp = t.par_or(ta, function() t.await(2) end)
	tp()
	assert(tp.state == "alive")
	assert(ta.state == "alive")
	t.emit(1)
	assert(tp.state == "dead")
	assert(ta.state == "dead")
end
tests.add(task_suicide_ends_par_or)

function task_suicide_counts_towards_par_and()
	local ta
	local function fa() t.await(1) ta:kill() t.await(2) end
	ta = t.task_t:new(fa)
	local tp = t.par_and(ta, function() end)
	tp()
	assert(tp.state == "alive")
	assert(ta.state == "alive")
	t.emit(1)
	assert(tp.state == "dead")
	assert(ta.state == "dead")
end
tests.add(task_suicide_counts_towards_par_and)

function inner_task_blocks_outer_task()
	local x = 0
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() ta() x = 1 end)
	tb()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	t.emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
end
tests.add(inner_task_blocks_outer_task)

function outer_task_kills_inner_task()
	local x = 0
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() ta() x = 1 end)
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

function inner_task_removes_done_listener_from_parent_on_kill()
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() ta() coroutine.yield() end)
	assert(tb.done:listener_count() == 0)
	tb()
	assert(tb.done:listener_count() == 2)
	assert(tb.done.listeners[ta.suicide_cb])
	ta:kill()
	assert(tb.done.listeners[ta.suicide_cb] == nil)
	assert(tb.done:listener_count() == 0)
end
tests.add(inner_task_removes_done_listener_from_parent_on_kill)

function task_no_wait_execution()
	local x = 0
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() ta(true) t.await(2) x = 1 end)
	tb()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	t.emit(2)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
end
tests.add(task_no_wait_execution)

function par_or_finishes_with_either()
	for i = 1, 2 do
		local x = 0
		local ta = t.task_t:new(function() t.await(1) end)
		local tb = t.task_t:new(function() t.await(2) end)
		local tc = t.task_t:new(function() t.par_or(ta, tb)() x = 1 end)
		tc()
		assert(x == 0, "i = " .. i)
		assert(ta.state == "alive", "i = " .. i)
		assert(tb.state == "alive", "i = " .. i)
		assert(tc.state == "alive", "i = " .. i)
		t.emit(i)
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
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.par_and(ta, tb)() x = 1 end)
	tc()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	t.emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	t.emit(2)
	assert(x == 1)
	assert(tb.state == "dead")
	assert(tc.state == "dead")

	-- tb finishes first
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.par_and(ta, tb)() x = 1 end)
	tc()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	t.emit(1)
	assert(x == 1)
	assert(tb.state == "dead")
	assert(tc.state == "dead")
end
tests.add(par_and_finishes_with_both)

function nested_par_or()
	-- ta finishes first
	local x = 0
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.await(3) end)
	local td = t.task_t:new(function() t.par_or(ta, t.par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- tb finishes first
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.await(3) end)
	td = t.task_t:new(function() t.par_or(ta, t.par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(2)
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
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.await(3) end)
	local td = t.task_t:new(function() t.par_and(ta, t.par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(3)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- ta finishes last
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.await(3) end)
	td = t.task_t:new(function() t.par_and(ta, t.par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(3)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	t.emit(1)
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
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.await(3) end)
	local td = t.task_t:new(function() t.par_or(ta, t.par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- par_and finishes first
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.await(3) end)
	td = t.task_t:new(function() t.par_or(ta, t.par_and(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(3)
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
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.await(3) end)
	local td = t.task_t:new(function() t.par_and(ta, t.par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")

	-- ta finishes last
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.await(3) end)
	td = t.task_t:new(function() t.par_and(ta, t.par_or(tb, tc))() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(3)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	t.emit(1)
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
		local ta = t.task_t:new(function() t.await(1) end)
		local tb = t.task_t:new(function() t.await(2) end)
		local tc = t.task_t:new(function() t.await(3) end)
		local td = t.task_t:new(function() t.await(4) end)
		local te = t.task_t:new(function() t.par_or(ta, t.par_or(tb, t.par_or(tc, td)))() x = 1 end)
		te()
		assert(x == 0)
		assert(ta.state == "alive")
		assert(tb.state == "alive")
		assert(tc.state == "alive")
		assert(td.state == "alive")
		assert(te.state == "alive")
		t.emit(i)
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
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.await(3) end)
	local td = t.task_t:new(function() t.await(4) end)
	local te = t.task_t:new(function() t.par_and(ta, t.par_and(tb, t.par_and(tc, td)))() x = 1 end)
	te()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(3)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(4)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "dead")

	-- Inner first
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.await(3) end)
	td = t.task_t:new(function() t.await(4) end)
	te = t.task_t:new(function() t.par_and(ta, t.par_and(tb, t.par_and(tc, td)))() x = 1 end)
	te()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(4)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "dead")
	assert(te.state == "alive")
	t.emit(3)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "alive")
	t.emit(1)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
	assert(te.state == "dead")

	-- Middle first
	x = 0
	ta = t.task_t:new(function() t.await(1) end)
	tb = t.task_t:new(function() t.await(2) end)
	tc = t.task_t:new(function() t.await(3) end)
	td = t.task_t:new(function() t.await(4) end)
	te = t.task_t:new(function() t.par_and(ta, t.par_and(tb, t.par_and(tc, td)))() x = 1 end)
	te()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(3)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "alive")
	assert(te.state == "alive")
	t.emit(4)
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
		local ta = t.task_t:new(function() t.await(1) end)
		local tb = t.task_t:new(function() t.await(2) end)
		local tc = t.task_t:new(function() t.await(3) end)
		local td = t.task_t:new(function() t.par_or(ta, tb, tc)() x = 1 end)
		td()
		assert(x == 0)
		assert(ta.state == "alive")
		assert(tb.state == "alive")
		assert(tc.state == "alive")
		assert(td.state == "alive")
		t.emit(i)
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
	local ta = t.task_t:new(function() t.await(1) end)
	local tb = t.task_t:new(function() t.await(2) end)
	local tc = t.task_t:new(function() t.await(3) end)
	local td = t.task_t:new(function() t.par_and(ta, tb, tc)() x = 1 end)
	td()
	assert(x == 0)
	assert(ta.state == "alive")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(1)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(2)
	assert(x == 0)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "alive")
	assert(td.state == "alive")
	t.emit(3)
	assert(x == 1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tc.state == "dead")
	assert(td.state == "dead")
end
tests.add(par_and_three_tasks)

function par_or_function_parameter()
	local x, y = 0, 0
	local function fx() x = 1 t.await(1) end
	local function fy() y = 2 t.await(1) end
	local p = t.par_or(fx, fy)
	p()
	assert(x == 1)
	assert(y == 2)
	p:kill()
end
tests.add(par_or_function_parameter)

function par_and_function_parameter()
	local x, y = 0, 0
	local function fx() x = 1 t.await(1) end
	local function fy() y = 2 t.await(1) end
	local p = t.par_and(fx, fy)
	p()
	assert(x == 1)
	assert(y == 2)
	p:kill()
end
tests.add(par_and_function_parameter)

function independent_subtask()
    local function fa() t.await(1) end
    local ta = t.task_t:new(fa)
    local function fb() ta(false, true) end
    local tb = t.task_t:new(fb)
    tb()
    assert(ta.state == "alive")
    assert(tb.state == "alive")
    tb:kill()
    assert(ta.state == "alive")
    assert(tb.state == "dead")
    ta:kill()
    assert(ta.state == "dead")

    function fa() t.await(1) end
    ta = t.task_t:new(fa)
    function fb() ta(true, true) end
    tb = t.task_t:new(fb)
    tb()
    assert(ta.state == "alive")
    assert(tb.state == "dead")
    ta:kill()
    assert(ta.state == "dead")
end
tests.add(independent_subtask)

function disown_subtask()
    local function fa() t.await(1) end
    local ta = t.task_t:new(fa)
    local function fb() ta(true) ta:disown() end
    local tb = t.task_t:new(fb)
    tb()
    assert(ta.state == "alive")
    assert(tb.state == "dead")
    ta:kill()
    assert(ta.state == "dead")
end
tests.add(disown_subtask)

function listen_repeat()
	local flag = false
	local function fa() flag = true end
	t.listen(1, fa)
	assert(flag == false)
	t.emit(1)
	assert(flag == true)
	flag = false
	t.emit(1)
	assert(flag == true)
	flag = false
	t.stop_listening(1, fa)
	t.emit(1)
	assert(flag == false)
end
tests.add(listen_repeat)

function listen_once()
	local flag = false
	local function fa() flag = true end
	t.listen(1, fa, true)
	assert(flag == false)
	t.emit(1)
	assert(flag == true)
	flag = false
	t.emit(1)
	assert(flag == false)
	t.stop_listening(1, fa)
	t.emit(1)
	assert(flag == false)
end
tests.add(listen_once)

function future_get_blocks()
	local a = 0
	local fa = function()
		local f = t.future_t:new(1)
		a = 1
		a = f:get()
	end
	local ta = t.task_t:new(fa)
	ta()
	assert(a == 1)
	assert(ta.state == "alive")
	t.emit(1, 2)
	assert(a == 2)
	assert(ta.state == "dead")
end
tests.add(future_get_blocks)

function future_get_doesntblock()
	local a = 0
	local fb = function()
		local f = t.future_t:new(1)
		a = 1
		t.emit(2)
		a = f:get()
	end
	local tb = t.task_t:new(fb)

	local fa = function()
		t.await(2)
		t.emit(1, 2)
	end
	local ta = t.task_t:new(fa)
	ta()
	tb()
	assert(a == 2)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
end
tests.add(future_get_doesntblock)

function future_get_multiple_returns()
	local a = 0
	local fa = function()
		local f = t.future_t:new(1)
		a = 1
		a = t.pack(f:get())
	end
	local ta = t.task_t:new(fa)
	ta()
	assert(a == 1)
	assert(ta.state == "alive")
	t.emit(1, 2, nil, 3, nil, 4, nil)

	assert(a[0] == 6)
	assert(a[1] == 2)
	assert(a[2] == nil)
	assert(a[3] == 3)
	assert(a[4] == nil)
	assert(a[5] == 4)
	assert(a[6] == nil)
	assert(ta.state == "dead")
end
tests.add(future_get_multiple_returns)

function future_done()
	local is_done = 0
	local function fa()
		local f = t.future_t:new(1)
		is_done = f:is_done()
		t.await(1)
		is_done = f:is_done()
	end
	local ta = t.task_t:new(fa)
	ta()
	assert(ta.state == "alive")
	assert(is_done == false)
	t.emit(1)
	assert(is_done == true)
	assert(ta.state == "dead")
end
tests.add(future_done)

function future_get_cancelled()
	local a = 0
	local b = 0
	local f = t.future_t:new(1)
	local function fa()
		a = f:get()
		b = 1
	end
	local ta = t.task_t:new(fa)
	f:cancel()
	ta()
	assert(a == nil)
	assert(b == 1)
	assert(f:is_cancelled())
	assert(not f:is_done())
end
tests.add(future_get_cancelled)

function future_get_cancelled_ignores_event()
	local a = 0
	local b = 0
	local f = t.future_t:new(1)
	local function fa()
		a = f:get()
		b = 1
	end
	local ta = t.task_t:new(fa)
	f:cancel()
	t.emit(1, 2)
	ta()
	t.emit(1, 2)
	assert(a == nil)
	assert(b == 1)
	assert(f:is_cancelled())
end
tests.add(future_get_cancelled_ignores_event)

function future_cancel_done()
	local f = t.future_t:new(1)
	assert(not f:is_done())
	assert(not f:is_cancelled())
	t.emit(1)
	assert(f:is_done())
	assert(not f:is_cancelled())
	f:cancel()
	assert(f:is_done())
	assert(not f:is_cancelled())
end
tests.add(future_cancel_done)

function future_cancel_cb_executes_on_cancel()
	local cancelled = false
	local f = t.future_t:new(1, function() cancelled = true end)
	assert(not f:is_done())
	assert(not f:is_cancelled())
	assert(not cancelled)
	f:cancel()
	assert(not f:is_done())
	assert(f:is_cancelled())
	assert(cancelled)
end
tests.add(future_cancel_cb_executes_on_cancel)

function future_cancel_cb_doesnt_execute_on_double_cancel()
	local cancelled = false
	local f = t.future_t:new(1, function() cancelled = true end)
	assert(not f:is_done())
	assert(not f:is_cancelled())
	assert(not cancelled)
	f:cancel()
	assert(not f:is_done())
	assert(f:is_cancelled())
	assert(cancelled)
	cancelled = false
	f:cancel()
	assert(not f:is_done())
	assert(f:is_cancelled())
	assert(not cancelled)
end
tests.add(future_cancel_cb_doesnt_execute_on_double_cancel)

function future_cancel_cb_doesnt_execute_after_done()
	local cancelled = false
	local f = t.future_t:new(1, function() cancelled = true end)
	assert(not f:is_done())
	assert(not f:is_cancelled())
	assert(not cancelled)
	t.emit(1)
	assert(f:is_done())
	assert(not f:is_cancelled())
	assert(not cancelled)
end
tests.add(future_cancel_cb_doesnt_execute_after_done)

function task_return_value()
	local ta = t.task_t:new(function() return 1, nil, 2, nil, 3, nil end)
	local r = t.pack(ta())
	assert(r[0] == 6)
	assert(r[1] == 1)
	assert(r[2] == nil)
	assert(r[3] == 2)
	assert(r[4] == nil)
	assert(r[5] == 3)
	assert(r[6] == nil)
end
tests.add(task_return_value)

function task_result()
	local ta = t.task_t:new(function() return 1, nil, 2, nil, 3, nil end)
	ta()
	local r = t.pack(ta:result())
	assert(r[0] == 6)
	assert(r[1] == 1)
	assert(r[2] == nil)
	assert(r[3] == 2)
	assert(r[4] == nil)
	assert(r[5] == 3)
	assert(r[6] == nil)
end
tests.add(task_result)

function par_or_return_value()
	local function fa() t.await(1) return 1, nil, 2, nil, 3, nil end
	local function fb() t.await(2) return 2, nil, 3, nil, 4, nil end
	local pt = t.par_or(fa, fb)
	pt(true)
	t.emit(1)
	local r = t.pack(pt:result())
	assert(r[0] == 6, ""..r[0].." ~= 6")
	assert(r[1] == 1)
	assert(r[2] == nil)
	assert(r[3] == 2)
	assert(r[4] == nil)
	assert(r[5] == 3)
	assert(r[6] == nil)

	pt = t.par_or(fa, fb)
	pt(true)
	t.emit(2)
	r = t.pack(pt:result())
	assert(r[0] == 6)
	assert(r[1] == 2)
	assert(r[2] == nil)
	assert(r[3] == 3)
	assert(r[4] == nil)
	assert(r[5] == 4)
	assert(r[6] == nil)
end
tests.add(par_or_return_value)

function par_or_handles_subtask_not_blocking()
	local function fa() return 1 end
	local function fb() t.await(1) end

	-- First ends first
	local ta = t.task_t:new(fa)
	local tb = t.task_t:new(fb)
	local tp = t.par_or(ta, tb)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(tp.state == "ready")
	tp()
	assert(ta.state == "dead")
	assert(tb.state == "ready")
	assert(tp.state == "dead")
	assert(tp:result() == 1)

	-- First ends last
	ta = t.task_t:new(fa)
	tb = t.task_t:new(fb)
	tp = t.par_or(tb, ta)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(tp.state == "ready")
	tp()
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tp.state == "dead")
	assert(tp:result() == 1)
end
tests.add(par_or_handles_subtask_not_blocking)

function par_and_handles_all_subtasks_not_blocking()
	local ta = t.task_t:new(function() end)
	local tb = t.task_t:new(function() end)
	local tp = t.par_and(ta, tb)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(tp.state == "ready")
	tp()
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tp.state == "dead")
end
tests.add(par_and_handles_all_subtasks_not_blocking)

function par_and_handles_subtask_not_blocking()
	-- First task ends first
	local ta = t.task_t:new(function() end)
	local tb = t.task_t:new(function() t.await(1) end)
	local tp = t.par_and(ta, tb)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(tp.state == "ready")
	tp()
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tp.state == "alive")
	t.emit(1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tp.state == "dead")

	-- First task ends last
	ta = t.task_t:new(function() end)
	tb = t.task_t:new(function() t.await(1) end)
	tp = t.par_and(tb, ta)
	assert(ta.state == "ready")
	assert(tb.state == "ready")
	assert(tp.state == "ready")
	tp()
	assert(ta.state == "dead")
	assert(tb.state == "alive")
	assert(tp.state == "alive")
	t.emit(1)
	assert(ta.state == "dead")
	assert(tb.state == "dead")
	assert(tp.state == "dead")
end
tests.add(par_and_handles_subtask_not_blocking)

function trigger_once_timer_executes_only_once()
	local exec = false
	local tmr = t.timer_t:new(1, function() exec = true end, false)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)
	t.update_time(1)
	assert(exec == true)
	assert(tmr.active == false)

	exec = false
	t.update_time(1)
	assert(exec == false)
	assert(tmr.active == false)
end
tests.add(trigger_once_timer_executes_only_once)

function cyclic_timer_executes_twice()
	local exec = false
	local tmr = t.timer_t:new(1, function() exec = true end, true)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(1)
	assert(exec == true)
	assert(tmr.active == true)

	exec = false
	t.update_time(1)
	assert(exec == true)
	assert(tmr.active == true)
end
tests.add(cyclic_timer_executes_twice)

function trigger_once_timer_executes_after_2_updates()
	local exec = false
	local tmr = t.timer_t:new(2, function() exec = true end, false)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(1)
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(1)
	assert(exec == true)
	assert(tmr.active == false)

	exec = false
	t.update_time(1)
	assert(exec == false)
	assert(tmr.active == false)
end
tests.add(trigger_once_timer_executes_after_2_updates)

function cyclic_timer_executes_after_2_updates()
	local exec = false
	local tmr = t.timer_t:new(2, function() exec = true end, true)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	for i = 1, 2 do
		exec = false
		t.update_time(1)
		assert(tmr.active == true)
		assert(exec == false)

		t.update_time(1)
		assert(exec == true)
		assert(tmr.active == true)
	end
end
tests.add(cyclic_timer_executes_after_2_updates)

function trigger_once_timer_executes_when_late()
	local exec = false
	local tmr = t.timer_t:new(2, function() exec = true end, false)
	assert(tmr.active == false)

	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(3)
	assert(exec == true)
	assert(tmr.active == false)

	exec = false
	t.update_time(3)
	assert(exec == false)
	assert(tmr.active == false)
end
tests.add(trigger_once_timer_executes_when_late)

function cyclic_timer_executes_when_late()
	local exec = false
	local tmr = t.timer_t:new(2, function() exec = true end, true)
	assert(tmr.active == false)

	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(3)
	assert(exec == true)
	assert(tmr.active == true)

	exec = false
	t.update_time(2)
	assert(exec == true)
	assert(tmr.active == true)
end
tests.add(cyclic_timer_executes_when_late)

function stop_trigger_once_timer()
	local exec = false
	local tmr = t.timer_t:new(2, function() exec = true end, false)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	tmr:stop()
	assert(tmr.active == false)
	assert(exec == false)

	t.update_time(1)
	assert(tmr.active == false)
	assert(exec == false)
end
tests.add(stop_trigger_once_timer)

function stop_cyclic_timer()
	local exec = false
	-- Stop before first execution
	local tmr = t.timer_t:new(2, function() exec = true end, true)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)
	tmr:stop()
	assert(tmr.active == false)
	assert(exec == false)

	t.update_time(1)
	assert(tmr.active == false)
	assert(exec == false)

	t.update_time(1)
	assert(tmr.active == false)
	assert(exec == false)

	-- Stop after the first execution
	tmr = t.timer_t:new(2, function() exec = true end, true)
	assert(tmr.active == false)
	tmr:start()
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(2)
	assert(tmr.active == true)
	assert(exec == true)

	exec = false
	tmr:stop()
	assert(tmr.active == false)
	assert(exec == false)

	t.update_time(2)
	assert(tmr.active == false)
	assert(exec == false)
end
tests.add(stop_cyclic_timer)

function in_ms_triggers_only_once()
	local exec = false
	local tmr = t.in_ms(2, function() exec = true end)

	t.update_time(1)
	assert(tmr.active == true)
	assert(exec == false)

	t.update_time(1)
	assert(exec == true)
	assert(tmr.active == false)

	exec = false
	t.update_time(1)
	assert(exec == false)
	assert(tmr.active == false)
end
tests.add(in_ms_triggers_only_once)

function every_ms_triggers_periodically()
	local exec = false
	local tmr = t.every_ms(2, function() exec = true end)

	for i = 1, 2 do
		exec = false
		t.update_time(1)
		assert(tmr.active == true)
		assert(exec == false)

		t.update_time(1)
		assert(exec == true)
		assert(tmr.active == true)
	end
end
tests.add(every_ms_triggers_periodically)

function await_ms_blocks_task()
	local out = 0
	local fa = function() t.await_ms(1) out = 1 end
	local ta = t.task_t:new(fa)
	ta()
	assert(out == 0)
	t.update_time(1)
	assert(out == 1)
end
tests.add(await_ms_blocks_task)

function await_ms_unblock_multiple_tasks_at_once()
	local a, b = 0, 0
	local fa = function() t.await_ms(1) a = 1 end
	local fb = function() t.await_ms(1) b = 1 end
	local ta = t.task_t:new(fa)
	local tb = t.task_t:new(fb)
	ta()
	tb()
	assert(a == 0)
	assert(b == 0)
	t.update_time(1)
	assert(a == 1)
	assert(b == 1)
end
tests.add(await_ms_unblock_multiple_tasks_at_once)

------------------------------------------------------

-- Get function names
local fname = {}
for _, f in ipairs(tests) do
	fname[f] = true
end
for name, f in pairs(_G) do
	if fname[f] then
		fname[f] = name
	end
end

-- Check command line args
if #arg > 0 then
	local t = {}
	for _, name in ipairs(arg) do
		local f = _G[name]
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
