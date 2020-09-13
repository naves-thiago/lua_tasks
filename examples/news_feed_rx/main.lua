local cards = require"cards"
local rx = require"rx"
local news_cards -- Card list to display the news

-- Note: Observable variable names end with _

local loadNews_ = rx.Observable(function(observer)
	-- Load news and send to the observer
end)

local refresh_ = rx.BehaviorSubject.create()
local news = refresh:exaustMap(function() return loadNews_ end) -- Descobrir o q eh exaustMap e implementar
-- refresh_:next() deve fazer com que loadNews_ recarregue as noticias

function love.load()
	local a= cards.card_t:new("bla bla 0000 1234 __aa__ lskadlsad askdjskajdk 1231312 4354353 aksjdkajskdljalkd 09809898098098")
	local b = cards.card_t:new("aaa bbb cccc dddd eeeeee fff gggggg hhhhh")
	news_cards = cards.card_list_t:new(5, 5, 400, love.window.getHeight() - 5)
	news_cards:add_card(a)
	news_cards:add_card(b)
end

function love.update(dt)
end

function love.keypressed(key, scancode, isrepeat)
end

function love.draw()
	news_cards:draw()
end
