--------------------------------------------------------------------
-- Example:
-- Blink LED 1 once every second
-- If button 1 is pressed, stop blinking
--------------------------------------------------------------------
local tasks = require"tasks"
local par_or = tasks.par_or
local await = tasks.await
local listen = tasks.listen
local await_ms = tasks.await_ms -- not implemented
local every_ms = tasks.every_ms -- not implemented
local button1_down -- not implemented
local led1 -- not implemented

----- Await API ------
function blink()
	while true do
		await_ms(500)
		led1:toggle()
	end
end

par_or(blink, function() await(button1_down) end)()
----------------------

---- Callback API ----
local blinker = every_ms(500, led1:toggle())
listen(button1_down, function() blinker:stop() end, true)
----------------------
