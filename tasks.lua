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

local heap = require"BinaryMinHeap"
local m = {} -- module
local event_t = {}
local task_t = {}
local future_t = {}
local timer_t = {}
local scheduler = {current = nil, waiting = {}, timestamp = 0, waiting_time = heap:new()}
local table_unpack

m.event_t    = event_t
m.task_t     = task_t
m.future_t   = future_t
m.timer_t    = timer_t
m._scheduler = scheduler

-- Lua 5.1 compatibility
if _VERSION == "Lua 5.1" then
	table_unpack = unpack
else
	table_unpack = table.unpack
end

----- DEBUG -----
local function trace(...)
	--print(table.concat({"[TRACE]", ...}, ' '))
end
-----------------

-- Param forwarding
function m.pack(...)
	return {[0]=select("#", ...), ...}
end

function m.unpack(t)
	return table_unpack(t, 1, t[0])
end

-- Observer / Event API

-- Instantiates a new event_t object.
-- This class provides an observable object able to call multiple listeners and copy data to each one.
function event_t:new()
	-- new_listeners is used to store listeners added while we are executing __call, so we only
	-- execute those the next time __call is executed
	return setmetatable({listeners = {}, new_listeners = {}, _listener_count = 0, in_call = false},
		{__index = self, __call = self.__call})
end

-- Adds a new listener to this event. This listener will be executed every time this event is triggered.
-- If the callback is already a listener on this event, change it to be executed every time.
-- Param f: Callback function. May receive any number of parameters (those will be forwarded from __call()).
function event_t:listen(f)
	if self.listeners[f] == "repeat" or self.new_listeners[f] == "repeat" then
		return
	end

	if self.listeners[f] == "once" then
		self.listeners[f] = "repeat"
		return
	end

	if self.new_listeners[f] == "once" then
		self.new_listeners[f] = "repeat"
		return
	end

	self._listener_count = self._listener_count + 1
	if self.in_call then
		self.new_listeners[f] = "repeat"
	else
		self.listeners[f] = "repeat"
	end
end

-- Adds a new listener to this event. This listener will be executed only on the next time this event is triggered.
-- If the callback is already a listener on this event, change it to be executed once.
-- Param f: Callback function. May receive any number of parameters (those will be forwarded from __call()).
function event_t:await(f)
	if self.listeners[f] == "once" or self.new_listeners[f] == "once" then
		return
	end

	if self.listeners[f] == "repeat" then
		self.listeners[f] = "once"
		return
	end

	if self.new_listeners[f] == "repeat" then
		self.new_listeners[f] = "once"
		return
	end

	self._listener_count = self._listener_count + 1
	if self.in_call then
		self.new_listeners[f] = "once"
	else
		self.listeners[f] = "once"
	end
end

-- Removes a callback function from this event.
-- Param f: Callback function. Ignored if not a listener.
function event_t:remove_listener(f)
	if self.listeners[f] or self.new_listeners[f] then
		self._listener_count = self._listener_count - 1
	end
	self.listeners[f] = nil
	self.new_listeners[f] = nil
end

-- Returns the number of listeners
function event_t:listener_count()
	return self._listener_count
end

-- Triggers this event: Executes all the listeners and forward all parameters to each listener.
-- The order of execution of the listeners is not defined.
function event_t:__call(...)
	-- This function is not reentrant. Do not emit the event that unblocked the current task!

	assert(not self.in_call, "Emitting or calling an event from within its listener or reaction is not supported.")
	self.in_call = true
	for l, mode in pairs(self.listeners) do
		if mode == "once" then
			self.listeners[l] = nil
			self._listener_count = self._listener_count - 1
		end
		l(self, ...) -- Must be after `if mode ...`, otherwise may break if `l()` calls `:await()`
	end
	for l, mode in pairs(self.new_listeners) do
		self.listeners[l] = mode
	end
	self.new_listeners = {}
	self.in_call = false
end

-- Task
local function task_parent_trace(t)
	local out = {"Task start stack:"}
	repeat
		table.insert(out,  "        " .. t.name)
		t = t.parent
	until t == nil
	return table.concat(out, "\n")
end

function task_t:new(f, name)
	local t = {f = f, done = event_t:new(), state = "ready", parent = nil, coroutine = nil, name = name}
	if not name then
		t.name = tostring(t):sub(8)
	end
	trace("New task:", name)
	return setmetatable(t, {__index = self, __call = self.__call, __tostring = self.__tostring})
end

-- Task's string representation
function task_t:__tostring()
	return "task: " .. self.name .. " (" .. self.state .. ")"
end

-- Starts the task execution
-- Param no_wait: If true, the caller will not yield to wait for this task to complete
-- Param independent: Do not kill this task when the calling (parent) task die
-- Returns: Same values returned by the task function (set in the constructor) if it returns before this function returns.
-- i.e. __call will only return if no_wait is false or the task function return immediately.
function task_t:__call(no_await, independent)
	trace("Start task:", self.name, "State:", self.state, "Caller:", (scheduler.current and scheduler.current.name))
	if self.state ~= "ready" then
		return
	end
	self.state = "alive"
	self.parent = scheduler.current
	self.coroutine = coroutine.create(function() self.ret_val = m.pack(self.f()) self:kill() end)
	if self.parent and not independent then
		self.suicide_cb = function() self:kill() end
		self.parent.done:listen(self.suicide_cb)
	end
	local success, error_message = self:_resume()
	if success and self.parent and coroutine.status(self.coroutine) ~= "dead" and not no_await then
		-- Started from another task and not done yet
		trace("Block parent:", self.name, "Parent:", self.parent.name)
		self.done:listen(function(_, ...) m.emit(self, ...) end)
		m.await(self)
		trace("Unblock parent:", self.name, "Parent:", self.parent.name)
	end
	if success and self.ret_val then
		return m.unpack(self.ret_val)
	end
end

-- Stops the task execution and execute the task's done event.
-- Can be called from within the task itself or elsewhere.
-- Unblocks the parent task if blocked on this task's __call.
function task_t:kill()
	trace("Kill task:", self.name, "State:", self.state)
	if self.state == "dead" then
		return
	end
	self.state = "dead"
	self.done(self)
	if self.parent and self.parent.done then
		self.parent.done:remove_listener(self.suicide_cb)
	end
	self.f = nil
	self.done = nil
	self.parent = nil
	self.coroutine = nil
	if scheduler.current == self then
		-- Prevent returning to the task function on suicide
		coroutine.yield()
	end
end

-- Dissociates this task from its parent such that killing the parent
-- task does not kill this task.
-- If this is called from within the task itself, the parent blocked
-- on __call WILL NOT BE UNBLOCKED.
-- This should not be called while the task is running unless it was stated
-- with no_wait = true.
function task_t:disown()
    if self.parent == nil then
        return
    end
    self.parent.done:remove_listener(self.suicide_cb)
    self.parent = nil
    self.suicide_cb = nil
end

-- Returns the values returned by the task's function.
-- If the task has not yet finished its execution, nothing is returned.
function task_t:result()
	if self.ret_val then
		return m.unpack(self.ret_val)
	end
end

-- Internal function.
-- Resumes the task's coroutine and updates scheduler.current
function task_t:_resume(...)
	local caller_task = scheduler.current
	scheduler.current = self
	trace("Resume task", self.name, "State", self.state, "Caller", caller_task and caller_task.name or "")
	local success, error_message = coroutine.resume(self.coroutine, ...)
	trace("Resume done", self.name, "State", self.state, "Back to", caller_task and caller_task.name or "")
	if not success then
		trace("Resume error (task", self.name .. "):", error_message)
		local msg = {
			"Error in the task '" .. self.name .. "'",
			error_message,
			debug.traceback(self.coroutine),
			task_parent_trace(self)
		}
		error(table.concat(msg, "\n"))
	end
	scheduler.current = caller_task
	return success, error_message
end

-- Parallel  API

-- Internal function.
-- Blocks the caller task until the <evt> event is emitted.
-- Param obj: event_t instance - the event to wait for.
-- Returns the parameters sent to emit() (minus the event id).
local function _await_obj(evt)
	local curr = scheduler.current
	local event_cb, done_cb
	function event_cb(_, ...)
		trace("(Await) Resume task", curr.name, "State", curr.state)
		if curr.state ~= "dead" then
			curr.done:remove_listener(done_cb)
			assert(curr:_resume(...))
		end
	end
	function done_cb()
		evt:remove_listener(event_cb)
	end
	curr.done:await(done_cb)
	evt:await(event_cb)

	trace("(Await) Yield task", curr.name, "State", curr.state)
	return coroutine.yield()
end

-- Blocks the caller task until the <evt_id> event is emitted.
-- Param evt_id: Event identifier. Can be any valid table key.
-- Returns the parameters sent to emit() (minus the event id).
function m.await(evt_id)
	trace("Await:", tostring(evt_id), "Task:", scheduler.current.name)
	local waiting = scheduler.waiting
	if not scheduler.current then
		return
	end

	if not waiting[evt_id] then
		waiting[evt_id] = event_t:new()
	end
	return _await_obj(waiting[evt_id])
end

-- Emits the <evt_id> event, sending the remaining parameters as data.
-- Unblocks await calls waiting for this event and executes the listeners.
function m.emit(evt_id, ...)
	trace("Emit:", tostring(evt_id))
	local e = scheduler.waiting[evt_id]
	if e then
		e(...)
		if e:listener_count() == 0 then
			scheduler.waiting[evt_id] = nil
		end
	end
end

-- Returns a task that starts multiple sub-tasks in parallel.
-- If any of these tasks finishes or is killed, all the other tasks will be killed.
-- The returned task's __call will return the same values returned by the task function
-- of the first sub-task to finish.
-- Params: Each parameter must be a task or a function.
-- Functions will be wrapped in new tasks to allow parallel execution.
function m.par_or(...)
	local tasks = {...}
	local i = 1
	for i, v in ipairs(tasks) do
		if type(v) == "function" then
			tasks[i] = task_t:new(v, "par_or_" .. i)
			i = i + 1
		end
	end
	local uuid = tasks -- Reuse the tasks table as an unique event ID for this call
	local in_done_reaction = false
	local done_cb = function(_, task)
		if not in_done_reaction then
			-- Prevent other subtasks from also emitting the event as we would still be
			-- inside the event's reaction and therefore reenter event_t:__call
			in_done_reaction = true
			m.emit(uuid, task:result())
		end
	end
	local task = task_t:new(function()
			for _, t in ipairs(tasks) do
				t(true)
				if t.state == "dead" then
					-- t did not block (done already)
					return t:result()
				end
			end
			return m.await(uuid)
		end, "par_or")
	for _, t in ipairs(tasks) do
		t.done:listen(done_cb)
	end
	return task
end

-- Returns a task that starts multiple sub-tasks in parallel.
-- The returned task finishes when all sub-tasks finish (or are killed).
-- Params: Each parameter must be a task or a function.
-- Functions will be wrapped in new tasks to allow concurrent execution.
function m.par_and(...)
	local tasks = {...}
	local i = 1
	for i, v in ipairs(tasks) do
		if type(v) == "function" then
			tasks[i] = task_t:new(v, "par_and_" .. i)
			i = i + 1
		end
	end
	local uuid = tasks -- Reuse the tasks table as an unique event ID for this call
	local pending = #tasks
	local done_cb = function()
			pending = pending - 1
			if pending == 0 then
				m.emit(uuid)
			end
		end

	for _, t in ipairs(tasks) do
		t.done:listen(done_cb)
	end
	return task_t:new(function()
			for _, t in ipairs(tasks) do
				t(true)
			end
			if pending > 0 then
				m.await(uuid)
			end
		end, "par_and")
end

-- Registers a callback to be called when the an event occurs.
-- If <callback> is already a listener of the event, updates the <once> mode.
-- Param evt_id: Event identifier.
-- Param callback: The callback function.
-- Param once: If true, the callback will be called only on the next time the event occurs (instead of everytime).
function m.listen(evt_id, callback, once)
	local event = scheduler.waiting[evt_id] or event_t:new()
	scheduler.waiting[evt_id] = event
	if once then
		event:await(callback)
	else
		event:listen(callback)
	end
end

-- Removes a callback from the event listeners.
-- If <callback> is not in the event's listeners, does nothing.
-- Param evt_id: Event identifier.
-- Param callback: The callback function.
function m.stop_listening(evt_id, callback)
	if not scheduler.waiting[evt_id] then
		return
	end
	scheduler.waiting[evt_id]:remove_listener(callback)
end

-- Future API

-- Instantiates a new future_t object.
-- This class allows waiting for events asynchronously or block until it's emitted.
-- Param evt_id: Event identifier.
-- Param cancel_cb: If set, this function will be called if the future is cancelled
function future_t:new(evt_id, cancel_cb)
	local out = setmetatable({state = "pending", data = {}, evt_id = evt_id, cancel_cb = cancel_cb},
	                         {__index = self})
	scheduler.waiting[evt_id] = scheduler.waiting[evt_id] or event_t:new()
	scheduler.waiting[out] = event_t:new()

	out.listener = function(_, ...)
		out.data = m.pack(...)
		out.state = "done"
		m.emit(out, ...)
	end
	scheduler.waiting[evt_id]:await(out.listener)
	return out
end

-- Gets the value from the event. Blocks the caller task if not emitted yet.
-- If the future is done, this function is guaranteed to not block.
-- See also: future_t:is_done().
-- Return: Event data if the future is done or nothing if cancelled.
function future_t:get()
	if self.state == "done" then
		return m.unpack(self.data)
	elseif self.state == "cancelled" then
		return
	else
		return m.await(self)
	end
end

-- Tests if the future is done (i.e. the event was emitted).
function future_t:is_done()
	return self.state == "done"
end

-- Cancels the future and stop waiting for the corresponding event.
function future_t:cancel()
	if self.state ~= "pending" then
		return
	end
	scheduler.waiting[self.evt_id]:remove_listener(self.listener)
	self.state = "cancelled"
	if self.cancel_cb then
		self.cancel_cb()
	end
	m.emit(self)
	scheduler.waiting[self] = nil
end

-- Checks if the future is cancelled.
function future_t:is_cancelled()
	return self.state == "cancelled"
end

-- Timer API

-- Instantiates a new timet_t object.
-- Param interval: Amount of time to wait before executing the callback.
-- Param callback: The callback function.
-- Param cyclic: If true, the timer will execute the callback each <interval> period.
-- Otherwise, the callback will execute once and the timer will be stopped.
function timer_t:new(interval, callback, cyclic)
	return setmetatable({interval = interval, callback = callback, cyclic = cyclic, active = false},
		{__index = self})
end

-- Schedules the timer for execution. If the timer is already running, does nothing.
function timer_t:start()
	if self.active then
		return
	end
	self.active = true
	scheduler.waiting_time:enqueue(self, scheduler.timestamp + self.interval)
end

-- Internal function.
-- Reschedules / stops the timer and executes the callback.
function timer_t:_execute()
	self.active = false
	if self.cyclic then
		self:start()
	end
	self.callback()
end

-- Stops the current timer. The timer callback won't be called.
-- If the timer is already stopped, does nothing.
function timer_t:stop()
	if not self.active then
		return
	end
	self.active = false
	scheduler.waiting_time:remove(self)
end

-- Increments the current timestamp.
-- Param dt: Elapsed time since last call to this function (or the program starting) in milliseconds.
function m.update_time(dt)
	scheduler.timestamp = scheduler.timestamp + dt
	local waiting_time = scheduler.waiting_time
	while true do
		local timer, timestamp = waiting_time:peek()
		if timer and scheduler.timestamp >= timestamp then
			waiting_time:dequeue()
			timer:_execute()
		else
			break
		end
	end
end

-- Get current time in milliseconds.
function m.now_ms()
	return scheduler.timestamp
end

-- Executes a callback in <ms> milliseconds from now.
-- Param ms: Period in milliseconds to wait before executing the callback.
-- Param cb: Callback function.
-- Return: timer_t instance - the timer controlling this operation.
function m.in_ms(ms, cb)
	local timer = timer_t:new(ms, cb, false)
	timer:start()
	return timer
end

-- Executes a callback every <ms> milliseconds. Starts counting now.
-- Param ms: Period of execution in milliseconds.
-- Param cb: Callback function.
-- Return: timer_t instance - the timer controlling this operation.
function m.every_ms(ms, cb)
	local timer = timer_t:new(ms, cb, true)
	timer:start()
	return timer
end

-- Blocks the caller task for <ms> milliseconds.
-- Param ms: Amount of time to block the task for.
function m.await_ms(ms)
	local evt = event_t:new()
	m.in_ms(ms, evt)
	_await_obj(evt)
end

-- Module export
if _VERSION == "Lua 5.1" then
	_G[...] = m
	module(..., package.seeall)
else
	return m
end
