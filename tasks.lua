local heap = require"BinaryMinHeap"
local module = {}
local event_t = {}
local future_t = {}
local task_t = {}
local scheduler = {current = nil, waiting = {}, timestamp = 0, waiting_time = heap:new()}

-- Param forwarding
local function pack(...)
	return {[0]=select("#", ...), ...}
end

local function unpack(t)
	return table.unpack(t, 1, t[0])
end

-- Observer
function event_t:new()
	return setmetatable({listeners = {}, waiting = {}}, {__index = self, __call = self.__call})
end

function event_t:listen(f)
	self.listeners[f] = "repeat"
end

function event_t:await(f)
	self.listeners[f] = "once"
end

function event_t:remove_listener(f)
	self.listeners[f] = nil
end

function event_t:__call(...)
	for l, mode in pairs(self.listeners) do
		l(self, ...)
		if mode == "once" then
			self.listeners[l] = nil
		end
	end
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
	return setmetatable(t, {__index = self, __call = self.__call})
end

-- If no_wait is true, the caller will not yield to wait for this task to complete
function task_t:__call(no_await, independent)
	if self.state ~= "ready" then
		return
	end
	self.state = "alive"
	self.parent = scheduler.current
	self.coroutine = coroutine.create(function() self.ret_val = pack(self.f()) self:kill() end)
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
	end
	if success and self.ret_val then
		return unpack(self.ret_val)
	end
	if not success then
		print("Error in the task '" .. self.name .. "'")
		print(debug.traceback(self.coroutine, output))
		print(task_parent_trace(self))
	end
end

function task_t:kill()
	if self.state == "dead" then
		return
	end
	self.state = "dead"
	self.done(self)
	if scheduler.current == self then
		scheduler.current = self.parent
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
		return unpack(self.ret_val)
	end
end

-- Scheduler API
-- Interal function
-- Blocks the caller task until the <evt> event is emitted
-- Param obj: event_t instance - the event to wait for
-- Returns the parameters sent to emit() (minus the event id)
local function _await_obj(evt)
	local curr = scheduler.current
	evt:await(function(_, ...)
			if curr.state ~= "dead" then
				scheduler.current = curr
				coroutine.resume(curr.coroutine, ...)
			end
		end)

	scheduler.current = curr.parent
	return coroutine.yield()
end

-- Blocks the caller task until the <evt> event is emitted
-- Param obj_id: Event identifier. Can be any valid table key.
-- Returns the parameters sent to emit() (minus the event id)
local function await(evt_id)
	local waiting = scheduler.waiting
	if not scheduler.current then
		return
	end

	if not waiting[evt_id] then
		waiting[evt_id] = event_t:new()
	end
	return _await_obj(waiting[evt_id])
end

local function emit(evt, ...)
	local e = scheduler.waiting[evt]
	if e then
		e(...)
	end
end

local function par_or(...)
	local tasks = {...}
	for i, v in ipairs(tasks) do
		if type(v) == "function" then
			tasks[i] = task_t:new(v)
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
		end)
	for _, t in ipairs(tasks) do
		t.done:listen(done_cb)
	end
	task.name = "par_or"
	return task
end

local function par_and(...)
	local tasks = {...}
	for i, v in ipairs(tasks) do
		if type(v) == "function" then
			tasks[i] = task_t:new(v)
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
		end)
end

local function listen(evt, callback, once)
	local event = scheduler.waiting[evt] or event_t:new()
	scheduler.waiting[evt] = event
	if once then
		event:await(callback)
	else
		event:listen(callback)
	end
end

local function stop_listening(evt, callback)
	if not scheduler.waiting[evt] then
		return
	end
	scheduler.waiting[evt]:remove_listener(callback)
end

-- Future API
function future_t:new(event)
	local out = setmetatable({state = "pending", data = {}, event = event},
	                         {__index = self})
	scheduler.waiting[event] = scheduler.waiting[event] or event_t:new()
	scheduler.waiting[out] = event_t:new()

	out.listener = function(_, ...)
		out.data = pack(...)
		out.state = "done"
		emit(out, ...)
	end
	scheduler.waiting[event]:await(out.listener)
	return out
end

function future_t:get()
	if self.state == "done" then
		return unpack(self.data)
	elseif self.state == "cancelled" then
		return
	else
		return await(self)
	end
end

function future_t:is_done()
	return self.state == "done"
end

function future_t:cancel()
	if self.state ~= "pending" then
		return
	end
	scheduler.waiting[self.event]:remove_listener(self.listener)
	self.state = "cancelled"
	emit(self)
	scheduler.waiting[self] = nil
end

function future_t:is_cancelled()
	return self.state == "cancelled"
end

-- Timer API
local timer_t = {}

-- Instantiates a new timet_t object
-- Param interval: Amount of time to wait before executing the callback
-- Param callback: The callback function
-- Param cyclic: If true, the timer will execute the callback each <interval> period.
-- Otherwise, the callback will execute once and the timer will be stopped
function timer_t:new(interval, callback, cyclic)
	return setmetatable({interval = interval, callback = callback, cyclic = cyclic, active = false},
		{__index = self})
end

-- Schedules the timer for execution. If the timer is already running, does nothing
function timer_t:start()
	if self.active then
		return
	end
	self.active = true
	scheduler.waiting_time:enqueue(self, scheduler.timestamp + self.interval)
end

-- Internal function. Reschedules / stops the timer and executes the callback
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

-- Increments the current timestamp
-- Param dt: Elapsed time since last call to this function (or the program starting) in milliseconds
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

-- Returns current time in milliseconds
local function now_ms()
	return scheduler.timestamp
end

-- Executes a callback in <ms> milliseconds from now
-- Param ms: Period in milliseconds to wait before executing the callback
-- Param cb: Callback function
-- Return: timer_t instance - the timer controlling this operation
local function in_ms(ms, cb)
	local timer = timer_t:new(ms, cb, false)
	timer:start()
	return timer
end

-- Executes a callback every <ms> milliseconds. Starts counting now
-- Param ms: Period of execution in milliseconds
-- Param cb: Callback function
-- Return: timer_t instance - the timer controlling this operation
local function every_ms(ms, cb)
	local timer = timer_t:new(ms, cb, true)
	timer:start()
	return timer
end

-- Blocks the caller task for <ms> milliseconds
-- Param ms: Amount of time to block the task for
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
module.pack = pack
module.unpack = unpack
module.now_ms = now_ms
module.in_ms = in_ms
module.timer_t = timer_t
module.update_time = update_time
module.now_ms = now_ms
module.in_ms = in_ms
module.every_ms = every_ms
module.await_ms = await_ms

return module
