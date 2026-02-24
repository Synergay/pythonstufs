local ts = game:GetService("TweenService");
local txts = game:GetService("TextService");

local utils = {};

function utils.create(cls, props, children)
	local inst = Instance.new(cls);
	for k, v in next, props do
		inst[k] = v;
	end;
	if children then
		for _, c in next, children do
			c.Parent = inst;
		end;
	end;
	return inst;
end;

function utils.tween(obj, info, props)
	local t = ts:Create(obj, info, props);
	t:Play();
	return t;
end;

function utils.measure(txt, sz, font)
	local ok, res = pcall(function()
		return txts:GetTextSize(txt, sz, font or Enum.Font.RobotoMono, Vector2.new(math.huge, math.huge));
	end);
	return ok and res.X or (#txt * sz * 0.6);
end;

function utils.truncate(txt, maxw, sz, font)
	local w = utils.measure(txt, sz, font);
	if w <= maxw then return txt, false; end;
	for i = #txt, 1, -1 do
		local cut = txt:sub(1, i) .. "...";
		if utils.measure(cut, sz, font) <= maxw then
			return cut, true;
		end;
	end;
	return "...", true;
end;

function utils.corner(parent, radius)
	return utils.create("UICorner", {CornerRadius = radius; Parent = parent});
end;

function utils.stroke(parent, clr, thick)
	return utils.create("UIStroke", {
		Color = clr;
		Thickness = thick or 1;
		Parent = parent;
	});
end;

function utils.pad(parent, t, b, l, r)
	return utils.create("UIPadding", {
		PaddingTop = UDim.new(0, t or 0);
		PaddingBottom = UDim.new(0, b or 0);
		PaddingLeft = UDim.new(0, l or 0);
		PaddingRight = UDim.new(0, r or 0);
		Parent = parent;
	});
end;

function utils.list(parent, dir, pad, halign, valign)
	return utils.create("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Horizontal;
		Padding = UDim.new(0, pad or 0);
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left;
		VerticalAlignment = valign or Enum.VerticalAlignment.Center;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = parent;
	});
end;

function utils.ripple(btn, clr)
	local r = utils.create("Frame", {
		Size = UDim2.new(0, 0, 0, 0);
		Position = UDim2.new(0.5, 0, 0.5, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		BackgroundColor3 = clr or Color3.new(1, 1, 1);
		BackgroundTransparency = 0.7;
		Parent = btn;
	});
	utils.corner(r, UDim.new(1, 0));
	local t = utils.tween(r, TweenInfo.new(0.3), {
		Size = UDim2.new(1.5, 0, 1.5, 0);
		BackgroundTransparency = 1;
	});
	t.Completed:Connect(function() r:Destroy(); end);
end;

function utils.hover(btn, normal, hovered, theme)
	btn.MouseEnter:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundColor3 = hovered});
	end);
	btn.MouseLeave:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundColor3 = normal});
	end);
end;

function utils.icon(parent, img, sz, clr, props)
	local p = {
		Size = UDim2.new(0, sz or 16, 0, sz or 16);
		BackgroundTransparency = 1;
		Image = img;
		ImageColor3 = clr or Color3.new(1, 1, 1);
		ScaleType = Enum.ScaleType.Fit;
		Parent = parent;
	};
	if props then for k, v in next, props do p[k] = v; end; end;
	return utils.create("ImageLabel", p);
end;

function utils.iconbtn(parent, img, sz, clr, props)
	local p = {
		Size = UDim2.new(0, sz or 20, 0, sz or 20);
		BackgroundTransparency = 1;
		Image = img;
		ImageColor3 = clr or Color3.new(1, 1, 1);
		ScaleType = Enum.ScaleType.Fit;
		AutoButtonColor = false;
		Parent = parent;
	};
	if props then for k, v in next, props do p[k] = v; end; end;
	return utils.create("ImageButton", p);
end;

function utils.uid()
	return game:GetService("HttpService"):GenerateGUID(false):sub(1, 8);
end;

return utils;
