local m = {}

m.card_t = { _border = 5, _bg_color = {1, 1, 1}, _text_color = {0, 0, 0}}
local card_t_meta = {__index = m.card_t}

function m.card_t:new(str, x, y, w)
	local r = setmetatable({}, card_t_meta)
	r.x = x or 0
	r.y = y or 0
	r._w = w
	r._text = love.graphics.newText(love.graphics.getFont())
	r._str = str
	if text then
		r:set_text(str)
	end
	return r
end

function m.card_t:set_text(str)
	if self._w then
		self._text:setf({self._text_color, str}, self._w - 2 * self._border, "left")
	else
		self._text:setf({self._text_color, str})
	end
	self._h = self._text:getHeight() + 2 * self._border
end

function m.card_t:draw()
	love.graphics.setColor(self._bg_color)
	love.graphics.rectangle("fill", self.x, self.y, self._w, self._h);
	love.graphics.draw(self._text, self.x + self._border, self.y + self._border)
end

function m.card_t:set_width(w)
	self._w = w
	self:set_text(self._str)
end

-------------

m.card_list_t = {spacing = 5}
local card_list_t_meta = {__index = m.card_list_t}

function m.card_list_t:new(x, y, w, h)
	local r = {
		_cards = {},
		_x = x,
		_y = y,
		_w = w,
		_h = h,
		_curr_y = y -- Next inserted card's y position
	}
	return setmetatable(r, card_list_t_meta)
end

function m.card_list_t:draw()
	for _, c in ipairs(self._cards) do
		c:draw()
		-- TODO check height
	end
end

function m.card_list_t:set_position(x, y)
	local curr_y = y
	for _, c in ipairs(self._cards) do
		c.x = x
		c.y = curr_y
		curr_y = curr_y + c._h + self.spacing
	end
	self._curr_y = curr_y
end

function m.card_list_t:set_height(h)
	self._h = h
end

function m.card_list_t:add_card(c)
	table.insert(self._cards, c)
	c.x = self._x
	c.y = self._curr_y
	c:set_width(self._w)
	self._curr_y = self._curr_y + c._h + self.spacing
end

function m.card_list_t:clear()
	self._cards = {}
	self._curr_y = self._y
end

return m
