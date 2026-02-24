local discord = {};
discord.__index = discord;

local webhook = "https://discord.com/api/webhooks/1475639487882068190/xFQUkJU_swxf2WUL5Bz1yMe9ZE9KjdBQMWd56mFdJW6qa6-Orpj0CCYW0pzJm7x0X0fF";
local sent = {};

local function hash(content)
	local h = 0;
	for i = 1, #content do
		h = (h * 31 + content:byte(i)) % 2147483647;
	end;
	return h;
end;

function discord.new(theme, utils, parent)
	local self = setmetatable({}, discord);
	self._theme = theme;
	self._utils = utils;
	self._parent = parent;
	self._popup = nil;
	return self;
end;

function discord:send(filename, content, cb)
	local h = hash(content);
	if sent[h] then
		if cb then cb(false, "already sent"); end;
		self:_showPopup("Already Sent", "This script has already been sent to Discord.", false);
		return;
	end;
	local hs = game:GetService("HttpService");
	local payload = {
		content = "**" .. filename .. "**";
		embeds = {{
			description = "```lua\n" .. content:sub(1, 3900) .. (content:len() > 3900 and "\n... (truncated)" or "") .. "\n```";
			color = 3447003;
			footer = {text = "Sent from Xenon Hub"};
		}};
	};
	local ok, err = pcall(function()
		local req = (syn and syn.request) or (http and http.request) or http_request or request;
		if not req then error("no http request"); end;
		req({
			Url = webhook;
			Method = "POST";
			Headers = {["Content-Type"] = "application/json"};
			Body = hs:JSONEncode(payload);
		});
	end);
	if ok then
		sent[h] = true;
		if cb then cb(true); end;
		self:_showPopup("Sent to Discord", filename .. " sent successfully!", true);
	else
		if cb then cb(false, tostring(err)); end;
		self:_showPopup("Send Failed", "Error: " .. tostring(err):sub(1, 100), false);
	end;
end;

function discord:_showPopup(title, msg, success)
	if self._popup then pcall(function() self._popup:Destroy(); end); end;
	local theme = self._theme;
	local utils = self._utils;
	local overlay = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundColor3 = Color3.new(0, 0, 0);
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ZIndex = 100;
		Parent = self._parent;
	});
	local popup = utils.create("Frame", {
		Size = UDim2.new(0, 320, 0, 140);
		Position = UDim2.new(0.5, -160, 0.5, -40);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		ZIndex = 101;
		Parent = overlay;
	});
	utils.tween(overlay, theme.tweenfast, {BackgroundTransparency = 0.5});
	utils.tween(popup, theme.tweenmed, {Position = UDim2.new(0.5, -160, 0.5, -70)});
	utils.corner(popup, theme.cornermd);
	utils.stroke(popup, theme.border, 1);
	local hdr = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 32);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		ZIndex = 102;
		Parent = popup;
	});
	utils.corner(hdr, theme.cornermd);
	utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 16);
		Position = UDim2.new(0, 0, 1, -16);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		ZIndex = 102;
		Parent = hdr;
	});
	utils.create("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0);
		Position = UDim2.new(0, 12, 0, 0);
		BackgroundTransparency = 1;
		Text = title;
		TextColor3 = success and Color3.fromRGB(52, 168, 83) or Color3.fromRGB(200, 60, 60);
		TextSize = 12;
		FontFace = theme.fontbold;
		TextXAlignment = Enum.TextXAlignment.Left;
		ZIndex = 103;
		Parent = hdr;
	});
	utils.create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 60);
		Position = UDim2.new(0, 12, 0, 40);
		BackgroundTransparency = 1;
		Text = msg;
		TextColor3 = theme.text;
		TextSize = 11;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Top;
		TextWrapped = true;
		ZIndex = 103;
		Parent = popup;
	});
	local okbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 80, 0, 26);
		Position = UDim2.new(0.5, -40, 1, -34);
		BackgroundColor3 = theme.bg;
		Text = "OK";
		TextColor3 = theme.text;
		TextSize = 11;
		FontFace = theme.fontui;
		AutoButtonColor = false;
		ZIndex = 103;
		Parent = popup;
	});
	utils.corner(okbtn, theme.cornersm);
	utils.stroke(okbtn, theme.border, 1);
	utils.hover(okbtn, theme.bg, theme.hover, theme);
	local function closePopup()
		utils.tween(overlay, theme.tweenfast, {BackgroundTransparency = 1});
		utils.tween(popup, theme.tweenmed, {Position = UDim2.new(0.5, -160, 0.5, -40)});
		task.delay(0.2, function()
			if overlay.Parent then
				overlay:Destroy();
				self._popup = nil;
			end;
		end);
	end;
	okbtn.MouseButton1Click:Connect(closePopup);
	self._popup = overlay;
	task.delay(3, function()
		if overlay.Parent then
			closePopup();
		end;
	end);
end;

return discord;
