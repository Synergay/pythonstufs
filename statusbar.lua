local statusbar = {};
statusbar.__index = statusbar;

function statusbar.new(theme, utils, parent, icons)
	local self = setmetatable({}, statusbar);
	self._theme = theme;
	self._utils = utils;
	self._icons = icons or {};

	self._frame = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.statush);
		BackgroundColor3 = theme.accent2;
		BorderSizePixel = 0;
		Parent = parent;
	});

	local left = utils.create("Frame", {
		Size = UDim2.new(0.5, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = self._frame;
	});
	utils.list(left, Enum.FillDirection.Horizontal, 12);
	utils.pad(left, 0, 0, 10, 0);

	local branchfrm = utils.create("Frame", {
		Size = UDim2.new(0, 80, 1, 0);
		BackgroundTransparency = 1;
		LayoutOrder = 1;
		Parent = left;
	});
	utils.icon(branchfrm, icons and icons.gitbranch or "", 12, Color3.new(1,1,1), {
		Position = UDim2.new(0, 0, 0.5, -6);
	});
	self._branch = utils.create("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0);
		Position = UDim2.new(0, 16, 0, 0);
		BackgroundTransparency = 1;
		Text = "main";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = branchfrm;
	});

	local errfrm = utils.create("Frame", {
		Size = UDim2.new(0, 70, 1, 0);
		BackgroundTransparency = 1;
		LayoutOrder = 2;
		Parent = left;
	});
	self._errico = utils.icon(errfrm, icons and icons.alertcircle or "", 12, Color3.new(1,1,1), {
		Position = UDim2.new(0, 0, 0.5, -6);
	});
	self._errlbl = utils.create("TextLabel", {
		Size = UDim2.new(0, 14, 1, 0);
		Position = UDim2.new(0, 14, 0, 0);
		BackgroundTransparency = 1;
		Text = "0";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = errfrm;
	});
	self._warnico = utils.icon(errfrm, icons and icons.alerttri or "", 12, Color3.new(1,1,1), {
		Position = UDim2.new(0, 32, 0.5, -6);
	});
	self._warnlbl = utils.create("TextLabel", {
		Size = UDim2.new(0, 14, 1, 0);
		Position = UDim2.new(0, 46, 0, 0);
		BackgroundTransparency = 1;
		Text = "0";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = errfrm;
	});

	local right = utils.create("Frame", {
		Size = UDim2.new(0.5, 0, 1, 0);
		Position = UDim2.new(0.5, 0, 0, 0);
		BackgroundTransparency = 1;
		Parent = self._frame;
	});
	utils.list(right, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Right);
	utils.pad(right, 0, 0, 0, 10);

	self._lang = utils.create("TextLabel", {
		Size = UDim2.new(0, 40, 1, 0);
		BackgroundTransparency = 1;
		Text = "Luau";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		LayoutOrder = 5;
		Parent = right;
	});

	self._encoding = utils.create("TextLabel", {
		Size = UDim2.new(0, 40, 1, 0);
		BackgroundTransparency = 1;
		Text = "UTF-8";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		LayoutOrder = 4;
		Parent = right;
	});

	self._line = utils.create("TextLabel", {
		Size = UDim2.new(0, 60, 1, 0);
		BackgroundTransparency = 1;
		Text = "Ln 1, Col 1";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		LayoutOrder = 3;
		Parent = right;
	});

	self._spaces = utils.create("TextLabel", {
		Size = UDim2.new(0, 55, 1, 0);
		BackgroundTransparency = 1;
		Text = "Spaces: 4";
		TextColor3 = Color3.new(1, 1, 1);
		TextSize = 12;
		FontFace = theme.fontui;
		LayoutOrder = 2;
		Parent = right;
	});

	return self;
end;

function statusbar:setLang(lang)
	self._lang.Text = lang or "Luau";
end;

function statusbar:setLine(ln, col)
	self._line.Text = ("Ln %d, Col %d"):format(ln or 1, col or 1);
end;

function statusbar:setBranch(name)
	self._branch.Text = name or "main";
end;

function statusbar:setErrors(errs, warns)
	self._errlbl.Text = tostring(errs or 0);
	self._warnlbl.Text = tostring(warns or 0);
end;

function statusbar:destroy()
	self._frame:Destroy();
end;

return statusbar;
