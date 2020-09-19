local rx = require"rx"
local util = rx.util
local Observable = rx.Observable
local Subscription = rx.Subscription

function Observable:exhaust()
	return self:exhaustMap(util.identity)
end

function Observable:exhaustMap(callback)
	return Observable.create(function(observer)
		callback = callback or util.identity
		local outterComplete = false
		local innerComplete = true
		local innerSubscription, outterSubscription
		local errorState = false

		local function onNext(...)
			if not innerComplete or errorState then
				return
			end

			local success, innerObservable = util.tryWithObserver(observer, callback, ...)
			if not success then
				errorState = true
				return
			end

			innerComplete = false
			local function innerOnNext(...)
				return observer:onNext(...)
			end

			local function innerOnError(e)
				-- Not setting innerComplete prevents the steram to continue emitting values.
				-- Current inner won't emit more not complete, ignoring the outter stream.
				errorState = true
				return observer:onError(e)
			end

			local function innerOnCompleted()
				innerComplete = true
				if outterComplete then
					return observer:onCompleted()
				end
			end

			if innerSubscription then
				innerSubscription:unsubscribe()
			end
			success, innerSubscription = util.tryWithObserver(observer, function()
				return innerObservable:subscribe(innerOnNext, innerOnError, innerOnCompleted)
			end)
			if not success then
				errorState = true
			end
		end

		local function onError(e)
			return observer:onError(e)
		end

		local function onCompleted()
			outterComplete = true
			if innerComplete then
				return observer:onCompleted()
			end
		end

		outterSubscription = self:subscribe(onNext, onError, onCompleted)
		return Subscription.create(function()
			if innerSubscription then
				innerSubscription:unsubscribe()
			end
			outterSubscription:unsubscribe()
		end)
	end)
end

