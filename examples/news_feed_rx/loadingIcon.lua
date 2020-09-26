local m = {}
m.loading_icon_t = {}

function m.loading_icon_t:new(x, y)
	local out = setmetatable({
		x = x,
		y = y,
		rotation = 0,
		visible = true,
		_canvas = love.graphics.newCanvas(20, 20)
	}, {__index = m.loading_icon_t})

	love.graphics.setCanvas(out._canvas)
	love.graphics.setColor(0.2, 1.0, 0.2)
	love.graphics.rectangle("fill", 0, 0, 20, 20)
	love.graphics.setCanvas()
	return out
end

function m.loading_icon_t:rotate(rotation)
	self.rotation = rotation
end

function m.loading_icon_t:draw()
	if self.visible then
		love.graphics.draw(self._canvas, self.x, self.y, math.rad(self.rotation), 1, 1, 10, 10)
	end
end

return m
