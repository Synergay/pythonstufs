local topbar = {};
topbar.__index = topbar;

function topbar.new(theme, utils, dropdown, parent, callbacks)
	local self = setmetatable({}, topbar);
	self._theme = theme;
	self._utils = utils;
	self._conns = {};
	self._menus = {};
	self._activemenu = nil;
	self._cbs = callbacks or {};
	self._parent = parent;

	self._frame = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.menuh);
		BackgroundColor3 = theme.title;
		BorderSizePixel = 0;
		Parent = parent;
	});

	local container = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = self._frame;
	});
	utils.list(container, Enum.FillDirection.Horizontal, 0);

	local guiroot = parent;
	while guiroot.Parent and not guiroot:IsA("ScreenGui") do
		guiroot = guiroot.Parent;
	end;
	self._guiroot = guiroot;

	self._overlay = utils.create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Text = "";
		ZIndex = 90;
		Visible = false;
		Parent = guiroot;
	});
	local c = self._overlay.MouseButton1Click:Connect(function()
		self:closeAll();
	end);
	table.insert(self._conns, c);

	-- // build menus
	local menus = {
		{
			name = "File";
			items = {
				{label = "New File"; shortcut = "Ctrl+N"; action = "newfile"};
				{label = "New Window"; shortcut = "Ctrl+Shift+N"; action = "newwindow"};
				{label = "---"};
				{label = "Open File..."; shortcut = "Ctrl+O"; action = "openfile"};
				{label = "Open Folder..."; action = "openfolder"};
				{label = "Close Folder"; action = "closefolder"};
				{label = "---"};
				{label = "Save"; shortcut = "Ctrl+S"; action = "save"};
				{label = "Save As..."; shortcut = "Ctrl+Shift+S"; action = "saveas"};
				{label = "Save All"; shortcut = "Ctrl+Alt+S"; action = "saveall"};
				{label = "Save Project"; action = "saveproject"};
				{label = "---"};
				{label = "Close Tab"; shortcut = "Ctrl+W"; action = "closetab"};
				{label = "Close All Tabs"; action = "closeall"};
				{label = "---"};
				{label = "Execute"; shortcut = "F5"; action = "execute"};
			};
		};
		{
			name = "Edit";
			items = {
				{label = "Undo"; shortcut = "Ctrl+Z"; action = "undo"};
				{label = "Redo"; shortcut = "Ctrl+Y"; action = "redo"};
				{label = "---"};
				{label = "Cut"; shortcut = "Ctrl+X"; action = "cut"};
				{label = "Copy"; shortcut = "Ctrl+C"; action = "copy"};
				{label = "Paste"; shortcut = "Ctrl+V"; action = "paste"};
				{label = "---"};
				{label = "Select All"; shortcut = "Ctrl+A"; action = "selectall"};
				{label = "Find"; shortcut = "Ctrl+F"; action = "find"};
				{label = "Replace"; shortcut = "Ctrl+H"; action = "replace"};
			};
		};
		{
			name = "View";
			items = {
				{label = "Explorer"; shortcut = "Ctrl+B"; action = "toggleexplorer"};
				{label = "Chat Panel"; shortcut = "Ctrl+Shift+C"; action = "togglechat"};
				{label = "---"};
				{label = "Minimap"; action = "minimap"};
				{label = "Word Wrap"; action = "wordwrap"};
				{label = "---"};
				{label = "Zoom In"; shortcut = "Ctrl++"; action = "zoomin"};
				{label = "Zoom Out"; shortcut = "Ctrl+-"; action = "zoomout"};
			};
		};
		{
			name = "Help";
			items = {
				{label = "Documentation"; action = "docs"};
				{label = "Keyboard Shortcuts"; action = "shortcuts"};
				{label = "---"};
				{label = "About"; action = "about"};
			};
		};
	};

	for i, menu in next, menus do
		local btn = utils.create("TextButton", {
			Size = UDim2.new(0, utils.measure(menu.name, 13, Enum.Font.Gotham) + 20, 1, 0);
			BackgroundTransparency = 1;
			Text = menu.name;
			TextColor3 = theme.text2;
			TextSize = 13;
			FontFace = theme.fontui;
			AutoButtonColor = false;
			LayoutOrder = i;
			Parent = container;
		});

		local dd = dropdown.new(theme, utils, guiroot);
		for _, item in next, menu.items do
			if item.label == "---" then
				dd:addItem("---");
			else
				dd:addItem(item.label, item.shortcut, function()
					if self._cbs.onAction then
						self._cbs.onAction(item.action);
					end;
				end);
			end;
		end;

		local c1 = btn.MouseEnter:Connect(function()
			utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 0; BackgroundColor3 = theme.hover});
			if self._activemenu and self._activemenu ~= menu.name then
				self:closeAll();
				self:_openMenu(menu.name, btn, dd);
			end;
		end);
		local c2 = btn.MouseLeave:Connect(function()
			if self._activemenu ~= menu.name then
				utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 1});
			end;
		end);
		local c3 = btn.MouseButton1Click:Connect(function()
			if self._activemenu == menu.name then
				self:closeAll();
			else
				self:closeAll();
				self:_openMenu(menu.name, btn, dd);
			end;
		end);

		table.insert(self._conns, c1);
		table.insert(self._conns, c2);
		table.insert(self._conns, c3);
		self._menus[menu.name] = {btn = btn; dd = dd};
	end;

	return self;
end;

function topbar:_openMenu(name, btn, dd)
	self._activemenu = name;
	self._overlay.Visible = true;
	local root = self._guiroot;
	local rx = root.AbsolutePosition and root.AbsolutePosition.X or 0;
	local ry = root.AbsolutePosition and root.AbsolutePosition.Y or 0;
	local bx = btn.AbsolutePosition.X - rx;
	local by = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y - ry;
	dd:open(UDim2.new(0, bx, 0, by));
end;

function topbar:closeAll()
	self._activemenu = nil;
	self._overlay.Visible = false;
	for _, m in next, self._menus do
		m.dd:close();
		self._utils.tween(m.btn, self._theme.tweenfast, {BackgroundTransparency = 1});
	end;
end;

function topbar:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	for _, m in next, self._menus do m.dd:destroy(); end;
	self._frame:Destroy();
end;

return topbar;
