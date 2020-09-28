local m = {}

local function interpolate(val_min, val_max, time_min, time_max, time_curr)
	local fraction = (time_curr - time_min) / (time_max - time_min)
	return val_min + (val_max - val_min) * fraction
end

-- Create a task to animate between 2 values over an interval
function m.tween(initial, final, duration, foreach_cb, loop)
	return tasks.task_t:new(function()
		repeat
			local start_time = tasks.now_ms()
			local end_time = tasks.now_ms() + duration
			while true do
				tasks.await_ms(1000 / 60)
				if tasks.now_ms() > end_time then
					foreach_cb(final)
					break
				end
				foreach_cb(interpolate(initial, final, start_time, end_time, tasks.now_ms()))
			end
		until not loop
	end)
end

return m
