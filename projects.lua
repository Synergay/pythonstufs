local projects = {};
projects.__index = projects;

function projects.new(theme, utils, parent, callbacks, icons)
	local self = setmetatable({}, projects);
	self._theme = theme;
	self._utils = utils;
	self._icons = icons or {};
	self._conns = {};
	self._cbs = callbacks or {};
	self._items = {};
	self._active = nil;

	self._frame = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		ClipsDescendants = true;
		Parent = parent;
	});

	local header = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 30);
		BackgroundTransparency = 1;
		Parent = self._frame;
	});
	utils.pad(header, 0, 0, 12, 0);

	utils.create("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0);
		BackgroundTransparency = 1;
		Text = "PROJECTS";
		TextColor3 = theme.text2;
		TextSize = 11;
		FontFace = theme.fontbold;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = header;
	});

	local hbtns = utils.create("Frame", {
		Size = UDim2.new(0, 66, 0, 20);
		Position = UDim2.new(1, -74, 0.5, -10);
		BackgroundTransparency = 1;
		Parent = header;
	});
	utils.list(hbtns, Enum.FillDirection.Horizontal, 2);

	local ic = self._icons;
	local function mkbtn(img, order, cb)
		local b = utils.create("TextButton", {
			Size = UDim2.new(0, 20, 0, 20);
			BackgroundTransparency = 1;
			Text = "";
			AutoButtonColor = false;
			LayoutOrder = order;
			Parent = hbtns;
		});
		utils.icon(b, img, 14, theme.text2, {
			Position = UDim2.new(0.5, -7, 0.5, -7);
		});
		utils.hover(b, Color3.new(0, 0, 0), theme.hover, theme);
		local bc = b.MouseButton1Click:Connect(cb);
		table.insert(self._conns, bc);
	end;

	mkbtn(ic.plus or "", 1, function() self:_promptNew(); end);
	mkbtn(ic.save or "", 2, function()
		if self._cbs.onSave then self._cbs.onSave(); end;
	end);
	mkbtn(ic.refresh or "", 3, function() self:refresh(); end);

	self._scroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -30);
		Position = UDim2.new(0, 0, 0, 30);
		BackgroundTransparency = 1;
		ScrollBarThickness = 4;
		ScrollBarImageColor3 = theme.scrollbar;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		Parent = self._frame;
	});
	utils.list(self._scroll, Enum.FillDirection.Vertical, 0, nil, Enum.VerticalAlignment.Top);

	utils.create("Frame", {
		Size = UDim2.new(0, 1, 1, 0);
		Position = UDim2.new(1, -1, 0, 0);
		BackgroundColor3 = theme.border;
		BorderSizePixel = 0;
		Parent = self._frame;
	});

	return self;
end;

function projects:show()
	self._frame.Visible = true;
end;

function projects:hide()
	self._frame.Visible = false;
end;

function projects:refresh()
	for _, it in next, self._items do
		if it.frame then it.frame:Destroy(); end;
	end;
	self._items = {};
	if self._cbs.onList then
		local list = self._cbs.onList();
		for _, entry in next, list do
			if type(entry) == "table" then
				self:_addProject(entry.name, entry.fcount);
			else
				self:_addProject(entry, 0);
			end;
		end;
	end;
	self:_recalc();
end;

function projects:setActive(name)
	self._active = name;
	for _, it in next, self._items do
		if it.name == name then
			it.frame.BackgroundTransparency = 0;
			it.frame.BackgroundColor3 = self._theme.hover;
		else
			it.frame.BackgroundTransparency = 1;
		end;
	end;
end;

function projects:_addProject(name, fcount)
	local theme = self._theme;
	local utils = self._utils;
	fcount = fcount or 0;

	local btn = utils.create("TextButton", {
		Size = UDim2.new(1, 0, 0, 32);
		BackgroundTransparency = 1;
		Text = "";
		AutoButtonColor = false;
		LayoutOrder = #self._items + 1;
		Parent = self._scroll;
	});

	utils.icon(btn, self._icons.folder or "", 14, theme.orange, {
		Position = UDim2.new(0, 8, 0.5, -7);
	});

	local namelbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -30, 0, 16);
		Position = UDim2.new(0, 26, 0, 2);
		BackgroundTransparency = 1;
		Text = name;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.AtEnd;
		Parent = btn;
	});

	utils.create("TextLabel", {
		Size = UDim2.new(1, -30, 0, 12);
		Position = UDim2.new(0, 26, 0, 17);
		BackgroundTransparency = 1;
		Text = fcount .. " files";
		TextColor3 = theme.textdim;
		TextSize = 10;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = btn;
	});

	local isactive = self._active == name;
	if isactive then
		btn.BackgroundTransparency = 0;
		btn.BackgroundColor3 = theme.hover;
	end;

	local c1 = btn.MouseEnter:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 0; BackgroundColor3 = theme.hover});
	end);
	local c2 = btn.MouseLeave:Connect(function()
		if self._active ~= name then
			utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 1});
		end;
	end);
	local c3 = btn.MouseButton1Click:Connect(function()
		if self._cbs.onOpen then self._cbs.onOpen(name); end;
		self:setActive(name);
	end);
	local c4 = btn.MouseButton2Click:Connect(function()
		if self._cbs.onContext then
			self._cbs.onContext(name, btn.AbsolutePosition.X + btn.AbsoluteSize.X * 0.5, btn.AbsolutePosition.Y + 32);
		end;
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);
	table.insert(self._conns, c4);

	local item = {frame = btn; name = name; namelbl = namelbl};
	table.insert(self._items, item);
end;

function projects:_recalc()
	self._scroll.CanvasSize = UDim2.new(0, 0, 0, #self._items * 32);
end;

function projects:renameProject(oldname, newname)
	for _, it in next, self._items do
		if it.name == oldname then
			it.name = newname;
			if it.namelbl then it.namelbl.Text = newname; end;
			break;
		end;
	end;
	if self._active == oldname then self._active = newname; end;
end;

function projects:_promptSaveAs(cb)
	local theme = self._theme;
	local utils = self._utils;
	local inp = utils.create("TextBox", {
		Size = UDim2.new(1, -10, 0, 24);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = "";
		PlaceholderText = "save as project...";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		LayoutOrder = 999;
		Parent = self._scroll;
	});
	utils.stroke(inp, theme.green, 1);
	utils.pad(inp, 0, 0, 4, 4);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local n = inp.Text;
		inp:Destroy();
		if n ~= "" and cb then cb(n); end;
	end);
end;

function projects:_promptNew()
	local theme = self._theme;
	local utils = self._utils;
	local inp = utils.create("TextBox", {
		Size = UDim2.new(1, -10, 0, 24);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = "";
		PlaceholderText = "project name";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		LayoutOrder = 999;
		Parent = self._scroll;
	});
	utils.stroke(inp, theme.accent, 1);
	utils.pad(inp, 0, 0, 4, 4);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local n = inp.Text;
		inp:Destroy();
		if n ~= "" then
			if self._cbs.onCreate then self._cbs.onCreate(n); end;
			self:refresh();
			self:setActive(n);
		end;
	end);
end;

function projects:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	self._frame:Destroy();
end;

return projects;
