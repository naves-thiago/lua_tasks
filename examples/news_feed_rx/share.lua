local rx = require"rx"
local Observable = rx.Observable
local Observer = rx.Observer
local Subscription = rx.Subscription

--- Shorthand for creating an Observer and passing it to this Observable's subscription function.
-- @arg {table} self - Observable object
-- @arg {function} onNext - Called when the Observable produces a value.
-- @arg {function} onError - Called when the Observable terminates due to an error.
-- @arg {function} onCompleted - Called when the Observable completes normally.
local function subscribeWithSelf(self, onNext, onError, onCompleted)
  if type(onNext) == 'table' then
    return self:_subscribe(onNext)
  else
    return self:_subscribe(Observer.create(onNext, onError, onCompleted))
  end
end

function Observable.share(parent)
	local out = Observable.create(function(self, observer)
		local function onNext(...)
			for i = #self._subscribers, 1, -1 do
				self._subscribers[i]:onNext(...)
			end
		end

		local function onError(e)
			for i = #self._subscribers, 1, -1 do
				self._subscribers[i]:onError(e)
			end
		end

		local function onCompleted()
			for i = #self._subscribers, 1, -1 do
				self._subscribers[i]:onCompleted()
			end
		end

		self._subscribers = self._subscribers or {}
		table.insert(self._subscribers, observer)
		if #self._subscribers == 1 then
			self._parentSubscription = parent:subscribe(onNext, onError, onCompleted)
		end

		return rx.Subscription.create(function()
			for i, o in ipairs(self._subscribers) do
				if o == observer then
					table.remove(self._subscribers, i)
					break
				end
			end

			if #self._subscribers == 0 then
				self._parentSubscription:unsubscribe()
			end
		end)
	end)
	out.subscribe = subscribeWithSelf
	return out
end


