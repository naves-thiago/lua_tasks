--------------------------------------------------------------------
-- Example:
-- News feed: Reads a list of posts from an HTTP server (mockup) and
-- displays them on the screen.
-- Posts are refreshed every 30s.
-- Draging down with the mouse past half of the screen reloads the
-- posts. A spinnig square indicates the news are being loaded.
--
-- RxLua API example
--
-- This example was adapted from the one presented by Ben Lesh (@benlesh)
-- in the "Complex features made easy with RxJS" talk presented at
-- JSFoo 2018.
--
-- Author: Thiago Duarte Naves
--------------------------------------------------------------------
local tasks = require'tasks'
local cards = require'cards'
local loading_icon_t = require('loadingIcon').loading_icon_t
local animations = require'animations'
local rx = require'rx'
require'exhaustMap'
require'catchError'
require'share'
require'resub'
require'endWith'

love.mousemoved = rx.Subject.create()
love.mousepressed = rx.Subject.create()
love.mousereleased = rx.Subject.create()

local news_cards
local load_ico

function love.load()
	love.window.setMode(410, 600)
	love.window.setTitle("News")

	local loadNews = http_get('/newsfeed')
		:catchError(function(e)
			print('[ERROR] error loading news feed')
			print('[ERROR] ' .. e)
		end)

	-- Subject that forces a news refresh
	local refresh = rx.BehaviorSubject.create(1)

	-- News feed observable
	local news = refresh:exhaustMap(function()
		return loadNews
	end):share()

	-- Reload news periodically
	timer(0, 30000):subscribe(refresh)

	-- Card list to display the news
	news_cards = cards.card_list_t:new(5, 5, 400, window_height() - 5)
	news:subscribe(function(n)
		news_cards:clear()
		for _, str in ipairs(n) do
			local c = cards.card_t:new(str)
			news_cards:add_card(c)
		end
	end)

	-- Loading icon object
	load_ico = loading_icon_t:new(195, 0, 20)

	-- Loading icon spring back animation
	local load_ico_move_home = rx.Observable.defer(function()
			return animations.tween(load_ico.y, 0, 200)
		end)

	-- Report mouse Y movement while the mouse is down relative to the mouse down position
	local mouse_drag = love.mousepressed:exhaustMap(function(start_x, start_y)
		return rx.Observable.concat(
				love.mousemoved
					:map(function(x, y) return y - start_y end) -- extract Y and offset by the start Y
					:takeUntil(love.mousereleased), -- stop tracking when the mouse is released
				load_ico_move_home
				)
					-- Trigger a news reload when we go past half window
					:tap(function(y) if y > window_height() / 2 then refresh:onNext(1) end end)
					:takeWhile(function(y) return y <= window_height() / 2 end) -- Stop when we get bellow half screen
	end):share()

	-- Animate the icon back home after loading the news
	local load_ico_position_update = mouse_drag:exhaustMap(function()
		return rx.Observable.concat(
			mouse_drag:takeUntil(news),
			load_ico_move_home)
	end)

	-- Emits the positions for the loading icon
	local load_ico_position = load_ico_position_update
		:startWith(-load_ico.size / 2) -- Start outside the screen (account for diagonal size due to rotation)
		:map(function(y) return y - load_ico.size end) -- Offset by the square size

	-- Loading icon rotation observable
	local load_ico_rotate = refresh:exhaustMap(function()
		return animations.tween(0, 360, 500)
				:resub()
				:takeUntil(news)
				:endWith(0)
	end)

	load_ico_position:subscribe(function(p) load_ico.y = p end)
	load_ico_rotate:subscribe(function(r) load_ico.rotation = r end)
end

function love.update(dt)
	tasks.update_time(dt * 1000)
end

function love.draw()
	news_cards:draw()
	load_ico:draw()
end

function window_height()
	local _, h = love.window.getMode()
	return h
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
		local count = mock_sent + mock_content_steps[mock_current_step]
		count = math.min(count, #mock_content)
		tasks.emit('news', {unpack(mock_content, 1, count)})
		if mock_current_step < #mock_content_steps then
			mock_sent = mock_sent + mock_content_steps[mock_current_step]
			mock_current_step = mock_current_step + 1
		end
		tasks.emit('news done')
	end
end)
http_task()

function http_get(path)
	return rx.Observable.create(function(observer)
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
end

-----------------------------------------------
-- Timer interface
function timer(initial, interval)
	return rx.Observable.create(function(observer)
		local count = initial
		local function onNext()
			observer:onNext(count)
			count = count + 1
		end
		local timer = tasks.every_ms(interval, onNext)
		return rx.Subscription.create(function()
			timer:stop()
		end)
	end)
end
