--local dbg = require "debugger"
-- Observer
event_t = {}

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
task_t = {}

function task_t:new(f, name)
	local t = {f = f, done = event_t:new(), state = "ready", parent = nil, coroutine = nil, name = name or "??"}
	return setmetatable(t, {__index = self, __call = self.__call})
end

-- If no_wait is true, the caller will not yield to wait for this task to complete
function task_t:__call(no_await)
	if self.state ~= "ready" then
		return
	end
	self.state = "alive"
	self.parent = scheduler.current
	self.coroutine = coroutine.create(function() self.f() self:kill() end)
	scheduler.current = self
	if self.parent then
		--self.parent.done:listen(function() print(self.name .. ": killed by parent ("..self.parent.name..")") self:kill() end)
		self.parent.done:listen(function() self:kill() end)
	end
	coroutine.resume(self.coroutine)
	if self.parent and not no_await then
		-- Started from another task
		self.done:listen(function() emit(self) end)
		await(self)
	end
end

function task_t:kill()
	--print('Kill ' .. self.name .. ' (' .. self.state .. ')')
	if self.state == "dead" then
		return
	end
	self.state = "dead"
	scheduler.current = self.parent
	self.done()
	self.f = nil
	--print(self.name .. ' killed')
	self.done = nil
	self.parent = nil
	self.coroutine = nil
end

-- Scheduler API
scheduler = {current = nil, waiting = {}}
function await(evt)
	local waiting = scheduler.waiting
	if not scheduler.current then
		print("no task")
		return
	end

	if not waiting[evt] then
		waiting[evt] = event_t:new()
	end
	local curr = scheduler.current
	waiting[evt]:await(function(_, ...) scheduler.current = curr coroutine.resume(curr.coroutine, ...) end)
	scheduler.current = curr.parent
	return coroutine.yield()
end

function emit(evt, ...)
	local e = scheduler.waiting[evt]
	if e then
		e(...)
	end
end

function par_or(t1, t2)
	local uuid = {} -- Unique event ID for this call
	local either_done = function() emit(uuid) end
	local task = task_t:new(function() t1(true) t2(true) await(uuid) end)
	t1.done:listen(either_done)
	t2.done:listen(either_done)
	return task
end

-- Test code
function fa() print("ta ini") await(1) print("ta fim") end
ta = task_t:new(fa, "A")
function fb() print("tb ini") await(2) print("tb fim") end
tb = task_t:new(fb, "B")
function fc() print("tc ini") await(3) print("tc fim") end
tc = task_t:new(fc, "C")
function fd() print("td ini") par_or(ta, par_or(tb, tc))() print("td fim") await(4) print("td fim 2") end
td = task_t:new(fd, "D")
td()
