local tasks = require"tasks"
local cards = require"cards"
local rx = require"rx"
require"exhaustMap"
require"catchError"
require"share"
local news_cards -- Card list to display the news

local loadNews = rx.Observable.create(function(observer)
	local function onNext(_, n)
		observer:onNext(n)
	end

	local function onCompleted()
		observer:onCompleted()
	end

	tasks.listen('news', onNext)
	tasks.listen('news done', onCompleted)
	tasks.emit('get news')
	return rx.Subscription.create(function()
		tasks.stop_listening('news', onNext)
		tasks.stop_listening('news done', onCompleted)
	end)
end)

local refresh = rx.BehaviorSubject.create(1)
local news = refresh:exhaustMap(function() return loadNews end)
-- refresh_:next() deve fazer com que loadNews_ recarregue as noticias
-- VIDEO 14:00

function love.load()
	local a= cards.card_t:new("bla bla 0000 1234 __aa__ lskadlsad askdjskajdk 1231312 4354353 aksjdkajskdljalkd 09809898098098")
	local b = cards.card_t:new("aaa bbb cccc dddd eeeeee fff gggggg hhhhh")
	local _, h = love.window.getMode()
	news_cards = cards.card_list_t:new(5, 5, 400, h - 5)
	news_cards:add_card(a)
	news_cards:add_card(b)
	loadNews:subscribe(function(n)
		local c = cards.card_t:new(n)
		news_cards:add_card(c)
	end)
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.keypressed(key, scancode, isrepeat)
	tasks.emit('get news')
end

function love.draw()
	news_cards:draw()
end


-------------------------------------------------
-- HTTP request mock
local mock_content = {
	'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed nunc nisl, volutpat id aliquet eu, semper in nisi.',
	'Maecenas nec ornare libero. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Praesent mattis ex eget dolor sagittis ornare.',
	'Morbi imperdiet pharetra arcu.',
	'Curabitur rhoncus, lectus ac elementum lacinia, ligula elit mollis velit, egestas porttitor nisi dui in eros.',
	'Nam turpis tellus, malesuada at augue ac, mollis dictum lorem. Morbi mi mi, laoreet ut erat sed, faucibus egestas lorem. Nam sodales lacus nec viverra sagittis.',
	'Mauris in sodales lorem, non blandit nulla. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Aenean mollis metus eget venenatis venenatis. Mauris elementum cursus rhoncus. Duis at nisl eu dolor congue aliquam.',
	'Aliquam eu magna vel odio malesuada lacinia et sit amet justo. Curabitur in posuere quam.',
	'Pellentesque ultricies bibendum sapien ac lobortis. Mauris eget ex augue.',
	'Phasellus dignissim vitae urna id hendrerit. Maecenas malesuada vulputate arcu a accumsan. Quisque dictum blandit risus, ac consequat lectus scelerisque vitae.',
	'Duis ac gravida velit. Nulla lectus ipsum, ullamcorper a nulla sed, volutpat blandit ipsum. Donec cursus tellus ut vestibulum posuere.',
	'Vestibulum nec odio sed magna venenatis porttitor ac ut metus. Vivamus eu tortor eget est venenatis lacinia. Mauris aliquet nunc ut velit sollicitudin luctus. Curabitur iaculis commodo enim, nec volutpat libero sollicitudin id. Phasellus nec cursus tortor. Donec ultrices, justo at pharetra laoreet, lacus dui blandit risus, quis vehicula augue justo nec lacus.',
	'Phasellus varius pulvinar tristique. Fusce mi arcu, venenatis eu nulla at, fringilla porta turpis. Praesent commodo condimentum risus, id lobortis ex. Ut eget nisl ligula.',
}

local mock_content_steps = {3, 5, 3} -- how many posts to add on each reply
local mock_current_step = 1 -- next content step to use
local mock_sent = 0 -- sent posts
local http_task = tasks.task_t:new(function()
	while true do
		tasks.await('get news')
		tasks.await_ms(2000)
		for i = 1, mock_sent + mock_content_steps[mock_current_step] do
			if not mock_content[i] then
				break
			end
			tasks.emit('news', mock_content[i])
		end
		if mock_current_step < #mock_content then
			mock_sent = mock_sent + mock_content_steps[mock_current_step]
			mock_current_step = mock_current_step + 1
		end
		tasks.emit('news done')
	end
end)
http_task()
