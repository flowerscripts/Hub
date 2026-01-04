local Maid = sharedRequire('utils/Maid.lua');
local Services = sharedRequire('utils/Services.lua');

local toCamelCase = sharedRequire('utils/toCamelCase.lua');
local library = sharedRequire('UILibrary.lua');

	local Players, CorePackages, HttpService = Services:Get('Players', 'CorePackages', 'HttpService');
	local LocalPlayer = Players.LocalPlayer;

	local NUM_ACTORS = 8;

		--[[
			We'll add an example cuz I have no brain
		
			local chestsESP = createBaseESP('chests'); -- This is the base ESP it returns a class with .new, .Destroy, :UpdateAll, :UnloadAll, and some other stuff
		
			-- Listen to chests childAdded through Utility.listenToChildAdded and then create an espObject for that chest
			-- chestsESP.new only accepts BasePart or CFrame
			-- It has a lazy parameter allowing it to not update the get the position everyframe only get the screen position
			-- Also a color parameter
		
			Utility.listenToChildAdded(workspace.Chests, function(obj)
				local espObject = chestsESP.new(obj, 'Normal Chest', color, isLazy);
		
				obj.Destroying:Connect(function()
					espObject:Destroy();
				end);
			end);
		
			local function updateChestESP(toggle)
				if (not toggle) then
					maid.chestESP = nil;
					chestsESP:UnloadAll();
					return;
				end;
		
				maid.chestESP = RunService.Stepped:Connect(function()
					chestsESP:UpdateAll();
				end);
			end;
		
			-- UI Lib functions
			:AddToggle({text = 'Enable', flag = 'chests', callback = updateChestESP});
			:AddToggle({text = 'Show Distance', textpos = 2, flag = 'Chests Show Distance'});
			:AddToggle({text = 'Show Normal Chest'}):AddColor({text = 'Normal Chest Color'}); -- Filer for if you want to see that chest and select the color of it
		]]

	local playerScripts = LocalPlayer:WaitForChild('PlayerScripts')

	--local playerScriptsLoader = playerScripts:FindFirstChild('PlayerScriptsLoader');
	local actors = {};

	local readyCount = 0;
	local broadcastEvent = Instance.new('BindableEvent');

	local supportedGamesList = HttpService:JSONDecode(customRequire('gameList.json'));
	local gameName = supportedGamesList[tostring(game.GameId)];

	if (playerScriptsLoader) then
		for _ = 1, NUM_ACTORS do
			local commId, commEvent;

			if (isSynapseV3) then
				commEvent = {
					_event = Instance.new('BindableEvent'),

					Connect = function(self, f)
						return self._event.Event:Connect(f)
					end,

					Fire = function(self, ...)
						self._event:Fire(...);
					end
				};
			else
				commId, commEvent = getgenv().syn.create_comm_channel();
			end;

			local clone = playerScriptsLoader:Clone();
			local actor = Instance.new('Actor');
			clone.Parent = actor;

			local playerModule = CorePackages.InGameServices.MouseIconOverrideService:Clone();
			playerModule.Name = 'PlayerModule';
			playerModule.Parent = actor;

			if (not isSynapseV3) then
				--syn.protect_gui(actor);
			end;

			actor.Parent = LocalPlayer.PlayerScripts;

			local connection;

			connection = commEvent:Connect(function(data)
				if (data.updateType == 'ready') then
					commEvent:Fire({updateType = 'giveEvent', event = broadcastEvent, gameName = gameName});
					actor:Destroy();

					readyCount += 1;

					connection:Disconnect();
					connection = nil;
				end;
			end);

			originalFunctions.runOnActor(actor, sharedRequire('utils/createBaseESPParallel.lua'), commId or commEvent);
			table.insert(actors, {
				actor = actor,
				commEvent = commEvent
			});
		end;

		print('Waiting for actors');
		repeat task.wait(); until readyCount >= NUM_ACTORS;
		print('All actors have been loaded');
	else
		local commId, commEvent = getgenv().syn.create_comm_channel();

		local connection;
		connection = commEvent:Connect(function(data)
			if (data.updateType == 'ready') then
				connection:Disconnect();
				connection = nil;

				commEvent:Fire({updateType = 'giveEvent', event = broadcastEvent});
			end;
		end);

		loadstring(sharedRequire('utils/createBaseESPParallel.lua'))(commId);

		table.insert(actors, {commEvent = commEvent});
		readyCount = 1;
	end;

	local count = 1;

	local function createBaseEsp(flag, container)
		container = container or {};
		local BaseEsp = {};

		BaseEsp.ClassName = 'BaseEsp';
		BaseEsp.Flag = flag; -- This is the Section Name (e.g., 'Npcs')
		BaseEsp.Container = container;
		BaseEsp.__index = BaseEsp;

		local whiteColor = Color3.new(1, 1, 1);
		local maxDistanceFlag = BaseEsp.Flag .. ' Max Distance'; -- Matches makeEsp slider
		local showHealthFlag = BaseEsp.Flag .. ' Show Health';
		local showESPFlag = BaseEsp.Flag; -- The "Enable" toggle

		function BaseEsp.new(instance, tag, color, isLazy)
			assert(instance, '#1 instance expected');
			assert(tag, '#2 tag expected');

			local self = setmetatable({}, BaseEsp);
			
			-- Identify the actor for this object
			local actorIndex = (count % readyCount) + 1;
			self._actor = actors[actorIndex];
			self._id = count;
			count += 1;

			-- Prepare the data packet for the Parallel Actor
			-- Your parallel script expects these specific keys in 'data.data'
			local packet = {
				_id = self._id,
				_tag = typeof(tag) == 'table' and tag.tag or tag,
				_text = typeof(tag) == 'table' and tag.displayName or tag,
				_instance = instance,
				_color = color or whiteColor,
				_isLazy = isLazy,
				_showFlag = toCamelCase('Show ' .. (typeof(tag) == 'table' and tag.tag or tag)),
				_maxDistanceFlag = maxDistanceFlag,
				_showHealthFlag = showHealthFlag,
				_colorFlag = toCamelCase((typeof(tag) == 'table' and tag.tag or tag) .. ' Color'),
				_colorFlag2 = BaseEsp.Flag .. ' Color',
				_showDistanceFlag = BaseEsp.Flag .. ' Show Distance',
			};

			-- Handle Custom Instances (for Voxl/Deepwoken style)
			local isCustom = false;
			if (typeof(instance) == 'table' and rawget(instance, 'code')) then
				isCustom = true;
				packet._code = instance.code;
				packet._vars = instance.vars;
			end;

			-- FIRE TO ACTOR
			self._actor.commEvent:Fire({
				updateType = 'new',
				data = packet,
				showFlag = showESPFlag, -- This links to the 'Enable' toggle
				isCustomInstance = isCustom
			});

			self._maid = Maid.new();
			return self;
		end;

		function BaseEsp:Unload() end;
		function BaseEsp:BaseUpdate() end;
		function BaseEsp:UpdateAll() end;
		function BaseEsp:Update() end;
		function BaseEsp:UnloadAll() end;
		function BaseEsp:Disable() end;

		function BaseEsp:Destroy()
			self._maid:Destroy();
			self._actor.commEvent:Fire({
				updateType = 'destroy',
				id = self._id
			});
		end;

		return BaseEsp;
	end;

	library.OnFlagChanged:Connect(function(data)
		broadcastEvent:Fire({
			type = data.type,
			flag = data.flag,
			color = data.color,
			state = data.state,
			value = data.value
		});
	end);

	return createBaseEsp;
