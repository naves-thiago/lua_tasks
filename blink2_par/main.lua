--------------------------------------------------------------------
-- Example:
-- Blink LED 1 once every second
-- If button 1 is clicked, blink faster
-- If button 2 is clicked, blink slower
-- If both buttons are pressed in less than 500ms, stop blinking
-- Parallel API example
--------------------------------------------------------------------

local tasks = require("tasks")
setmetatable(_G, {__index = tasks})

local main_task
local interval = 500

function love.load()
	main_task = par_and(
		function()
			while true do
				par_or(
					function()
						par_and(
							function() await("1_down") end,
							function() await("2_down") end
						)()
						emit("stop")
					end,
					function()
						par_and(
							function() await("2_down") end,
							function() await("1_down") end
						)()
						emit("stop")
					end,
					function() await_ms(500) end,
					function() await("1_up") end,
					function() await("2_up") end
				)()
			end
		end,
		function()
			while true do
				await("1_up")
				interval = interval - 50
			end
		end,
		function()
			while true do
				await("2_up")
				interval = interval + 50
			end
		end,
		par_or(
			function()
				while true do
					if interval < 50 then
						interval = 50
					end
					await_ms(interval)
					led1 = not led1
				end
			end,
			function() await("stop") end
		)
	)
	main_task()
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.keypressed(key, scancode, isrepeat)
	if isrepeat then return end
	tasks.emit(key .. "_down")
end

function love.keyreleased(key, scancode, isrepeat)
	if isrepeat then return end
	tasks.emit(key .. "_up")
end

function love.draw()
	love.graphics.setColor(1, 1, 1) -- White
	--                                              x    y    r   segments
	love.graphics.circle(led1 and "fill" or "line", 100, 100, 20, 100)
end
