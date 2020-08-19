--------------------------------------------------------------------
-- Example:
-- Blinks an LED once every second
-- If the space bar is pressed, toggles blinking
-- Author: Thiago Duarte Naves
--------------------------------------------------------------------
local tasks = require("tasks")
local timer
local led1 = true

function love.load()
	-- main
	timer = tasks.every_ms(500, function()
		led1 = not led1
	end)

	tasks.listen("space", function()
		if timer.active then
			timer:stop()
		else
			timer:start()
		end
	end)
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.keypressed(key, scancode, isrepeat)
	if isrepeat then return end
	tasks.emit(key)
end

function love.draw()
	love.graphics.setColor(1, 1, 1) -- White
	--                                              x    y    r   segments
	love.graphics.circle(led1 and "fill" or "line", 100, 100, 20, 100)
end
