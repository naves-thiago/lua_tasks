local module = {}
local event_t = {}
local task_t = {}
local scheduler = {current = nil, waiting = {}}

-- Observer
function event_t:new()
	return setmetatable({listeners = {}, waiting = {}}, {__index = self, __call = self.__call})
end

function event_t:listen(f)
	self.listeners[f] = true
end

function event_t:await(f)
	self.waiting[f] = true
end

function event_t:remove_listener(f)
	self.listeners[f] = nil
end

function event_t:remove_await(f)
	self.waiting[f] = nil
end

function event_t:__call(...)
	for l in pairs(self.listeners) do
		l(self, ...)
	end
	for l in pairs(self.waiting) do
		l(self, ...)
	end
	self.waiting = {}
end

-- Task
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
	self.coroutine = coroutine.create(function() self.f() self:kill() end)
	scheduler.current = self
	if self.parent and not independent then
		self.suicide_cb = function() self:kill() end
		self.parent.done:listen(self.suicide_cb)
	end
	coroutine.resume(self.coroutine)
	if self.parent and not no_await then
		-- Started from another task
		self.done:listen(function() emit(self) end)
		await(self)
	end
end

function task_t:kill()
	if self.state == "dead" then
		return
	end
	self.state = "dead"
	self.done()
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

-- Scheduler API
local function await(evt)
	local waiting = scheduler.waiting
	if not scheduler.current then
		return
	end

	if not waiting[evt] then
		waiting[evt] = event_t:new()
	end
	local curr = scheduler.current
	waiting[evt]:await(function(_, ...)
			if curr.state ~= "dead" then
				scheduler.current = curr
				coroutine.resume(curr.coroutine, ...)
			end
		end)

	scheduler.current = curr.parent
	return coroutine.yield()
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
	local done_cb = function() emit(uuid) end
	local task = task_t:new(function()
			for _, t in ipairs(tasks) do
				t(true)
			end
			await(uuid)
		end)
	for _, t in ipairs(tasks) do
		t.done:listen(done_cb)
	end
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

module.event_t = event_t
module.task_t = task_t
module.await = await
module.emit = emit
module.par_or = par_or
module.par_and = par_and

return module
