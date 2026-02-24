local dropdown = {};
dropdown.__index = dropdown;

function dropdown.new(theme, utils, parent, width)
	local self = setmetatable({}, dropdown);
	self._theme = theme;
	self._utils = utils;
	self._items = {};
	self._conns = {};
	self._open = false;
	self._w = width or theme.dropw;

	self._frame = utils.create("Frame", {
		Size = UDim2.new(0, self._w, 0, 0);
		BackgroundColor3 = theme.dropdown;
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		Visible = false;
		ZIndex = 100;
		Parent = parent;
	});
	utils.corner(self._frame, theme.cornersm);
	utils.stroke(self._frame, theme.border, 1);

	self._list = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		ScrollBarThickness = 3;
		ScrollBarImageColor3 = theme.scrollbar;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		Parent = self._frame;
	});
	utils.list(self._list, Enum.FillDirection.Vertical, 1);

	return self;
end;

function dropdown:addItem(label, shortcut, callback, icon)
	local theme = self._theme;
	local utils = self._utils;

	if label == "---" then
		local sep = utils.create("Frame", {
			Size = UDim2.new(1, -16, 0, 1);
			BackgroundColor3 = theme.separator;
			BorderSizePixel = 0;
			LayoutOrder = #self._items + 1;
			Parent = self._list;
		});
		table.insert(self._items, {frame = sep; type = "sep"});
		self:_recalc();
		return self;
	end;

	local btn = utils.create("TextButton", {
		Size = UDim2.new(1, 0, 0, theme.droph);
		BackgroundColor3 = theme.dropdown;
		BackgroundTransparency = 0;
		BorderSizePixel = 0;
		Text = "";
		AutoButtonColor = false;
		LayoutOrder = #self._items + 1;
		Parent = self._list;
	});

	local _lbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -80, 1, 0);
		Position = UDim2.new(0, icon and 30 or 12, 0, 0);
		BackgroundTransparency = 1;
		Text = label;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.AtEnd;
		Parent = btn;
	});

	if icon then
		utils.create("TextLabel", {
			Size = UDim2.new(0, 20, 1, 0);
			Position = UDim2.new(0, 6, 0, 0);
			BackgroundTransparency = 1;
			Text = icon;
			TextColor3 = theme.text2;
			TextSize = 14;
			FontFace = theme.fontui;
			Parent = btn;
		});
	end;

	if shortcut then
		utils.create("TextLabel", {
			Size = UDim2.new(0, 70, 1, 0);
			Position = UDim2.new(1, -75, 0, 0);
			BackgroundTransparency = 1;
			Text = shortcut;
			TextColor3 = theme.textdim;
			TextSize = 12;
			FontFace = theme.fontui;
			TextXAlignment = Enum.TextXAlignment.Right;
			Parent = btn;
		});
	end;

	local c1 = btn.MouseEnter:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundColor3 = theme.dropdownhvr});
	end);
	local c2 = btn.MouseLeave:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundColor3 = theme.dropdown});
	end);
	local c3 = btn.MouseButton1Click:Connect(function()
		if callback then callback(); end;
		self:close();
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);
	table.insert(self._items, {frame = btn; type = "item"});
	self:_recalc();
	return self;
end;

function dropdown:_recalc()
	local h = 0;
	for _, item in next, self._items do
		if item.type == "sep" then
			h += 5;
		else
			h += self._theme.droph + 1;
		end;
	end;
	self._totalh = math.min(h + 4, 300);
	self._list.CanvasSize = UDim2.new(0, 0, 0, h);
end;

function dropdown:open(pos)
	if self._open then self:close(); return; end;
	self._open = true;
	self._frame.Position = pos or self._frame.Position;
	self._frame.Size = UDim2.new(0, self._w, 0, 0);
	self._frame.BackgroundTransparency = 1;
	self._frame.Visible = true;

	self._utils.tween(self._frame, self._theme.tweenfast, {
		Size = UDim2.new(0, self._w, 0, self._totalh);
		BackgroundTransparency = 0;
	});
end;

function dropdown:close()
	if not self._open then return; end;
	self._open = false;
	local t = self._utils.tween(self._frame, self._theme.tweenfast, {
		Size = UDim2.new(0, self._w, 0, 0);
		BackgroundTransparency = 1;
	});
	t.Completed:Connect(function()
		if not self._open then
			self._frame.Visible = false;
		end;
	end);
end;

function dropdown:toggle(pos)
	if self._open then self:close(); else self:open(pos); end;
end;

function dropdown:isOpen()
	return self._open;
end;

function dropdown:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	self._frame:Destroy();
end;

return dropdown;
