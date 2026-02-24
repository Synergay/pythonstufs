local ts = game:GetService("TweenService");

local anim = {};

local ei = {
	smooth = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
	snap = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
	bounce = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
	slow = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut);
	fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out);
	elastic = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out);
	fadein = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out);
	fadeout = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In);
	slidein = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out);
	slideout = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In);
	pop = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out);
	shrink = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In);
	breathe = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut);
};
anim.easing = ei;

function anim.tween(obj, info, props)
	local t = ts:Create(obj, info, props);
	t:Play();
	return t;
end;

function anim.windowOpen(main)
	main.Size = UDim2.new(0, 0, 0, 0);
	main.BackgroundTransparency = 1;
	local anchor = main.AnchorPoint;
	main.AnchorPoint = Vector2.new(0.5, 0.5);
	local goal = main:GetAttribute("_origsize") or UDim2.new(0, 900, 0, 560);
	main.Visible = true;
	local t1 = anim.tween(main, ei.pop, {Size = goal; BackgroundTransparency = 0});
	t1.Completed:Connect(function()
		main.AnchorPoint = anchor;
	end);
	return t1;
end;

function anim.windowClose(main, cb)
	local center = UDim2.new(
		main.Position.X.Scale, main.Position.X.Offset + main.Size.X.Offset * 0.5,
		main.Position.Y.Scale, main.Position.Y.Offset + main.Size.Y.Offset * 0.5
	);
	main.AnchorPoint = Vector2.new(0.5, 0.5);
	main.Position = center;
	local t = anim.tween(main, ei.shrink, {
		Size = UDim2.new(0, 0, 0, 0);
		BackgroundTransparency = 1;
	});
	t.Completed:Connect(function()
		if cb then cb(); end;
	end);
	return t;
end;

function anim.windowMinimize(main, statusbar)
	local origsize = main.Size;
	main:SetAttribute("_origsize", origsize);
	local t = anim.tween(main, ei.smooth, {
		Size = UDim2.new(0, origsize.X.Offset, 0, 30);
	});
	return t;
end;

function anim.windowRestore(main)
	local origsize = main:GetAttribute("_origsize") or UDim2.new(0, 900, 0, 560);
	local t = anim.tween(main, ei.bounce, {Size = origsize});
	return t;
end;

function anim.windowMaximize(main, vps)
	main:SetAttribute("_premax", main.Size);
	main:SetAttribute("_premaxpos", main.Position);
	local t = anim.tween(main, ei.smooth, {
		Size = UDim2.new(0, vps.X, 0, vps.Y);
		Position = UDim2.new(0, 0, 0, 0);
	});
	return t;
end;

function anim.windowUnmax(main)
	local sz = main:GetAttribute("_premax") or UDim2.new(0, 900, 0, 560);
	local pos = main:GetAttribute("_premaxpos") or UDim2.new(0.5, -450, 0.5, -280);
	local t = anim.tween(main, ei.smooth, {Size = sz; Position = pos});
	return t;
end;

function anim.panelSlideIn(panel, dir)
	dir = dir or "left";
	panel.Visible = true;
	if dir == "left" then
		local orig = panel.Position;
		panel.Position = UDim2.new(orig.X.Scale, orig.X.Offset - 40, orig.Y.Scale, orig.Y.Offset);
		panel.BackgroundTransparency = 1;
		anim.tween(panel, ei.slidein, {Position = orig; BackgroundTransparency = 0});
	elseif dir == "right" then
		local orig = panel.Position;
		panel.Position = UDim2.new(orig.X.Scale, orig.X.Offset + 40, orig.Y.Scale, orig.Y.Offset);
		panel.BackgroundTransparency = 1;
		anim.tween(panel, ei.slidein, {Position = orig; BackgroundTransparency = 0});
	elseif dir == "up" then
		local orig = panel.Position;
		panel.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset - 30);
		panel.BackgroundTransparency = 1;
		anim.tween(panel, ei.slidein, {Position = orig; BackgroundTransparency = 0});
	elseif dir == "down" then
		local orig = panel.Position;
		panel.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset + 30);
		panel.BackgroundTransparency = 1;
		anim.tween(panel, ei.slidein, {Position = orig; BackgroundTransparency = 0});
	end;
end;

function anim.panelSlideOut(panel, dir, cb)
	dir = dir or "left";
	local dx, dy = 0, 0;
	if dir == "left" then dx = -40;
	elseif dir == "right" then dx = 40;
	elseif dir == "up" then dy = -30;
	elseif dir == "down" then dy = 30;
	end;
	local goal = UDim2.new(
		panel.Position.X.Scale, panel.Position.X.Offset + dx,
		panel.Position.Y.Scale, panel.Position.Y.Offset + dy
	);
	local t = anim.tween(panel, ei.slideout, {Position = goal; BackgroundTransparency = 1});
	t.Completed:Connect(function()
		panel.Visible = false;
		panel.Position = UDim2.new(
			goal.X.Scale, goal.X.Offset - dx,
			goal.Y.Scale, goal.Y.Offset - dy
		);
		panel.BackgroundTransparency = 0;
		if cb then cb(); end;
	end);
	return t;
end;

function anim.fadeIn(obj, dur)
	obj.Visible = true;
	if obj:IsA("GuiObject") then
		obj.BackgroundTransparency = 1;
		anim.tween(obj, dur and TweenInfo.new(dur, Enum.EasingStyle.Sine) or ei.fadein, {
			BackgroundTransparency = 0;
		});
	end;
	for _, ch in next, obj:GetDescendants() do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("TextBox") then
			ch.TextTransparency = 1;
			anim.tween(ch, dur and TweenInfo.new(dur, Enum.EasingStyle.Sine) or ei.fadein, {TextTransparency = 0});
		elseif ch:IsA("ImageLabel") or ch:IsA("ImageButton") then
			ch.ImageTransparency = 1;
			anim.tween(ch, dur and TweenInfo.new(dur, Enum.EasingStyle.Sine) or ei.fadein, {ImageTransparency = 0});
		end;
	end;
end;

function anim.fadeOut(obj, dur, cb)
	local info = dur and TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.In) or ei.fadeout;
	local t;
	if obj:IsA("GuiObject") then
		t = anim.tween(obj, info, {BackgroundTransparency = 1});
	end;
	for _, ch in next, obj:GetDescendants() do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("TextBox") then
			anim.tween(ch, info, {TextTransparency = 1});
		elseif ch:IsA("ImageLabel") or ch:IsA("ImageButton") then
			anim.tween(ch, info, {ImageTransparency = 1});
		end;
	end;
	if t then
		t.Completed:Connect(function()
			obj.Visible = false;
			if cb then cb(); end;
		end);
	end;
	return t;
end;

function anim.tabOpen(frame)
	frame.Size = UDim2.new(0, 0, 1, 0);
	frame.BackgroundTransparency = 0.5;
	local w = frame:GetAttribute("_tabw") or 120;
	anim.tween(frame, ei.snap, {Size = UDim2.new(0, w, 1, 0); BackgroundTransparency = 0});
end;

function anim.tabClose(frame, cb)
	local t = anim.tween(frame, ei.fast, {
		Size = UDim2.new(0, 0, 1, 0);
		BackgroundTransparency = 1;
	});
	t.Completed:Connect(function()
		if cb then cb(); end;
	end);
	return t;
end;

function anim.dropdownOpen(frame)
	frame.Visible = true;
	frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 0);
	frame.BackgroundTransparency = 0.3;
	local h = frame:GetAttribute("_ddh") or 200;
	anim.tween(frame, ei.snap, {
		Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, h);
		BackgroundTransparency = 0;
	});
end;

function anim.dropdownClose(frame, cb)
	local t = anim.tween(frame, ei.fast, {
		Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 0);
		BackgroundTransparency = 0.3;
	});
	t.Completed:Connect(function()
		frame.Visible = false;
		if cb then cb(); end;
	end);
	return t;
end;

function anim.ctxOpen(frame)
	frame.Visible = true;
	local origsize = frame.Size;
	frame.Size = UDim2.new(0, origsize.X.Offset, 0, 0);
	frame.BackgroundTransparency = 0.2;
	anim.tween(frame, ei.snap, {Size = origsize; BackgroundTransparency = 0});
end;

function anim.ctxClose(frame, cb)
	local t = anim.tween(frame, ei.fast, {
		Size = UDim2.new(0, frame.Size.X.Offset, 0, 0);
		BackgroundTransparency = 0.2;
	});
	t.Completed:Connect(function()
		frame.Visible = false;
		if cb then cb(); end;
	end);
	return t;
end;

function anim.shake(obj, intensity, dur)
	intensity = intensity or 4;
	dur = dur or 0.3;
	local orig = obj.Position;
	local steps = math.floor(dur / 0.03);
	task.spawn(function()
		for i = 1, steps do
			local ox = math.random(-intensity, intensity);
			local oy = math.random(-intensity, intensity);
			local factor = 1 - (i / steps);
			obj.Position = UDim2.new(
				orig.X.Scale, orig.X.Offset + ox * factor,
				orig.Y.Scale, orig.Y.Offset + oy * factor
			);
			task.wait(0.03);
		end;
		obj.Position = orig;
	end);
end;

function anim.pulse(obj, scale, dur)
	scale = scale or 1.05;
	dur = dur or 0.3;
	local orig = obj.Size;
	local pw = orig.X.Offset * scale;
	local ph = orig.Y.Offset * scale;
	local dx = (pw - orig.X.Offset) * 0.5;
	local dy = (ph - orig.Y.Offset) * 0.5;
	local big = UDim2.new(orig.X.Scale, pw, orig.Y.Scale, ph);
	local opos = obj.Position;
	local bpos = UDim2.new(opos.X.Scale, opos.X.Offset - dx, opos.Y.Scale, opos.Y.Offset - dy);
	local t1 = anim.tween(obj, TweenInfo.new(dur * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = big; Position = bpos;
	});
	t1.Completed:Connect(function()
		anim.tween(obj, TweenInfo.new(dur * 0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = orig; Position = opos;
		});
	end);
end;

function anim.ripple(btn, theme)
	local circle = Instance.new("Frame");
	circle.Size = UDim2.new(0, 0, 0, 0);
	circle.Position = UDim2.new(0.5, 0, 0.5, 0);
	circle.AnchorPoint = Vector2.new(0.5, 0.5);
	circle.BackgroundColor3 = Color3.new(1, 1, 1);
	circle.BackgroundTransparency = 0.7;
	circle.BorderSizePixel = 0;
	circle.ZIndex = btn.ZIndex + 1;
	circle.Parent = btn;
	local cr = Instance.new("UICorner");
	cr.CornerRadius = UDim.new(1, 0);
	cr.Parent = circle;
	local sz = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2;
	local t = anim.tween(circle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, sz, 0, sz);
		BackgroundTransparency = 1;
	});
	t.Completed:Connect(function()
		circle:Destroy();
	end);
end;

function anim.typewriter(lbl, text, speed)
	speed = speed or 0.02;
	lbl.Text = "";
	task.spawn(function()
		for i = 1, #text do
			lbl.Text = text:sub(1, i);
			task.wait(speed);
		end;
	end);
end;

function anim.flash(obj, clr, dur)
	clr = clr or Color3.new(1, 1, 1);
	dur = dur or 0.3;
	local orig = obj.BackgroundColor3;
	anim.tween(obj, TweenInfo.new(dur * 0.3, Enum.EasingStyle.Quad), {BackgroundColor3 = clr});
	task.delay(dur * 0.3, function()
		anim.tween(obj, TweenInfo.new(dur * 0.7, Enum.EasingStyle.Quad), {BackgroundColor3 = orig});
	end);
end;

function anim.stagger(items, propfn, delay_)
	delay_ = delay_ or 0.03;
	for i, item in next, items do
		task.delay((i - 1) * delay_, function()
			local props = propfn(item, i);
			if props then
				anim.tween(item, ei.snap, props);
			end;
		end);
	end;
end;

function anim.notifIn(frame, dir)
	dir = dir or "right";
	frame.Visible = true;
	if dir == "right" then
		local orig = frame.Position;
		frame.Position = UDim2.new(orig.X.Scale, orig.X.Offset + 60, orig.Y.Scale, orig.Y.Offset);
		frame.BackgroundTransparency = 0.5;
		anim.tween(frame, ei.bounce, {Position = orig; BackgroundTransparency = 0});
	elseif dir == "top" then
		local orig = frame.Position;
		frame.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale, orig.Y.Offset - 40);
		frame.BackgroundTransparency = 0.5;
		anim.tween(frame, ei.bounce, {Position = orig; BackgroundTransparency = 0});
	end;
end;

function anim.notifOut(frame, dir, cb)
	dir = dir or "right";
	local dx, dy = 0, 0;
	if dir == "right" then dx = 60;
	elseif dir == "top" then dy = -40;
	end;
	local goal = UDim2.new(
		frame.Position.X.Scale, frame.Position.X.Offset + dx,
		frame.Position.Y.Scale, frame.Position.Y.Offset + dy
	);
	local t = anim.tween(frame, ei.slideout, {Position = goal; BackgroundTransparency = 1});
	t.Completed:Connect(function()
		frame.Visible = false;
		if cb then cb(); end;
	end);
	return t;
end;

return anim;
