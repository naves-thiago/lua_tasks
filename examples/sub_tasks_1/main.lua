--------------------------------------------------------------------
-- Example:
-- Starts a main task that writes "Press either 1 or 2".
-- Creates a sub-task to wait for either button using `par_or`.
-- Writes "Press 3 and 4 in any order".
-- Creates a sub-task to wait for both buttons using `par_and`.
-- Writes "Done".
-- Author: Thiago Duarte Naves
--------------------------------------------------------------------

local tasks = require("tasks")
local main -- Task handle to avoid garbage collection
local show_txt_1_2  = false
local show_txt_3_4  = false
local show_txt_done = false
local line_height

function love.load()
	local font = love.graphics.newFont(18)
	love.graphics.setFont(font)
	line_height = font:getHeight()

	main = tasks.task_t:new(function()
		show_txt_1_2 = true

		local subtask_1 = tasks.par_or(function() tasks.await("1") end, function() tasks.await("2") end)
		subtask_1() -- Blocks the main task until either 1 or 2 is pressed
		show_txt_3_4 = true

		local subtask_2 = tasks.par_and(function() tasks.await("3") end, function() tasks.await("4") end)
		subtask_2() -- Blocks the main task until both 3 and 4 are pressed
		show_txt_done = true
	end)
	main()
end

function love.keypressed(key, scancode, isrepeat)
	if isrepeat then return end
	tasks.emit(key)
end

local function green()
	love.graphics.setColor(0.2, 1, 0.2)
end

local function white()
	love.graphics.setColor(1, 1, 1)
end

function love.draw()
	if show_txt_1_2 then
		if show_txt_3_4 then
			green()
		else
			white()
		end
		love.graphics.print("Press either 1 or 2", 130, 50)
	end

	if show_txt_3_4 then
		if show_txt_done then
			green()
		else
			white()
		end
		love.graphics.print("Press both 3 and 4 in any order", 130, 50 + line_height)
	end

	if show_txt_done then
		green()
		love.graphics.print("Done", 130, 50 + 2 * line_height)
	end
end
