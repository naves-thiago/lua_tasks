local heap = require"BinaryMinHeap"
local module = {}
local event_t = {}
local task_t = {}
local future_t = {}
local timer_t = {}
local scheduler = {current = nil, waiting = {}, timestamp = 0, waiting_time = heap:new()}
local table_unpack

-- Lua 5.1 compatibility
if _VERSION == "Lua 5.1" then
	table_unpack = unpack
else
	table_unpack = table.unpack
end

----- DEBUG -----
function trace(...)
	--print(table.concat({"[TRACE]", ...}, ' '))
end
-----------------

-- Param forwarding
local function va_pack(...)
	return {[0]=select("#", ...), ...}
end

local function va_unpack(t)
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
	-- Doing:
	-- `local nl = self.new_listeners`
	-- `self.new_listeners {}`
	-- calling the new_listeners on the inner calls
	-- `[...] self.new_listeners = nl`
	-- replacing `if self.in_call` with `if self.new_listeners` everywhere
	-- may allow it to be reentrant
	--
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
	local t = {f = f, done = event_t:new(), state = "ready", parent = nil, coroutine = nil, name = name or "??"}
	trace("New task:", name)
	return setmetatable(t, {__index = self, __call = self.__call})
end

-- If no_wait is true, the caller will not yield to wait for this task to complete
function task_t:__call(no_await, independent)
	trace("Start task:", self.name, "State:", self.state, "Caller:", (scheduler.current and scheduler.current.name))
	if self.state ~= "ready" then
		return
	end
	self.state = "alive"
	self.parent = scheduler.current
	self.coroutine = coroutine.create(function() self.ret_val = va_pack(self.f()) self:kill() end)
	scheduler.current = self
	if self.parent and not independent then
		self.suicide_cb = function() self:kill() end
		self.parent.done:listen(self.suicide_cb)
	end
	local success, output = coroutine.resume(self.coroutine)
	if success and self.parent and not no_await then
		-- Started from another task
		self.done:listen(function(_, ...) emit(self, ...) end)
		await(self)
		trace("Unblock parent:", self.name, "Parent:", self.parent.name)
	end
	if success and self.ret_val then
		return va_unpack(self.ret_val)
	end
	if not success then
		print("Error in the task '" .. self.name .. "'")
		print(debug.traceback(self.coroutine, output))
		print(task_parent_trace(self))
	end
end

function task_t:kill()
	trace("Kill task:", self.name, "State:", self.state)
	if self.state == "dead" then
		return
	end
	self.state = "dead"
	self.done(self)
	if scheduler.current == self then
		scheduler.current = self.parent
	end
	if self.parent and self.parent.done then
		self.parent.done:remove_listener(self.suicide_cb)
	end
	self.f = nil
	self.done = nil
	self.parent = nil
	self.coroutine = nil
end

function task_t:disown()
    if self.parent == nil then
        return
    end
    self.parent.done:remove_listener(self.suicide_cb)
    self.parent = nil
    self.suicide_cb = nil
end

function task_t:result()
	if self.ret_val then
		return va_unpack(self.ret_val)
	end
end

-- Scheduler API

-- Internal function.
-- Blocks the caller task until the <evt> event is emitted.
-- Param obj: event_t instance - the event to wait for.
-- Returns the parameters sent to emit() (minus the event id).
local function _await_obj(evt)
	local curr = scheduler.current
	local event_cb, done_cb
	function event_cb(_, ...)
		trace("Resume task:", curr.name, "State:", curr.state)
		if curr.state ~= "dead" then
			scheduler.current = curr
			curr.done:remove_listener(done_cb)
			coroutine.resume(curr.coroutine, ...)
		end
	end
	function done_cb()
		evt:remove_listener(event_cb)
	end
	curr.done:await(done_cb)
	evt:await(event_cb)

	trace("Yield task: ", curr.name, "State: ", curr.state)
	scheduler.current = curr.parent
	return coroutine.yield()
end

-- Blocks the caller task until the <evt> event is emitted.
-- Param evt_id: Event identifier. Can be any valid table key.
-- Returns the parameters sent to emit() (minus the event id).
local function await(evt_id)
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

local function emit(evt_id, ...)
	trace("Emit:", tostring(evt_id))
	local e = scheduler.waiting[evt_id]
	if e then
		e(...)
		if e:listener_count() == 0 then
			scheduler.waiting[evt_id] = nil
		end
	end
end

local function par_or(...)
	local tasks = {...}
	local i = 1
	for i, v in ipairs(tasks) do
		if type(v) == "function" then
			tasks[i] = task_t:new(v, "par_or_" .. i)
			i = i + 1
		end
	end
	local uuid = tasks -- Reuse the tasks table as an unique event ID for this call
	local done_cb = function(_, task)
		emit(uuid, task:result())
	end
	local task = task_t:new(function()
			for _, t in ipairs(tasks) do
				t(true)
			end
			return await(uuid)
		end, "par_or")
	for _, t in ipairs(tasks) do
		t.done:listen(done_cb)
	end
	return task
end

local function par_and(...)
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
				emit(uuid)
			end
		end

	for _, t in ipairs(tasks) do
		t.done:listen(done_cb)
	end
	return task_t:new(function()
			for _, t in ipairs(tasks) do
				t(true)
			end
			await(uuid)
		end, "par_and")
end

-- Registers a callback to be called when the an event occurs.
-- If <callback> is already a listener of the event, updates the <once> mode.
-- Param evt_id: Event identifier.
-- Param callback: The callback function.
-- Param once: If true, the callback will be called only on the next time the event occurs (instead of everytime).
local function listen(evt_id, callback, once)
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
local function stop_listening(evt_id, callback)
	if not scheduler.waiting[evt_id] then
		return
	end
	scheduler.waiting[evt_id]:remove_listener(callback)
end

-- Future API

-- Instantiates a new future_t object.
-- This class allows waiting for events asynchronously or block until it's emitted.
-- Param evt_id: Event identifier.
function future_t:new(evt_id)
	local out = setmetatable({state = "pending", data = {}, evt_id = evt_id},
	                         {__index = self})
	scheduler.waiting[evt_id] = scheduler.waiting[evt_id] or event_t:new()
	scheduler.waiting[out] = event_t:new()

	out.listener = function(_, ...)
		out.data = va_pack(...)
		out.state = "done"
		emit(out, ...)
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
		return va_unpack(self.data)
	elseif self.state == "cancelled" then
		return
	else
		return await(self)
	end
end

-- Test if the future is done (i.e. the event was emitted).
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
	emit(self)
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
local function update_time(dt)
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
local function now_ms()
	return scheduler.timestamp
end

-- Executes a callback in <ms> milliseconds from now.
-- Param ms: Period in milliseconds to wait before executing the callback.
-- Param cb: Callback function.
-- Return: timer_t instance - the timer controlling this operation.
local function in_ms(ms, cb)
	local timer = timer_t:new(ms, cb, false)
	timer:start()
	return timer
end

-- Executes a callback every <ms> milliseconds. Starts counting now.
-- Param ms: Period of execution in milliseconds.
-- Param cb: Callback function.
-- Return: timer_t instance - the timer controlling this operation.
local function every_ms(ms, cb)
	local timer = timer_t:new(ms, cb, true)
	timer:start()
	return timer
end

-- Blocks the caller task for <ms> milliseconds.
-- Param ms: Amount of time to block the task for.
local function await_ms(ms)
	local evt = event_t:new()
	in_ms(ms, evt)
	_await_obj(evt)
end

-- Module API
module.event_t = event_t
module.task_t = task_t
module.future_t = future_t
module.await = await
module.emit = emit
module.par_or = par_or
module.par_and = par_and
module.listen = listen
module.stop_listening = stop_listening
module.pack = va_pack
module.unpack = va_unpack
module.now_ms = now_ms
module.in_ms = in_ms
module.timer_t = timer_t
module.update_time = update_time
module.now_ms = now_ms
module.in_ms = in_ms
module.every_ms = every_ms
module.await_ms = await_ms
module._scheduler = scheduler

return module
