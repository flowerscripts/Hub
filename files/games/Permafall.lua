local library = sharedRequire('UILibrary.lua');

local AudioPlayer = sharedRequire('utils/AudioPlayer.lua');
local makeESP = sharedRequire('utils/makeESP.lua');

local Utility = sharedRequire('utils/Utility.lua');
local Maid = sharedRequire('utils/Maid.lua');
local AnalyticsAPI = sharedRequire('classes/AnalyticsAPI.lua');

local Services = sharedRequire('utils/Services.lua');
local createBaseESP = sharedRequire('utils/createBaseESP.lua');

local EntityESP = sharedRequire('classes/EntityESP.lua');
local ControlModule = sharedRequire('classes/ControlModule.lua');
local ToastNotif = sharedRequire('classes/ToastNotif.lua');

local prettyPrint = sharedRequire('utils/prettyPrint.lua');
local BlockUtils = sharedRequire('utils/BlockUtils.lua');
local TextLogger = sharedRequire('classes/TextLogger.lua');
local fromHex = sharedRequire('utils/fromHex.lua');
local toCamelCase = sharedRequire('utils/toCamelCase.lua');
local Webhook = sharedRequire('utils/Webhook.lua');

if (game.PlaceId == 126222071643660) then
    ToastNotif.new({
        text = 'Script will not run in menu!',
        duration = 5
    });

    task.delay(0.005, function()
        library:Unload();
    end);
    return;
end;


local column1, column2 = unpack(library.columns);

local functions = {};

local Players, RunService, UserInputService, HttpService, CollectionService, MemStorageService = Services:Get('Players', 'RunService', 'UserInputService', 'HttpService', 'CollectionService', 'MemStorageService');

local LocalPlayer = Players.LocalPlayer;
local playerMouse = LocalPlayer:GetMouse();

local maid = Maid.new();

local localCheats = column1:AddSection('Local Cheats');
local notifier = column1:AddSection('Notifier');
local playerMods = column1:AddSection('Player Mods');
local misc = column1:AddSection('Misc');
local visuals = column2:AddSection('Visuals');
local farms = column2:AddSection('Farms');
local inventoryViewer = column2:AddSection('Inventory Viewer');

do -- // Functions
    function functions.speedHack(toggle)
        if (not toggle) then
            maid.speedHack = nil;
            maid.speedHackBv = nil;

            return;
        end;

        maid.speedHack = RunService.Heartbeat:Connect(function()
            local playerData = Utility:getPlayerData();
            local humanoid, rootPart = playerData.humanoid, playerData.primaryPart;
            if (not humanoid or not rootPart) then return end;

            if (library.flags.fly) then
                maid.speedHackBv = nil;
                return;
            end;

            maid.speedHackBv = maid.speedHackBv or Instance.new('BodyVelocity');
            maid.speedHackBv.MaxForce = Vector3.new(100000, 0, 100000);

            if (not CollectionService:HasTag(maid.speedHackBv, 'good')) then
                CollectionService:AddTag(maid.speedHackBv, 'good');
            end;

            maid.speedHackBv.Parent = not library.flags.fly and rootPart or nil;
            maid.speedHackBv.Velocity = (humanoid.MoveDirection.Magnitude ~= 0 and humanoid.MoveDirection or gethiddenproperty(humanoid, 'WalkDirection')) * library.flags.speedHackValue;
        end);
    end;


    function functions.fly(toggle)
        if (not toggle) then
            maid.flyHack = nil;
            maid.flyBv = nil;

            return;
        end;

        maid.flyBv = Instance.new('BodyVelocity');
        maid.flyBv.MaxForce = Vector3.new(math.huge, math.huge, math.huge);

        maid.flyHack = RunService.Heartbeat:Connect(function()
            local playerData = Utility:getPlayerData();
            local rootPart, camera = playerData.rootPart, workspace.CurrentCamera;
            if (not rootPart or not camera) then return end;

            if (not CollectionService:HasTag(maid.flyBv, 'good')) then
                CollectionService:AddTag(maid.flyBv, 'good');
            end;

            maid.flyBv.Parent = rootPart;
            maid.flyBv.Velocity = camera.CFrame:VectorToWorldSpace(ControlModule:GetMoveVector() * library.flags.flyHackValue);
        end);
    end;


   function functions.noKillBricks(toggle)
		for i, v in next, killBricks do
			v.part.Parent = not toggle and v.oldParent or nil;
		end;
	end;

	function functions.infiniteJump(toggle)
		if(not toggle) then return end;

		repeat
			local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');
			if(rootPart and UserInputService:IsKeyDown(Enum.KeyCode.Space)) then
				rootPart.Velocity = Vector3.new(rootPart.Velocity.X, library.flags.infiniteJumpHeight, rootPart.Velocity.Z);
			end;
			task.wait(0.1);
		until not library.flags.infiniteJump;
	end;

	function functions.goToGround()
		local params = RaycastParams.new();
		params.FilterDescendantsInstances = {workspace.Live, workspace.NPCs};
		params.FilterType = Enum.RaycastFilterType.Blacklist;

		if (not myRootPart or not myRootPart.Parent) then return end;

		local floor = workspace:Raycast(myRootPart.Position, Vector3.new(0, -1000, 0), params);
		if(not floor or not floor.Instance) then return end;

		local isKillBrick = false;

		for _, v in next, killBricks do
			if (floor.Instance == v.part) then
				isKillBrick = true;
				break;
			end;
		end;

		if (isKillBrick) then return end;

		myRootPart.CFrame *= CFrame.new(0, -(myRootPart.Position.Y - floor.Position.Y) + 3, 0);
		myRootPart.Velocity *= Vector3.new(1, 0, 1);
	end;

    library.OnKeyPress:Connect(function(input, gpe)
			SX_VM_CNONE();

			if (gpe) then return end;

			local key = library.options.attachToBack.key;
			if (input.KeyCode.Name == key or input.UserInputType.Name == key) then
				local myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');
				local closest, closestDistance = nil, math.huge;

				if (not myRootPart) then return end;

				repeat
					for _, entity in next, workspace.Live:GetChildren() do
						local rootPart = entity:FindFirstChild('HumanoidRootPart');
						if (not rootPart or rootPart == myRootPart) then continue end;

						local distance = (rootPart.Position - myRootPart.Position).magnitude;

						if (distance < 300 and distance < closestDistance) then
							closest, closestDistance = rootPart, distance;
						end;
					end;

					task.wait();
				until closest or input.UserInputState == Enum.UserInputState.End;
				if (input.UserInputState == Enum.UserInputState.End) then return end;

				maid.attachToBack = RunService.Heartbeat:Connect(function()
					local goalCF = closest.CFrame * CFrame.new(0, library.flags.attachToBackHeight, library.flags.attachToBackSpace);

					local distance = (goalCF.Position - myRootPart.Position).Magnitude;
					local tweenInfo = TweenInfo.new(distance / 100, Enum.EasingStyle.Linear);

					local tween = TweenService:Create(myRootPart, tweenInfo, {
						CFrame = goalCF
					});

					tween:Play();

					maid.attachToBackTween = function()
						tween:Cancel();
					end;
				end);
			end;
		end);

		library.OnKeyRelease:Connect(function(input)
			SX_VM_CNONE();

			local key = library.options.attachToBack.key;
			if (input.KeyCode.Name == key or input.UserInputType.Name == key) then
				maid.attachToBack = nil;
				maid.attachToBackTween = nil;
			end;
		end);
	end;
end;

-- NoClip
	do
		function functions.noClip(toggle)
			if (not toggle) then
				maid.noClip = nil;

				local humanoid = Utility:getPlayerData().humanoid;
				if (not humanoid) then return end;

				humanoid:ChangeState('Physics');
				task.wait();
				humanoid:ChangeState('RunningNoPhysics');

				return;
			end;

			maid.noClip = RunService.Stepped:Connect(function()
				debug.profilebegin('noclip');

				local myCharacterParts = Utility:getPlayerData().parts;
				local isKnocked = ActuallyRagdolled;
				local disableNoClipWhenKnocked = library.flags.disableNoClipWhenKnocked;

				for _, v in next, myCharacterParts do
					if (disableNoClipWhenKnocked) then
						v.CanCollide = not not isKnocked;
					else
						v.CanCollide = false;
					end;
				end;
				debug.profileend();
			end);
		end;
	end;

	function functions.clickDestroy(toggle)
		if (not toggle) then
			maid.clickDestroy = nil;
			return;
		end;

		maid.clickDestroy = UserInputService.InputBegan:Connect(function(input, gpe)
			if (input.UserInputType ~= Enum.UserInputType.MouseButton1 or gpe) then return end;

			local target = playerMouse.Target;
			if (not target or target:IsA('Terrain')) then return end;

			target:Destroy();
		end)
	end;

	function functions.serverHop(bypass)
		if(bypass or library:ShowConfirm('Are you sure you want to switch server?')) then
			library:UpdateConfig();
			local dataSlot = LocalPlayer:GetAttribute('DataSlot');
			MemStorageService:SetItem('DataSlot', dataSlot);

			BlockUtils:BlockRandomUser();
			TeleportService:Teleport(4111023553);
		end;
	end;

    function functions.playerProximityCheck(toggle)
        if (not toggle) then
            maid.proximityCheck = nil;
            return;
        end;

        local notifSend = setmetatable({}, {
            __mode = 'k';
        });

        maid.proximityCheck = RunService.Heartbeat:Connect(function()
            if (not myRootPart) then return end;

            for _, v in next, Players:GetPlayers() do
                local rootPart = v.Character and v.Character.PrimaryPart;
                if (not rootPart or v == LocalPlayer) then continue end;

                local distance = (myRootPart.Position - rootPart.Position).Magnitude;

                if (distance < 300 and not table.find(notifSend, rootPart)) then
                    table.insert(notifSend, rootPart);
                    ToastNotif.new({
                        text = string.format('%s is nearby [%d]', v.Name, distance),
                        duration = 30
                    });
                elseif (distance > 500 and table.find(notifSend, rootPart)) then
                    table.remove(notifSend, table.find(notifSend, rootPart))
                    ToastNotif.new({
                        text = string.format('%s is no longer nearby [%d]', v.Name, distance),
                        duration = 30
                    });
                end;
            end;
        end);
    end;



do -- // Auto Sprint
    function functions.autoSprint(toggle)
        if (not toggle) then
            maid.autoSprint = nil;
            return;
        end;

        local moveKeys = {Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D};
        local lastRan = 0;

        maid.autoSprint = UserInputService.InputBegan:Connect(function(input, gpe)
            if (gpe or tick() - lastRan < 0.1) then return end;

            if (table.find(moveKeys, input.KeyCode)) then
                lastRan = tick();
                print('auto sprint');
                --VirtualInputManager:SendKeyEvent(true, input.KeyCode, false, game);
            end;
        end);
    end;
end;


local myChatLogs = {};

local chatLogger = TextLogger.new({
	title = 'Chat Logger',
	preset = 'chatLogger',
	buttons = {'Spectate', 'Copy Username', 'Copy User Id', 'Copy Text', 'Report User'}
});


local assetsList = {'ModeratorJoin.mp3', 'ModeratorLeft.mp3'};
local audios = {};

local apiEndpoint = USE_INSECURE_ENDPOINT and 'https://rukiascripts.xyz/';

for i, v in next, assetsList do
	audios[v] = AudioPlayer.new({
		url = string.format('%s%s', apiEndpoint, v),
		volume = 10,
		forcedAudio = true
	});
end;

local function loadSound(soundName)
	if ((soundName == 'ModeratorJoin.mp3' or soundName == 'ModeratorLeft.mp3') and not library.flags.modNotifier) then
		return;
	end;

	audios[soundName]:Play();
end;

_G.loadSound = loadSound;

local setCameraSubject;
local isInDanger;

local moderators = {};

do -- // Mod Logs and chat logger
	-- Y am I hardcoding this?

    local GROUP_ID = 475163115;
    local MINIMUM_RANK = 252;

    local suc, err = pcall(function()
        for _, player in ipairs(Players:GetPlayers()) do
            player:GetRankInGroup(GROUP_ID);
        end;
    end);

    if (not suc) then
        if (debugMode) then
            task.spawn(error, err);
        end;

        ToastNotif.new({text = 'Script has failed to setup moderator detection. Error Code 1.' .. (err or -1)});
    end;

    local function isModerator(player)
        local suc, inGroup = pcall(player.IsInGroup, player, GROUP_ID);
        if (not suc or not inGroup) then return false end;

        local rankSuc, rank = pcall(player.GetRankInGroup, player, GROUP_ID);
        if (not rankSuc) then return false end;

        return rank >= MINIMUM_RANK;
    end;
=
	local function onPlayerChatted(player, message)
		local timeText = DateTime.now():FormatLocalTime('H:mm:ss', 'en-us');
		local playerName = player.Name;
		local playerIngName = player:GetAttribute('CharacterName') or 'N/A';

		message = ('[%s] [%s] [%s] %s'):format(timeText, playerName, playerIngName, message);

		local textData = chatLogger:AddText({
			text = message,
			player = player
		});

		if (player == LocalPlayer) then
			table.insert(myChatLogs, textData);
			functions.streamerMode(library.flags.streamerMode);
		end;
	end;

	local function onPlayerAdded(player)
		if (player == LocalPlayer) then return end;

		local userId = player.UserId;

		if (library.flags.modNotifier and isModerator(player)) then
			moderators[player] = true;

			loadSound('ModeratorJoin.mp3');
			ToastNotif.new({
				text = ('Moderator Detected [%s]'):format(player.Name),
			});
		end;
	end;

	local function onPlayerRemoving(player)
		if (player == LocalPlayer) then return end;

		if (moderators[player]) then
			ToastNotif.new({
				text = ('Moderator Left [%s]'):format(player.Name),
			});

			loadSound('ModeratorLeft.mp3');
			moderators[player] = nil;
		end;
	end;

	library.OnLoad:Connect(function()
		local chatLoggerSize = library.configVars.chatLoggerSize;
		chatLoggerSize = chatLoggerSize and Vector2.new(unpack(chatLoggerSize:split(',')));

		local chatLoggerPosition = library.configVars.chatLoggerPosition;
		chatLoggerPosition = chatLoggerPosition and Vector2.new(unpack(chatLoggerPosition:split(',')));

		if (chatLoggerSize) then
			chatLogger:SetSize(UDim2.fromOffset(chatLoggerSize.X, chatLoggerSize.Y));
		end;

		if (chatLoggerPosition) then
			chatLogger:SetPosition(UDim2.fromOffset(chatLoggerPosition.X, chatLoggerPosition.Y));
		end;

		chatLogger:UpdateCanvas();
	end);

	library.OnLoad:Connect(function()
		Utility.listenToChildAdded(Players, onPlayerAdded);
		Utility.listenToChildRemoving(Players, onPlayerRemoving);
	end);

	chatLogger.OnPlayerChatted:Connect(onPlayerChatted);
end;

local function tweenTeleport(rootPart, position, noWait)
    local distance = (rootPart.Position - position).Magnitude;
    local tween = TweenService:Create(rootPart, TweenInfo.new(distance / 120, Enum.EasingStyle.Linear), {
        CFrame = CFrame.new(position)
    });

    tween:Play();

    if (not noWait) then
        tween.Completed:Wait();
    end;

    return tween;
end;

do -- // Removal Functions
    function functions.noFall(toggle)

    end;

    function functions.noStun(toggle)

    end;

    function functions.antiFire(toggle)
        if(not toggle) then
            maid.antiFire = nil;
            return;
        end;

        local character = LocalPlayer.Character;

        maid.antiFire = character.Values.OnFire.Changed:Connect(function(boolean)
            if(boolean) then
                character:WaitForChild("Communicate"):FireServer(unpack({{ Enabled = true,  Character = character,  InputType = "Dash"  }}))
            end;
        end);
    end;

    function functions.noStunLessBlatant(toggle)

    end;
end;


do -- // Removals

	playerMods:AddToggle({
		text = 'No Fall Damage',
		tip = 'Removes fall damage for you',
        callback = functions.NoFall
	});

	playerMods:AddToggle({
		text = 'No Stun',
		tip = 'Makes it so you will not get stunned in combat',
        callback = functions.noStun
	});

	playerMods:AddToggle({
		text = 'No Kill Bricks',
		tip = 'Removes all the kill bricks',
		callback = functions.noKillBricks
	});

	playerMods:AddToggle({
		text = 'No Fire Damage',
		flag = 'Anti Fire',
		tip = 'Prevent you from taking damage from fire.',
        callback = functions.antiFire
	});


	playerMods:AddToggle({
		text = 'No Stun Less Blatant',
		tip = 'Like no stun but it\'s less blatant',
        callback = functions.noStunLessBlatant
	});
end;

do -- // Local Cheats
	localCheats:AddDivider("Movement");

	localCheats:AddToggle({
		text = 'Fly',
		callback = functions.fly
	}):AddSlider({
		min = 16,
		max = 200,
		flag = 'Fly Hack Value'
	});

	localCheats:AddToggle({
		text = 'Speedhack',
		callback = functions.speedHack
	}):AddSlider({
		min = 16,
		max = 200,
		flag = 'Speed Hack Value'
	});

	localCheats:AddToggle({
		text = 'Infinite Jump',
		callback = functions.infiniteJump
	}):AddSlider({
		min = 50,
		max = 250,
		flag = 'Infinite Jump Height'
	});

	localCheats:AddToggle({
		text = 'No Clip',
		callback = functions.noClip
	});

	localCheats:AddToggle({
		text = 'Disable When Knocked',
		tip = 'Disables noclip when you get ragdolled',
		flag = 'Disable No Clip When Knocked'
	});

	localCheats:AddToggle({
		text = 'Click Destroy',
		tip = 'Everything you click on will be destroyed (client sided)',
		callback = functions.clickDestroy
	});

	localCheats:AddBind({text = 'Go To Ground', callback = functions.goToGround, mode = 'hold', nomouse = true});


	localCheats:AddDivider("Gameplay-Assist");

	localCheats:AddToggle({
		text = 'Auto Sprint',
		tip = 'Whenever you want to walk you sprint instead',
		callback = functions.autoSprint
	});

	localCheats:AddDivider("Combat Tweaks");

	localCheats:AddToggle({
		text = 'One Shot Mobs',
		tip = 'This feature randomly works sometimes and causes them to die',
	});

	localCheats:AddBind({
		text = 'Instant Log',
        tip  = 'Not finished',
		nomouse = true,
		callback = function()
			print('NEED TO FIX THIS PLEASE')
		end
	});

	localCheats:AddButton({
		text = 'Server Hop',
		tip = 'Jumps to any other server, non region dependant',
		callback = functions.serverHop
	});

	localCheats:AddBind({
		text = 'Attach To Back',
		tip = 'This attaches to the nearest entities back based on settings',
		callback = functions.attachToBack,
	});

	localCheats:AddSlider({
		text = 'Attach To Back Height',
		value = 0,
		min = -100,
		max = 100,
		textpos = 2
	});

	localCheats:AddSlider({
		text = 'Attach To Back Space',
		value = 2,
		min = -100,
		max = 100,
		textpos = 2
	});
end;

do --// Notifier
	notifier:AddToggle({
		text = 'Mod Notifier',
		state = true
	});

	notifier:AddToggle({
		text = 'Moderator Sound Alert',
		tip = 'Makes a sound when the mod joins',
		state = true
	});

	notifier:AddToggle({
		text = 'Blessing Notifier',
	});

	notifier:AddToggle({
		text = 'Player Proximity Check',
		tip = 'Gives you a warning when a player is close to you',
		callback = functions.playerProximityCheck
	});
end

do -- // Performance Functions
    function functions.disableShadows(t)
        Lighting.GlobalShadows = not t;
    end;

     do -- // FPS Boost
		local fpsBoostMaid = Maid.new();
		local hooked = {};

		function functions.fpsBoost(t)
			table.clear(hooked);
		end;

		task.spawn(function()
			if (isSynapseV3) then return warn('warning: we do not run fps boost on syn v3!'); end;
			while task.wait(1) do
				for _, v in next, getconnections(RunService.RenderStepped) do
					if (not v.Function) then continue end;
					local conScript = getinstancefromstate(v.State);
					if (not conScript or not checkName(conScript.Name)) then continue end;
					if (hooked[v.Function]) then continue end;
					fpsBoostMaid[conScript] = nil;

					local f = v.Function;

					hooked[f] = true;

					if (not library.flags.fpsBoost) then
						v:Enable();
					else
						v:Disable();
						fpsBoostMaid[conScript] = stepped:Connect(function(_, dt)
							if (not v.Function) then
								fpsBoostMaid[conScript] = nil;
								hooked[f] = nil;
								v:Enable();
								return print('no more func!');
							end;

							setscriptes(conScript);
							set_thread_identity(2);
							pcall(v.Function, dt);
						end);
					end;
				end;
			end;
		end);
	end;
end;

do -- // Misc
	misc:AddDivider('Perfomance Improvements');

	misc:AddToggle({
		text = 'FPS Boost',
		tip = 'Improves FPS by making game functions faster',
		callback = functions.fpsBoost
	});

	misc:AddToggle({
		text = 'Disable Shadows',
		tip = 'Disabling all shadows adds a large bump to your FPS',
		callback = functions.disableShadows
	});

	misc:AddDivider('Chat Logger');


	misc:AddDivider('Chat Logger', 'You can right click the chatlogger to report infractions.');

	misc:AddToggle({
		text = 'Chat Logger',
		tip = 'You can right click users on the chat logger to report them for infractions to the TOS',
		callback = functions.chatLogger
	});

	misc:AddToggle({
		text = 'Chat Logger Auto Scroll'
	});

	misc:AddToggle({
		text = 'Use Alt Manager To Block'
	});
end;

do -- // Visual Functions
    function functions.fullBright(toggle)
        if (not toggle) then
            maid.fullBright = nil;
            Lighting.Ambient, Lighting.Brightness = oldAmbient, oldBrightness;
            return;
        end;

        oldAmbient, oldBrightness = Lighting.Ambient, Lighting.Brightness;

        maid.fullBright = Lighting:GetPropertyChangedSignal('Ambient'):Connect(function()
            Lighting.Ambient = Color3.fromRGB(255, 255, 255);
            Lighting.Brightness = 0.1 * (library.flags['Full Bright Value'] or 1);
        end);

        Lighting.Ambient = Color3.fromRGB(255, 255, 255);
        Lighting.Brightness = 0.1 * (library.flags['Full Bright Value'] or 1);
    end;
end;

do -- // Visuals
    visuals:AddToggle({
        text = 'Full Bright'
    }):AddSlider({
        flag = 'Full Bright Value',
        min = 1,
        max = 10,
        value = 1,
    });
end;
