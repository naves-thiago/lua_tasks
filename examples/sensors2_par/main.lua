-------------------------------------------------------------------------------------
-- Example:
-- Simulates a task requesting readings from multiple sensors with asynchronous APIs
-- Each of the 3 sensors take a different amount of time to return a reading.
-- Sensor 1 takes 2 seconds, sensor 2 takes 1 and sensor 3 takes 2.5.
-- Our function needs all 3 values and print them ordered.
-- Author: Thiago Duarte Naves
-------------------------------------------------------------------------------------

local tasks = require("tasks")
local main_task -- Task handle to avoid garbage collection
local text = ""

-- Slow asynchronous call mockup factory
-- returns a future to get the reading
local function sensor_factory(time, result, request_event, response_event)
	local sensor_task
	sensor_task = tasks.task_t:new(function()
		tasks.await(request_event)
		tasks.await_ms(time * 1000) -- Pretend we are waiting for an external process
		tasks.emit(response_event, result)
	end)

	-- Start as an independent task and don't block the call
	sensor_task(true, true)
end

local function init()
	sensor_factory(2,   1.111, "read_sensor1", "sensor1")
	sensor_factory(1,   2.222, "read_sensor2", "sensor2")
	sensor_factory(2.5, 3.333, "read_sensor3", "sensor3")
end
-------------------------

function love.load()
	init()
	main_task = tasks.task_t:new(main)
	main_task()
end

function main()
	-- Request sensor reads
	text = text .. "Waiting for sensor readings...\n"
	tasks.emit("read_sensor1")
	tasks.emit("read_sensor2")
	tasks.emit("read_sensor3")

	-- Pretend to do some work while we wait
	local x = 0
	for i = 0, 1000 do
		x = x + 2
	end

	-- We need the values now, block while waiting for the events
	tasks.par_and(
		function() val1 = tasks.await("sensor1") end,
		function() val2 = tasks.await("sensor2") end,
		function() val3 = tasks.await("sensor3") end
	)()

	text = text .. "Sensor 1: " .. val1 .. "\n"
	text = text .. "Sensor 2: " .. val2 .. "\n"
	text = text .. "Sensor 3: " .. val3 .. "\n"
	text = text .. "Done."
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(text, 40, 100)
end

