local module = {}
local event_t = {}
local future_t = {}
local task_t = {}
local scheduler = {current = nil, waiting = {}}
local heap = require"BinaryMinHeap"

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
-- Blocks the caller thread until the evt event is emitted
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

-- Blocks the caller thread until the evt event is emitted
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
	local uuid = tasks -- Reuse the taskts table as an unique event ID for this call
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
	local uuid = tasks -- Reuse the taskts table as an unique event ID for this call
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
	scheduler.waiting[event]  = scheduler.waiting[event] or event_t:new()
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
-- Returns current time in milliseconds
local function now_ms()
	--TODO
end

local function in_ms(ms, cb)
	scheduler.waiting_time:enqueue(cb, now_ms() + ms)
end

--function await_ms

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

return module
