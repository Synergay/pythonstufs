local window = {};
window.__index = window;

function window.new(theme, utils, parent, icons, anim)
	local self = setmetatable({}, window);
	self._theme = theme;
	self._utils = utils;
	self._icons = icons or {};
	self._anim = anim;
	self._conns = {};
	self._minimized = false;
	self._maximized = false;
	self._sidevis = true;
	self._chatvis = true;

	local uis = game:GetService("UserInputService");

	self._gui = utils.create("ScreenGui", {
		Name = "VSCodeUI";
		ResetOnSpawn = false;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		Parent = parent;
	});

	self._main = utils.create("Frame", {
		Size = UDim2.new(0, 1140, 0, 650);
		Position = UDim2.new(0.5, -570, 0.5, -325);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		ClipsDescendants = true;
		Parent = self._gui;
	});
	utils.corner(self._main, theme.corner);
	utils.stroke(self._main, theme.border, 1);

	self._titlebar = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.titleh);
		BackgroundColor3 = theme.title;
		BorderSizePixel = 0;
		Parent = self._main;
	});

	self._titlelbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -150, 1, 0);
		Position = UDim2.new(0, 12, 0, 0);
		BackgroundTransparency = 1;
		Text = "VSCode - Executor";
		TextColor3 = theme.text2;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = self._titlebar;
	});

	local controls = utils.create("Frame", {
		Size = UDim2.new(0, 110, 1, 0);
		Position = UDim2.new(1, -110, 0, 0);
		BackgroundTransparency = 1;
		Parent = self._titlebar;
	});
	utils.list(controls, Enum.FillDirection.Horizontal, 0, Enum.HorizontalAlignment.Right);

	local ic = icons;
	local function mkctrl(img, clr, order, cb)
		local btn = utils.create("TextButton", {
			Size = UDim2.new(0, 36, 1, 0);
			BackgroundTransparency = 1;
			Text = "";
			AutoButtonColor = false;
			LayoutOrder = order;
			Parent = controls;
		});
		utils.icon(btn, img, 14, theme.text2, {
			Position = UDim2.new(0.5, -7, 0.5, -7);
		});
		local hclr = clr or theme.hover;
		local c1 = btn.MouseEnter:Connect(function()
			utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 0; BackgroundColor3 = hclr});
		end);
		local c2 = btn.MouseLeave:Connect(function()
			utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 1});
		end);
		local c3 = btn.MouseButton1Click:Connect(cb);
		table.insert(self._conns, c1);
		table.insert(self._conns, c2);
		table.insert(self._conns, c3);
		return btn;
	end;

	mkctrl(ic.minus, nil, 1, function() self:minimize(); end);
	mkctrl(ic.maximize, nil, 2, function() self:maximize(); end);
	mkctrl(ic.x, theme.red, 3, function() self:destroy(); end);

	local dragging, dragstart, startpos;
	local c1 = self._titlebar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true;
			dragstart = input.Position;
			startpos = self._main.Position;
		end;
	end);
	local c2 = uis.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragstart;
			self._main.Position = UDim2.new(
				startpos.X.Scale, startpos.X.Offset + delta.X,
				startpos.Y.Scale, startpos.Y.Offset + delta.Y
			);
		end;
	end);
	local c3 = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false;
		end;
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);

	self._content = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, -(theme.titleh + theme.statush));
		Position = UDim2.new(0, 0, 0, theme.titleh);
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		Parent = self._main;
	});

	self._menucontainer = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.menuh);
		BackgroundColor3 = theme.title;
		BorderSizePixel = 0;
		Parent = self._content;
	});

	self._tabcontainer = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.tabh);
		Position = UDim2.new(0, 0, 0, theme.menuh);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Parent = self._content;
	});

	self._body = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, -(theme.menuh + theme.tabh));
		Position = UDim2.new(0, 0, 0, theme.menuh + theme.tabh);
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		Parent = self._content;
	});

	local actw = 40;
	self._actbar = utils.create("Frame", {
		Size = UDim2.new(0, actw, 1, 0);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Parent = self._body;
	});

	local ablist = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0);
		BackgroundTransparency = 1;
		AutomaticSize = Enum.AutomaticSize.Y;
		Parent = self._actbar;
	});
	utils.list(ablist, Enum.FillDirection.Vertical, 0);

	self._actbtns = {};
	self._acticons = {};
	local function mkact(img, id, order)
		local b = utils.create("TextButton", {
			Size = UDim2.new(1, 0, 0, 40);
			BackgroundTransparency = 1;
			Text = "";
			AutoButtonColor = false;
			LayoutOrder = order;
			Parent = ablist;
		});
		local ico = utils.icon(b, img, 18, theme.text2, {
			Position = UDim2.new(0.5, -9, 0.5, -9);
		});
		self._actbtns[id] = b;
		self._acticons[id] = ico;
		local bc = b.MouseButton1Click:Connect(function()
			self:_switchSideView(id);
		end);
		table.insert(self._conns, bc);
	end;

	mkact(ic.files, "files", 1);
	mkact(ic.grid, "projects", 2);
	self._sideview = "files";
	self._acticons["files"].ImageColor3 = theme.text;

	utils.create("Frame", {
		Size = UDim2.new(0, 1, 1, 0);
		Position = UDim2.new(1, -1, 0, 0);
		BackgroundColor3 = theme.border;
		BorderSizePixel = 0;
		Parent = self._actbar;
	});

	self._leftpanel = utils.create("Frame", {
		Size = UDim2.new(0, theme.sidebarw, 1, 0);
		Position = UDim2.new(0, actw, 0, 0);
		BackgroundTransparency = 1;
		Parent = self._body;
	});

	self._projpanel = utils.create("Frame", {
		Size = UDim2.new(0, theme.sidebarw, 1, 0);
		Position = UDim2.new(0, actw, 0, 0);
		BackgroundTransparency = 1;
		Visible = false;
		Parent = self._body;
	});

	self._rightpanel = utils.create("Frame", {
		Size = UDim2.new(0, theme.chatw, 1, 0);
		Position = UDim2.new(1, -theme.chatw, 0, 0);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Parent = self._body;
	});

	self._centerpanel = utils.create("Frame", {
		Size = UDim2.new(1, -(actw + theme.sidebarw + theme.chatw), 1, 0);
		Position = UDim2.new(0, actw + theme.sidebarw, 0, 0);
		BackgroundTransparency = 1;
		Parent = self._body;
	});

	self._actw = actw;

	self._statuscontainer = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.statush);
		Position = UDim2.new(0, 0, 1, -theme.statush);
		BackgroundTransparency = 1;
		Parent = self._main;
	});

	self._sw = theme.sidebarw;
	self._cw = theme.chatw;

	local lh = utils.create("TextButton", {
		Size = UDim2.new(0, 4, 1, 0);
		Position = UDim2.new(0, actw + theme.sidebarw - 2, 0, 0);
		BackgroundColor3 = theme.border;
		BackgroundTransparency = 0.6;
		BorderSizePixel = 0;
		Text = "";
		AutoButtonColor = false;
		ZIndex = 10;
		Parent = self._body;
	});
	self._lhandle = lh;

	local rh = utils.create("TextButton", {
		Size = UDim2.new(0, 4, 1, 0);
		Position = UDim2.new(1, -theme.chatw, 0, 0);
		BackgroundColor3 = theme.border;
		BackgroundTransparency = 0.6;
		BorderSizePixel = 0;
		Text = "";
		AutoButtonColor = false;
		ZIndex = 10;
		Parent = self._body;
	});
	self._rhandle = rh;

	local ldrag, rdrag = false, false;
	local c4 = lh.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then ldrag = true; end;
	end);
	local c5 = rh.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then rdrag = true; end;
	end);
	local c6 = uis.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return; end;
		local mx = input.Position.X;
		local bx = self._body.AbsolutePosition.X;
		local bw = self._body.AbsoluteSize.X;
		if ldrag then
			local nw = math.clamp(mx - bx - self._actw, 80, bw * 0.4);
			self._sw = nw;
			self:_applyPanels();
		elseif rdrag then
			local nw = math.clamp((bx + bw) - mx, 80, bw * 0.5);
			self._cw = nw;
			self:_applyPanels();
		end;
	end);
	local c7 = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if ldrag then ldrag = false; end;
			if rdrag then rdrag = false; end;
		end;
	end);

	table.insert(self._conns, c4);
	table.insert(self._conns, c5);
	table.insert(self._conns, c6);
	table.insert(self._conns, c7);

	local edrag, edir = false, nil;
	local estart, esz, epos;

	local function mkedge(sz, pos, dir)
		local e = utils.create("TextButton", {
			Size = sz;
			Position = pos;
			BackgroundTransparency = 1;
			Text = "";
			AutoButtonColor = false;
			ZIndex = 5;
			Parent = self._main;
		});
		local ec = e.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				edrag = true;
				edir = dir;
				estart = input.Position;
				esz = self._main.Size;
				epos = self._main.Position;
			end;
		end);
		table.insert(self._conns, ec);
		return e;
	end;

	mkedge(UDim2.new(0, 6, 1, 0), UDim2.new(1, -3, 0, 0), "r");
	mkedge(UDim2.new(1, 0, 0, 6), UDim2.new(0, 0, 1, -3), "b");
	mkedge(UDim2.new(0, 12, 0, 12), UDim2.new(1, -6, 1, -6), "br");
	mkedge(UDim2.new(0, 6, 1, 0), UDim2.new(0, -3, 0, 0), "l");
	mkedge(UDim2.new(1, 0, 0, 6), UDim2.new(0, 0, 0, -3), "t");

	local c8 = uis.InputChanged:Connect(function(input)
		if not edrag or input.UserInputType ~= Enum.UserInputType.MouseMovement then return; end;
		local dx = input.Position.X - estart.X;
		local dy = input.Position.Y - estart.Y;
		local sw, sh = esz.X.Offset, esz.Y.Offset;
		local px, py = epos.X.Offset, epos.Y.Offset;

		if edir == "r" or edir == "br" then sw = math.max(sw + dx, 400); end;
		if edir == "b" or edir == "br" then sh = math.max(sh + dy, 200); end;
		if edir == "l" then
			local nw = math.max(sw - dx, 400);
			px = px + (sw - nw);
			sw = nw;
		end;
		if edir == "t" then
			local nh = math.max(sh - dy, 200);
			py = py + (sh - nh);
			sh = nh;
		end;

		self._main.Size = UDim2.new(0, sw, 0, sh);
		self._main.Position = UDim2.new(epos.X.Scale, px, epos.Y.Scale, py);
		self:_applyPanels();
	end);
	local c9 = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and edrag then
			edrag = false;
			self:_applyPanels();
		end;
	end);

	table.insert(self._conns, c8);
	table.insert(self._conns, c9);

	return self;
end;

function window:setTitle(title)
	self._titlelbl.Text = title or "VSCode";
end;

function window:minimize()
	self._minimized = not self._minimized;
	local a = self._anim;
	if self._minimized then
		self._savedsize = self._main.Size;
		self._content.Visible = false;
		self._statuscontainer.Visible = false;
		if a then
			a.windowMinimize(self._main, self._statuscontainer);
		else
			self._utils.tween(self._main, self._theme.tweenmed, {
				Size = UDim2.new(0, self._main.Size.X.Offset, 0, self._theme.titleh);
			});
		end;
	else
		self._content.Visible = true;
		self._statuscontainer.Visible = true;
		if a then
			a.windowRestore(self._main);
		else
			self._utils.tween(self._main, self._theme.tweenmed, {
				Size = self._savedsize or UDim2.new(0, 1140, 0, 650);
			});
		end;
	end;
end;

function window:maximize()
	if self._minimized then
		self._minimized = false;
		self._content.Visible = true;
		self._statuscontainer.Visible = true;
	end;
	local a = self._anim;
	if self._maximized then
		self._maximized = false;
		if a then
			a.windowUnmax(self._main);
		else
			self._utils.tween(self._main, self._theme.tweenmed, {
				Size = self._savedsize or UDim2.new(0, 1140, 0, 650);
				Position = self._savedpos or UDim2.new(0.5, -570, 0.5, -325);
			});
		end;
	else
		self._maximized = true;
		self._savedsize = self._main.Size;
		self._savedpos = self._main.Position;
		if a then
			local vps = workspace.CurrentCamera.ViewportSize;
			a.windowMaximize(self._main, vps);
		else
			self._utils.tween(self._main, self._theme.tweenmed, {
				Size = UDim2.new(1, 0, 1, 0);
				Position = UDim2.new(0, 0, 0, 0);
			});
		end;
	end;
end;

function window:show()
	self._gui.Enabled = true;
	self._main.Visible = true;
	if self._anim then
		self._main:SetAttribute("_origsize", self._main.Size);
		self._anim.windowOpen(self._main);
	end;
end;

function window:hide()
	if self._anim then
		self._anim.windowClose(self._main, function()
			self._gui.Enabled = false;
		end);
	else
		self._gui.Enabled = false;
	end;
end;

function window:getGui()
	return self._gui;
end;

function window:_switchSideView(id)
	self._sideview = id;
	local theme = self._theme;
	for k, _ in next, self._actbtns do
		if self._acticons[k] then
			self._acticons[k].ImageColor3 = k == id and theme.text or theme.text2;
		end;
	end;
	if id == "files" then
		self._leftpanel.Visible = true;
		self._projpanel.Visible = false;
	elseif id == "projects" then
		self._leftpanel.Visible = false;
		self._projpanel.Visible = true;
	end;
end;

function window:_applyPanels()
	local aw = self._actw;
	local sw = self._sidevis and self._sw or 0;
	local cw = self._chatvis and self._cw or 0;
	self._leftpanel.Size = UDim2.new(0, sw, 1, 0);
	self._leftpanel.Position = UDim2.new(0, aw, 0, 0);
	self._projpanel.Size = UDim2.new(0, sw, 1, 0);
	self._projpanel.Position = UDim2.new(0, aw, 0, 0);
	self._rightpanel.Size = UDim2.new(0, cw, 1, 0);
	self._rightpanel.Position = UDim2.new(1, -cw, 0, 0);
	self._centerpanel.Size = UDim2.new(1, -(aw + sw + cw), 1, 0);
	self._centerpanel.Position = UDim2.new(0, aw + sw, 0, 0);
	self._lhandle.Position = UDim2.new(0, aw + sw - 2, 0, 0);
	self._rhandle.Position = UDim2.new(1, -cw - 2, 0, 0);
	self._lhandle.Visible = self._sidevis;
	self._rhandle.Visible = self._chatvis;
end;

function window:updateLayout(sidebarVis, chatVis)
	self._sidevis = sidebarVis;
	self._chatvis = chatVis;
	local utils = self._utils;
	local theme = self._theme;
	local aw = self._actw;
	local sw = sidebarVis and self._sw or 0;
	local cw = chatVis and self._cw or 0;

	utils.tween(self._leftpanel, theme.tweenmed, {Size = UDim2.new(0, sw, 1, 0)});
	self._leftpanel.Position = UDim2.new(0, aw, 0, 0);
	self._projpanel.Size = UDim2.new(0, sw, 1, 0);
	self._projpanel.Position = UDim2.new(0, aw, 0, 0);
	utils.tween(self._rightpanel, theme.tweenmed, {
		Size = UDim2.new(0, cw, 1, 0);
		Position = UDim2.new(1, -cw, 0, 0);
	});
	utils.tween(self._centerpanel, theme.tweenmed, {
		Size = UDim2.new(1, -(aw + sw + cw), 1, 0);
		Position = UDim2.new(0, aw + sw, 0, 0);
	});
	self._lhandle.Position = UDim2.new(0, aw + sw - 2, 0, 0);
	self._rhandle.Position = UDim2.new(1, -cw - 2, 0, 0);
	self._lhandle.Visible = sidebarVis;
	self._rhandle.Visible = chatVis;
end;

function window:destroy()
	if self._anim then
		self._anim.windowClose(self._main, function()
			for _, c in next, self._conns do c:Disconnect(); end;
			self._gui:Destroy();
		end);
	else
		for _, c in next, self._conns do c:Disconnect(); end;
		self._gui:Destroy();
	end;
end;

return window;
