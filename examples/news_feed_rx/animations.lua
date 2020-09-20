local rx = require'rx'
local tasks = require'tasks'

local m = {}

local function interpolate(val_min, val_max, time_min, time_max, time_curr)
	--if time_curr > time_max then
	--	return val_max
	--end

	local fraction = (time_curr - time_min) / (time_max - time_min)
	return val_min + (val_max - val_min) * fraction
end

function m.tween(initial, final, duration)
	return rx.Observable.create(function(observer)
		local start_time = tasks.now_ms()
		local end_time = tasks.now_ms() + duration
		local timer
		local function timer_cb()
			if tasks.now_ms() > end_time then
				observer:onNext(final)
				observer:onCompleted()
				timer:stop()
				return
			end

			observer:onNext(interpolate(initial, final, start_time, end_time, tasks.now_ms()))
			--timer = tasks.in_ms(1000/60, timer_cb)
		end

		timer = tasks.every_ms(1000/60, timer_cb)

		return rx.Subscription.create(function()
			timer:stop()
		end)
	end)
end

return m
