local hs = game:GetService("HttpService");
local maxch = 50;
local maxdc = 4000;
local maxsr = 30;

local dcfn = (typeof(decompile) == "function" and decompile) or nil;

local function resolve(path)
	if not path or path == "" or path == "game" then return game; end;
	local p = path:gsub("^game%.?", "");
	if p == "" then return game; end;
	local cur = game;
	for part in p:gmatch("[^%.]+") do
		local ch = cur:FindFirstChild(part);
		if not ch then
			local ok, svc = pcall(game.GetService, game, part);
			if ok and svc then ch = svc; else return nil; end;
		end;
		cur = ch;
	end;
	return cur;
end;

local function gpath(inst)
	if inst == game then return "game"; end;
	local pts = {};
	local cur = inst;
	while cur and cur ~= game do
		table.insert(pts, 1, cur.Name);
		cur = cur.Parent;
	end;
	return "game." .. table.concat(pts, ".");
end;

local function fmti(inst)
	return {name = inst.Name; class = inst.ClassName; path = gpath(inst)};
end;

local function pval(v)
	local t = typeof(v);
	if t == "string" then return v:sub(1, 200);
	elseif t == "number" or t == "boolean" then return v;
	elseif t == "Instance" then return gpath(v);
	elseif t == "EnumItem" then return tostring(v);
	else return tostring(v):sub(1, 100);
	end;
end;

local gt = {};

gt.defs = {
	{
		type = "function";
		["function"] = {
			name = "get_game_info";
			description = "Get current game info: PlaceId, PlaceVersion, JobId, game name";
			parameters = {type = "object"; properties = {}};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_services";
			description = "List all services in the game DataModel with their class names";
			parameters = {type = "object"; properties = {}};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_children";
			description = "Get children of an instance at a path. Returns name, class, path for each (max 50). Path format: game.Workspace.Folder";
			parameters = {
				type = "object";
				properties = {
					path = {type = "string"; description = "Instance path e.g. game.Workspace"};
				};
				required = {"path"};
			};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_properties";
			description = "Get common properties of an instance at a path. Returns name, class, and relevant properties";
			parameters = {
				type = "object";
				properties = {
					path = {type = "string"; description = "Instance path"};
				};
				required = {"path"};
			};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "decompile_script";
			description = "Decompile a ModuleScript, LocalScript, or Script at the given path. Returns decompiled Lua source code (max 4000 chars)";
			parameters = {
				type = "object";
				properties = {
					path = {type = "string"; description = "Instance path to the script e.g. game.ReplicatedStorage.MyModule"};
				};
				required = {"path"};
			};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "search_instances";
			description = "Search for instances by name pattern and/or class under a parent path. Returns up to 30 matches";
			parameters = {
				type = "object";
				properties = {
					parent = {type = "string"; description = "Parent path to search under e.g. game.ReplicatedStorage"};
					name = {type = "string"; description = "Name substring to match (case insensitive)"};
					class = {type = "string"; description = "ClassName to filter by e.g. ModuleScript, RemoteEvent"};
				};
				required = {"parent"};
			};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_remotes";
			description = "Find all RemoteEvents, RemoteFunctions, BindableEvents, BindableFunctions under a path";
			parameters = {
				type = "object";
				properties = {
					path = {type = "string"; description = "Instance path to search under. Defaults to game if empty"};
				};
			};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_player_info";
			description = "Get detailed info about the LocalPlayer: name, UserId, character children, backpack tools, PlayerGui top-level children, team, health, position";
			parameters = {type = "object"; properties = {}};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_connections";
			description = "Get the script connections on a RemoteEvent or RemoteFunction at a path. Shows which scripts are listening. Requires executor getconnections support";
			parameters = {
				type = "object";
				properties = {
					path = {type = "string"; description = "Instance path to the remote e.g. game.ReplicatedStorage.MyRemote"};
					signal = {type = "string"; description = "Signal name e.g. OnClientEvent, OnServerEvent, OnInvoke. Defaults to OnClientEvent"};
				};
				required = {"path"};
			};
		};
	};
	{
		type = "function";
		["function"] = {
			name = "get_nil_instances";
			description = "Get instances parented to nil (hidden from game tree). Useful for finding hidden scripts, guis, or anti-cheat. Requires executor getnilinstances support";
			parameters = {
				type = "object";
				properties = {
					class = {type = "string"; description = "Optional ClassName filter e.g. LocalScript, ModuleScript, ScreenGui"};
				};
			};
		};
	};
};

gt.exec = {};

gt.exec.get_game_info = function()
	local info = {placeId = game.PlaceId; jobId = game.JobId; placeVer = game.PlaceVersion};
	pcall(function()
		info.name = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name;
	end);
	pcall(function()
		info.player = game:GetService("Players").LocalPlayer.Name;
	end);
	return hs:JSONEncode(info);
end;

gt.exec.get_services = function()
	local svcs = {};
	for _, v in next, game:GetChildren() do
		table.insert(svcs, {name = v.Name; class = v.ClassName});
	end;
	return hs:JSONEncode(svcs);
end;

gt.exec.get_children = function(args)
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	local all = inst:GetChildren();
	local ch = {};
	for i = 1, math.min(#all, maxch) do
		table.insert(ch, fmti(all[i]));
	end;
	return hs:JSONEncode({total = #all; shown = #ch; children = ch});
end;

gt.exec.get_properties = function(args)
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	local out = {name = inst.Name; class = inst.ClassName; path = gpath(inst)};
	local keys = {
		"Parent"; "Size"; "Position"; "CFrame"; "Value"; "Text"; "Transparency";
		"Color"; "BrickColor"; "Material"; "Anchored"; "CanCollide"; "Velocity";
		"MaxHealth"; "Health"; "WalkSpeed"; "JumpPower"; "Archivable"; "Disabled";
		"MaxActivationDistance"; "Brightness"; "Range"; "Image"; "Visible";
	};
	if inst:IsA("LuaSourceContainer") then
		pcall(function() out.srclen = #inst.Source; end);
	end;
	for _, k in next, keys do
		local ok, v = pcall(function() return inst[k]; end);
		if ok and v ~= nil then out[k] = pval(v); end;
	end;
	return hs:JSONEncode(out);
end;

gt.exec.decompile_script = function(args)
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	if not inst:IsA("LuaSourceContainer") then
		return '{"error":"not a script: ' .. inst.ClassName .. '"}';
	end;
	if not dcfn then
		local ok, src = pcall(function() return inst.Source; end);
		if ok and src and #src > 0 then
			if #src > maxdc then src = src:sub(1, maxdc) .. "\n-- [truncated]"; end;
			return hs:JSONEncode({path = gpath(inst); source = src; note = "raw Source property"});
		end;
		return '{"error":"decompile not available in this executor"}';
	end;
	local ok, src = pcall(dcfn, inst);
	if not ok then return '{"error":"decompile failed: ' .. tostring(src):sub(1, 200) .. '"}'; end;
	if #src > maxdc then src = src:sub(1, maxdc) .. "\n-- [truncated at " .. maxdc .. " chars]"; end;
	return hs:JSONEncode({path = gpath(inst); source = src; length = #src});
end;

gt.exec.search_instances = function(args)
	local parent = resolve(args.parent or "game");
	if not parent then return '{"error":"parent not found: ' .. tostring(args.parent) .. '"}'; end;
	local results = {};
	local nq = args.name and args.name:lower() or nil;
	local cq = args.class or nil;
	for _, v in next, parent:GetDescendants() do
		if #results >= maxsr then break; end;
		local ok = true;
		if nq and not v.Name:lower():find(nq, 1, true) then ok = false; end;
		if cq and v.ClassName ~= cq then ok = false; end;
		if ok then table.insert(results, fmti(v)); end;
	end;
	return hs:JSONEncode({count = #results; capped = #results >= maxsr; results = results});
end;

gt.exec.get_remotes = function(args)
	local parent = resolve(args.path or "game");
	if not parent then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	local rems = {};
	for _, v in next, parent:GetDescendants() do
		if #rems >= maxsr then break; end;
		if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") or v:IsA("BindableEvent") or v:IsA("BindableFunction") then
			table.insert(rems, fmti(v));
		end;
	end;
	return hs:JSONEncode({count = #rems; capped = #rems >= maxsr; remotes = rems});
end;

gt.exec.get_player_info = function()
	local plrs = game:GetService("Players");
	local lp = plrs.LocalPlayer;
	if not lp then return '{"error":"no LocalPlayer"}'; end;
	local info = {name = lp.Name; userId = lp.UserId; displayName = lp.DisplayName};
	pcall(function() info.team = lp.Team and lp.Team.Name or nil; end);
	pcall(function()
		local ch = lp.Character;
		if ch then
			info.charChildren = {};
			for _, v in next, ch:GetChildren() do
				table.insert(info.charChildren, {name = v.Name; class = v.ClassName});
			end;
			local hum = ch:FindFirstChildOfClass("Humanoid");
			if hum then
				info.health = hum.Health;
				info.maxHealth = hum.MaxHealth;
				info.walkSpeed = hum.WalkSpeed;
				info.jumpPower = hum.JumpPower;
			end;
			local hrp = ch:FindFirstChild("HumanoidRootPart");
			if hrp then info.position = tostring(hrp.Position); end;
		end;
	end);
	pcall(function()
		local bp = lp:FindFirstChildOfClass("Backpack");
		if bp then
			info.backpack = {};
			for _, v in next, bp:GetChildren() do
				table.insert(info.backpack, {name = v.Name; class = v.ClassName});
			end;
		end;
	end);
	pcall(function()
		local pg = lp:FindFirstChildOfClass("PlayerGui");
		if pg then
			info.playerGui = {};
			for _, v in next, pg:GetChildren() do
				table.insert(info.playerGui, {name = v.Name; class = v.ClassName});
			end;
		end;
	end);
	return hs:JSONEncode(info);
end;

gt.exec.get_connections = function(args)
	local gcfn = (typeof(getconnections) == "function" and getconnections) or nil;
	if not gcfn then return '{"error":"getconnections not available"}'; end;
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	local sig = args.signal or "OnClientEvent";
	local ok, signal = pcall(function() return inst[sig]; end);
	if not ok or not signal then return '{"error":"signal not found: ' .. sig .. '"}'; end;
	local cok, conns = pcall(gcfn, signal);
	if not cok then return '{"error":"getconnections failed: ' .. tostring(conns):sub(1, 200) .. '"}'; end;
	local out = {};
	for idx, c in next, conns do
		if idx > maxsr then break; end;
		local entry = {enabled = c.Enabled or true};
		pcall(function() entry.func = tostring(c.Function):sub(1, 100); end);
		pcall(function()
			if c.ForeignState then entry.foreign = true; end;
		end);
		table.insert(out, entry);
	end;
	return hs:JSONEncode({path = gpath(inst); signal = sig; count = #out; connections = out});
end;

gt.exec.get_nil_instances = function(args)
	local gnfn = (typeof(getnilinstances) == "function" and getnilinstances) or nil;
	if not gnfn then return '{"error":"getnilinstances not available"}'; end;
	local ok, nils = pcall(gnfn);
	if not ok then return '{"error":"getnilinstances failed"}'; end;
	local cq = args.class or nil;
	local results = {};
	for _, v in next, nils do
		if #results >= maxsr then break; end;
		if not cq or v.ClassName == cq then
			table.insert(results, {name = v.Name; class = v.ClassName});
		end;
	end;
	return hs:JSONEncode({count = #results; capped = #results >= maxsr; instances = results});
end;

table.insert(gt.defs, {
	type = "function";
	["function"] = {
		name = "get_workspace_items";
		description = "Smart scan of workspace for interactive items (collectibles, drops, weapons, tools). Scores each candidate Model/Tool/BasePart by interactivity signals: ClickDetector, ProximityPrompt, BillboardGui, value children, name patterns. Returns items sorted by score so you only see relevant objects, not map geometry.";
		parameters = {
			type = "object";
			properties = {
				parent = {type = "string"; description = "Path to scan under (default: game.Workspace)"};
				minscore = {type = "number"; description = "Min score to include (default 1). Use 2+ for stricter filtering."};
			};
		};
	};
});

local itemkw = {"item","drop","pickup","coin","gem","chest","loot","weapon","sword","gun","orb","crystal","key","potion","powerup","reward","collectible","star","ring","token","fruit","egg","shard","rune","arrow","ammo","bomb","shield","armor","helm","glove","tool","axe","bow","staff","wand","heart","cash","gold","silver","diamond","jewel","ore","berry","trophy","badge","collectib"};
local mapkw = {"wall","floor","ceiling","ground","baseplate","boundary","invisible","hitbox","region","barrier","anchor","terrain","spawnloc"};

local function hasword(name, words)
	local ln = name:lower();
	for _, w in next, words do
		if ln:find(w, 1, true) then return true; end;
	end;
	return false;
end;

local function scoreinst(inst)
	local s = 0;
	pcall(function()
		if inst:IsA("Tool") or inst:IsA("HopperBin") then s += 5; end;
		if inst:FindFirstChildOfClass("ClickDetector") then s += 3; end;
		if inst:FindFirstChildOfClass("ProximityPrompt") then s += 3; end;
		if inst:FindFirstChildOfClass("BillboardGui") then s += 2; end;
		if inst:FindFirstChildOfClass("SurfaceGui") then s += 1; end;
		for _, ch in next, inst:GetChildren() do
			if ch:IsA("ValueBase") then s += 1; break; end;
		end;
		if hasword(inst.Name, itemkw) then s += 2; end;
		if hasword(inst.Name, mapkw) then s -= 2; end;
		if inst:IsA("Model") then s += 1; end;
	end);
	return s;
end;

gt.exec.get_workspace_items = function(args)
	local parent = resolve(args.parent or "game.Workspace");
	if not parent then return '{"error":"parent not found: ' .. tostring(args.parent) .. '"}'; end;
	local minscore = tonumber(args.minscore) or 1;
	local candidates = {};
	local seen = {};

	local function scan(inst, depth)
		if #candidates >= 60 or seen[inst] then return; end;
		seen[inst] = true;
		if inst:IsA("Model") or inst:IsA("Tool") or inst:IsA("HopperBin") or inst:IsA("BasePart") then
			local sc = scoreinst(inst);
			if sc >= minscore then
				table.insert(candidates, {inst = inst; score = sc});
			end;
		end;
		if depth < 2 and (inst:IsA("Folder") or inst:IsA("Model") or inst == parent) then
			for _, ch in next, inst:GetChildren() do
				scan(ch, depth + 1);
				if #candidates >= 60 then break; end;
			end;
		end;
	end;

	for _, ch in next, parent:GetChildren() do
		scan(ch, 0);
		if #candidates >= 60 then break; end;
	end;

	table.sort(candidates, function(a, b) return a.score > b.score; end);

	local out = {};
	for i = 1, math.min(#candidates, 40) do
		local c = candidates[i];
		local entry = fmti(c.inst);
		entry.score = c.score;
		local sigs = {};
		pcall(function()
			if c.inst:IsA("Tool") then table.insert(sigs, "Tool"); end;
			if c.inst:FindFirstChildOfClass("ClickDetector") then table.insert(sigs, "ClickDetector"); end;
			if c.inst:FindFirstChildOfClass("ProximityPrompt") then table.insert(sigs, "ProximityPrompt"); end;
			if c.inst:FindFirstChildOfClass("BillboardGui") then table.insert(sigs, "BillboardGui"); end;
			if hasword(c.inst.Name, itemkw) then table.insert(sigs, "nameMatch"); end;
		end);
		entry.signals = sigs;
		table.insert(out, entry);
	end;

	return hs:JSONEncode({count = #out; parent = gpath(parent); items = out});
end;

return gt;
