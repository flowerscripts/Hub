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

local Players, RunService, UserInputService, HttpService, CollectionService, MemStorageService, Lighting, TweenService, VirtualInputManager = Services:Get(
    'Players', 
    'RunService',
    'UserInputService', 
    'HttpService', 
    'CollectionService', 
    'MemStorageService', 
    'Lighting', 
    'TweenService', 
    'VirtualInputManager'
);

local LocalPlayer = Players.LocalPlayer;
local playerMouse = LocalPlayer:GetMouse();

local oldAmbient, oldBrightness;

local BodyMoverTag = 'good';

local myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');

local maid = Maid.new();

local localCheats = column1:AddSection('Local Cheats');
local notifier = column1:AddSection('Notifier');
local playerMods = column1:AddSection('Player Mods');
local misc = column2:AddSection('Misc');
local visuals = column2:AddSection('Visuals');
local farms = column2:AddSection('Farms');
local inventoryViewer = column2:AddSection('Inventory Viewer');

do -- // Inventory Viewer (SMH)
    local inventoryLabels = {};
    local itemColors = {};

    itemColors[100] = Color3.new(0.76862699999999995, 1, 0);
    itemColors[9] = Color3.new(1, 0.90000000000000002, 0.10000000000000001);
    itemColors[10] = Color3.new(0, 1, 0);
    itemColors[11] = Color3.new(0.90000000000000002, 0, 1);
    itemColors[3] = Color3.new(0, 0.80000000000000004, 1);
    itemColors[8] = Color3.new(0.17254900000000001, 0.80000000000000004, 0.64313699999999996);
    itemColors[7] = Color3.new(0.2588, 0.6588, 0.3490); -- Regular Spell
    itemColors[6] = Color3.new(1, 0, 0);
    itemColors[4] = Color3.new(0.82745100000000005, 0.466667, 0.207843);
    itemColors[0] = Color3.new(1, 1, 1);
    itemColors[5] = Color3.new(0.33333299999999999, 0, 1);
    itemColors[999] = Color3.new(0.792156, 0.792156, 0.792156);
    itemColors[87] = Color3.new(0.235, 0.714, 0.961); -- God Spell

    local function getToolType(tool)
        if (tool:FindFirstChild("PrimaryWeapon"))then
            return 0;
        elseif (tool:FindFirstChild("Skill") or tool:FindFirstChild('Activator')) then
            return 8;
        elseif (tool:FindFirstChild("Droppable")) then
            return 6;
        elseif (tool:FindFirstChild("Spell")) then
            if (tool:FindFirstChild('Godspell')) then
                return 87;
            end;
            return 7;
        elseif (tool:FindFirstChild("Trinket")) then
            return 4;
        elseif (tool:FindFirstChild("COWL")) then

            return 100;	
        elseif (tool:FindFirstChild("Active") or tool.Parent.Name == "Novachrono" or tool.Parent.Name == "Muto's Blood") then
            return 5;
        elseif (tool:FindFirstChild("Schematic")) then
            return 8;
        elseif (tool:FindFirstChild("Ingredient")) then
            return 10;
        elseif (tool:FindFirstChild("SpellIngredient")) then
            return 11;
        elseif (tool:FindFirstChild("Item")) then
            return 9;
        end

        return 999;
    end;

    local function showPlayerInventory(player)
        if (typeof(player) ~= 'Instance') then return end;

        for _, v in next, inventoryLabels do
            v.main:Destroy();
        end;

        inventoryLabels = {};

        local playerItems = {};
        local seen = {};
        local seenJSON = {};

        local function onBackpackChildAdded(tool)
            debug.profilebegin('onBackpackChildAdded');
            local toolName = tool:GetAttribute('DisplayName') or tool.Name:gsub('[^:]*:', ''):gsub('%$[^%$]*', '');
            local toolType = getToolType(tool);
            local weaponData = tool:FindFirstChild('WeaponData');

            xpcall(function()
                weaponData = seenJSON[weaponData] or HttpService:JSONDecode(weaponData.Value);
            end, function()
                weaponData = crypt.base64decode(weaponData.Value);
                weaponData = weaponData:sub(1, #weaponData - 2);

                weaponData = HttpService:JSONDecode(weaponData);
            end);

            if (typeof(weaponData) == 'table') then
                table.foreach(weaponData, warn);
                toolName = string.format('%s%s', toolName, (weaponData.Soulbound or weaponData.SoulBound) and ' [Soulbound]' or '');
            end;

            local exitingPlayerItem = seen[toolName];

            if (exitingPlayerItem) then
                exitingPlayerItem.quantity += 1;
                return;
            end;

            local playerItem =  {
                type = toolType,
                toolName = toolName,
                quantity = 1
            };

            table.insert(playerItems, playerItem);
            seen[toolName] = playerItem;
        end;

        for _, tool in next, player.Backpack:GetChildren() do
            task.spawn(onBackpackChildAdded, tool);
        end;

        table.sort(playerItems, function(a, b)
            return a.type < b.type;
        end);

        for _, v in next, playerItems do
            v.text = ('<font color="#%s">%s [x%d]</font>'):format(itemColors[v.type]:ToHex(), v.toolName, v.quantity);
            table.insert(inventoryLabels, inventoryViewer:AddLabel(v.text));
        end;
    end;

    inventoryViewer:AddList({
        text = 'Player',
        tip = 'Player to watch inventory for',
        playerOnly = true,
        skipflag = true,
        callback = showPlayerInventory
    });
end

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

        local myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');

		if (not myRootPart or not myRootPart.Parent) then return end;

		local floor = workspace:Raycast(myRootPart.Position, Vector3.new(0, -1000, 0), params);
		if(not floor or not floor.Instance) then return end;	

		myRootPart.CFrame *= CFrame.new(0, -(myRootPart.Position.Y - floor.Position.Y) + 3, 0);
		myRootPart.Velocity *= Vector3.new(1, 0, 1);
	end;

    library.OnKeyPress:Connect(function(input, gpe)
        if (gpe or not library.options.attachToBack) then return end;

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
        if (not library.options.attachToBack) then return end;
        local key = library.options.attachToBack.key;

        if (input.KeyCode.Name == key or input.UserInputType.Name == key) then
            maid.attachToBack = nil;
            maid.attachToBackTween = nil;
        end;
    end);
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
				local isKnocked = LocalPlayer.Character:FindFirstChild('Knocked') or LocalPlayer.Character:FindFirstChild('Ragdolled') or LocalPlayer.Character:FindFirstChild('ActuallyRagdolled');
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

    function functions.knockedOwnership(toggle)
        if(not toggle) then
            maid.knockedOwnership = nil;
            return;
        end;

        if(LocalPlayer.Character:FindFirstChild('Knocked')) then
            for _, newChild in LocalPlayer.Character:GetChildren() do
                if(newChild.Name == 'Ragdolled' or newChild.Name == 'ActuallyRagdolled') then
                    newChild:Destroy();
                end;
            end;

            LocalPlayer.Character.Knocked:Destroy();
        end;

        maid.knockedOwnership = LocalPlayer.Character.ChildAdded:Connect(function(child)
            if(child.Name == 'Knocked') then
                for _, newChild in LocalPlayer.Character:GetChildren() do
                    if(newChild.Name == 'Ragdolled' or newChild.Name == 'ActuallyRagdolled') then
                        newChild:Destroy();
                    end;
                end;
                child:Destroy();
            end;
        end);
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

			BlockUtils:BlockRandomUser();
			TeleportService:Teleport(4111023553);
		end;
	end;

    function functions.respawn(bypass)
		if(bypass or library:ShowConfirm('Are you sure you want to respawn?')) then
			LocalPlayer.Character.Humanoid.Health = 0;
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

        myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');

        maid.proximityCheck = RunService.Heartbeat:Connect(function()
            if (not myRootPart) then return end;

            for _, v in next, Players:GetPlayers() do
                local rootPart = v.Character and v.Character.PrimaryPart;
                if (not rootPart or v == LocalPlayer) then continue end;

                local distance = (myRootPart.Position - rootPart.Position).Magnitude;

                if (distance < 400 and not table.find(notifSend, rootPart)) then
                    table.insert(notifSend, rootPart);
                    ToastNotif.new({
                        text = string.format('%s is nearby [%d]', v.Name, distance),
                        duration = 30
                    });
                elseif (distance > 600 and table.find(notifSend, rootPart)) then
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
            if (gpe or tick() - lastRan < 0.35) then return end;

            if (table.find(moveKeys, input.KeyCode)) then
                lastRan = tick();

                VirtualInputManager:SendKeyEvent(true, input.KeyCode, false, game);
                VirtualInputManager:SendKeyEvent(true, input.KeyCode, false, game);

                --LocalPlayer.Character:WaitForChild("Communicate"):FireServer(unpack({{ InputType = "Sprinting",  Enabled = true }}))
            end;
        end);
    end;
end;

local myChatLogs = {};

local assetsList = {'ModeratorJoin.mp3', 'ModeratorLeft.mp3'};
local audios = {};

local apiEndpoint = 'https://rukiascripts.xyz/';

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
		Utility.listenToChildAdded(Players, onPlayerAdded);
		Utility.listenToChildRemoving(Players, onPlayerRemoving);
	end);
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
        if (not toggle) then
            maid.noFall = nil;
            return;
        end;

        local Humanoid = LocalPlayer.Character.Humanoid;

        local FloorMaterial = Humanoid.FloorMaterial;
        local OldPosition   = LocalPlayer.Character.HumanoidRootPart.Position;

        maid.noFall = Humanoid:GetPropertyChangedSignal('FloorMaterial'):Connect(function()
            local oldFloorMaterial = FloorMaterial;
            FloorMaterial = Humanoid.FloorMaterial;

            if (oldFloorMaterial == FloorMaterial) then return; end;

            if (oldFloorMaterial == Enum.Material.Air) then
                LocalPlayer.Character:WaitForChild("Communicate"):FireServer(unpack({{  InputType = "Crouching", Enabled = true }}))

                task.delay(0.1, function()
                    LocalPlayer.Character:WaitForChild("Communicate"):FireServer(unpack({{  InputType = "Crouching", Enabled = false }}))
                end);
            end;
        end);
    end;

    function functions.noStun(toggle)

    end;

    function functions.antiFire(toggle)
        if(not toggle) then
            maid.antiFire = nil;
            return;
        end;

        maid.antiFire = LocalPlayer.Character.ChildAdded:Connect(function(child)
            if(child and child.Name == 'Burning') then
                LocalPlayer.Character:WaitForChild("Communicate"):FireServer(unpack({{ Enabled = true,  Character = LocalPlayer.Character,  InputType = "Dash"  }}))
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
        callback = functions.noFall
	});

	playerMods:AddToggle({
		text = 'No Stun',
		tip = 'Makes it so you will not get stunned in combat',
        callback = functions.noStun
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
	})
    localCheats:AddSlider({
		min = 16,
		max = 200,
		flag = 'Fly Hack Value',
        textpos = 2
	});

	localCheats:AddToggle({
		text = 'Speedhack',
		callback = functions.speedHack
	})
    localCheats:AddSlider({
		min = 16,
		max = 200,
		flag = 'Speed Hack Value',
        textpos = 2
	});

	localCheats:AddToggle({
		text = 'Infinite Jump',
		callback = functions.infiniteJump
	})
    localCheats:AddSlider({
		min = 50,
		max = 250,
		flag = 'Infinite Jump Height',
        textpos = 2
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
		text = 'Knocked Ownership',
		tip = 'Allow you to fly/move while being knocked.',
        callback = functions.knockedOwnership
	})

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

    localCheats:AddButton({
		text = 'Respawn',
		tip = 'Kills the character prompting it to respawn',
		callback = functions.respawn
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
end;


local NPCFolder = workspace.NPCs;

local Armors, Weapons, Items, NPCs = {}, {}, {}, {};
local ArmorSelected, WeaponSelected, ItemSelected, NPCSelected;

do -- // Load All Buyables
    for _, child in NPCFolder:GetChildren() do
        if (child.Name == 'Purchasable') then
            local PurchaseInfo = child.PurchaseInfo;
            local ItemType = PurchaseInfo.ItemType;
            local ItemName = PurchaseInfo.ItemName;

            if (ItemType.Value == 'Armor') then
                Armors[ItemName.Value] = true;
            elseif (ItemType.Value == 'Weapon') then
                Weapons[ItemName.Value] = true;
            elseif (ItemType.Value == 'Item' or ItemType.Value == 'Trinket') then
                Items[ItemName.Value] = true;
            end;
        else
            if (not NPCs[child.Name]) then
                NPCs[child.Name] = true;
            end;
        end;
    end;
end;

do -- // Opens dialogue stuff
    function functions.buyItem(name)
        for _, child in NPCs:GetChildren() do
            if (child.Name == 'Purchasable') then
                local PurchaseInfo = child.PurchaseInfo;
                local ItemName = PurchaseInfo.ItemName;

                if (ItemName.Value == name) then
                    fireclickdetector(child.ClickDetector);
                end;
            end;
        end;
    end;

    function functions.interactWithNPC(name)
        for _, child in NPCs:GetChildren() do
            if (child.Name == name) then
                fireclickdetector(child.ClickDetector);
            end;
        end;
    end;
end;

do -- // Misc
	misc:AddDivider('Buyables');

    misc:AddList({
        text = 'Select Armor',
        tip = 'Select the Armor you wish to buy.',
        values = Armors;
        multiselect = false,
        callback = function(name)
            ArmorSelected = name;
        end,
    });

    misc:AddButton({
		text = 'Buy Armor',
		tip = 'Buys the Armor you selected.',
        callback = function()
            functions.buyItem(ArmorSelected);
        end,
	});

    misc:AddList({
        text = 'Select Weapon',
        tip = 'Select the Weapon you wish to buy.',
        values = Weapons;
        multiselect = false,
        callback = function(name)
            WeaponSelected = name;
        end,
    });

    misc:AddButton({
		text = 'Buy Weapon',
		tip = 'Buys the Weapon you selected.',
        callback = function()
            functions.buyItem(WeaponSelected);
        end,
	});

    misc:AddList({
        text = 'Select Item',
        tip = 'Select the Item you wish to buy.',
        values = Items;
        multiselect = false,
        callback = function(name)
            ItemSelected = name;
        end,
    });

    misc:AddButton({
		text = 'Buy Item',
		tip = 'Buys the Item you selected.',
        callback = function()
            functions.buyItem(ItemSelected);
        end,
	});

    misc:AddDivider('NPCs');

    misc:AddList({
        text = 'Select NPC',
        tip = 'Select the NPC you wish to interact with.',
        values = NPCs;
        multiselect = false,
        callback = function(name)
            NPCSelected = name;
        end,
    });

    misc:AddButton({
		text = 'Interact with NPC',
		tip = 'Interacts with the NPC you selected.',
        callback = function()
            functions.interactWithNPC(NPCSelected);
        end,
	});

	misc:AddDivider('Perfomance Improvements');

	misc:AddToggle({
		text = 'Disable Shadows',
		tip = 'Disabling all shadows adds a large bump to your FPS',
		callback = functions.disableShadows
	});
end;

function functions.fullBright(toggle)
    if (not toggle) then
        maid.fullBright = nil;
        Lighting.Ambient = oldAmbient;
        Lighting.Brightness = oldBrightness;
        return;
    end;

    oldAmbient = Lighting.Ambient;
    oldBrightness = Lighting.Brightness;

    maid.fullBright = Lighting:GetPropertyChangedSignal('Ambient'):Connect(function()
        Lighting.Ambient = Color3.fromRGB(255, 255, 255);
        Lighting.Brightness = 1;
    end);

    Lighting.Ambient = Color3.fromRGB(255, 255, 255);
    Lighting.Brightness = 1;
end;


do -- // Visuals
    visuals:AddToggle({
        text = 'Full Bright',
        callback = functions.fullBright
    })
end;
