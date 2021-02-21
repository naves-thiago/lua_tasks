--------------------------------------------------------------------
-- Example:
-- News feed: Reads a list of posts from an HTTP server (mockup) and
-- displays them on the screen.
-- Posts are refreshed every 30s.
-- Draging down with the mouse past half of the screen reloads the
-- posts. A spinnig square indicates the news are being loaded.
--
-- Tasks / parallel blocks API example
--
-- This example was inspired by the one presented by Ben Lesh (@benlesh)
-- in the "Complex features made easy with RxJS" talk presented at
-- JSFoo 2018.
--
-- Author: Thiago Duarte Naves
--------------------------------------------------------------------
local tasks = require'tasks'
local cards = require'cards'
local loading_icon_t = require('loadingIcon').loading_icon_t
local tween = require('animations').tween

local reload_task
local news_cards
local load_ico

-- Request the news and fill the news_cards
function update_news()
	tasks.task_t:new(function()
		local success, n = http_get('/newsfeed')
		if not success then
			print('[ERROR] error loading news feed')
			print('[ERROR] ' .. n)
			return
		end

		news_cards:clear()
		for _, str in ipairs(n) do
			local c = cards.card_t:new(str)
			news_cards:add_card(c)
		end
	end)()
end

-- Animate the loading icon back home
function load_ico_move_home()
	tween(load_ico.y, -load_ico.size, 200, function(y)
		load_ico.y = y
	end)()
end

-- Reload task function
function manual_reload_f()
	while true do
		local _, start_y = tasks.await('mousepressed')
		local reload = tasks.par_or(
			function()
				local y
				repeat
					_, y = tasks.await('mousemoved')
					load_ico.y = y - start_y - load_ico.size
				until y - start_y >= window_height() / 2
				return true
			end,
			function()
				tasks.await('mousereleased')
			end
		)

		if reload() then
			local spin_task = tween(0, 360, 500, function(r)
				load_ico.rotation = r
			end, true)
			tasks.par_or(spin_task, update_news)()
			load_ico.rotation = 0
		end
		load_ico_move_home()
	end
end

function love.load()
	love.window.setMode(410, 600)
	love.window.setTitle("News")

	load_ico = loading_icon_t:new(195, -30, 20)
	news_cards = cards.card_list_t:new(5, 5, 400, window_height() - 5)

	-- Load news when the app start
	update_news()

	-- Reload news periodically
	tasks.task_t:new(function()
		while true do
			tasks.await_ms(30000)
			update_news()
		end
	end)()
	reload_task = tasks.task_t:new(manual_reload_f)
	reload_task()
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

function love.mousemoved(...)
	tasks.emit('mousemoved', ...)
end

function love.mousepressed(...)
	tasks.emit('mousepressed', ...)
end

function love.mousereleased(...)
	tasks.emit('mousereleased', ...)
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
	end
end)
http_task()

function http_get(path)
	tasks.emit('get news')
	return tasks.par_or(
		function()
			return true, tasks.await('news')
		end,
		function()
			return false, tasks.await('news error')
		end)()
end
