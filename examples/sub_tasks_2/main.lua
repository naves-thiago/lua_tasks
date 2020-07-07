--------------------------------------------------------------------
-- Example:
-- A main task waits for the space bar to be pressed.
-- Creates 10 sub-tasks, each blinking an LED in a different speed.
-- After another space bar press, the main task finishes, killing
-- all the sub-tasks.
-- Author: Thiago Duarte Naves
--------------------------------------------------------------------

local tasks = require("tasks")
local main -- Task handle to avoid garbage collection
local leds = {} -- State of each LED
function love.load()
	love.graphics.setFont(love.graphics.newFont(18))

	main = tasks.task_t:new(function()
		tasks.await("space") -- Wait for space bar to be pressed
		local subtasks = {}  -- Sub-tasks handles

		for i = 1, 10 do
			local t = tasks.task_t:new(function()
				-- Sub-task to blink the LED
				local id = i
				while true do
					tasks.await_ms(100 + 20 * id)
					leds[id] = not leds[id]
				end
			end)
			table.insert(subtasks, t)
			t(true) -- Start task but don't block waiting for it to finish
		end

		tasks.await("space") -- Wait for space bar to be pressed
		-- Main tasks finishes, killing all sub-tasks
	end)

	-- This call won't block because it's being executed from outside a task
	main()
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.keypressed(key, scancode, isrepeat)
	if isrepeat then return end
	tasks.emit(key)
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print("Press SPACE to start. Press again to stop.", 130, 100)

	for i = 1, 10 do
		love.graphics.setColor(1 - 0.1 * i, 0, 0.1 * i)
		--                                                 x             y    r   segments
		love.graphics.circle(leds[i] and "fill" or "line", 100 + i * 50, 200, 20, 100)
	end

end
