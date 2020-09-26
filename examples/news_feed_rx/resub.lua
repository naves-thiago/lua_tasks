local rx = require"rx"
local Observable = rx.Observable
local Observer = rx.Observer
local Subscription = rx.Subscription

function Observable:resub()
	return Observable.create(function(observer)
		local subscription

		local function onNext(...)
			observer:onNext(...)
		end

		local function onError(...)
			observer:onError(...)
		end

		local function onCompleted()
			if subscription then
				subscription:unsubscribe()
			end
			subscription = self:subscribe(onNext, onError, onCompleted)
		end

		onCompleted()
		return Subscription.create(function()
			subscription:unsubscribe()
		end)
	end)
end
