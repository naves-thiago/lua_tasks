local rx = require"rx"
local util = rx.util
local Observable = rx.Observable
local Subscription = rx.Subscription

function Observable:catchError(callback)
	return Observable.create(function(observer)
		local function onNext(...)
			return observer:onNext(...)
		end

		local function onError(e)
			local success, result = util.tryWithObserver(observer, callback, e)
			return result
		end

		local function onCompleted()
			return observer:onCompleted()
		end

		return self:subscribe(onNext, onError, onCompleted)
	end)
end

