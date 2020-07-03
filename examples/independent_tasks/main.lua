--------------------------------------------------------------------
-- Example:
-- Two tasks, each blinking an LED in a different speed
--------------------------------------------------------------------

local tasks = require("tasks")
local task_1, task_2 -- Task handles to avoid them being collected
local led1 = true
local led2 = true

function love.load()
	task_1 = tasks.task_t:new(function()
		while true do
			tasks.await_ms(500)
			led1 = not led1
		end
	end)

	task_2 = tasks.task_t:new(function()
		while true do
			tasks.await_ms(200)
			led2 = not led2
		end
	end)

	-- Start both tasks.
	-- These calls won't block because they are being called from outside a task.
	task_1()
	task_2()
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.draw()
	love.graphics.setColor(1, 1, 1) -- White
	--                                              x    y    r   segments
	love.graphics.circle(led1 and "fill" or "line", 100, 100, 20, 100)

	love.graphics.setColor(1, 0, 0) -- Red
	love.graphics.circle(led2 and "fill" or "line", 150, 100, 20, 100)
end
