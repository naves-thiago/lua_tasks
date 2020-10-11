local m = {}
m.loading_icon_t = {}

function m.loading_icon_t:new(x, y, size)
	size = size or 20
	local out = setmetatable({
		x = x,
		y = y,
		size = size,
		rotation = 0,
		visible = true,
		_canvas = love.graphics.newCanvas(size, size)
	}, {__index = m.loading_icon_t})

	love.graphics.setCanvas(out._canvas)
	love.graphics.setColor(0.2, 1.0, 0.2)
	love.graphics.rectangle("fill", 0, 0, size, size)
	love.graphics.setCanvas()
	return out
end

function m.loading_icon_t:rotate(rotation)
	self.rotation = rotation
end

function m.loading_icon_t:draw()
	if self.visible then
		love.graphics.draw(self._canvas, self.x + self.size / 2, self.y + self.size / 2,
			math.rad(self.rotation), 1, 1, self.size / 2, self.size / 2)
	end
end

return m
