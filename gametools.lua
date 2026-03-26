local hs = game:GetService("HttpService");
local maxch = 50;
local maxdc = 4000;
local maxsr = 30;

local dcfn = (typeof(decompile) == "function" and decompile) or nil;
local gsenv = (typeof(getsenv) == "function" and getsenv) or nil;
local gupvals = (typeof(getupvalues) == "function" and getupvalues) or nil;
local gconsts = (typeof(getconstants) == "function" and getconstants) or nil;
local gsclos = (typeof(getscriptclosure) == "function" and getscriptclosure)
	or (typeof(getscriptfunction) == "function" and getscriptfunction) or nil;
local req = (typeof(request) == "function" and request)
	or (typeof(http_request) == "function" and http_request)
	or (typeof(syn) == "table" and syn.request)
	or (typeof(http) == "table" and http.request)
	or nil;

local function fetchurl(url)
	if req then
		local ok, res = pcall(req, {Url = url; Method = "GET"});
		if ok and res and (res.Success or res.StatusCode == 200) and res.Body then
			return true, res.Body;
		end;
		return false, (res and (res.StatusMessage or res.StatusCode) or "request failed");
	end;
	local ok, body = pcall(function() return game:HttpGet(url); end);
	if ok and body then return true, body; end;
	return false, body;
end;

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
			description = "Decompile/analyze a script. Tries: 1) decompile() 2) raw Source 3) fallback analysis via getsenv/getconstants/getupvalues. Returns source or script analysis data";
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
			description = "Get remotes from captured Cobalt-style traffic (not static tree scan). Ensures remote spy is active, optionally waits for calls, then returns unique remotes observed from logs.";
			parameters = {
				type = "object";
				properties = {
					wait = {type = "number"; description = "Seconds to wait after ensuring spy so traffic can be captured. Default 1.5"};
					limit = {type = "number"; description = "Max log entries to inspect (default 50)"};
					filter = {type = "string"; description = "Optional remote name substring filter"};
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
	if dcfn then
		local ok, src = pcall(dcfn, inst);
		if ok and src and #src > 0 then
			if #src > maxdc then src = src:sub(1, maxdc) .. "\n-- [truncated]"; end;
			return hs:JSONEncode({path = gpath(inst); source = src; length = #src});
		end;
	end;
	local sok, src = pcall(function() return inst.Source; end);
	if sok and src and #src > 0 then
		if #src > maxdc then src = src:sub(1, maxdc) .. "\n-- [truncated]"; end;
		return hs:JSONEncode({path = gpath(inst); source = src; note = "raw Source property"});
	end;
	local out = {path = gpath(inst); class = inst.ClassName; method = "analysis"};
	if gsenv then
		pcall(function()
			local senv = gsenv(inst);
			if senv then
				local ek = {};
				for k, v in next, senv do
					if k ~= "script" then
						table.insert(ek, {name = tostring(k); type = typeof(v); val = tostring(v):sub(1, 80)});
					end;
					if #ek >= 40 then break; end;
				end;
				out.env = ek;
			end;
		end);
	end;
	if gsclos then
		pcall(function()
			local cl = gsclos(inst);
			if cl then
				if gconsts then
					local cok, cs = pcall(gconsts, cl);
					if cok and cs then
						local clist = {};
						for i = 1, math.min(#cs, 60) do
							local v = cs[i];
							if v ~= nil then table.insert(clist, tostring(v):sub(1, 100)); end;
						end;
						out.constants = clist;
					end;
				end;
				if gupvals then
					local uok, uvs = pcall(gupvals, cl);
					if uok and uvs then
						local ulist = {};
						for k, v in next, uvs do
							table.insert(ulist, {idx = k; type = typeof(v); val = tostring(v):sub(1, 80)});
							if #ulist >= 30 then break; end;
						end;
						out.upvalues = ulist;
					end;
				end;
			end;
		end);
	end;
	if not out.env and not out.constants and not out.upvalues then
		out.error = "no decompile/source available, analysis functions also unavailable";
	end;
	local r = hs:JSONEncode(out);
	if #r > maxdc then r = r:sub(1, maxdc) .. "...[trimmed]"; end;
	return r;
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
	if not args then args = {}; end;
	if gt.exec.ensure_remote_spy then gt.exec.ensure_remote_spy({filter = args.filter}); end;
	local waitt = tonumber(args.wait) or 1.5;
	if waitt > 0 then task.wait(math.clamp(waitt, 0, 8)); end;
	if not gt.exec.get_remote_spy_logs then return '{"error":"remote spy logs function unavailable"}'; end;
	local raw = gt.exec.get_remote_spy_logs({limit = args.limit or 50; filter = args.filter});
	local ok, parsed = pcall(hs.JSONDecode, hs, raw);
	if not ok or not parsed then return raw; end;
	if parsed.error then return raw; end;
	local uniq = {};
	local rems = {};
	for _, e in next, parsed.log or {} do
		local k = tostring(e.remote or "") .. "|" .. tostring(e.class or "") .. "|" .. tostring(e.path or "");
		if k ~= "||" and not uniq[k] then
			uniq[k] = true;
			table.insert(rems, {
				name = e.remote;
				class = e.class;
				path = e.path;
				method = e.method;
				calls = parsed.freq and parsed.freq[e.remote] or nil;
			});
		end;
		if #rems >= maxsr then break; end;
	end;
	return hs:JSONEncode({
		mode = "remote_spy";
		source = parsed.source or "internal";
		active = parsed.active;
		captured = parsed.total or 0;
		unique = #rems;
		remotes = rems;
		note = "results come from observed traffic. if empty, trigger gameplay/actions and call again.";
	});
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

local spylog = {};
local spymax = 200;
local spyactive = false;
local oldnc = nil;
local spyfilter = nil;
local spyexclude = {};
local spyfreq = {};
local spyblocked = {};
local spyignored = {};
local cobalturl = "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau";
local cobaltok = false;

local function getcobalt()
	local cb = nil;
	pcall(function()
		if getgenv then
			local g = getgenv();
			cb = g.Cobalt or g.cobalt or g._cobalt or g.COBALT;
			if not cb and type(g.wax) == "table" and type(g.wax.shared) == "table" then cb = g.wax.shared; end;
			if not cb and type(g.WAX) == "table" and type(g.WAX.shared) == "table" then cb = g.WAX.shared; end;
		end;
	end);
	if cb then return cb; end;
	pcall(function()
		cb = shared and (shared.Cobalt or shared.cobalt or shared._cobalt or shared.COBALT) or nil;
		if not cb and shared and type(shared.wax) == "table" and type(shared.wax.shared) == "table" then cb = shared.wax.shared; end;
		if not cb and shared and type(shared.WAX) == "table" and type(shared.WAX.shared) == "table" then cb = shared.WAX.shared; end;
	end);
	if cb then return cb; end;
	pcall(function()
		cb = _G and (_G.Cobalt or _G.cobalt or _G._cobalt or _G.COBALT) or nil;
		if not cb and _G and type(_G.wax) == "table" and type(_G.wax.shared) == "table" then cb = _G.wax.shared; end;
		if not cb and _G and type(_G.WAX) == "table" and type(_G.WAX.shared) == "table" then cb = _G.WAX.shared; end;
	end);
	return cb;
end;

local function loadcobalt()
	if cobaltok and getcobalt() then return true; end;
	local ok, err = pcall(function()
		local fok, src = fetchurl(cobalturl);
		if not fok then error(tostring(src)); end;
		local fn = loadstring(src);
		if fn then fn(); else error("loadstring unavailable"); end;
	end);
	if ok then
		cobaltok = true;
		return true;
	end;
	return false, err;
end;

local function getcobaltlogs(limit, filter)
	local cb = getcobalt();
	if not cb then return nil; end;
	local logs = nil;
	pcall(function()
		if type(cb.GetLogs) == "function" then logs = cb:GetLogs(); end;
	end);
	if not logs then pcall(function() if type(cb.getLogs) == "function" then logs = cb:getLogs(); end; end); end;
	if not logs then pcall(function() if type(cb.GetRemoteLogs) == "function" then logs = cb:GetRemoteLogs(); end; end); end;
	if not logs then pcall(function() if type(cb.getRemoteLogs) == "function" then logs = cb:getRemoteLogs(); end; end); end;
	if not logs then pcall(function() logs = cb.Logs or cb.logs or cb.RemoteLogs or cb.remoteLogs or cb.Events or cb.events or cb.NetworkLogs or cb.networkLogs; end); end;
	if not logs then
		pcall(function()
			local st = cb.State or cb.state or cb.Store or cb.store;
			if type(st) == "table" then
				logs = st.Logs or st.logs or st.RemoteLogs or st.remoteLogs or st.Events or st.events;
			end;
		end);
	end;
	if not logs then
		pcall(function()
			local rs = cb.Remotes or cb.remotes;
			if type(rs) == "table" then logs = rs.Logs or rs.logs or rs.Events or rs.events; end;
		end);
	end;
	if type(logs) ~= "table" then return nil; end;
	local lim = math.min(tonumber(limit) or 50, 100);
	local filt = filter and filter:lower() or nil;
	local out = {};
	local freq = {};
	for i = #logs, 1, -1 do
		if #out >= lim then break; end;
		local e = logs[i];
		local rn = tostring(e.remote or e.remoteName or e.name or e.RemoteName or e.Name or "");
		if rn ~= "" then
			if not filt or rn:lower():find(filt, 1, true) then
				local dir = tostring(e.direction or e.Direction or "Outgoing");
				local cls = tostring(e.class or e.Class or e.remoteClass or e.RemoteClass or "RemoteEvent");
				local pth = tostring(e.path or e.Path or e.remotePath or e.RemotePath or "");
				local args = e.args or e.Arguments or e.calls or e.Calls or {};
				table.insert(out, {
					remote = rn;
					class = cls;
					direction = dir;
					path = pth;
					args = args;
					argc = type(args) == "table" and #args or 0;
					time = e.time or e.Time or tick();
				});
				freq[rn] = (freq[rn] or 0) + 1;
			end;
		end;
	end;
	return {active = true; total = #logs; shown = #out; freq = freq; log = out; source = "cobalt"};
end;

local consolelog = {};
local consolemax = 200;
pcall(function()
	game:GetService("LogService").MessageOut:Connect(function(msg, msgtype)
		if #consolelog >= consolemax then table.remove(consolelog, 1); end;
		table.insert(consolelog, {msg = msg:sub(1, 500); type = tostring(msgtype); time = tick()});
	end);
end);

local noisykw = {"heartbeat","replication","update","sync","ping","tick","physics","clientremotesignal","replicate","stream","poll","keep_alive","keepalive","clientevent"};

local function sarg(v)
	local ok, res = pcall(function()
		local t = typeof(v);
		if t == "string" then return {t = "string"; v = v:sub(1, 300)};
		elseif t == "number" then return {t = "number"; v = v};
		elseif t == "boolean" then return {t = "boolean"; v = v};
		elseif t == "nil" then return {t = "nil"};
		elseif t == "buffer" then return {t = "buffer"; v = "<buffer:" .. buffer.len(v) .. ">"};
		elseif t == "Instance" then return {t = "Instance"; v = gpath(v); class = v.ClassName};
		elseif t == "Vector3" then return {t = "Vector3"; v = {x = v.X; y = v.Y; z = v.Z}};
		elseif t == "Vector2" then return {t = "Vector2"; v = {x = v.X; y = v.Y}};
		elseif t == "CFrame" then
			local p = v.Position;
			local rx, ry, rz = v:ToEulerAnglesXYZ();
			return {t = "CFrame"; pos = {x = p.X; y = p.Y; z = p.Z}; rot = {x = math.deg(rx); y = math.deg(ry); z = math.deg(rz)}};
		elseif t == "Color3" then return {t = "Color3"; v = {r = v.R; g = v.G; b = v.B}};
		elseif t == "BrickColor" then return {t = "BrickColor"; v = v.Name};
		elseif t == "EnumItem" then return {t = "EnumItem"; v = tostring(v)};
		elseif t == "UDim2" then return {t = "UDim2"; v = tostring(v)};
		elseif t == "Ray" then return {t = "Ray"; origin = tostring(v.Origin); dir = tostring(v.Direction)};
		elseif t == "NumberSequence" or t == "ColorSequence" then return {t = t; v = tostring(v):sub(1, 200)};
		elseif t == "table" then
			local out = {};
			local cnt = 0;
			for k, val in next, v do
				if cnt >= 20 then out["_truncated"] = true; break; end;
				out[tostring(k)] = sarg(val);
				cnt += 1;
			end;
			return {t = "table"; v = out};
		else return {t = t; v = tostring(v):sub(1, 100)};
		end;
	end);
	if ok then return res; end;
	return {t = "error"; v = tostring(res):sub(1, 100)};
end;

local function isexcluded(rname)
	local ln = rname:lower();
	if spyignored[ln] then return true; end;
	for _, ex in next, spyexclude do
		if ln:find(ex, 1, true) then return true; end;
	end;
	return false;
end;

local ckc = typeof(checkcaller) == "function" and checkcaller or nil;
local hkfn_fn = typeof(hookfunction) == "function" and hookfunction or nil;
local hkmm = typeof(hookmetamethod) == "function" and hookmetamethod or nil;
local oldfs = nil;
local oldis = nil;

local function logremote(remote, method, args)
	pcall(function()
		local rname = remote.Name;
		if isexcluded(rname) then return; end;
		if spyfilter and not rname:lower():find(spyfilter, 1, true) then return; end;
		spyfreq[rname] = (spyfreq[rname] or 0) + 1;
		local sa = {};
		for i = 1, #args do sa[i] = sarg(args[i]); end;
		if #spylog >= spymax then table.remove(spylog, 1); end;
		table.insert(spylog, {
			remote = rname;
			path = gpath(remote);
			class = remote.ClassName;
			method = method;
			args = sa;
			argc = #args;
			time = tick();
		});
	end);
end;

local function hookspy()
	if hkmm then
		oldnc = hkmm(game, "__namecall", newcclosure(function(...)
			local method = getnamecallmethod();
			if method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer" then
				if typeof((...)) == "Instance" then
					local remote = (...);
					if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") or remote:IsA("UnreliableRemoteEvent") then
						if not (ckc and ckc()) then
							logremote(remote, method, {select(2, ...)});
						end;
						if spyblocked[remote.Name:lower()] then return; end;
					end;
				end;
			end;
			return oldnc(...);
		end));
	else
		local mt = getrawmetatable(game);
		if not mt then return false, "getrawmetatable/hookmetamethod not available"; end;
		oldnc = mt.__namecall;
		local wrp = newcclosure(function(...)
			local method = getnamecallmethod();
			if method == "FireServer" or method == "fireServer" or method == "InvokeServer" or method == "invokeServer" then
				if typeof((...)) == "Instance" then
					local remote = (...);
					if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") or remote:IsA("UnreliableRemoteEvent") then
						if not (ckc and ckc()) then
							logremote(remote, method, {select(2, ...)});
						end;
						if spyblocked[remote.Name:lower()] then return; end;
					end;
				end;
			end;
			return oldnc(...);
		end);
		pcall(function()
			if setreadonly then setreadonly(mt, false); end;
			mt.__namecall = wrp;
			if setreadonly then setreadonly(mt, true); end;
		end);
	end;
	if hkfn_fn then
		pcall(function()
			local re = Instance.new("RemoteEvent");
			local rf = Instance.new("RemoteFunction");
			oldfs = hkfn_fn(re.FireServer, newcclosure(function(self, ...)
				if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")) then
					if not (ckc and ckc()) then
						logremote(self, "FireServer", {...});
					end;
					if spyblocked[self.Name:lower()] then return; end;
				end;
				return oldfs(self, ...);
			end));
			oldis = hkfn_fn(rf.InvokeServer, newcclosure(function(self, ...)
				if typeof(self) == "Instance" and self:IsA("RemoteFunction") then
					if not (ckc and ckc()) then
						logremote(self, "InvokeServer", {...});
					end;
					if spyblocked[self.Name:lower()] then return; end;
				end;
				return oldis(self, ...);
			end));
			re:Destroy();
			rf:Destroy();
		end);
	end;
	return true;
end;

local function unhookspy()
	if oldnc then
		pcall(function()
			if hkmm then
				hkmm(game, "__namecall", oldnc);
			else
				local mt = getrawmetatable(game);
				if setreadonly then setreadonly(mt, false); end;
				mt.__namecall = oldnc;
				if setreadonly then setreadonly(mt, true); end;
			end;
		end);
		oldnc = nil;
	end;
	if oldfs and hkfn_fn then
		pcall(function()
			local re = Instance.new("RemoteEvent");
			hkfn_fn(re.FireServer, oldfs);
			re:Destroy();
		end);
		oldfs = nil;
	end;
	if oldis and hkfn_fn then
		pcall(function()
			local rf = Instance.new("RemoteFunction");
			hkfn_fn(rf.InvokeServer, oldis);
			rf:Destroy();
		end);
		oldis = nil;
	end;
end;

table.insert(gt.defs, {
	type = "function";
	["function"] = {
		name = "fire_remote";
		description = "Fire a RemoteEvent or invoke a RemoteFunction with specified arguments. Args are JSON-encoded. Supports Instance paths (prefix with 'inst:'), Vector3 (prefix with 'v3:x,y,z'), CFrame (prefix with 'cf:x,y,z'), numbers, booleans, strings, and tables.";
		parameters = {
			type = "object";
			properties = {
				path = {type = "string"; description = "Instance path to the remote e.g. game.ReplicatedStorage.MyRemote"};
				method = {type = "string"; description = "FireServer or InvokeServer. Defaults to FireServer"};
				args = {type = "string"; description = 'JSON array of arguments. Use prefixes for types: "inst:game.Workspace.Part", "v3:1,2,3", "cf:1,2,3", "enum:Enum.X.Y". Plain strings/numbers/bools auto-detected. Tables use JSON objects.'};
			};
			required = {"path"};
		};
	};
});

local function parsearg(v)
	if type(v) == "string" then
		if v:sub(1, 5) == "inst:" then return resolve(v:sub(6));
		elseif v:sub(1, 3) == "v3:" then
			local parts = v:sub(4):split(",");
			return Vector3.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0);
		elseif v:sub(1, 3) == "cf:" then
			local parts = v:sub(4):split(",");
			return CFrame.new(tonumber(parts[1]) or 0, tonumber(parts[2]) or 0, tonumber(parts[3]) or 0);
		elseif v:sub(1, 5) == "enum:" then
			local ok, ev = pcall(function()
				local p = v:sub(6);
				local segs = p:split(".");
				if #segs == 3 and segs[1] == "Enum" then
					return Enum[segs[2]][segs[3]];
				end;
				return nil;
			end);
			if ok and ev then return ev; end;
			return v;
		elseif v == "true" then return true;
		elseif v == "false" then return false;
		elseif v == "nil" then return nil;
		elseif tonumber(v) then return tonumber(v);
		else return v;
		end;
	elseif type(v) == "number" or type(v) == "boolean" then return v;
	elseif type(v) == "table" then
		local out = {};
		for k, val in next, v do
			local pk = tonumber(k) or k;
			out[pk] = parsearg(val);
		end;
		return out;
	else return v;
	end;
end;

gt.exec.fire_remote = function(args)
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	if not inst:IsA("RemoteEvent") and not inst:IsA("RemoteFunction") then
		return '{"error":"not a remote: ' .. inst.ClassName .. '"}';
	end;
	local method = args.method or (inst:IsA("RemoteEvent") and "FireServer" or "InvokeServer");
	local fargs = {};
	if args.args and args.args ~= "" then
		local dok, parsed = pcall(hs.JSONDecode, hs, args.args);
		if not dok then return '{"error":"bad json args: ' .. tostring(parsed):sub(1, 200) .. '"}'; end;
		if type(parsed) == "table" then
			for i, v in next, parsed do
				fargs[tonumber(i) or i] = parsearg(v);
			end;
		end;
	end;
	local ok, res = pcall(function()
		if method == "InvokeServer" then
			return inst:InvokeServer(unpack(fargs));
		else
			inst:FireServer(unpack(fargs));
			return "fired";
		end;
	end);
	if not ok then return '{"error":"fire failed: ' .. tostring(res):sub(1, 200) .. '"}'; end;
	local ret = {status = "ok"; method = method; path = gpath(inst); argc = #fargs};
	if method == "InvokeServer" and res ~= "fired" then
		ret.result = sarg(res);
	end;
	return hs:JSONEncode(ret);
end;

table.insert(gt.defs, {type = "function"; ["function"] = {name = "execute"; description = "Execute Lua code in the game client. Does NOT return output - use get_data_by_code if you need results."; parameters = {type = "object"; properties = {code = {type = "string"; description = "Lua code to execute"}}; required = {"code"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "get_data_by_code"; description = "Execute Lua code and return the result. Code MUST return a value. Do NOT JSONEncode yourself - raw values are auto-serialized."; parameters = {type = "object"; properties = {code = {type = "string"; description = "Lua code that returns a value"}}; required = {"code"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "get_script_content"; description = "Get decompiled/analyzed source of a script. Tries decompile(), raw Source, then fallback analysis via getsenv/getconstants/getupvalues."; parameters = {type = "object"; properties = {path = {type = "string"; description = "Instance path to the script"}}; required = {"path"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "search_scripts_sources"; description = "Search across all scripts by their source code content. Returns matching scripts with context lines around matches."; parameters = {type = "object"; properties = {query = {type = "string"; description = "String to search for in script sources"}; limit = {type = "number"; description = "Max results (default 20)"}}; required = {"query"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "get_descendants_tree"; description = "Returns a structured hierarchy tree of an instance's descendants showing names, classes, and nesting. Depth-limited and optionally filtered by class."; parameters = {type = "object"; properties = {root = {type = "string"; description = "Instance path e.g. game.Workspace"}; maxDepth = {type = "number"; description = "Max depth (default 3)"}; maxChildren = {type = "number"; description = "Max children per node (default 30)"}; classFilter = {type = "string"; description = "Only show instances IsA this class"}}; required = {"root"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "get_console_output"; description = "Retrieve recent console/output log messages from the game."; parameters = {type = "object"; properties = {limit = {type = "number"; description = "Max entries (default 30)"}}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "ensure_remote_spy"; description = "Load/ensure the remote spy is active. Hooks all RemoteEvents/RemoteFunctions outgoing calls. Must be called before get_remote_spy_logs."; parameters = {type = "object"; properties = {filter = {type = "string"; description = "Only capture remotes matching this substring"}; exclude = {type = "string"; description = "Comma-separated remote names to exclude"}}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "get_remote_spy_logs"; description = "Get captured remote call logs. Returns remote name, class, method, args with types. Also returns frequency stats."; parameters = {type = "object"; properties = {limit = {type = "number"; description = "Max entries (default 20)"}; filter = {type = "string"; description = "Filter by remote name substring"}; stats = {type = "boolean"; description = "If true, only return frequency stats"}}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "clear_remote_spy_logs"; description = "Clear all captured remote spy logs."; parameters = {type = "object"; properties = {}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "block_remote"; description = "Block/unblock a remote. Blocked remotes have their calls prevented from reaching the server."; parameters = {type = "object"; properties = {name = {type = "string"; description = "Remote name to block/unblock"}; block = {type = "boolean"; description = "true to block, false to unblock (default true)"}}; required = {"name"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "ignore_remote"; description = "Ignore/unignore a remote in spy logs. Ignored remotes still fire but won't be logged."; parameters = {type = "object"; properties = {name = {type = "string"; description = "Remote name to ignore/unignore"}; ignore = {type = "boolean"; description = "true to ignore, false to unignore (default true)"}}; required = {"name"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "click_button"; description = "Simulate a click on a TextButton or ImageButton by firing its signals via firesignal."; parameters = {type = "object"; properties = {path = {type = "string"; description = "Instance path to the button"}}; required = {"path"}}}});
table.insert(gt.defs, {type = "function"; ["function"] = {name = "type_text_box"; description = "Type text into a TextBox instance."; parameters = {type = "object"; properties = {path = {type = "string"; description = "Instance path to the TextBox"}; text = {type = "string"; description = "Text to type"}; enter = {type = "boolean"; description = "Simulate Enter after typing"}}; required = {"path", "text"}}}});

gt.exec.execute = function(args)
	if not args.code or args.code == "" then return '{"error":"no code"}'; end;
	local fn, cerr = loadstring(args.code);
	if not fn then return '{"error":"syntax: ' .. tostring(cerr):sub(1, 200) .. '"}'; end;
	local ok, rerr = pcall(fn);
	if not ok then return '{"error":"runtime: ' .. tostring(rerr):sub(1, 200) .. '"}'; end;
	return '{"status":"executed"}';
end;

gt.exec.get_data_by_code = function(args)
	if not args.code or args.code == "" then return '{"error":"no code"}'; end;
	local fn, cerr = loadstring(args.code);
	if not fn then return '{"error":"syntax: ' .. tostring(cerr):sub(1, 200) .. '"}'; end;
	local ok, res = pcall(fn);
	if not ok then return '{"error":"runtime: ' .. tostring(res):sub(1, 200) .. '"}'; end;
	local function ser(v)
		local t = typeof(v);
		if t == "Instance" then return {type = t; value = gpath(v); class = v.ClassName};
		elseif t == "table" then
			local out = {}; local cnt = 0;
			for k, val in next, v do
				if cnt >= 50 then out["_truncated"] = true; break; end;
				out[tostring(k)] = ser(val); cnt += 1;
			end;
			return {type = "table"; value = out};
		elseif t == "string" then return {type = t; value = v:sub(1, 2000)};
		elseif t == "number" or t == "boolean" then return {type = t; value = v};
		elseif t == "Vector3" then return {type = t; value = {x = v.X; y = v.Y; z = v.Z}};
		elseif t == "CFrame" then return {type = t; value = tostring(v):sub(1, 200)};
		elseif t == "Color3" then return {type = t; value = {r = v.R; g = v.G; b = v.B}};
		elseif t == "EnumItem" then return {type = t; value = tostring(v)};
		elseif t == "nil" then return {type = "nil"};
		else return {type = t; value = tostring(v):sub(1, 500)}; end;
	end;
	local sok, sres = pcall(function() return hs:JSONEncode(ser(res)); end);
	if sok then return sres; end;
	return hs:JSONEncode({type = typeof(res); value = tostring(res):sub(1, 2000)});
end;

gt.exec.get_script_content = gt.exec.decompile_script;

gt.exec.search_scripts_sources = function(args)
	if not args.query or args.query == "" then return '{"error":"no query"}'; end;
	local lim = math.min(tonumber(args.limit) or 20, 40);
	local q = args.query;
	local results = {};
	pcall(function()
		for _, v in next, game:GetDescendants() do
			if #results >= lim then break; end;
			if v:IsA("LuaSourceContainer") then
				local sok, src = pcall(function() return v.Source; end);
				if not sok or not src or src == "" then
					if dcfn then pcall(function() src = dcfn(v); end); end;
				end;
				if src and src ~= "" then
					local pos = src:find(q, 1, true);
					if pos then
						local ln = 1;
						for _ in src:sub(1, pos):gmatch("\n") do ln += 1; end;
						local cs = math.max(1, pos - 80);
						local ce = math.min(#src, pos + #q + 80);
						table.insert(results, {path = gpath(v); class = v.ClassName; line = ln; context = src:sub(cs, ce)});
					end;
				end;
			end;
		end;
	end);
	return hs:JSONEncode({query = q; count = #results; results = results});
end;

gt.exec.get_descendants_tree = function(args)
	local root = resolve(args.root or "game");
	if not root then return '{"error":"not found: ' .. tostring(args.root) .. '"}'; end;
	local maxd = math.min(tonumber(args.maxDepth) or 3, 6);
	local maxc = math.min(tonumber(args.maxChildren) or 30, 50);
	local cf = args.classFilter;
	local function bld(inst, depth)
		if depth > maxd then return nil; end;
		local node = {name = inst.Name; class = inst.ClassName};
		local ch = {};
		local children = inst:GetChildren();
		local shown = 0;
		for _, c in next, children do
			if shown >= maxc then break; end;
			if cf then
				local isa = pcall(function() return c:IsA(cf); end) and c:IsA(cf);
				if isa then
					local cn = bld(c, depth + 1);
					if cn then table.insert(ch, cn); shown += 1; end;
				else
					local cn = bld(c, depth + 1);
					if cn and cn.children and #cn.children > 0 then
						table.insert(ch, cn); shown += 1;
					end;
				end;
			else
				local cn = bld(c, depth + 1);
				if cn then table.insert(ch, cn); shown += 1; end;
			end;
		end;
		if #ch > 0 then node.children = ch; end;
		if #children > maxc then node.truncated = #children - maxc; end;
		return node;
	end;
	local tree = bld(root, 0);
	local r = hs:JSONEncode(tree);
	if #r > 8000 then r = r:sub(1, 8000) .. "...[truncated]"; end;
	return r;
end;

gt.exec.get_console_output = function(args)
	local lim = math.min(tonumber(args.limit) or 30, 100);
	local out = {};
	for i = math.max(1, #consolelog - lim + 1), #consolelog do
		table.insert(out, consolelog[i]);
	end;
	return hs:JSONEncode({count = #out; total = #consolelog; logs = out});
end;

gt.exec.ensure_remote_spy = function(args)
	local cok, cerr = loadcobalt();
	if cok then
		local cb = getcobalt();
		pcall(function() if cb and type(cb.Start) == "function" then cb:Start(); end; end);
		pcall(function() if cb and type(cb.start) == "function" then cb:start(); end; end);
		return hs:JSONEncode({status = "active"; source = "cobalt"});
	end;
	return hs:JSONEncode({error = "cobalt_load_failed"; source = "cobalt"; details = tostring(cerr or "")});
end;

gt.exec.get_remote_spy_logs = function(args)
	if not args then args = {}; end;
	local clog = getcobaltlogs(args.limit or args.count, args.filter);
	if clog then
		if args.stats then
			local sorted = {};
			for rname, cnt in next, clog.freq do
				table.insert(sorted, {remote = rname; fires = cnt});
			end;
			table.sort(sorted, function(a, b) return a.fires > b.fires; end);
			return hs:JSONEncode({active = true; source = "cobalt"; total = clog.total; stats = sorted});
		end;
		return hs:JSONEncode({active = true; source = "cobalt"; total = clog.total; shown = clog.shown; freq = clog.freq; log = clog.log});
	end;
	return hs:JSONEncode({error = "cobalt_logs_unavailable"; source = "cobalt"});
end;

gt.exec.clear_remote_spy_logs = function()
	local cb = getcobalt();
	if not cb then return hs:JSONEncode({error = "cobalt_not_loaded"; source = "cobalt"}); end;
	pcall(function() if type(cb.ClearLogs) == "function" then cb:ClearLogs(); end; end);
	pcall(function() if type(cb.clearLogs) == "function" then cb:clearLogs(); end; end);
	pcall(function() if type(cb.ResetLogs) == "function" then cb:ResetLogs(); end; end);
	pcall(function() if type(cb.resetLogs) == "function" then cb:resetLogs(); end; end);
	pcall(function()
		if type(cb.Logs) == "table" then table.clear(cb.Logs); end;
		if type(cb.logs) == "table" then table.clear(cb.logs); end;
	end);
	return hs:JSONEncode({status = "cleared"; source = "cobalt"});
end;

gt.exec.block_remote = function(args)
	if not args.name then return '{"error":"no name"}'; end;
	local blk = args.block ~= false;
	local cb = getcobalt();
	if not cb then return hs:JSONEncode({error = "cobalt_not_loaded"; source = "cobalt"}); end;
	pcall(function() if type(cb.BlockRemote) == "function" then cb:BlockRemote(args.name, blk); end; end);
	pcall(function() if type(cb.blockRemote) == "function" then cb:blockRemote(args.name, blk); end; end);
	pcall(function() if type(cb.SetBlockedRemote) == "function" then cb:SetBlockedRemote(args.name, blk); end; end);
	pcall(function() if type(cb.setBlockedRemote) == "function" then cb:setBlockedRemote(args.name, blk); end; end);
	return hs:JSONEncode({remote = args.name; blocked = blk; source = "cobalt"});
end;

gt.exec.ignore_remote = function(args)
	if not args.name then return '{"error":"no name"}'; end;
	local ign = args.ignore ~= false;
	local cb = getcobalt();
	if not cb then return hs:JSONEncode({error = "cobalt_not_loaded"; source = "cobalt"}); end;
	pcall(function() if type(cb.IgnoreRemote) == "function" then cb:IgnoreRemote(args.name, ign); end; end);
	pcall(function() if type(cb.ignoreRemote) == "function" then cb:ignoreRemote(args.name, ign); end; end);
	pcall(function() if type(cb.SetIgnoredRemote) == "function" then cb:SetIgnoredRemote(args.name, ign); end; end);
	pcall(function() if type(cb.setIgnoredRemote) == "function" then cb:setIgnoredRemote(args.name, ign); end; end);
	return hs:JSONEncode({remote = args.name; ignored = ign; source = "cobalt"});
end;

gt.exec.click_button = function(args)
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	if not inst:IsA("GuiButton") then return '{"error":"not a button: ' .. inst.ClassName .. '"}'; end;
	local fs = typeof(firesignal) == "function" and firesignal or nil;
	if fs then
		pcall(fs, inst.Activated);
		pcall(fs, inst.MouseButton1Click);
		pcall(fs, inst.MouseButton1Down);
		pcall(fs, inst.MouseButton1Up);
	else
		pcall(function() inst.MouseButton1Click:Fire(); end);
	end;
	return hs:JSONEncode({status = "clicked"; path = gpath(inst); class = inst.ClassName});
end;

gt.exec.type_text_box = function(args)
	local inst = resolve(args.path);
	if not inst then return '{"error":"not found: ' .. tostring(args.path) .. '"}'; end;
	if not inst:IsA("TextBox") then return '{"error":"not a textbox: ' .. inst.ClassName .. '"}'; end;
	inst.Text = args.text or "";
	if args.enter then
		pcall(function()
			local fs = typeof(firesignal) == "function" and firesignal or nil;
			if fs then fs(inst.FocusLost, true); end;
		end);
	end;
	return hs:JSONEncode({status = "typed"; path = gpath(inst); text = args.text});
end;

return gt;
