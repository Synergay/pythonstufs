local explorer = {};
explorer.__index = explorer;

function explorer.new(theme, utils, parent, ctxmenu, callbacks, icons)
	local self = setmetatable({}, explorer);
	self._theme = theme;
	self._utils = utils;
	self._icons = icons or {};
	self._conns = {};
	self._items = {};
	self._cbs = callbacks or {};
	self._expanded = {};
	self._visible = true;
	self._ctx = ctxmenu;
	self._dragging = nil;
	self._ghost = nil;
	self._dropline = nil;
	self._droptarget = nil;

	self._frame = utils.create("Frame", {
		Size = UDim2.new(0, theme.sidebarw, 1, 0);
		BackgroundColor3 = theme.bg2;
		BorderSizePixel = 0;
		ClipsDescendants = true;
		Parent = parent;
	});

	local header = utils.create("Frame", {
		Size = UDim2.new(1, 0, 0, 30);
		BackgroundTransparency = 1;
		Parent = self._frame;
	});
	utils.pad(header, 0, 0, 12, 0);

	utils.create("TextLabel", {
		Size = UDim2.new(1, -50, 1, 0);
		BackgroundTransparency = 1;
		Text = "EXPLORER";
		TextColor3 = theme.text2;
		TextSize = 11;
		FontFace = theme.fontbold;
		TextXAlignment = Enum.TextXAlignment.Left;
		Parent = header;
	});

	local hbtns = utils.create("Frame", {
		Size = UDim2.new(0, 66, 0, 20);
		Position = UDim2.new(1, -74, 0.5, -10);
		BackgroundTransparency = 1;
		Parent = header;
	});
	utils.list(hbtns, Enum.FillDirection.Horizontal, 2);

	local ic = self._icons;
	local function mkbtn(img, order, cb)
		local b = utils.create("TextButton", {
			Size = UDim2.new(0, 20, 0, 20);
			BackgroundTransparency = 1;
			Text = "";
			AutoButtonColor = false;
			LayoutOrder = order;
			Parent = hbtns;
		});
		utils.icon(b, img, 14, theme.text2, {
			Position = UDim2.new(0.5, -7, 0.5, -7);
		});
		utils.hover(b, Color3.new(0, 0, 0), theme.hover, theme);
		local bc = b.MouseButton1Click:Connect(cb);
		table.insert(self._conns, bc);
	end;

	mkbtn(ic.plus or "", 1, function()
		self:_promptNewFile();
	end);
	mkbtn(ic.folderplus or "", 2, function()
		self:_promptNewFolder();
	end);
	mkbtn(ic.chevsdown or "", 3, function()
		self:collapseAll();
	end);

	self._scroll = utils.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -30);
		Position = UDim2.new(0, 0, 0, 30);
		BackgroundTransparency = 1;
		ScrollBarThickness = 4;
		ScrollBarImageColor3 = theme.scrollbar;
		BorderSizePixel = 0;
		CanvasSize = UDim2.new(0, 0, 0, 0);
		Parent = self._frame;
	});
	utils.list(self._scroll, Enum.FillDirection.Vertical, 0, nil, Enum.VerticalAlignment.Top);

	self._dropline = utils.create("Frame", {
		Size = UDim2.new(1, -8, 0, 2);
		Position = UDim2.new(0, 4, 0, 0);
		BackgroundColor3 = theme.accent;
		BorderSizePixel = 0;
		Visible = false;
		ZIndex = 20;
		Parent = self._frame;
	});

	self._globalconns = {};
	local uis = game:GetService("UserInputService");
	local dc1 = uis.InputChanged:Connect(function(input)
		if not self._dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return; end;
		if self._ghost then
			self._ghost.Position = UDim2.new(0, input.Position.X - self._frame.AbsolutePosition.X + 10, 0, input.Position.Y - self._frame.AbsolutePosition.Y - 8);
		end;
		self:_updateDropTarget(input.Position.Y);
	end);
	local dc2 = uis.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self._dragging then
			self:_endDrag();
		end;
	end);
	table.insert(self._globalconns, dc1);
	table.insert(self._globalconns, dc2);

	utils.create("Frame", {
		Size = UDim2.new(0, 1, 1, 0);
		Position = UDim2.new(1, -1, 0, 0);
		BackgroundColor3 = theme.border;
		BorderSizePixel = 0;
		Parent = self._frame;
	});

	return self;
end;

function explorer:addFolder(name, files, depth, isroot)
	local theme = self._theme;
	local utils = self._utils;
	depth = depth or 0;
	local fid = name .. "_" .. depth;
	self._expanded[fid] = true;
	local ih = 22;

	local data = {name = name; fid = fid};

	local btn = utils.create("TextButton", {
		Size = UDim2.new(1, 0, 0, ih);
		BackgroundTransparency = 1;
		Text = "";
		AutoButtonColor = false;
		LayoutOrder = #self._items + 1;
		Parent = self._scroll;
	});

	local ic = self._icons;
	local arrow = utils.icon(btn, ic.chevdown or "", 10, theme.text2, {
		Position = UDim2.new(0, 4 + (depth * 12), 0.5, -5);
	});

	utils.icon(btn, ic.folder or "", 12, theme.orange, {
		Position = UDim2.new(0, 18 + (depth * 12), 0.5, -6);
	});

	local namelbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -36 - (depth * 12), 1, 0);
		Position = UDim2.new(0, 34 + (depth * 12), 0, 0);
		BackgroundTransparency = 1;
		Text = name;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.AtEnd;
		Parent = btn;
	});

	local c1 = btn.MouseEnter:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 0; BackgroundColor3 = theme.hover});
	end);
	local c2 = btn.MouseLeave:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 1});
	end);
	table.insert(self._conns, c1);
	table.insert(self._conns, c2);

	local item = {frame = btn; type = "folder"; name = name; depth = depth; fid = fid; children = {}; namelbl = namelbl; data = data; isroot = isroot or false};
	table.insert(self._items, item);

	local fileFrames = {};
	if files then
		for _, f in next, files do
			if f.children then
				local subframes = self:addFolder(f.name, f.children, depth + 1);
				for _, sf in next, subframes do
					table.insert(fileFrames, sf);
					table.insert(item.children, sf);
				end;
			else
				local ff = self:_addFile(f.name, f.content, depth + 1, fid);
				table.insert(fileFrames, ff);
				table.insert(item.children, ff);
			end;
		end;
	end;

	local c3 = btn.MouseButton1Click:Connect(function()
		if self._dragging then return; end;
		self._expanded[fid] = not self._expanded[fid];
		local exp = self._expanded[fid];
		arrow.Image = exp and (ic.chevdown or "") or (ic.chevright or "");
		for _, ff in next, item.children do
			ff.Visible = exp;
		end;
		self:_recalc();
	end);
	table.insert(self._conns, c3);

	local c4 = btn.MouseButton2Click:Connect(function()
		if self._dragging then return; end;
		local mx = btn.AbsolutePosition.X + btn.AbsoluteSize.X * 0.5;
		local my = btn.AbsolutePosition.Y + ih;
		self._ctx:show({
			{label = "New File"; callback = function() self:_promptNewFile(); end};
			{label = "New Folder"; callback = function() self:_promptNewFolder(); end};
			{label = "---"};
			{label = "Rename"; callback = function()
				self:_promptRenameItem(item);
			end};
			{label = "Delete"; callback = function()
				for _, child in next, item.children do child:Destroy(); end;
				btn:Destroy();
				self:_removeItem(item);
			end};
		}, mx, my);
	end);
	table.insert(self._conns, c4);

	self:_setupDrag(item);
	self:_recalc();
	return fileFrames;
end;

function explorer:_getFolderByFid(fid)
	for _, it in next, self._items do
		if it.type == "folder" and it.fid == fid then return it; end;
	end;
	return nil;
end;

function explorer:_removeFromParent(item)
	if not item.parentfid then return; end;
	local parent = self:_getFolderByFid(item.parentfid);
	if not parent or not parent.children then return; end;
	for i, child in next, parent.children do
		if child == item.frame then
			table.remove(parent.children, i);
			break;
		end;
	end;
end;

function explorer:_addFile(name, content, depth, parentfid)
	local theme = self._theme;
	local utils = self._utils;
	depth = depth or 0;
	local ih = 22;

	local parent = parentfid and self:_getFolderByFid(parentfid);
	local fpath = (parent and not parent.isroot) and (parent.name .. "/" .. name) or name;
	local data = {name = name; content = content or ""; path = fpath};

	local btn = utils.create("TextButton", {
		Size = UDim2.new(1, 0, 0, ih);
		BackgroundTransparency = 1;
		Text = "";
		AutoButtonColor = false;
		LayoutOrder = #self._items + 1;
		Parent = self._scroll;
	});

	local ic = self._icons;
	local ext = name:match("%.(%w+)$") or "";
	local ficons = {
		lua = ic.filecode; luau = ic.filecode; py = ic.filecode; js = ic.filecode;
		json = ic.filejson; txt = ic.filetext; md = ic.filetext;
	};
	local iclrs = {
		lua = theme.blue; luau = theme.blue; py = theme.green;
		js = theme.yellow; json = theme.orange; txt = theme.text2;
	};

	local iconlbl = utils.icon(btn, ficons[ext:lower()] or ic.file or "", 12, iclrs[ext:lower()] or theme.text2, {
		Position = UDim2.new(0, 8 + (depth * 12), 0.5, -6);
	});

	local namelbl = utils.create("TextLabel", {
		Size = UDim2.new(1, -26 - (depth * 12), 1, 0);
		Position = UDim2.new(0, 24 + (depth * 12), 0, 0);
		BackgroundTransparency = 1;
		Text = name;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.AtEnd;
		Parent = btn;
	});

	local item = {frame = btn; type = "file"; name = name; depth = depth; parentfid = parentfid; namelbl = namelbl; iconlbl = iconlbl; data = data; path = fpath};

	local c1 = btn.MouseEnter:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 0; BackgroundColor3 = theme.hover});
	end);
	local c2 = btn.MouseLeave:Connect(function()
		utils.tween(btn, theme.tweenfast, {BackgroundTransparency = 1});
	end);
	local c3 = btn.MouseButton1Click:Connect(function()
		if self._dragging then return; end;
		if self._cbs.onFileClick then
			self._cbs.onFileClick(data.name, data.content, data.path);
		end;
	end);
	local c4 = btn.MouseButton2Click:Connect(function()
		if self._dragging then return; end;
		local mx = btn.AbsolutePosition.X + btn.AbsoluteSize.X * 0.5;
		local my = btn.AbsolutePosition.Y + ih;
		self._ctx:show({
			{label = "Open"; callback = function()
				if self._cbs.onFileClick then self._cbs.onFileClick(data.name, data.content, data.path); end;
			end};
			{label = "---"};
			{label = "Rename"; callback = function()
				self:_promptRenameItem(item);
			end};
			{label = "Delete"; callback = function()
				self:_removeFromParent(item);
				btn:Destroy();
				self:_removeItem(item);
				if self._cbs.onDeleteFile then self._cbs.onDeleteFile(data.path); end;
			end};
		}, mx, my);
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);
	table.insert(self._conns, c4);
	table.insert(self._items, item);

	self:_setupDrag(item);
	self:_recalc();
	return btn;
end;

function explorer:toggle()
	local utils = self._utils;
	local theme = self._theme;
	self._visible = not self._visible;
	if self._visible then
		self._frame.Visible = true;
		utils.tween(self._frame, theme.tweenmed, {Size = UDim2.new(0, theme.sidebarw, 1, 0)});
	else
		local t = utils.tween(self._frame, theme.tweenmed, {Size = UDim2.new(0, 0, 1, 0)});
		t.Completed:Connect(function()
			if not self._visible then self._frame.Visible = false; end;
		end);
	end;
end;

function explorer:isVisible()
	return self._visible;
end;

function explorer:collapseAll()
	for fid, _ in next, self._expanded do
		self._expanded[fid] = false;
	end;
	for _, item in next, self._items do
		if item.type == "folder" and item.children then
			for _, child in next, item.children do
				pcall(function() (child :: any).Visible = false; end);
			end;
			if item.frame then
				local arrow = item.frame:FindFirstChildWhichIsA("ImageLabel");
				if arrow then arrow.Image = self._icons.chevright or ""; end;
			end;
		end;
	end;
	self:_recalc();
end;

function explorer:setActiveFile(name)
	for _, item in next, self._items do
		if item.type == "file" then
			if name and item.name == name then
				item.frame.BackgroundTransparency = 0;
				item.frame.BackgroundColor3 = self._theme.hover;
			else
				item.frame.BackgroundTransparency = 1;
			end;
		end;
	end;
end;

function explorer:_removeItem(item)
	for i, it in next, self._items do
		if it == item then table.remove(self._items, i); break; end;
	end;
	self:_recalc();
end;

function explorer:_recalc()
	local h = 0;
	for _, item in next, self._items do
		if item.frame and item.frame.Parent and item.frame.Visible then h += 22; end;
	end;
	self._scroll.CanvasSize = UDim2.new(0, 0, 0, h);
end;

function explorer:clear()
	for _, c in next, self._conns do c:Disconnect(); end;
	self._conns = {};
	for _, item in next, self._items do
		if item.frame then item.frame:Destroy(); end;
	end;
	self._items = {};
	self._expanded = {};
	self:_recalc();
end;

function explorer:renameFile(oldname, newname)
	for _, item in next, self._items do
		if item.type == "file" and item.name == oldname then
			item.name = newname;
			if item.data then item.data.name = newname; end;
			if item.namelbl then item.namelbl.Text = newname; end;
			local parent = item.parentfid and self:_getFolderByFid(item.parentfid);
			local np = parent and (parent.name .. "/" .. newname) or newname;
			item.path = np;
			if item.data then item.data.path = np; end;
			break;
		end;
	end;
end;

function explorer:addFileEntry(name, content, depth, parentfid)
	self:_addFile(name, content or "", depth or 0, parentfid);
end;

function explorer:_promptRenameItem(item)
	local theme = self._theme;
	local utils = self._utils;
	local lbl = item.namelbl;
	if not lbl then return; end;
	lbl.Visible = false;
	local inp = utils.create("TextBox", {
		Size = lbl.Size;
		Position = lbl.Position;
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = item.name;
		TextColor3 = theme.text;
		TextSize = 13;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		ZIndex = 6;
		Parent = item.frame;
	});
	utils.stroke(inp, theme.accent, 1);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local nn = inp.Text;
		inp:Destroy();
		lbl.Visible = true;
		if nn ~= "" and nn ~= item.name then
			local oldname = item.name;
			local oldpath = item.path or (item.data and item.data.path) or oldname;
			item.name = nn;
			if item.data then item.data.name = nn; end;
			lbl.Text = nn;
			if item.type == "file" then
				local parent = item.parentfid and self:_getFolderByFid(item.parentfid);
				local np = parent and not parent.isroot and (parent.name .. "/" .. nn) or nn;
				item.path = np;
				if item.data then item.data.path = np; end;
				if self._cbs.onRenameFile then
					self._cbs.onRenameFile(oldname, nn, oldpath, np);
				end;
			elseif item.type == "folder" then
				item.fid = nn .. "_" .. (item.depth or 0);
				if self._cbs.onRenameFolder then
					self._cbs.onRenameFolder(oldname, nn);
				end;
			end;
		end;
	end);
end;

function explorer:_setupDrag(item)
	local _theme = self._theme;
	local _utils = self._utils;
	local btn = item.frame;
	local pressing = false;
	local startpos;

	local c1 = btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = true;
			startpos = input.Position;
		end;
	end);

	local c2 = btn.InputChanged:Connect(function(input)
		if not pressing or self._dragging then return; end;
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local dist = (input.Position - startpos).Magnitude;
			if dist > 5 then
				self:_startDrag(item, input.Position);
			end;
		end;
	end);

	local c3 = btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressing = false;
		end;
	end);

	table.insert(self._conns, c1);
	table.insert(self._conns, c2);
	table.insert(self._conns, c3);
end;

function explorer:_startDrag(item, pos)
	self._dragging = item;
	item.frame.BackgroundTransparency = 0.5;

	self._ghost = self._utils.create("TextLabel", {
		Size = UDim2.new(0, 120, 0, 20);
		Position = UDim2.new(0, pos.X - self._frame.AbsolutePosition.X + 10, 0, pos.Y - self._frame.AbsolutePosition.Y - 8);
		BackgroundColor3 = self._theme.bg3;
		BackgroundTransparency = 0.3;
		BorderSizePixel = 0;
		Text = item.name;
		TextColor3 = self._theme.text;
		TextSize = 12;
		FontFace = self._theme.fontui;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ZIndex = 30;
		Parent = self._frame;
	});
	self._utils.corner(self._ghost, self._theme.cornersm);
end;

function explorer:_updateDropTarget(my)
	if self._highlightedFolder then
		self._highlightedFolder.frame.BackgroundTransparency = 1;
		self._highlightedFolder = nil;
	end;
	local best, bestdist, folderHit;
	for i, item in next, self._items do
		if item ~= self._dragging and item.frame and item.frame.Visible then
			local iy = item.frame.AbsolutePosition.Y;
			local ih = item.frame.AbsoluteSize.Y;
			if item.type == "folder" and self._dragging.type == "file" and my >= iy and my <= iy + ih then
				folderHit = {idx = i; item = item};
			end;
			local mid = iy + ih * 0.5;
			local d = math.abs(my - mid);
			if not bestdist or d < bestdist then
				bestdist = d;
				if my < mid then
					best = {idx = i; y = iy; side = "above"};
				else
					best = {idx = i; y = iy + ih; side = "below"};
				end;
			end;
		end;
	end;
	if folderHit then
		self._droptarget = {idx = folderHit.idx; side = "into"; item = folderHit.item};
		self._dropline.Visible = false;
		folderHit.item.frame.BackgroundTransparency = 0;
		folderHit.item.frame.BackgroundColor3 = self._theme.accent;
		self._highlightedFolder = folderHit.item;
	elseif best then
		self._droptarget = best;
		self._dropline.Visible = true;
		self._dropline.Position = UDim2.new(0, 4, 0, best.y - self._frame.AbsolutePosition.Y);
	else
		self._droptarget = nil;
		self._dropline.Visible = false;
	end;
end;

function explorer:_endDrag()
	local item = self._dragging;
	if not item then return; end;

	item.frame.BackgroundTransparency = 1;
	if self._ghost then self._ghost:Destroy(); self._ghost = nil; end;
	self._dropline.Visible = false;
	if self._highlightedFolder then
		self._highlightedFolder.frame.BackgroundTransparency = 1;
		self._highlightedFolder = nil;
	end;

	if self._droptarget then
		local tgt = self._droptarget;

		if tgt.side == "into" and tgt.item and item.type == "file" then
			local folder = tgt.item;
			if item.parentfid == folder.fid then
				self._dragging = nil;
				self._droptarget = nil;
				return;
			end;
			self:_removeFromParent(item);
			item.parentfid = folder.fid;
			item.depth = folder.depth + 1;
			local newpath = folder.isroot and item.name or (folder.name .. "/" .. item.name);
			item.path = newpath;
			if item.data then item.data.path = newpath; end;
			local d = item.depth;
			if item.iconlbl then
				item.iconlbl.Position = UDim2.new(0, 8 + (d * 12), 0, 0);
			end;
			if item.namelbl then
				item.namelbl.Position = UDim2.new(0, 24 + (d * 12), 0, 0);
				item.namelbl.Size = UDim2.new(1, -26 - (d * 12), 1, 0);
			end;
			table.insert(folder.children, item.frame);
			local lastorder = folder.frame.LayoutOrder;
			for _, ch in next, folder.children do
				if ch.LayoutOrder and ch.LayoutOrder > lastorder then
					lastorder = ch.LayoutOrder;
				end;
			end;
			item.frame.LayoutOrder = lastorder + 1;
			item.frame.Visible = self._expanded[folder.fid] ~= false;
			if self._cbs.onFileMove then
				self._cbs.onFileMove(item.name, newpath);
			end;
		else
			local tgtitem = self._items[tgt.idx];
			if not tgtitem then
				self._dragging = nil;
				self._droptarget = nil;
				return;
			end;

			if item.type == "folder" and item.children then
				for _, child in next, item.children do
					if tgtitem.frame == child then
						self._dragging = nil;
						self._droptarget = nil;
						return;
					end;
				end;
				if tgtitem.parentfid == item.fid then
					self._dragging = nil;
					self._droptarget = nil;
					return;
				end;
			end;

			local neworder;
			if tgt.side == "above" then
				neworder = tgtitem.frame.LayoutOrder;
			else
				neworder = tgtitem.frame.LayoutOrder + 1;
			end;

			local oldorder = item.frame.LayoutOrder;
			for _, it in next, self._items do
				if it ~= item and it.frame then
					if oldorder < neworder then
						if it.frame.LayoutOrder > oldorder and it.frame.LayoutOrder <= neworder then
							it.frame.LayoutOrder -= 1;
						end;
					else
						if it.frame.LayoutOrder >= neworder and it.frame.LayoutOrder < oldorder then
							it.frame.LayoutOrder += 1;
						end;
					end;
				end;
			end;
			item.frame.LayoutOrder = neworder;

			if item.type == "folder" and item.children then
				for ci, child in next, item.children do
					child.LayoutOrder = neworder + ci;
				end;
			end;
		end;
	end;

	self._dragging = nil;
	self._droptarget = nil;
end;

function explorer:_promptNewFile()
	local theme = self._theme;
	local utils = self._utils;
	local inp = utils.create("TextBox", {
		Size = UDim2.new(1, -10, 0, 22);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = "";
		PlaceholderText = "filename.lua";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		LayoutOrder = 999;
		Parent = self._scroll;
	});
	utils.stroke(inp, theme.accent, 1);
	utils.pad(inp, 0, 0, 4, 4);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local n = inp.Text;
		inp:Destroy();
		if n ~= "" then
			self:_addFile(n, "", 0, nil);
			if self._cbs.onNewFile then self._cbs.onNewFile(n, n); end;
		end;
	end);
end;

function explorer:_promptNewFolder()
	local theme = self._theme;
	local utils = self._utils;
	local inp = utils.create("TextBox", {
		Size = UDim2.new(1, -10, 0, 22);
		Position = UDim2.new(0, 5, 0, 0);
		BackgroundColor3 = theme.bg;
		BorderSizePixel = 0;
		Text = "";
		PlaceholderText = "foldername";
		PlaceholderColor3 = theme.textdim;
		TextColor3 = theme.text;
		TextSize = 12;
		FontFace = theme.fontui;
		TextXAlignment = Enum.TextXAlignment.Left;
		ClearTextOnFocus = false;
		LayoutOrder = 999;
		Parent = self._scroll;
	});
	utils.stroke(inp, theme.accent, 1);
	utils.pad(inp, 0, 0, 4, 4);
	inp:CaptureFocus();
	inp.FocusLost:Connect(function()
		local n = inp.Text;
		inp:Destroy();
		if n ~= "" then
			self:addFolder(n, {}, 0);
			if self._cbs.onNewFolder then self._cbs.onNewFolder(n); end;
		end;
	end);
end;

function explorer:getAllFiles()
	local files = {};
	for _, item in next, self._items do
		if item.type == "file" then
			table.insert(files, item.name);
		end;
	end;
	return files;
end;

function explorer:getAllFilesWithPaths()
	local out = {};
	for _, item in next, self._items do
		if item.type == "file" then
			local p = item.path or item.data and item.data.path or item.name;
			table.insert(out, {name = item.name; path = p; content = item.data and item.data.content or ""});
		end;
	end;
	return out;
end;

function explorer:getFolderPaths()
	local out = {};
	for _, item in next, self._items do
		if item.type == "folder" and not item.isroot then
			table.insert(out, item.name);
		end;
	end;
	return out;
end;

function explorer:destroy()
	for _, c in next, self._conns do c:Disconnect(); end;
	for _, c in next, self._globalconns do c:Disconnect(); end;
	self._frame:Destroy();
end;

return explorer;
