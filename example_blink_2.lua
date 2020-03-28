--------------------------------------------------------------------
-- Example:
-- Blink LED 1 once every second
-- If button 1 is clicked, blink faster
-- If button 2 is clicked, blink slower
-- If both buttons are pressed in less than 500ms, stop blinking
--------------------------------------------------------------------
local tasks = require"tasks"
local task_t = tasks.task_t
local par_or = tasks.par_or
local await = tasks.await
local emit = tasks.emit
local listen = tasks.listen
local stop_listening = tasks.stop_listening
local in_ms = tasks.in_ms -- not implemented
local every_ms = tasks.every_ms -- not implemented
local await_ms = tasks.await_ms -- not implemented
local button1_up -- not implemented
local button2_up -- not implemented
local button1_down -- not implemented
local button2_down -- not implemented
local led1 -- not implemented

-- Button events are placeholders for events that would be triggered by hardware buttons
-- The led1 object is a placeholder for a LED interface

----- Await API --------------
local interval = 500
par_and(
	par_or(
		function()
			par_and(
				function() await(button1_down) end,
				function() await(button2_down) end
			)()
			emit("stop")
		end,
		function() await_ms(500) end,
		function() await(button1_up) end,
		function() await(button2_up) end
	),
	function()
		while true do
			await(button1_up)
			interval = interval - 20
		end
	end,
	function()
		while true do
			await(button2_up)
			interval = interval + 20
		end
	end,
	par_or(
		function()
			while true do
				await_ms(interval)
				led1:toggle()
			end
		end,
		function() await("stop") end
	)
)()
------------------------------

---- Callback API ------------
local interval = 500
local btn1_pressed = false
local btn2_pressed = false
local timed_out = false
local blinker = every_ms(interval, function() led1:toggle() end)

function change_interval(delta)
	bliker:stop()
	interval = interval + delta
	blinker = every_ms(interval, function() led1:toggle() end)
end

function btn1_down()
	btn1_pressed = true
	if btn2_pressed then
		blinker:stop()
	else
		timer = in_ms(500, function() timed_out = true end)
	end
end

function btn1_up()
	if not timed_out then
		timer:stop()
	end
	change_interval(-20)
	timed_out = false
	btn1_pressed = false
end

function btn2_down()
	btn2_pressed = true
	if btn1_pressed then
		blinker:stop()
	else
		timer = in_ms(500, function() timed_out = true end)
	end
end

function btn2_up()
	if not timed_out then
		timer:stop()
	end
	change_interval(+20)
	timed_out = false
	btn2_pressed = false
end
listen(button1_down, btn1_down)
listen(button2_down, btn2_down)
listen(button1_up, btn1_up)
listen(button2_up, btn2_up)
------------------------------

----- Await API --------------
--[[
-- Old implementation that doesn't react to buttons being
-- released after 500ms
local interval = 500
function blink()
	while true do
		await_ms(interval)
		led1:toggle()
	end
end

function buttons()
	while true do
		par_or(
			function()
				await(button1_down)
				par_or(
					function() await(button2_down) emit("stop") end,
					function() await_ms(500) end,
					function() await(button1_up) interval = interval - 20 end
				)()
			end,
			function()
				await(button2_down)
				par_or(
					function() await(button1_down) emit("stop") end,
					function() await_ms(500) end,
					function() await(button2_up) interval = interval + 20 end
				)()
			end
		)()
	end
end
par_or(function() await("stop") end, blink)()
par_or(function() await("stop") end, buttons)()
--]]
------------------------------
