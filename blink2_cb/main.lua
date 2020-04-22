--------------------------------------------------------------------
-- Example:
-- Blink LED 1 once every second
-- If button 1 is clicked, blink faster
-- If button 2 is clicked, blink slower
-- If both buttons are pressed in less than 500ms, stop blinking
-- Callback API example
--------------------------------------------------------------------

local tasks = require("tasks")
setmetatable(_G, {__index = tasks})

local timer, blinker
local state = "blink"
local interval = 500
local sm -- generated state machine

local function start_timer()
	print("START_TIMER")
	timer = in_ms(500, function() update_state("timeout") end)
end

local function stop_timer()
	print("STOP_TIMER")
	timer:stop()
end

local function faster()
	interval = interval - 50
	print("FASTER")
end

local function slower()
	interval = interval + 50
	print("SLOWER")
end

local function stop()
	blinker:stop()
	print("STOP")
end

sm_def = { -- state machine definition
	--State     Event       New state   Function
	{"blink",   "1_down",   "wait_2",   start_timer},
	{"blink",   "2_down",   "wait_1",   start_timer},
	{"blink",   "1_up",     "blink",    function() stop_timer() faster() end},
	{"blink",   "2_up",     "blink",    function() stop_timer() slower() end},
	{"wait_1",  "timeout",  "blink"},
	{"wait_2",  "timeout",  "blink"},
	{"wait_1",  "1_up",     "blink",    function() stop_timer() faster() end},
	{"wait_1",  "2_up",     "blink",    function() stop_timer() slower() end},
	{"wait_2",  "1_up",     "blink",    function() stop_timer() faster() end},
	{"wait_2",  "2_up",     "blink",    function() stop_timer() slower() end},
	{"wait_1",  "1_down",   "stop",     stop},
	{"wait_2",  "2_down",   "stop",     stop},
}

function gen_state_machine()
	sm = {}
	for _, t in ipairs(sm_def) do
		local from_state, event, to_state, f = unpack(t)
		local sm_state = sm[from_state] or {}
		sm[from_state] = sm_state
		sm_state[event] = {to_state, f}
	end

--	for from_state, t in pairs(sm) do
--		for event, to_state in pairs(t) do
--			print(from_state, event, to_state[1])
--		end
--	end
end

--gen_state_machine()

function update_state(event)
	if not sm[state] then return end -- Final state
	local t = sm[state][event]
	if not t then return end -- No transition from current state with this event
	local to_state, f = unpack(t)
	state = to_state
	if f then f() end
end

--print("State: " .. state)
--print("Event: 1_down")
--update_state("1_down")
--print("State: " .. state)
--print("Event: 1_up")
--update_state("1_up")
--print("State: " .. state)
--print("Event: 2_down")
--update_state("2_down")
--print("State: " .. state)
--print("Event: 1_down")
--update_state("1_down")
--print("State: " .. state)
--print("Event: 1_down")
--update_state("1_down")
--print("State: " .. state)

function love.load()
	gen_state_machine()
	local function f()
		led1 = not led1
		if interval < 50 then
			interval = 50
		end
		blinker = in_ms(interval, f)
	end
	blinker = in_ms(interval, f)
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.keypressed(key, scancode, isrepeat)
	if isrepeat then return end
	update_state(key .. "_down")
end

function love.keyreleased(key, scancode, isrepeat)
	if isrepeat then return end
	update_state(key .. "_up")
end

function love.draw()
	love.graphics.setColor(1, 1, 1) -- White
	--                                              x    y    r   segments
	love.graphics.circle(led1 and "fill" or "line", 100, 100, 20, 100)
end
