local ctxmenu = {};
ctxmenu.__index = ctxmenu;

function ctxmenu.new(theme, utils, dropdown, guiroot)
	local self = setmetatable({}, ctxmenu);
	self._theme = theme;
	self._utils = utils;
	self._dd = nil;
	self._guiroot = guiroot;
	self._dropdown = dropdown;
	self._conns = {};

	self._overlay = utils.create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Text = "";
		ZIndex = 89;
		Visible = false;
		Parent = guiroot;
	});

	local c = self._overlay.MouseButton1Click:Connect(function()
		self:close();
	end);
	table.insert(self._conns, c);
	local c2 = self._overlay.MouseButton2Click:Connect(function()
		self:close();
	end);
	table.insert(self._conns, c2);

	return self;
end;

function ctxmenu:show(items, x, y)
	self:close();
	local dd = self._dropdown.new(self._theme, self._utils, self._guiroot);
	self._dd = dd;
	for _, item in next, items do
		if item.label == "---" then
			dd:addItem("---");
		else
			dd:addItem(item.label, item.shortcut, function()
				self:close();
				if item.callback then item.callback(); end;
			end);
		end;
	end;
	self._overlay.Visible = true;
	local rx = self._guiroot.AbsolutePosition and self._guiroot.AbsolutePosition.X or 0;
	local ry = self._guiroot.AbsolutePosition and self._guiroot.AbsolutePosition.Y or 0;
	dd:open(UDim2.new(0, x - rx, 0, y - ry));
end;

function ctxmenu:close()
	self._overlay.Visible = false;
	if self._dd then
		self._dd:close();
		task.delay(0.2, function()
			if self._dd then
				self._dd:destroy();
				self._dd = nil;
			end;
		end);
	end;
end;

function ctxmenu:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	self:close();
	self._overlay:Destroy();
end;

return ctxmenu;
