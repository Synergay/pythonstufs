local tabs = {};
tabs.__index = tabs;

function tabs.new(theme, utils, parent, ctxmenu, callbacks, icons)
	local self = setmetatable({}, tabs);
	self._theme = theme;
	self._utils = utils;
	self._icons = icons or {};
	self._tabs = {};
	self._active = nil;
	self._conns = {};
	self._cbs = callbacks or {};
	self._ctx = ctxmenu;

	self._bar = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.tabh);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Parent = parent;
	});

	self._scroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, -30, 1, 0);
		BackgroundTransparency = 1;
		ScrollBarThickness = 0;
		BorderSizePixel = 0;
		ScrollingDirection = Enum.ScrollingDirection.X;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		ElasticBehavior = Enum.ElasticBehavior.Never;
		Parent = self._bar;
	});
	utils.list(self._scroll, Enum.FillDirection.Horizontal, 0);

	self._addbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 30, 0, theme.tabh);
		Position = UDim2.new(1, -30, 0, 0);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Text = "";
		AutoButtonColor = false;
		Parent = self._bar;
	});
	utils.icon(self._addbtn, self._icons.plus or "", 14, theme.text2, {
		Position = UDim2.new(0.5, -7, 0.5, -7);
	});
	utils.hover(self._addbtn, theme.bg2, theme.hover, theme);

	local c = self._addbtn.MouseButton1Click:Connect(function()
		self:add("untitled-" .. #self._tabs + 1);
	end);
	table.insert(self._conns, c);

	return self;
end;

function tabs:add(name, content, id, path)
	local theme = self._theme;
	local utils = self._utils;
	id = id or utils.uid();

	local fullw = utils.measure(name, 13, Enum.Font.Gotham) + 50;
	local dispw = math.min(fullw, theme.tabmaxw);
	local truncated, wasCut = utils.truncate(name, dispw - 50, 13, Enum.Font.Gotham);

	local tab = {
		id = id;
		name = name;
		path = path or name;
		content = content or "";
		modified = false;
		fullw = fullw;
		dispw = dispw;
		truncated = wasCut;
	};

	local frame = utils.create("TextButton", {
		Size = UDim2.new(0, dispw, 1, 0);
		BackgroundColor3 = theme.tabinactive;
		BorderSizePixel = 0;
		Text = "";
		AutoButtonColor = false;
		ClipsDescendants = true;
		LayoutOrder = #self._tabs + 1;
		Parent = self._scroll;
	});
	tab.frame = frame;

	local indicator = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 2);
		Position = UDim2.new(0, 0, 0, 0);
		BackgroundColor3 = theme.accent;
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Parent = frame;
	});
	tab.indicator = indicator;

	utils.icon(frame, self:_getIcon(name), 12, self:_getIconClr(name), {
		Position = UDim2.new(0, 8, 0.5, -6);
	});

	local lbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -48, 1, 0);
		Position = UDim2.new(0, 26, 0, 0);
		BackgroundTransparency = 1;
		Text = wasCut and truncated or name;
		TextColor3 = theme.text2;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.None;
		Parent = frame;
	});
	tab.label = lbl;

	local dot = utils.create("TextLabel", {
		Size = UDim2.new(0, 14, 0, 14);
		Position = UDim2.new(1, -20, 0.5, -7);
		BackgroundTransparency = 1;
		Text = "";
		TextColor3 = theme.text2;
		TextSize = 14;
		FontFace = theme.fontui;
		Visible = false;
		Parent = frame;
	});
	tab.dot = dot;

	local closebtn = utils.create("TextButton", {
		Size = UDim2.new(0, 14, 0, 14);
		Position = UDim2.new(1, -20, 0.5, -7);
		BackgroundTransparency = 1;
		Text = "";
		AutoButtonColor = false;
		Visible = false;
		ZIndex = 5;
		Parent = frame;
	});
	utils.icon(closebtn, self._icons.x or "", 10, theme.text2, {
		Position = UDim2.new(0.5, -5, 0.5, -5);
		ZIndex = 6;
	});
	tab.closebtn = closebtn;

	local hovered = false;
	local c1 = frame.MouseEnter:Connect(function()
		hovered = true;
		closebtn.Visible = true;
		dot.Visible = false;
		if self._active ~= id then
			utils.tween(frame, theme.tweenfast, {BackgroundColor3 = theme.hover});
		end;
		if tab.truncated then
			lbl.Text = tab.name;
			utils.tween(frame, theme.tweenmed, {Size = UDim2.new(0, tab.fullw, 1, 0)});
			self:_recalcCanvas();
		end;
	end);

	local c2 = frame.MouseLeave:Connect(function()
		hovered = false;
		if not tab.modified then
			closebtn.Visible = false;
		else
			closebtn.Visible = false;
			dot.Visible = true;
		end;
		if self._active ~= id then
			utils.tween(frame, theme.tweenfast, {BackgroundColor3 = theme.tabinactive});
		end;
		if tab.truncated then
			local ttext, wasCut = utils.truncate(tab.name, tab.dispw - 50, 13, Enum.Font.Gotham);
			lbl.Text = wasCut and ttext or tab.name;
			utils.tween(frame, theme.tweenmed, {Size = UDim2.new(0, tab.dispw, 1, 0)});
			task.delay(0.25, function()
				if not hovered then self:_recalcCanvas(); end;
			end);
		end;
	end);

	local c3 = frame.MouseButton1Click:Connect(function()
		self:select(id);
	end);

	local c5 = frame.MouseButton2Click:Connect(function()
		local mx = frame.AbsolutePosition.X + frame.AbsoluteSize.X * 0.5;
		local my = frame.AbsolutePosition.Y + frame.AbsoluteSize.Y;
		self._ctx:show({
			{label = "Rename"; callback = function() self:_startRename(tab); end};
			{label = "Close"; callback = function() self:close(id); end};
			{label = "Close Others"; callback = function()
				for _, t in next, self._tabs do
					if t.id ~= id then self:close(t.id); end;
				end;
			end};
			{label = "---"};
			{label = "Add to Chat"; callback = function()
				if self._cbs.onAddToChat then self._cbs.onAddToChat(tab); end;
			end};
			{label = "Send to Discord"; callback = function()
				if self._cbs.onSendToDiscord then self._cbs.onSendToDiscord(tab); end;
			end};
			{label = "Copy Path"; callback = function() end};
		}, mx, my);
	end);

	local c4 = closebtn.MouseButton1Click:Connect(function()
		self:close(id);
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);
	table.insert(self._conns, c4);
	table.insert(self._conns, c5);

	table.insert(self._tabs, tab);
	self:_recalcCanvas();
	self:select(id);

	if self._cbs.onAdd then self._cbs.onAdd(tab); end;
	return tab;
end;

function tabs:select(id)
	local theme = self._theme;
	local utils = self._utils;

	for _, t in next, self._tabs do
		if t.id == id then
			self._active = id;
			utils.tween(t.frame, theme.tweenfast, {BackgroundColor3 = theme.tabactive});
			utils.tween(t.indicator, theme.tweenfast, {BackgroundTransparency = 0});
			t.label.TextColor3 = theme.text;
		else
			utils.tween(t.frame, theme.tweenfast, {BackgroundColor3 = theme.tabinactive});
			utils.tween(t.indicator, theme.tweenfast, {BackgroundTransparency = 1});
			t.label.TextColor3 = theme.text2;
		end;
	end;

	local sel = self:get(id);
	if sel and sel.frame then
		local fx = sel.frame.AbsolutePosition.X - self._scroll.AbsolutePosition.X + self._scroll.CanvasPosition.X;
		local fw = sel.frame.AbsoluteSize.X;
		local sw = self._scroll.AbsoluteSize.X;
		local cx = self._scroll.CanvasPosition.X;
		if fx < cx then
			self._scroll.CanvasPosition = Vector2.new(fx, 0);
		elseif fx + fw > cx + sw then
			self._scroll.CanvasPosition = Vector2.new(fx + fw - sw, 0);
		end;
	end;

	if self._cbs.onSelect then
		if sel then self._cbs.onSelect(sel); end;
	end;
end;

function tabs:close(id)
	local theme = self._theme;
	local utils = self._utils;
	local idx;

	for i, t in next, self._tabs do
		if t.id == id then
			idx = i;
			local tw = utils.tween(t.frame, theme.tweenfast, {
				Size = UDim2.new(0, 0, 1, 0);
				BackgroundTransparency = 1;
			});
			tw.Completed:Connect(function() t.frame:Destroy(); end);
			if self._cbs.onClose then self._cbs.onClose(t); end;
			break;
		end;
	end;

	if idx then
		table.remove(self._tabs, idx);
		if self._active == id and #self._tabs > 0 then
			local next_idx = math.min(idx, #self._tabs);
			self:select(self._tabs[next_idx].id);
		elseif #self._tabs == 0 then
			self._active = nil;
			if self._cbs.onSelect then self._cbs.onSelect(nil); end;
		end;
		task.delay(0.2, function() self:_recalcCanvas(); end);
	end;
end;

function tabs:get(id)
	for _, t in next, self._tabs do
		if t.id == id then return t; end;
	end;
	return nil;
end;

function tabs:getActive()
	return self._active and self:get(self._active);
end;

function tabs:setModified(id, val)
	local t = self:get(id);
	if not t then return; end;
	t.modified = val;
	t.dot.Text = val and "●" or "";
	t.dot.Visible = val;
end;

function tabs:rename(id, newname)
	local t = self:get(id);
	if not t then return; end;
	t.name = newname;
	local fullw = self._utils.measure(newname, 13, Enum.Font.Gotham) + 50;
	local dispw = math.min(fullw, self._theme.tabmaxw);
	local trunc, wasCut = self._utils.truncate(newname, dispw - 50, 13, Enum.Font.Gotham);
	t.fullw = fullw;
	t.dispw = dispw;
	t.truncated = wasCut;
	t.label.Text = wasCut and trunc or newname;
	t.frame.Size = UDim2.new(0, dispw, 1, 0);
	self:_recalcCanvas();
end;

function tabs:setContent(id, content)
	local t = self:get(id);
	if t then t.content = content; end;
end;

function tabs:getAll()
	return self._tabs;
end;

function tabs:_getIcon(name)
	local ext = name:match("%.(%w+)$") or "";
	local ic = self._icons;
	local imap = {
		lua = ic.filecode; luau = ic.filecode; py = ic.filecode; js = ic.filecode;
		json = ic.filejson; txt = ic.filetext; md = ic.filetext; xml = ic.filecode;
		css = ic.filecode; html = ic.filecode; ts = ic.filecode; rb = ic.filecode;
	};
	return imap[ext:lower()] or ic.file or "";
end;

function tabs:_getIconClr(name)
	local ext = name:match("%.(%w+)$") or "";
	local clrs = {
		lua = self._theme.blue; luau = self._theme.blue;
		py = self._theme.green; js = self._theme.yellow;
		json = self._theme.orange; txt = self._theme.text2;
		md = self._theme.blue; xml = self._theme.orange;
		css = self._theme.purple; html = self._theme.red;
	};
	return clrs[ext:lower()] or self._theme.text2;
end;

function tabs:_recalcCanvas()
	local total = 0;
	for _, t in next, self._tabs do
		total += t.frame.Size.X.Offset;
	end;
	self._scroll.CanvasSize = UDim2.new(0, total + 5, 0, 0);
end;

function tabs:_startRename(tab)
	local theme = self._theme;
	local utils = self._utils;
	tab.label.Visible = false;
	local inp = utils.create("TextBox", {
		Size = tab.label.Size;
		Position = tab.label.Position;
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = tab.name;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		ZIndex = 6;
		Parent = tab.frame;
	});
	utils.stroke(inp, theme.accent, 1);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local nn = inp.Text;
		inp:Destroy();
		tab.label.Visible = true;
		if nn ~= "" and nn ~= tab.name then
			local oldname = tab.name;
			self:rename(tab.id, nn);
			if self._cbs.onRename then self._cbs.onRename(tab, oldname); end;
		end;
	end);
end;

function tabs:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	self._bar:Destroy();
end;

return tabs;
