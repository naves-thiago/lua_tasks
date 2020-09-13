local cards = require"cards"

function love.load()
	local a= cards.card_t:new("bla bla 0000 1234 __aa__ lskadlsad askdjskajdk 1231312 4354353 aksjdkajskdljalkd 09809898098098")
	local b = cards.card_t:new("aaa bbb cccc dddd eeeeee fff gggggg hhhhh")
	news = cards.card_list_t:new(5, 5, 400, 400)
	news:add_card(a)
	news:add_card(b)
end

function love.update(dt)
end

function love.keypressed(key, scancode, isrepeat)
end

function love.draw()
	news:draw()
end
