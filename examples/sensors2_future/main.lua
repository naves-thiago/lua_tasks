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
local function sensor_factory(time, result)
	local sensor_task
	sensor_task = tasks.task_t:new(function()
		tasks.await_ms(time * 1000) -- Pretend we are waiting for an external process
		tasks.emit(sensor_task, result) -- Use the task itself as an event id
	end)

	-- Start as an independent task and don't block the call
	sensor_task(true, true)

	return tasks.future_t:new(sensor_task)
end

local function read_sensor1()
	return sensor_factory(2, 1.111)
end

local function read_sensor2()
	return sensor_factory(1, 2.222)
end

local function read_sensor3()
	return sensor_factory(2.5, 3.333)
end
-------------------------

function love.load()
	main_task = tasks.task_t:new(main)
	main_task()
end

function main()
	-- Request sensor reads
	s1 = read_sensor1()
	s2 = read_sensor2()
	s3 = read_sensor3()

	-- Pretend to do some work while we wait
	local x = 0
	for i = 0, 1000 do
		x = x + 2
	end

	-- We need the values now, wait for all sensors to respond
	-- get calls only block if the readig is still pending, so
	-- we can just call all in sequence
	text = text .. "Waiting for sensor readings...\n"
	val1 = s1:get()
	val2 = s2:get()
	val3 = s3:get()
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
