-------------------------------------------------------------------------------------
-- Example:
-- Simulates a task requesting readings from multiple sensors with asynchronous APIs
-- Each of the 3 sensors take a different amount of time to return a reading.
-- Sensor 1 takes 2 seconds, sensor 2 takes 1 and sensor 3 takes 2.5.
-- Our function needs all 3 values and print them ordered.
-- Author: Thiago Duarte Naves
-------------------------------------------------------------------------------------

local tasks = require("tasks")
local text = ""

-- Slow asynchronous call mockup factory
-- executes a callback passing the reading
local function sensor_factory(time, result, cb)
	local sensor_task = tasks.task_t:new(function()
		tasks.await_ms(time * 1000) -- Pretend we are waiting for an external process
		cb(result)
	end)

	-- Start as an independent task and don't block the call
	sensor_task(true, true)
end

local function read_sensor1(cb)
	sensor_factory(2, 1.111, cb)
end

local function read_sensor2(cb)
	sensor_factory(1, 2.222, cb)
end

local function read_sensor3(cb)
	sensor_factory(2.5, 3.333, cb)
end
-------------------------

function love.load()
	main()
end

function main()
	local val1, val2, val3
	local reading_count = 0

	local function update_count()
		reading_count = reading_count + 1
		if reading_count == 3 then
			text = text .. "Sensor 1: " .. val1 .. "\n"
			text = text .. "Sensor 2: " .. val2 .. "\n"
			text = text .. "Sensor 3: " .. val3 .. "\n"
			text = text .. "Done."
		end
	end

	local function sensor1_cb(value)
		val1 = value
		update_count()
	end

	local function sensor2_cb(value)
		val2 = value
		update_count()
	end

	local function sensor3_cb(value)
		val3 = value
		update_count()
	end

	-- Request sensor reads
	text = text .. "Waiting for sensor readings...\n"
	read_sensor1(sensor1_cb)
	read_sensor2(sensor2_cb)
	read_sensor3(sensor3_cb)

	-- Pretend to do some work while we wait
	local x = 0
	for i = 0, 1000 do
		x = x + 2
	end

	-- We need the values now, return and the values will be used in the callbacks
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.draw()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(text, 40, 100)
end

