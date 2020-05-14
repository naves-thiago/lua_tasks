--------------------------------------------------------------------
-- Example:
-- Simulates a task requesting some data from an asynchronous API
--------------------------------------------------------------------

local tasks = require("tasks")
local main -- Task handle to avoid garbage collection
local deep_thought_supercomputer
local text = ""

-- Slow asynchronous call mockup
-- returns a future to get the answer
local function answer_question_of_live_universe_everything()
	deep_thought_supercomputer = tasks.task_t:new(function()
		tasks.await_ms(6500) -- Pretend we are processing...
		tasks.emit(deep_thought_supercomputer, 42) -- Use the task itself as an event id
	end)

	-- Start as an independent task and don't block the call
	deep_thought_supercomputer(true, true)

	return tasks.future_t:new(deep_thought_supercomputer)
end

function love.load()
	love.graphics.setFont(love.graphics.newFont(18))

	main = tasks.task_t:new(function()
		text = "Requesting the answer to the ultimate question of life, universe and everything..."
		local future = answer_question_of_live_universe_everything()
		tasks.await_ms(700)
		text = text .. "\nWaiting"
		tasks.await_ms(700)
		for i = 1, 5 do
			text = text .. "."
			tasks.await_ms(600)
		end
		text = text .. "\nDone yet? "
		tasks.await_ms(600)
		if future:is_done() then
			text = text .. " Yes!\nAnswer: " .. future:get()
		else
			text = text .. " No, sleeping until done."
			text = text .. "\nDone!\nAnswer: " .. future:get() -- Get blocks until the async task is done
		end
	end)

	main()
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(text, 40, 100)
end
