local rx = require"rx"
local Observable = rx.Observable
local Observer = rx.Observer
local Subscription = rx.Subscription

function Observable:endWith(...)
	local endVal = rx.util.pack(...)
	return Observable.create(function(observer)
		local function onNext(...)
			observer:onNext(...)
		end

		local function onError(...)
			observer:onError(...)
		end

		local function onCompleted()
			observer:onNext(rx.util.unpack(endVal))
			observer:onCompleted()
		end

		return self:subscribe(onNext, onError, onCompleted)
	end)
end

