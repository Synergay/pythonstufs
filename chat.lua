local chat = {};
chat.__index = chat;

local function parseseg(text)
	local segs = {};
	local last = 1;
	while true do
		local s, e, lang, code = text:find("```(%w*)\n(.-)```", last);
		if not s then break; end;
		if s > last then
			local before = text:sub(last, s - 1);
			if before:match("%S") then table.insert(segs, {t = "text"; c = before}); end;
		end;
		table.insert(segs, {t = "code"; lang = lang or ""; c = code});
		last = e + 1;
	end;
	if last <= #text then
		local rem = text:sub(last);
		if rem:match("%S") then table.insert(segs, {t = "text"; c = rem}); end;
	end;
	if #segs == 0 then table.insert(segs, {t = "text"; c = text}); end;
	return segs;
end;

local function richify(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;");
	s = s:gsub("`([^`]+)`", '<font color="#ce9178">%1</font>');
	s = s:gsub("%*%*(.-)%*%*", "<b>%1</b>");
	s = s:gsub("%*(.-)%*", "<i>%1</i>");
	s = s:gsub("__(.-)__", "<b>%1</b>");
	local lines = s:split("\n");
	for idx, ln in next, lines do
		ln = ln:match("^%s*(.-)%s*$");
		if ln:match("^###%s+(.+)") then
			lines[idx] = "<b>" .. ln:match("^###%s+(.+)") .. "</b>";
		elseif ln:match("^##%s+(.+)") then
			lines[idx] = '<b><font size="15">' .. ln:match("^##%s+(.+)") .. "</font></b>";
		elseif ln:match("^#%s+(.+)") then
			lines[idx] = '<b><font size="16">' .. ln:match("^#%s+(.+)") .. "</font></b>";
		elseif ln:match("^[%-*]%s+(.+)") then
			lines[idx] = "  \u{2022}  " .. ln:match("^[%-*]%s+(.+)");
		elseif ln:match("^(%d+)%.%s+(.+)") then
			local num, rest = ln:match("^(%d+)%.%s+(.+)");
			lines[idx] = "  " .. num .. ".  " .. rest;
		end;
	end;
	return table.concat(lines, "<br/>");
end;

function chat.new(theme, utils, dropdown, guiroot, parent, callbacks, icons)
	local self = setmetatable({}, chat);
	self._theme = theme;
	self._utils = utils;
	self._conns = {};
	self._msgs = {};
	self._msgdata = {};
	self._sessname = "default";
	self._cbs = callbacks or {};
	self._visible = true;
	self._agent = false;
	self._attached = {};
	self._dropdown = dropdown;
	self._guiroot = guiroot;

	self._frame = utils.create("Frame", {
		Size = UDim2.new(0, theme.chatw, 1, 0);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		ClipsDescendants = true;
		Parent = parent;
	});

	utils.create("Frame", {
		Size = UDim2.new(0, 1, 1, 0);
		BackgroundColor3 = theme.border;
		BorderSizePixel = 0;
		Parent = self._frame;
	});

	local header = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 36);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Parent = self._frame;
	});

	utils.create("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0);
		Position = UDim2.new(0, 12, 0, 0);
		BackgroundTransparency = 1;
		Text = "CHAT";
		TextColor3 = theme.text2;
		TextSize = 11;
		FontFace = theme.fontbold;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = header;
	});

	local sessbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 70, 0, 20);
		Position = UDim2.new(1, -78, 0.5, -10);
		BackgroundTransparency = 1;
		Text = "Sessions";
		TextColor3 = theme.text2;
		TextSize = 11;
		FontFace = theme.fontui;
		AutoButtonColor = false;
		Parent = header;
	});
	utils.hover(sessbtn, theme.bg2, theme.hover, theme);

	local sessdd = dropdown.new(theme, utils, guiroot, 160);
	sessdd:addItem("New Session", nil, function()
		self._sessname = "session-" .. os.time();
		self:clearMessages();
		if self._cbs.onNewSession then self._cbs.onNewSession(); end;
	end);
	sessdd:addItem("Save Session", nil, function()
		self:_promptSessName(function(n)
			self._sessname = n;
			if self._cbs.onSaveSession then self._cbs.onSaveSession(n); end;
		end);
	end);
	sessdd:addItem("---");
	sessdd:addItem("Load Session", nil, function()
		self:_promptSessName(function(n)
			self._sessname = n;
			if self._cbs.onLoadSession then self._cbs.onLoadSession(n); end;
		end);
	end);
	sessdd:addItem("Rename Session", nil, function()
		local old = self._sessname;
		self:_promptSessName(function(n)
			if self._cbs.onRenameSession then self._cbs.onRenameSession(old, n); end;
			self._sessname = n;
		end);
	end);
	self._sessdd = sessdd;

	local cs = sessbtn.MouseButton1Click:Connect(function()
		local bx = sessbtn.AbsolutePosition.X;
		local by = sessbtn.AbsolutePosition.Y + sessbtn.AbsoluteSize.Y;
		local rx = guiroot.AbsolutePosition and guiroot.AbsolutePosition.X or 0;
		local ry = guiroot.AbsolutePosition and guiroot.AbsolutePosition.Y or 0;
		sessdd:toggle(UDim2.new(0, bx - rx, 0, by - ry));
	end);
	table.insert(self._conns, cs);

	utils.create("Frame", {
		Size = UDim2.new(1, -16, 0, 1);
		Position = UDim2.new(0, 8, 0, 35);
		BackgroundColor3 = theme.border;
		BorderSizePixel = 0;
		Parent = self._frame;
	});

	local toolbar = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 26);
		Position = UDim2.new(0, 0, 0, 37);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		Parent = self._frame;
	});

	local modelbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 120, 0, 18);
		Position = UDim2.new(0, 6, 0.5, -9);
		BackgroundColor3 = theme.bg;
		Text = "";
		AutoButtonColor = false;
		Parent = toolbar;
	});
	utils.corner(modelbtn, theme.cornersm);
	utils.stroke(modelbtn, theme.border, 1);

	self._modellbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -6, 1, 0);
		Position = UDim2.new(0, 6, 0, 0);
		BackgroundTransparency = 1;
		Text = "select model";
		TextColor3 = theme.text2;
		TextSize = 10;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.AtEnd;
		Parent = modelbtn;
	});

	self._modeldd = dropdown.new(theme, utils, guiroot, 180);

	local cmbtn = modelbtn.MouseButton1Click:Connect(function()
		local bx = modelbtn.AbsolutePosition.X;
		local by = modelbtn.AbsolutePosition.Y + modelbtn.AbsoluteSize.Y;
		local rx = guiroot.AbsolutePosition and guiroot.AbsolutePosition.X or 0;
		local ry = guiroot.AbsolutePosition and guiroot.AbsolutePosition.Y or 0;
		self._modeldd:toggle(UDim2.new(0, bx - rx, 0, by - ry));
	end);
	table.insert(self._conns, cmbtn);

	self._planner = false;
	self._plannerbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 52, 0, 18);
		Position = UDim2.new(1, -120, 0.5, -9);
		BackgroundColor3 = theme.bg;
		Text = "Plan";
		TextColor3 = theme.text2;
		TextSize = 10;
		FontFace = theme.fontui;
		AutoButtonColor = false;
		Parent = toolbar;
	});
	utils.corner(self._plannerbtn, theme.cornersm);
	utils.stroke(self._plannerbtn, theme.border, 1);

	local cpbtn = self._plannerbtn.MouseButton1Click:Connect(function()
		self._planner = not self._planner;
		if self._planner then
			self._plannerbtn.BackgroundColor3 = Color3.fromRGB(180, 120, 40);
			self._plannerbtn.TextColor3 = Color3.new(1, 1, 1);
		else
			self._plannerbtn.BackgroundColor3 = theme.bg;
			self._plannerbtn.TextColor3 = theme.text2;
		end;
	end);
	table.insert(self._conns, cpbtn);

	self._agentbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 52, 0, 18);
		Position = UDim2.new(1, -64, 0.5, -9);
		BackgroundColor3 = theme.bg;
		Text = "Agent";
		TextColor3 = theme.text2;
		TextSize = 10;
		FontFace = theme.fontui;
		AutoButtonColor = false;
		Parent = toolbar;
	});
	utils.corner(self._agentbtn, theme.cornersm);
	utils.stroke(self._agentbtn, theme.border, 1);

	local cabtn = self._agentbtn.MouseButton1Click:Connect(function()
		self._agent = not self._agent;
		if self._agent then
			self._agentbtn.BackgroundColor3 = theme.accent;
			self._agentbtn.TextColor3 = Color3.new(1, 1, 1);
		else
			self._agentbtn.BackgroundColor3 = theme.bg;
			self._agentbtn.TextColor3 = theme.text2;
			self._attached = {};
			self:_refreshAttach();
		end;
	end);
	table.insert(self._conns, cabtn);

	self._attachbar = utils.create("Frame", {
		Size = UDim2.new(1, -12, 0, 18);
		Position = UDim2.new(0, 6, 1, -96);
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		Visible = false;
		Parent = self._frame;
	});
	utils.list(self._attachbar, Enum.FillDirection.Horizontal, 4);
	self._attachtags = {};

	self._msgscroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -140);
		Position = UDim2.new(0, 4, 0, 64);
		BackgroundTransparency = 1;
		ScrollBarThickness = 3;
		ScrollBarImageColor3 = theme.scrollbar;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		Parent = self._frame;
	});
	utils.list(self._msgscroll, Enum.FillDirection.Vertical, 6);
	utils.pad(self._msgscroll, 6, 6, 4, 4);

	self:_addMsg("ai", "what is my purpose?");

	local qabar = utils.create("Frame", {
		Size = UDim2.new(1, -12, 0, 20);
		Position = UDim2.new(0, 6, 1, -74);
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		Parent = self._frame;
	});
	utils.list(qabar, Enum.FillDirection.Horizontal, 3);
	local qactions = {
		{label = "Explain"; cmd = "/explain"};
		{label = "Optimize"; cmd = "/optimize"};
		{label = "Fix"; cmd = "/fix"};
		{label = "Scan"; cmd = "/scan"};
		{label = "Doc"; cmd = "/doc"};
	};
	for _, qa in next, qactions do
		local tw = utils.measure(qa.label, 9, Enum.Font.Gotham) + 12;
		local qbtn = utils.create("TextButton", {
			Size = UDim2.new(0, tw, 0, 18);
			BackgroundColor3 = theme.bg;
			Text = qa.label;
			TextColor3 = theme.text2;
			TextSize = 9;
			FontFace = theme.fontui;
			AutoButtonColor = false;
			Parent = qabar;
		});
		utils.corner(qbtn, theme.cornersm);
		utils.stroke(qbtn, theme.border, 1);
		local qcmd = qa.cmd;
		qbtn.MouseButton1Click:Connect(function()
			self._inputbox.Text = "";
			self:_addMsg("user", qcmd);
			if self._cbs.onSend then self._cbs.onSend(qcmd); end;
		end);
	end;

	local inputarea = utils.create("Frame", {
		Size = UDim2.new(1, -12, 0, 44);
		Position = UDim2.new(0, 6, 1, -50);
		BackgroundColor3 = theme.input;
		BorderSizePixel = 0;
		Parent = self._frame;
	});
	utils.corner(inputarea, theme.corner);
	utils.stroke(inputarea, theme.border, 1);

	self._inputbox = utils.create("TextBox", {
		Size = UDim2.new(1, -40, 1, 0);
		Position = UDim2.new(0, 8, 0, 0);
		BackgroundTransparency = 1;
		Text = "";
		PlaceholderText = "ask anything...";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		Parent = inputarea;
	});

	self._fileac = utils.create("Frame", {
		Size = UDim2.new(0, 200, 0, 0);
		Position = UDim2.new(0, 8, 0, -10);
		AnchorPoint = Vector2.new(0, 1);
		BackgroundColor3 = theme.bg3;
		BorderSizePixel = 0;
		Visible = false;
		ZIndex = 100;
		ClipsDescendants = true;
		Parent = inputarea;
	});
	utils.corner(self._fileac, theme.cornersm);
	utils.stroke(self._fileac, theme.border, 1);

	self._fileacscroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		ScrollBarThickness = 3;
		ScrollBarImageColor3 = theme.scrollbar;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		ZIndex = 101;
		Parent = self._fileac;
	});
	utils.list(self._fileacscroll, Enum.FillDirection.Vertical, 0);

	local function updateFileAc()
		local txt = self._inputbox.Text;
		local atpos = txt:reverse():find("@");
		if not atpos then
			self._fileac.Visible = false;
			return;
		end;
		local atidx = #txt - atpos + 1;
		local query = txt:sub(atidx + 1):lower();
		for _, ch in next, self._fileacscroll:GetChildren() do
			if ch:IsA("TextButton") then ch:Destroy(); end;
		end;
		local matches = {};
		if self._cbs.onGetFiles then
			local files = self._cbs.onGetFiles();
			for _, f in next, files do
				if query == "" or f:lower():find(query, 1, true) then
					table.insert(matches, f);
				end;
			end;
		end;
		if #matches == 0 then
			self._fileac.Visible = false;
			return;
		end;
		local h = math.min(#matches * 24, 200);
		self._fileac.Size = UDim2.new(0, 200, 0, h);
		self._fileac.Visible = true;
		for i, fname in next, matches do
			local btn = utils.create("TextButton", {
				Size = UDim2.new(1, 0, 0, 24);
				BackgroundColor3 = theme.bg;
				Text = "";
				AutoButtonColor = false;
				LayoutOrder = i;
				ZIndex = 102;
				Parent = self._fileacscroll;
			});
			utils.hover(btn, theme.bg, theme.hover, theme);
			utils.create("ImageLabel", {
				Size = UDim2.new(0, 14, 0, 14);
				Position = UDim2.new(0, 6, 0.5, -7);
				BackgroundTransparency = 1;
				Image = "rbxassetid://7733717447";
				ImageColor3 = theme.accent;
				ZIndex = 103;
				Parent = btn;
			});
			utils.create("TextLabel", {
				Size = UDim2.new(1, -26, 1, 0);
				Position = UDim2.new(0, 24, 0, 0);
				BackgroundTransparency = 1;
				Text = fname;
				TextColor3 = theme.text;
				TextSize = 12;
				FontFace = theme.fontui;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextTruncate = Enum.TextTruncate.AtEnd;
				ZIndex = 103;
				Parent = btn;
			});
			local clickfn = fname;
			btn.MouseButton1Click:Connect(function()
				self._fileac.Visible = false;
				local newtxt = txt:sub(1, atidx - 1) .. "@" .. clickfn .. " ";
				self._inputbox.Text = newtxt;
				if self._cbs.onAttachFile then
					self._cbs.onAttachFile(clickfn);
				end;
				self._inputbox:CaptureFocus();
			end);
			if i == 1 then
				btn.BackgroundColor3 = theme.hover;
			end;
		end;
		self._fileacscroll.CanvasSize = UDim2.new(0, 0, 0, #matches * 24);
	end;

	local c3 = self._inputbox:GetPropertyChangedSignal("Text"):Connect(updateFileAc);
	table.insert(self._conns, c3);

	local sendbtn = utils.create("TextButton", {
		Size = UDim2.new(0, 28, 0, 28);
		Position = UDim2.new(1, -34, 0.5, -14);
		BackgroundColor3 = theme.accent;
		Text = "";
		AutoButtonColor = false;
		Parent = inputarea;
	});
	utils.icon(sendbtn, icons and icons.send or "", 14, Color3.new(1,1,1), {
		Position = UDim2.new(0.5, -7, 0.5, -7);
	});
	utils.corner(sendbtn, theme.cornersm);
	utils.hover(sendbtn, theme.accent, theme.accent2, theme);

	local function send()
		local txt = self._inputbox.Text;
		if txt == "" then return; end;
		self._inputbox.Text = "";
		self:_addMsg("user", txt);
		if self._cbs.onSend then self._cbs.onSend(txt); end;
	end;

	local c1 = sendbtn.MouseButton1Click:Connect(send);
	local c2 = self._inputbox.FocusLost:Connect(function(enter)
		if enter then send(); end;
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);

	return self;
end;

function chat:_addMsg(role, text)
	local theme = self._theme;
	local utils = self._utils;
	local isuser = role == "user";
	local msgf = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0);
		BackgroundTransparency = 1;
		AutomaticSize = Enum.AutomaticSize.Y;
		LayoutOrder = #self._msgs + 1;
		Parent = self._msgscroll;
	});
	utils.list(msgf, Enum.FillDirection.Vertical, 4);
	utils.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16);
		BackgroundTransparency = 1;
		Text = isuser and "You" or "AI";
		TextColor3 = isuser and theme.chatuser or theme.chatai;
		TextSize = 12;
		FontFace = theme.fontbold;
		TextXAlignment = Enum.TextXAlignment.Left;
		LayoutOrder = 1;
		Parent = msgf;
	});
	if isuser then
		utils.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 0);
			BackgroundTransparency = 1;
			Text = text;
			TextColor3 = theme.text;
			TextSize = 13;
			FontFace = theme.fontui;
			TextXAlignment = Enum.TextXAlignment.Left;
			TextWrapped = true;
			AutomaticSize = Enum.AutomaticSize.Y;
			LayoutOrder = 2;
			Parent = msgf;
		});
	else
		self:_buildContent(msgf, text, 2);
	end;
	table.insert(self._msgs, msgf);
	table.insert(self._msgdata, {role = role; text = text});
	for _, ch in next, msgf:GetDescendants() do
		if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("Frame") then
			if ch.BackgroundTransparency < 1 then
				local orig = ch.BackgroundTransparency;
				ch.BackgroundTransparency = 1;
				utils.tween(ch, theme.tweenfast, {BackgroundTransparency = orig});
			end;
			if ch:IsA("TextLabel") or ch:IsA("TextButton") then
				local orig = ch.TextTransparency;
				ch.TextTransparency = 1;
				utils.tween(ch, theme.tweenfast, {TextTransparency = orig});
			end;
		end;
	end;
	task.defer(function()
		self:_recalc();
		self._msgscroll.CanvasPosition = Vector2.new(0, self._msgscroll.CanvasSize.Y.Offset);
	end);
end;

function chat:addResponse(text)
	if #self._msgdata > 0 then
		local last = self._msgdata[#self._msgdata];
		if last.role == "ai" and last.text == text then
			return;
		end;
	end;
	self:_addMsg("ai", text);
	if text == "thinking..." then
		self:_startThinkAnim();
	end;
end;

function chat:_startThinkAnim()
	self:_stopThinkAnim();
	local last = self._msgs[#self._msgs];
	if not last then return; end;
	local lbl;
	for _, ch in next, last:GetChildren() do
		if ch:IsA("TextLabel") and ch.LayoutOrder == 2 then lbl = ch; break; end;
	end;
	if not lbl then return; end;
	local dots = {"thinking", "thinking.", "thinking..", "thinking..."};
	local idx = 1;
	self._thinkrun = true;
	self._thinkconn = task.spawn(function()
		while self._thinkrun do
			idx = idx % #dots + 1;
			pcall(function() lbl.Text = dots[idx]; end);
			task.wait(0.4);
		end;
	end);
end;

function chat:_stopThinkAnim()
	self._thinkrun = false;
end;

function chat:replaceLastResponse(text)
	self:_stopThinkAnim();
	if #self._msgs == 0 then self:addResponse(text); return; end;
	if #self._msgdata > 0 and self._msgdata[#self._msgdata].text == text then
		return;
	end;
	local last = self._msgs[#self._msgs];
	for _, ch in next, last:GetChildren() do
		if ch:IsA("GuiObject") and ch.LayoutOrder >= 2 then ch:Destroy(); end;
	end;
	self:_buildContent(last, text, 2);
	if self._msgdata[#self._msgdata] then
		self._msgdata[#self._msgdata].text = text;
	end;
	task.defer(function()
		self:_recalc();
		self._msgscroll.CanvasPosition = Vector2.new(0, self._msgscroll.CanvasSize.Y.Offset);
	end);
end;

function chat:addJumpButtons(files, onJump)
	if #self._msgs == 0 or #files == 0 then return; end;
	local last = self._msgs[#self._msgs];
	local theme = self._theme;
	local utils = self._utils;
	local maxord = 2;
	for _, ch in next, last:GetChildren() do
		if ch:IsA("GuiObject") and ch.LayoutOrder >= maxord then maxord = ch.LayoutOrder + 1; end;
	end;
	local row = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 22);
		BackgroundTransparency = 1;
		LayoutOrder = maxord;
		Parent = last;
	});
	utils.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Padding = UDim.new(0, 4);
		Parent = row;
	});
	for i, fname in next, files do
		local tw = utils.measure(fname, 10, Enum.Font.Gotham) + 20;
		local btn = utils.create("TextButton", {
			Size = UDim2.new(0, tw, 0, 20);
			BackgroundColor3 = theme.accent;
			Text = fname;
			TextColor3 = Color3.new(1, 1, 1);
			TextSize = 10;
			FontFace = theme.fontui;
			AutoButtonColor = false;
			LayoutOrder = i;
			Parent = row;
		});
		utils.corner(btn, theme.cornersm);
		btn.MouseButton1Click:Connect(function()
			if onJump then onJump(fname); end;
		end);
	end;
	task.defer(function()
		self:_recalc();
		self._msgscroll.CanvasPosition = Vector2.new(0, self._msgscroll.CanvasSize.Y.Offset);
	end);
end;

function chat:toggle()
	local utils = self._utils;
	local theme = self._theme;
	self._visible = not self._visible;
	if self._visible then
		self._frame.Visible = true;
		utils.tween(self._frame, theme.tweenmed, {Size = UDim2.new(0, theme.chatw, 1, 0)});
	else
		local t = utils.tween(self._frame, theme.tweenmed, {Size = UDim2.new(0, 0, 1, 0)});
		t.Completed:Connect(function()
			if not self._visible then self._frame.Visible = false; end;
		end);
	end;
end;

function chat:isVisible()
	return self._visible;
end;

function chat:_recalc()
	local h = 0;
	for _, m in next, self._msgs do
		h += m.AbsoluteSize.Y + 6;
	end;
	self._msgscroll.CanvasSize = UDim2.new(0, 0, 0, h + 20);
end;

function chat:clearMessages()
	for _, m in next, self._msgs do m:Destroy(); end;
	self._msgs = {};
	self._msgdata = {};
	self:_recalc();
end;

function chat:getMessages()
	return self._msgdata;
end;

function chat:addMsg(role, text)
	self:_addMsg(role, text);
end;

function chat:_buildContent(parent, text, startord)
	local theme = self._theme;
	local utils = self._utils;
	local segs = parseseg(text);
	local ord = startord or 2;
	for _, seg in next, segs do
		if seg.t == "text" then
			local trimmed = seg.c:match("^%s*(.-)%s*$");
			if trimmed and trimmed ~= "" then
				utils.create("TextLabel", {
					Size = UDim2.new(1, 0, 0, 0);
					BackgroundTransparency = 1;
					Text = richify(trimmed);
					RichText = true;
					TextColor3 = theme.text;
					TextSize = 13;
					FontFace = theme.fontui;
					TextXAlignment = Enum.TextXAlignment.Left;
					TextYAlignment = Enum.TextYAlignment.Top;
					TextWrapped = true;
					AutomaticSize = Enum.AutomaticSize.Y;
					LayoutOrder = ord;
					Parent = parent;
				});
				ord = ord + 1;
			end;
		elseif seg.t == "code" then
			local lns = 1;
			for _ in seg.c:gmatch("\n") do lns = lns + 1; end;
			local txth = lns * 16 + 8;
			local maxh = 200;
			local scrh = math.min(txth, maxh);
			local cf = utils.create("Frame", {
				Size = UDim2.new(1, 0, 0, scrh + 28);
				BackgroundColor3 = Color3.fromRGB(20, 20, 20);
				BorderSizePixel = 0;
				ClipsDescendants = true;
				LayoutOrder = ord;
				Parent = parent;
			});
			utils.corner(cf, theme.cornersm);
			local hdr = utils.create("Frame", {
				Size = UDim2.new(1, 0, 0, 22);
				BackgroundColor3 = Color3.fromRGB(28, 28, 28);
				BorderSizePixel = 0;
				Parent = cf;
			});
			utils.create("TextLabel", {
				Size = UDim2.new(0, 60, 1, 0);
				Position = UDim2.new(0, 8, 0, 0);
				BackgroundTransparency = 1;
				Text = seg.lang ~= "" and seg.lang or "code";
				TextColor3 = theme.text2;
				TextSize = 10;
				FontFace = theme.fontui;
				TextXAlignment = Enum.TextXAlignment.Left;
				Parent = hdr;
			});
			local addbtn = utils.create("TextButton", {
				Size = UDim2.new(0, 72, 0, 16);
				Position = UDim2.new(1, -80, 0.5, -8);
				BackgroundColor3 = theme.accent;
				Text = "Add to folder";
				TextColor3 = Color3.new(1, 1, 1);
				TextSize = 10;
				FontFace = theme.fontui;
				AutoButtonColor = false;
				Parent = hdr;
			});
			utils.corner(addbtn, theme.cornersm);
			local codecontent = seg.c;
			addbtn.MouseButton1Click:Connect(function()
				self:_promptAddCode(codecontent, seg.lang);
			end);
			local cscroll = utils.create("ScrollingFrame", {
				Size = UDim2.new(1, -8, 0, scrh);
				Position = UDim2.new(0, 4, 0, 24);
				BackgroundTransparency = 1;
				ScrollBarThickness = 3;
				ScrollBarImageColor3 = theme.scrollbar;
				BorderSizePixel = 0;
				CanvasSize = UDim2.new(0, 0, 0, txth);
				Parent = cf;
			});
			utils.create("TextLabel", {
				Size = UDim2.new(1, -4, 0, 0);
				BackgroundTransparency = 1;
				Text = seg.c;
				TextColor3 = Color3.fromRGB(206, 145, 120);
				TextSize = 12;
				FontFace = theme.font;
				TextXAlignment = Enum.TextXAlignment.Left;
				TextYAlignment = Enum.TextYAlignment.Top;
				TextWrapped = true;
				AutomaticSize = Enum.AutomaticSize.Y;
				Parent = cscroll;
			});
			ord = ord + 1;
		end;
	end;
end;

function chat:_promptAddCode(code, lang)
	local theme = self._theme;
	local utils = self._utils;
	local ext = (lang == "lua" or lang == "luau") and ".lua" or (lang ~= "" and ("." .. lang) or ".lua");
	local inp = utils.create("TextBox", {
		Size = UDim2.new(1, -12, 0, 26);
		Position = UDim2.new(0, 6, 0, 38);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = "script" .. ext;
		PlaceholderText = "path/filename.lua";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		ZIndex = 55;
		Parent = self._frame;
	});
	utils.stroke(inp, theme.accent, 1);
	utils.pad(inp, 0, 0, 4, 4);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local fname = inp.Text;
		inp:Destroy();
		if fname ~= "" and self._cbs.onAddCode then
			self._cbs.onAddCode(fname, code);
		end;
	end);
end;

function chat:_promptSessName(cb)
	local theme = self._theme;
	local utils = self._utils;
	local inp = utils.create("TextBox", {
		Size = UDim2.new(1, -12, 0, 26);
		Position = UDim2.new(0, 6, 0, 38);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = self._sessname;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		ZIndex = 55;
		Parent = self._frame;
	});
	utils.stroke(inp, theme.accent, 1);
	utils.pad(inp, 0, 0, 4, 4);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local n = inp.Text;
		inp:Destroy();
		if n ~= "" then cb(n); end;
	end);
end;

function chat:setModels(mdls)
	for _, m in next, mdls do
		local mid = m.id;
		local mname = m.name;
		self._modeldd:addItem(mname, nil, function()
			self._modellbl.Text = mname;
			if self._cbs.onModelChange then self._cbs.onModelChange(mid); end;
		end);
	end;
	if mdls[1] then self._modellbl.Text = mdls[1].name; end;
end;

function chat:attachFile(name, content)
	for i, f in next, self._attached do
		if f.name == name then self._attached[i].content = content; self:_refreshAttach(); return; end;
	end;
	table.insert(self._attached, {name = name; content = content});
	self:_refreshAttach();
end;

function chat:isAgent()
	return self._agent;
end;

function chat:isPlanner()
	return self._planner;
end;

function chat:addPlannerOptions(options, onPick)
	if #self._msgs == 0 or #options == 0 then return; end;
	local last = self._msgs[#self._msgs];
	local theme = self._theme;
	local utils = self._utils;
	local maxord = 2;
	for _, ch in next, last:GetChildren() do
		if ch:IsA("GuiObject") and ch.LayoutOrder >= maxord then maxord = ch.LayoutOrder + 1; end;
	end;
	local row = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0);
		BackgroundTransparency = 1;
		AutomaticSize = Enum.AutomaticSize.Y;
		LayoutOrder = maxord;
		Parent = last;
	});
	utils.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal;
		SortOrder = Enum.SortOrder.LayoutOrder;
		Padding = UDim.new(0, 4);
		Wraps = true;
		Parent = row;
	});
	for i, opt in next, options do
		local tw = utils.measure(opt, 10, Enum.Font.Gotham) + 16;
		local btn = utils.create("TextButton", {
			Size = UDim2.new(0, tw, 0, 22);
			BackgroundColor3 = Color3.fromRGB(180, 120, 40);
			Text = opt;
			TextColor3 = Color3.new(1, 1, 1);
			TextSize = 10;
			FontFace = theme.fontui;
			AutoButtonColor = false;
			LayoutOrder = i;
			Parent = row;
		});
		utils.corner(btn, theme.cornersm);
		btn.MouseButton1Click:Connect(function()
			for _, ch in next, row:GetChildren() do
				if ch:IsA("TextButton") then ch.BackgroundColor3 = theme.bg; ch.TextColor3 = theme.text2; end;
			end;
			btn.BackgroundColor3 = Color3.fromRGB(180, 120, 40);
			btn.TextColor3 = Color3.new(1, 1, 1);
			if onPick then onPick(opt); end;
		end);
	end;
	task.defer(function()
		self:_recalc();
		self._msgscroll.CanvasPosition = Vector2.new(0, self._msgscroll.CanvasSize.Y.Offset);
	end);
end;

function chat:getAttached()
	return self._attached;
end;

function chat:clearAttached()
	self._attached = {};
	self:_refreshAttach();
end;

function chat:detachFile(name)
	for i, f in next, self._attached do
		if f.name == name then table.remove(self._attached, i); break; end;
	end;
	self:_refreshAttach();
end;

function chat:_refreshAttach()
	for _, tag in next, self._attachtags do
		if tag.frame then tag.frame:Destroy(); end;
	end;
	self._attachtags = {};
	if #self._attached == 0 then
		self._attachbar.Visible = false;
		self._msgscroll.Size = UDim2.new(1, -8, 1, -140);
		return;
	end;
	self._attachbar.Visible = true;
	self._msgscroll.Size = UDim2.new(1, -8, 1, -164);
	local theme = self._theme;
	local utils = self._utils;
	for _, f in next, self._attached do
		local fname = f.name;
		local tw = utils.measure(fname, 9, Enum.Font.Gotham) + 26;
		local tag = utils.create("Frame", {
			Size = UDim2.new(0, tw, 0, 16);
			BackgroundColor3 = theme.bg;
			LayoutOrder = #self._attachtags + 1;
			Parent = self._attachbar;
		});
		utils.corner(tag, theme.cornersm);
		utils.stroke(tag, theme.border, 1);
		utils.create("TextLabel", {
			Size = UDim2.new(1, -18, 1, 0);
			Position = UDim2.new(0, 4, 0, 0);
			BackgroundTransparency = 1;
			Text = fname;
			TextColor3 = theme.text2;
			TextSize = 9;
			FontFace = theme.fontui;
			TextXAlignment = Enum.TextXAlignment.Left;
			TextTruncate = Enum.TextTruncate.AtEnd;
			Parent = tag;
		});
		local xbtn = utils.create("TextButton", {
			Size = UDim2.new(0, 14, 0, 14);
			Position = UDim2.new(1, -15, 0.5, -7);
			BackgroundTransparency = 1;
			Text = "\195\151";
			TextColor3 = theme.text2;
			TextSize = 10;
			FontFace = theme.fontui;
			AutoButtonColor = false;
			Parent = tag;
		});
		xbtn.MouseButton1Click:Connect(function()
			self:detachFile(fname);
		end);
		table.insert(self._attachtags, {frame = tag; name = fname});
	end;
end;

function chat:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	self._frame:Destroy();
end;

return chat;
