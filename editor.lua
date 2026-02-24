local editor = {};
editor.__index = editor;

local txtsz = 14;
local gutterw = 50;
local lineh = 17;

local function splitlines(s)
	local t = {};
	for line in (s .. "\n"):gmatch("(.-)\n") do table.insert(t, line); end;
	return t;
end;

local function seqdiff(old, new_)
	local out = {};
	local i, j = 1, 1;
	while i <= #old and j <= #new_ do
		if old[i] == new_[j] then
			table.insert(out, {t = "="; l = old[i]});
			i += 1; j += 1;
		else
			local fi, fj = nil, nil;
			for k = 1, math.max(#old - i, #new_ - j) + 1 do
				if not fi then
					for di = 0, math.min(k, #new_ - j) do
						local ni, nj = i + k - di, j + di;
						if ni <= #old and nj <= #new_ and old[ni] == new_[nj] then
							fi = ni; fj = nj; break;
						end;
					end;
				end;
				if fi then break; end;
			end;
			if fi and fj then
				for x = i, fi - 1 do table.insert(out, {t = "-"; l = old[x]}); end;
				for x = j, fj - 1 do table.insert(out, {t = "+"; l = new_[x]}); end;
				i = fi; j = fj;
			else
				for x = i, #old do table.insert(out, {t = "-"; l = old[x]}); end;
				for x = j, #new_ do table.insert(out, {t = "+"; l = new_[x]}); end;
				i = #old + 1; j = #new_ + 1;
			end;
		end;
	end;
	while i <= #old do table.insert(out, {t = "-"; l = old[i]}); i += 1; end;
	while j <= #new_ do table.insert(out, {t = "+"; l = new_[j]}); j += 1; end;
	return out;
end;

local kwset = {};
for _, k in next, {
	"and"; "break"; "do"; "else"; "elseif"; "end"; "for";
	"function"; "if"; "in"; "local"; "not"; "or"; "repeat";
	"return"; "then"; "until"; "while"; "continue";
} do kwset[k] = true; end;

local bset = {};
for _, b in next, {
	"print"; "warn"; "error"; "type"; "typeof"; "tostring"; "tonumber";
	"pairs"; "ipairs"; "next"; "select"; "unpack"; "pcall"; "xpcall";
	"require"; "setmetatable"; "getmetatable"; "rawget"; "rawset";
	"assert"; "loadstring"; "task"; "wait"; "spawn"; "delay";
	"game"; "workspace"; "script"; "math"; "string"; "table"; "coroutine";
	"Instance"; "Enum"; "Vector2"; "Vector3"; "CFrame"; "Color3";
	"UDim"; "UDim2"; "TweenInfo"; "BrickColor"; "Ray"; "Region3";
	"NumberRange"; "NumberSequence"; "ColorSequence"; "Rect"; "OverlapParams";
	"RaycastParams"; "Random"; "os"; "debug"; "bit32"; "buffer"; "utf8";
} do bset[b] = true; end;

local opset = {};
for _, o in next, {
	"#"; "+"; "-"; "*"; "%"; "/"; "^"; "="; "~"; "<"; ">";
	","; "."; "("; ")"; "{"; "}"; "["; "]"; ";"; ":";
} do opset[o] = true; end;

local valset = {["true"] = true; ["false"] = true; ["nil"] = true};

local function tokenize(src)
	local toks = {};
	local cur = "";
	local instr = false;
	local incmt = false;
	local cpers = false;

	for i = 1, #src do
		local ch = src:sub(i, i);
		if incmt then
			if ch == "\n" and not cpers then
				toks[#toks + 1] = cur;
				toks[#toks + 1] = ch;
				cur = "";
				incmt = false;
			elseif src:sub(i - 1, i) == "]]" and cpers then
				cur = cur .. "]";
				toks[#toks + 1] = cur;
				cur = "";
				incmt = false;
				cpers = false;
			else
				cur = cur .. ch;
			end;
		elseif instr then
			if (ch == instr and src:sub(i - 1, i - 1) ~= "\\") or ch == "\n" then
				cur = cur .. ch;
				instr = false;
			else
				cur = cur .. ch;
			end;
		else
			if src:sub(i, i + 1) == "--" then
				if cur ~= "" then toks[#toks + 1] = cur; end;
				cur = "-";
				incmt = true;
				cpers = src:sub(i + 2, i + 3) == "[[";
			elseif ch == '"' or ch == "'" then
				if cur ~= "" then toks[#toks + 1] = cur; end;
				cur = ch;
				instr = ch;
			elseif opset[ch] then
				if cur ~= "" then toks[#toks + 1] = cur; end;
				toks[#toks + 1] = ch;
				cur = "";
			elseif ch:match("[%w_]") then
				cur = cur .. ch;
			else
				if cur ~= "" then toks[#toks + 1] = cur; end;
				toks[#toks + 1] = ch;
				cur = "";
			end;
		end;
	end;
	if cur ~= "" then toks[#toks + 1] = cur; end;
	return toks;
end;

local function highlight(src, theme)
	local toks = tokenize(src);
	local out = {};
	local clrs = {
		kw = theme.purple:ToHex();
		bi = theme.blue:ToHex();
		str = theme.orange:ToHex();
		num = theme.green:ToHex();
		cmt = Color3.fromRGB(106, 153, 85):ToHex();
		call = theme.yellow:ToHex();
		self_ = Color3.fromRGB(146, 134, 234):ToHex();
		val = Color3.fromRGB(214, 128, 23):ToHex();
		op = Color3.fromRGB(232, 210, 40):ToHex();
		prop = Color3.fromRGB(129, 222, 255):ToHex();
	};

	for i, tok in ipairs(toks) do
		local esc = tok:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;");
		local clr;

		if tok:sub(1, 2) == "--" then
			clr = clrs.cmt;
		elseif tok:sub(1, 1) == '"' or tok:sub(1, 1) == "'" then
			clr = clrs.str;
		elseif tonumber(tok) then
			clr = clrs.num;
		elseif valset[tok] then
			clr = clrs.val;
		elseif kwset[tok] then
			clr = clrs.kw;
		elseif bset[tok] then
			clr = clrs.bi;
		elseif tok == "self" then
			clr = clrs.self_;
		elseif toks[i + 1] == "(" then
			if toks[i - 1] == ":" then
				clr = clrs.self_;
			else
				clr = clrs.call;
			end;
		elseif toks[i - 1] == "." then
			if toks[i - 2] == "Enum" then
				clr = clrs.bi;
			else
				clr = clrs.prop;
			end;
		elseif opset[tok] then
			clr = clrs.op;
		end;

		if clr then
			out[#out + 1] = '<font color="#' .. clr .. '">' .. esc .. '</font>';
		else
			out[#out + 1] = esc;
		end;
	end;
	return table.concat(out);
end;

function editor.new(theme, utils, parent, icons, callbacks)
	local self = setmetatable({}, editor);
	self._theme = theme;
	self._utils = utils;
	self._conns = {};
	self._cbs = callbacks or {};

	self._frame = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Parent = parent;
	});

	self._empty = utils.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Parent = self._frame;
	});

	utils.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20);
		Position = UDim2.new(0.5, 0, 0.4, 0);
		AnchorPoint = Vector2.new(0.5, 0.5);
		BackgroundTransparency = 1;
		Text = "No file open";
		TextColor3 = theme.textdim;
		TextSize = 16;
		FontFace = theme.fontui;
		Parent = self._empty;
	});

	utils.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14);
		Position = UDim2.new(0.5, 0, 0.4, 24);
		AnchorPoint = Vector2.new(0.5, 0);
		BackgroundTransparency = 1;
		Text = "Open a file or create a new tab to start editing";
		TextColor3 = theme.textdim;
		TextSize = 12;
		FontFace = theme.fontui;
		Parent = self._empty;
	});

	self._gutter = utils.create("Frame", {
		Size = UDim2.new(0, gutterw, 1, 0);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Visible = false;
		ZIndex = 2;
		Parent = self._frame;
	});

	self._gutterscroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		ScrollBarThickness = 0;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		ScrollingEnabled = false;
		Parent = self._gutter;
	});
	self._guttertxt = utils.create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0);
		BackgroundTransparency = 1;
		Text = "1";
		TextColor3 = theme.text2;
		TextSize = txtsz;
		FontFace = theme.font;
		TextXAlignment = Enum.TextXAlignment.Right;
		TextYAlignment = Enum.TextYAlignment.Top;
		Parent = self._gutterscroll;
	});
	utils.pad(self._guttertxt, 2, 4, 0, 10);

	self._diffadded = {};
	self._diffremoved = {};
	self._pendingold = nil;
	self._pendingnew = nil;
	self._diffcbs = {};

	self._codescroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, -gutterw, 1, 0);
		Position = UDim2.new(0, gutterw, 0, 0);
		BackgroundTransparency = 1;
		ScrollBarThickness = 6;
		ScrollBarImageColor3 = theme.scrollbar;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		Visible = false;
		Parent = self._frame;
	});

	self._input = utils.create("TextBox", {
		Size = UDim2.new(1, -10, 1, 0);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundTransparency = 1;
		Text = "";
		TextColor3 = theme.text;
		TextSize = txtsz;
		FontFace = theme.font;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Top;
		ClearTextOnFocus = false;
		MultiLine = true;
		TextWrapped = false;
		TextTransparency = 1;
		Parent = self._codescroll;
	});
	utils.pad(self._input, 2, 4, 0, 0);

	self._diffhighlight = utils.create("Frame", {
		Size = UDim2.new(1, -10, 1, 0);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundTransparency = 1;
		ZIndex = 1;
		Parent = self._codescroll;
	});
	utils.pad(self._diffhighlight, 2, 4, 0, 0);

	local ic = icons or {};
	self._diffbar = utils.create("Frame", {
		Size = UDim2.new(0, 56, 0, 24);
		Position = UDim2.new(1, -64, 0, 6);
		BackgroundColor3 = theme.bg3;
		BorderSizePixel = 0;
		ZIndex = 20;
		Visible = false;
		Parent = self._frame;
	});
	utils.corner(self._diffbar, theme.cornersm);
	utils.stroke(self._diffbar, theme.border, 1);
	local acceptbtn = utils.iconbtn(self._diffbar, ic.check or "", 16, Color3.fromRGB(80, 200, 120), {
		Position = UDim2.new(0, 4, 0.5, -8);
		ZIndex = 21;
	});
	acceptbtn.MouseEnter:Connect(function()
		utils.tween(acceptbtn, theme.tweenfast, {ImageColor3 = Color3.fromRGB(120, 240, 160)});
	end);
	acceptbtn.MouseLeave:Connect(function()
		utils.tween(acceptbtn, theme.tweenfast, {ImageColor3 = Color3.fromRGB(80, 200, 120)});
	end);
	local rejectbtn = utils.iconbtn(self._diffbar, ic.x or "", 16, Color3.fromRGB(200, 80, 80), {
		Position = UDim2.new(0, 28, 0.5, -8);
		ZIndex = 21;
	});
	rejectbtn.MouseEnter:Connect(function()
		utils.tween(rejectbtn, theme.tweenfast, {ImageColor3 = Color3.fromRGB(240, 120, 120)});
	end);
	rejectbtn.MouseLeave:Connect(function()
		utils.tween(rejectbtn, theme.tweenfast, {ImageColor3 = Color3.fromRGB(200, 80, 80)});
	end);
	acceptbtn.MouseButton1Click:Connect(function()
		self:acceptDiff();
	end);
	rejectbtn.MouseButton1Click:Connect(function()
		self:rejectDiff();
	end);

	self._highlight = utils.create("TextLabel", {
		Size = UDim2.new(1, -10, 1, 0);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundTransparency = 1;
		Text = "";
		RichText = true;
		TextColor3 = theme.text;
		TextSize = txtsz;
		FontFace = theme.font;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextYAlignment = Enum.TextYAlignment.Top;
		TextWrapped = false;
		Parent = self._codescroll;
	});
	utils.pad(self._highlight, 2, 4, 0, 0);

	self._findbar = utils.create("Frame", {
		Size = UDim2.new(0, 340, 0, 64);
		Position = UDim2.new(1, -350, 0, 4);
		BackgroundColor3 = theme.bg3;
		BorderSizePixel = 0;
		Visible = false;
		ZIndex = 20;
		Parent = self._frame;
	});
	utils.corner(self._findbar, theme.cornersm);
	utils.stroke(self._findbar, theme.border, 1);

	self._findinp = utils.create("TextBox", {
		Size = UDim2.new(1, -100, 0, 24);
		Position = UDim2.new(0, 8, 0, 4);
		BackgroundColor3 = theme.input;
		BorderSizePixel = 0;
		Text = "";
		PlaceholderText = "find...";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		ZIndex = 21;
		Parent = self._findbar;
	});
	utils.corner(self._findinp, theme.cornersm);
	utils.pad(self._findinp, 0, 0, 6, 6);

	self._findcount = utils.create("TextLabel", {
		Size = UDim2.new(0, 60, 0, 24);
		Position = UDim2.new(1, -96, 0, 4);
		BackgroundTransparency = 1;
		Text = "0/0";
		TextColor3 = theme.text2;
		TextSize = 11;
		FontFace = theme.fontui;
		ZIndex = 21;
		Parent = self._findbar;
	});

	local ic = icons or {};
	local function mkfbtn(img, px, py, cb)
		local b = utils.create("TextButton", {
			Size = UDim2.new(0, 24, 0, 24);
			Position = UDim2.new(1, px, 0, py);
			BackgroundTransparency = 1;
			Text = "";
			AutoButtonColor = false;
			ZIndex = 21;
			Parent = self._findbar;
		});
		utils.icon(b, img, 14, theme.text2, {
			Position = UDim2.new(0.5, -7, 0.5, -7);
			ZIndex = 22;
		});
		utils.hover(b, Color3.new(0, 0, 0), theme.hover, theme);
		local bc = b.MouseButton1Click:Connect(cb);
		table.insert(self._conns, bc);
	end;

	mkfbtn(ic.arrowup or "", -34, 4, function() self:findPrev(); end);
	mkfbtn(ic.arrowdown or "", -10, 4, function() self:findNext(); end);

	self._repinp = utils.create("TextBox", {
		Size = UDim2.new(1, -100, 0, 24);
		Position = UDim2.new(0, 8, 0, 34);
		BackgroundColor3 = theme.input;
		BorderSizePixel = 0;
		Text = "";
		PlaceholderText = "replace...";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		ZIndex = 21;
		Parent = self._findbar;
	});
	utils.corner(self._repinp, theme.cornersm);
	utils.pad(self._repinp, 0, 0, 6, 6);

	mkfbtn(ic.refresh or "", -34, 34, function() self:replaceCurrent(); end);
	mkfbtn(ic.code or "", -10, 34, function() self:replaceAll(); end);

	self._findmatches = {};
	self._findidx = 0;

	local c1 = self._codescroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self._gutterscroll.CanvasPosition = Vector2.new(0, self._codescroll.CanvasPosition.Y);
	end);

	local c2 = self._input:GetPropertyChangedSignal("Text"):Connect(function()
		self:_updateLines();
		self:_syntax();
		if self._cbs.onChange then
			self._cbs.onChange(self._input.Text);
		end;
	end);

	local c3 = self._input:GetPropertyChangedSignal("CursorPosition"):Connect(function()
		self:_updateCursor();
	end);

	local c4 = self._findinp:GetPropertyChangedSignal("Text"):Connect(function()
		self:_doFind();
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);
	table.insert(self._conns, c4);

	return self;
end;

function editor:setContent(text)
	self._empty.Visible = false;
	self._gutter.Visible = true;
	self._codescroll.Visible = true;
	self._input.Text = text or "";
	self:_updateLines();
	self:_syntax();
end;

function editor:getContent()
	return self._input.Text;
end;

function editor:clear()
	self._input.Text = "";
	self._empty.Visible = true;
	self._gutter.Visible = false;
	self._codescroll.Visible = false;
	self._guttertxt.Text = "1";
end;

function editor:setReadOnly(val)
	self._input.TextEditable = not val;
end;

function editor:showFind()
	self._findbar.Visible = true;
	self._findinp:CaptureFocus();
end;

function editor:hideFind()
	self._findbar.Visible = false;
	self._findmatches = {};
	self._findidx = 0;
	self._findcount.Text = "";
end;

function editor:toggleWordWrap()
	local wrapped = self._input.TextWrapped;
	self._input.TextWrapped = not wrapped;
	self._highlight.TextWrapped = not wrapped;
end;

function editor:setZoom(delta)
	local cur = self._input.TextSize;
	local nz = math.clamp(cur + delta, 8, 32);
	self._input.TextSize = nz;
	self._highlight.TextSize = nz;
	self._guttertxt.TextSize = nz;
	self:_updateLines();
end;

function editor:_doFind()
	local q = self._findinp.Text:lower();
	self._findmatches = {};
	self._findidx = 0;
	if q == "" then self._findcount.Text = "0/0"; return; end;
	local src = self._input.Text:lower();
	local s = 1;
	while true do
		local f = src:find(q, s, true);
		if not f then break; end;
		table.insert(self._findmatches, f);
		s = f + 1;
	end;
	if #self._findmatches > 0 then self._findidx = 1; end;
	self._findcount.Text = (#self._findmatches > 0 and "1" or "0") .. "/" .. #self._findmatches;
end;

function editor:findNext()
	if #self._findmatches == 0 then return; end;
	self._findidx = self._findidx % #self._findmatches + 1;
	self._input.CursorPosition = self._findmatches[self._findidx];
	self._findcount.Text = self._findidx .. "/" .. #self._findmatches;
end;

function editor:findPrev()
	if #self._findmatches == 0 then return; end;
	self._findidx = (self._findidx - 2) % #self._findmatches + 1;
	self._input.CursorPosition = self._findmatches[self._findidx];
	self._findcount.Text = self._findidx .. "/" .. #self._findmatches;
end;

function editor:replaceCurrent()
	if #self._findmatches == 0 or self._findidx == 0 then return; end;
	local q = self._findinp.Text;
	local r = self._repinp.Text;
	local pos = self._findmatches[self._findidx];
	local txt = self._input.Text;
	self._input.Text = txt:sub(1, pos - 1) .. r .. txt:sub(pos + #q);
	self:_doFind();
end;

function editor:replaceAll()
	local q = self._findinp.Text;
	local r = self._repinp.Text;
	if q == "" then return; end;
	self._input.Text = self._input.Text:gsub(q:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0"), r);
	self:_doFind();
end;

function editor:_syntax()
	local src = self._input.Text;
	if src == "" then self._highlight.Text = ""; return; end;
	local ok, res = pcall(highlight, src, self._theme);
	self._highlight.Text = ok and res or src;
end;

function editor:_updateCursor()
	local pos = self._input.CursorPosition;
	if pos < 0 then return; end;
	local txt = self._input.Text:sub(1, pos - 1);
	local ln = 1;
	local lastNl = 0;
	for i = 1, #txt do
		if txt:sub(i, i) == "\n" then ln += 1; lastNl = i; end;
	end;
	local col = pos - lastNl;
	if self._cbs.onCursor then self._cbs.onCursor(ln, col); end;
end;

function editor:_updateLines()
	local text = self._input.Text;
	local count = 1;
	for _ in text:gmatch("\n") do count += 1; end;
	local nums = {};
	for i = 1, count do nums[i] = tostring(i); end;
	self._guttertxt.Text = table.concat(nums, "\n");
	task.defer(function()
		local tb = self._input.TextBounds;
		local h = math.max(tb and tb.Y or (count * lineh), count * lineh) + 30;
		self._gutterscroll.CanvasSize = UDim2.new(0, 0, 0, h);
		self._codescroll.CanvasSize = UDim2.new(0, 0, 0, h);
	end);
	self:_renderDiffs();
end;

function editor:showDiff(newcontent, oldcontent, cbs)
	self._empty.Visible = false;
	self._gutter.Visible = true;
	self._codescroll.Visible = true;
	self._pendingold = oldcontent;
	self._pendingnew = newcontent;
	self._diffcbs = cbs or {};
	local oldlines = splitlines(oldcontent or "");
	local newlines = splitlines(newcontent or "");
	local diff = seqdiff(oldlines, newlines);
	local merged = {};
	local added = {};
	local removed = {};
	for _, d in next, diff do
		table.insert(merged, d.l);
		if d.t == "+" then table.insert(added, #merged);
		elseif d.t == "-" then table.insert(removed, #merged); end;
	end;
	self._diffadded = added;
	self._diffremoved = removed;
	self._input.Text = table.concat(merged, "\n");
	self:_updateLines();
	self:_syntax();
	self:_renderDiffs();
	self._diffbar.Visible = true;
	self._input.TextEditable = false;
end;

function editor:acceptDiff()
	local new_ = self._pendingnew;
	self._pendingold = nil;
	self._pendingnew = nil;
	self._diffadded = {};
	self._diffremoved = {};
	self._diffbar.Visible = false;
	self._input.TextEditable = true;
	if new_ then
		self._input.Text = new_;
		self:_updateLines();
		self:_syntax();
	end;
	self:_renderDiffs();
	if self._diffcbs.onAccept then self._diffcbs.onAccept(); end;
	self._diffcbs = {};
end;

function editor:rejectDiff()
	local old = self._pendingold;
	self._pendingold = nil;
	self._pendingnew = nil;
	self._diffadded = {};
	self._diffremoved = {};
	self._diffbar.Visible = false;
	self._input.TextEditable = true;
	self:_renderDiffs();
	if old then
		self._input.Text = old;
		self:_updateLines();
		self:_syntax();
	end;
	if self._diffcbs.onReject then self._diffcbs.onReject(old); end;
	self._diffcbs = {};
end;

function editor:hasPendingDiff()
	return self._pendingold ~= nil;
end;

function editor:clearDiffs()
	local new_ = self._pendingnew;
	self._diffadded = {};
	self._diffremoved = {};
	self._pendingold = nil;
	self._pendingnew = nil;
	self._diffbar.Visible = false;
	self._input.TextEditable = true;
	self._diffcbs = {};
	if new_ then
		self._input.Text = new_;
		self:_updateLines();
		self:_syntax();
	end;
	self:_renderDiffs();
end;

function editor:_renderDiffs()
	for _, ch in next, self._diffhighlight:GetChildren() do ch:Destroy(); end;
	local utils = self._utils;
	for _, ln in next, self._diffadded do
		utils.create("Frame", {
			Size = UDim2.new(1, 0, 0, lineh);
			Position = UDim2.new(0, 0, 0, (ln - 1) * lineh);
			BackgroundColor3 = Color3.fromRGB(52, 168, 83);
			BackgroundTransparency = 0.93;
			BorderSizePixel = 0;
			ZIndex = 1;
			Parent = self._diffhighlight;
		});
		utils.create("Frame", {
			Size = UDim2.new(0, 3, 0, lineh);
			Position = UDim2.new(0, -5, 0, (ln - 1) * lineh);
			BackgroundColor3 = Color3.fromRGB(52, 168, 83);
			BackgroundTransparency = 0.2;
			BorderSizePixel = 0;
			ZIndex = 2;
			Parent = self._diffhighlight;
		});
	end;
	for _, ln in next, self._diffremoved do
		utils.create("Frame", {
			Size = UDim2.new(1, 0, 0, lineh);
			Position = UDim2.new(0, 0, 0, (ln - 1) * lineh);
			BackgroundColor3 = Color3.fromRGB(200, 60, 60);
			BackgroundTransparency = 0.93;
			BorderSizePixel = 0;
			ZIndex = 1;
			Parent = self._diffhighlight;
		});
		utils.create("Frame", {
			Size = UDim2.new(0, 3, 0, lineh);
			Position = UDim2.new(0, -5, 0, (ln - 1) * lineh);
			BackgroundColor3 = Color3.fromRGB(200, 60, 60);
			BackgroundTransparency = 0.2;
			BorderSizePixel = 0;
			ZIndex = 2;
			Parent = self._diffhighlight;
		});
	end;
end;

function editor:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	self._frame:Destroy();
end;

return editor;
