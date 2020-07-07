--------------------------------------------------------------------
-- Example:
-- Blink an LED once every second
-- If button 1 is clicked, blink faster
-- If button 2 is clicked, blink slower
-- If both buttons are pressed in less than 500ms, stop blinking
-- Parallel API example
-- Author: Thiago Duarte Naves
--------------------------------------------------------------------

local tasks = require("tasks")

local await = tasks.await
local emit = tasks.emit
local await_ms = tasks.await_ms
local update_time = tasks.update_time
local par_or = tasks.par_or
local par_and = tasks.par_and

local main_task
local interval = 500

function love.load()
	main_task = par_and( -- Using a par_and to create multiple tasks
		function()
			while true do
				par_or(
					function()
						-- Button 1 pressed first, wait until button 2 is pressed (then stop blinking),
						-- either button is released (button 2 could be pressed already),
						-- or the 500ms timeout
						await("1_down")
						par_or(
							function() await("2_down") emit("stop") end,
							function() await_ms(500) end,
							function() await("1_up") end,
							function() await("2_up") end
						)()
					end,
					function()
						-- Button 2 pressed first, wait until button 1 is pressed (then stop blinking),
						-- either button is released (button 1 could be pressed already),
						-- or the 500ms timeout
						await("2_down")
						par_or(
							function() await("1_down") emit("stop") end,
							function() await_ms(500) end,
							function() await("1_up") end,
							function() await("2_up") end
						)()
					end
				)()
			end
		end,
		function()
			while true do
				-- interval has no effect if stopped
				await("1_up")
				interval = interval - 50
			end
		end,
		function()
			while true do
				-- interval has no effect if stopped
				await("2_up")
				interval = interval + 50
			end
		end,
		par_or( -- Blink until the stop event is emitted
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
	update_time(dt * 1000)
end

function love.keypressed(key, scancode, isrepeat)
	if isrepeat then return end
	emit(key .. "_down")
end

function love.keyreleased(key, scancode, isrepeat)
	if isrepeat then return end
	emit(key .. "_up")
end

function love.draw()
	love.graphics.setColor(1, 1, 1) -- White
	--                                              x    y    r   segments
	love.graphics.circle(led1 and "fill" or "line", 100, 100, 20, 100)
end
