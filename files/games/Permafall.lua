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

local Players, RunService, UserInputService, HttpService, CollectionService, MemStorageService, Lighting, TweenService, VirtualInputManager, ReplicatedFirst, TeleportService, ReplicatedStorage = Services:Get(
    'Players', 
    'RunService',
    'UserInputService', 
    'HttpService', 
    'CollectionService', 
    'MemStorageService', 
    'Lighting', 
    'TweenService', 
    'VirtualInputManager',
    'ReplicatedFirst',
    'TeleportService',
    'ReplicatedStorage'
);

local LocalPlayer = Players.LocalPlayer;
local playerMouse = LocalPlayer:GetMouse();

local maid = Maid.new();

local localCheats = column1:AddSection('Local Cheats');
local notifier = column1:AddSection('Notifier');
local playerMods = column1:AddSection('Player Mods');
local automation = column2:AddSection('Automation');
local misc = column2:AddSection('Misc');
local visuals = column2:AddSection('Visuals');
local farms = column2:AddSection('Farms');
local inventoryViewer = column2:AddSection('Inventory Viewer');

local IsA = game.IsA;
local FindFirstChild = game.FindFirstChild;
local FindFirstChildWhichIsA = game.FindFirstChildWhichIsA;
local IsDescendantOf = game.IsDescendantOf;

local Trinkets = {};
local playerClassesList = {};

local rayParams = RaycastParams.new();
rayParams.FilterDescendantsInstances = {workspace.Live};
rayParams.FilterType = Enum.RaycastFilterType.Blacklist;

local NPCFolder = workspace.NPCs;

local Armors, Weapons, Items, NPCs = {}, {}, {}, {};
local ArmorSelected, WeaponSelected, ItemSelected, NPCSelected;

local Thrown = workspace.Thrown;
local Map    = workspace.Map;

local oldAmbient, oldBrightness;

local BodyMoverTag = 'good';

local myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');

local DUNGEON_PLACE_ID = 89371625020632;

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
                CollectionService:AddTag(maid.speedHackBv, 'DONTDELETE');
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
                CollectionService:AddTag(maid.flyBv, 'DONTDELETE');
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
			TeleportService:Teleport(89371625020632);
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
    -- // AUTO SPRINT LOGIC

    function functions.autoSprint(toggle)
        if (not toggle) then
            maid.autoSprint = nil
            return
        end
        maid.autoSprint = true

        -- Force a check immediately when W is pressed
        maid.sprintLoop = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.KeyCode == Enum.KeyCode.W then
                -- This signals the game's remote that we want to sprint
                local remote = LocalPlayer.Character:FindFirstChild("Communicate") -- Update path if needed
                if remote then
                    remote:FireServer({
                        ["InputType"] = "Sprinting",
                        ["Enabled"] = true
                    })
                end
            end
        end)
    end
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

do -- // Mod Logs
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

            if (library.flags.panicOnModeratorJoin and not FindFirstChild(LocalPlayer.Character, 'Danger')) then
                LocalPlayer.Character.Communicate:FireServer({
                    ["Character"] = LocalPlayer.Character,
                    ["InputType"] = "menu",
                    ["Enabled"] = true
                })
            end;
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

do -- // Core Hook
    local function onCharacterAdded(character)
        if(not character) then return end;

        task.delay(1,function()
            ReplicatedStorage.GetMouseHit.OnClientInvoke = function()
                playerMouse = LocalPlayer:GetMouse();

                mouseHit = playerMouse.Hit;

                if (library.flags.autoAimSpells) then
                    local target = Utility:getClosestCharacter(rayParams);
                    target = target and target.Character;

                    if (target and target.Head) then
                        mouseHit = target.Head.CFrame;
                    end;
                end;

                return mouseHit;
            end;
        end);
    end;

    onCharacterAdded(LocalPlayer.Character);
    LocalPlayer.CharacterAdded:Connect(onCharacterAdded);

    local oldNamecall;

    oldNamecall = hookmetamethod(game, '__namecall', function(self, ...)
        local args = {...}

        if (getnamecallmethod() == 'FireServer' and self.Name == 'Communicate') then
            if (type(args[1]) == 'table' and args[1].InputType) then
                local InputType = args[1].InputType;

                if (library.flags.noFallDamage and InputType == 'Landed') then
                    -- // Change StudsFallen to 0 so we take no damage and effectively stop "FallDamage". 
                    args[1].StudsFallen = 0
                    -- // If legitNoFall is enabled then it'll perfect roll everytime you take "FallDamage". However, you still take 0 damage it just makes it look legit.
                    args[1].FallBrace = library.flags.legitNoFall or false;
                    
                    return oldNamecall(self, unpack(args));
                end;
            end;
        end;

        return oldNamecall(self, ...);
    end);
end;

do -- // Removal Functions

    function functions.noStun(toggle)
          if(not toggle) then
            maid.noStun = nil;
            return;
        end;

        local function removeStun(child)
            if(child and child.Name == 'Stun') then
                task.defer(function()
                    child:Destroy();
                end);
            end;
        end;

        for _, child in LocalPlayer.Character:GetChildren() do
            removeStun(child);
        end;

        maid.noStun = LocalPlayer.Character.ChildAdded:Connect(removeStun)
    end;

    function functions.antiFire(toggle)
        if(not toggle) then
            maid.antiFire = nil;
            return;
        end;

        local function removeFire(child)
            if(child and child.Name == 'Burning') then
                task.defer(function()
                    LocalPlayer.Character:WaitForChild("Communicate"):FireServer(unpack({{ Enabled = true,  Character = LocalPlayer.Character,  InputType = "Dash"  }}))
                end);
            end;
        end;

        for _, child in LocalPlayer.Character:GetChildren() do
            removeFire(child);
        end;

        maid.antiFire = LocalPlayer.Character.ChildAdded:Connect(removeFire)
    end;

    do -- One Shot NPCs
		local mobs = {};

		local NetworkOneShot = {};
		NetworkOneShot.__index = NetworkOneShot;

		function NetworkOneShot.new(mob)
			local self = setmetatable({},NetworkOneShot);

			self._maid = Maid.new();
			self.char = mob;

			self._maid:GiveTask(mob.Destroying:Connect(function()
				self:Destroy();
			end));

			self._maid:GiveTask(Utility.listenToChildAdded(mob, function(obj)
				if (obj.Name == 'HumanoidRootPart') then
					self.hrp = obj;
				end;
			end));

			mobs[mob] = self;
			return self;
		end;

		function NetworkOneShot:Update()
			if (not self.hrp or not isnetworkowner(self.hrp) or not self.hrp.Parent or self.hrp.Parent.Parent ~= workspace.Live) then return end;
			self.char:PivotTo(CFrame.new(self.hrp.Position.X, workspace.FallenPartsDestroyHeight - 100000, self.hrp.Position.Z));
		end;

		function NetworkOneShot:Destroy()
			self._maid:DoCleaning();

			for i,v in next, mobs do
				if (v ~= self) then continue; end
				mobs[i] = nil;
			end;
		end;

		function NetworkOneShot:ClearAll()
			for _, v in next, mobs do
				v:Destroy();
			end;

			table.clear(mobs);
		end;

		Utility.listenToChildAdded(workspace.Live, function(obj)
			task.wait(0.2);
			if (obj == LocalPlayer.Character) then return; end
			NetworkOneShot.new(obj);
		end);

		function functions.networkOneShot(t)
			if (not t) then
				maid.networkOneShot = nil;
				maid.networkOneShot2 = nil;
				return;
			end;

			maid.networkOneShot2 = RunService.Heartbeat:Connect(function()
				sethiddenproperty(LocalPlayer, 'MaxSimulationRadius', math.huge);
				sethiddenproperty(LocalPlayer, 'SimulationRadius', math.huge);
			end);

			maid.networkOneShot = task.spawn(function()
				while task.wait() do
					for _, mob in next, mobs do
						mob:Update();
					end;
				end;
			end);
		end;
	end;
end;

do -- // Removals

	playerMods:AddToggle({
		text = 'No Fall Damage',
		tip = 'Removes fall damage for you',
	});

    playerMods:AddToggle({
        text = 'Legit No Fall',
        tip = ' Removes fall damage but still rolls'
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
end;

do -- // Local Cheats
	localCheats:AddDivider("Movement");

	localCheats:AddToggle({
		text = 'Fly',
		callback = functions.fly
	})
    localCheats:AddSlider({
		min = 16,
		max = 250,
		flag = 'Fly Hack Value',
        textpos = 2
	});

	localCheats:AddToggle({
		text = 'Speedhack',
		callback = functions.speedHack
	})
    localCheats:AddSlider({
		min = 16,
		max = 250,
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

	-- localCheats:AddToggle({
	-- 	text = 'No Clip',
	-- 	callback = functions.noClip
	-- });

	-- localCheats:AddToggle({
	-- 	text = 'Disable When Knocked',
	-- 	tip = 'Disables noclip when you get ragdolled',
	-- 	flag = 'Disable No Clip When Knocked'
	-- });

    localCheats:AddToggle({
		text = 'Knocked Ownership',
		tip = 'Allow you to fly/move while being knocked.',
        callback = functions.knockedOwnership
	})

	-- localCheats:AddToggle({
	-- 	text = 'Click Destroy',
	-- 	tip = 'Everything you click on will be destroyed (client sided)',
	-- 	callback = functions.clickDestroy
	-- });

	localCheats:AddBind({text = 'Go To Ground', callback = functions.goToGround, mode = 'hold', nomouse = true});

	localCheats:AddDivider("Gameplay-Assist");

    localCheats:AddToggle({
		text = 'Auto Aim Spells',
        tip = 'Automatically aims the spell (sagitta, pulso, etc) onto the nearest characters head.'
	});

	localCheats:AddToggle({
		text = 'Auto Sprint',
		tip = 'Whenever you want to walk you sprint instead',
		callback = functions.autoSprint
	});

	localCheats:AddDivider("Combat Tweaks");

    localCheats:AddToggle({
		text = 'One Shot Mobs',
		tip = 'This feature randomly works sometimes and causes them to die, but it makes AP have issues',
		callback = functions.networkOneShot
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

    localCheats:AddBind({
		text = 'Instant Log',
		nomouse = true,
		callback = function()
            LocalPlayer.Character.Communicate:FireServer({
                ["Character"] = LocalPlayer.Character,
                ["InputType"] = "menu",
                ["Enabled"] = true
            })
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
end;

do --// Notifier
	notifier:AddToggle({
		text = 'Mod Notifier',
		state = true
	});

    notifier:AddToggle({
		text = 'Panic on Moderator Join'
	});

	notifier:AddToggle({
		text = 'Moderator Sound Alert',
		tip = 'Makes a sound when the mod joins',
		state = true
	});

    if (game.PlaceId == DUNGEON_PLACE_ID) then
        notifier:AddToggle({
            text = 'Blessing Notifier',
        });

        notifier:AddToggle({
            text = 'Race Reroll Notifier',
        });
    end;

	notifier:AddToggle({
		text = 'Player Proximity Check',    
		tip = 'Gives you a warning when a player is close to you',
		callback = functions.playerProximityCheck
	});
end

local weatherParts = {'Rain', 'Snow'};
local movedParts = {};

do -- // Performance Functions
    function functions.disableShadows(t)
        Lighting.GlobalShadows = not t;
    end;

    function functions.disableWeatherEffects(t)
        if (not t) then
            for part, _ in pairs(movedParts) do
                if (part and part.Parent == ReplicatedFirst) then
                    part.Position = LocalPlayer.Character.Head.Position + Vector3.new(0, 10, 0);
                    part.Parent = Thrown;
                end;
            end;

            table.clear(movedParts);
            return;
        end;

        for _, weatherName in weatherParts do
            local weatherPart = Thrown:FindFirstChild(weatherName);
            if (weatherPart) then
                weatherPart.Parent = ReplicatedFirst;
                movedParts[weatherPart] = true;
            end;
        end;
    end;
end;

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
                CollectionService:AddTag(child, 'NPC');
            end;
        end;
    end;
end;

do -- // Automation Functions

    function functions.pickupItem(item, data)
        local isSilver = data.isSilver;
        local isChestCoin = data.isChestCoin;
        local isChestLoot = data.isChestLoot;

        if (not item) then return end;
        
        if (isChestCoin and item.Name ~= 'ChestCoin') then return end;
        if (isChestLoot and not item.Name:find('Chest') and item.Name ~= 'GoldBar') then return end;
        if (not isChestCoin and not isSilver and not isChestLoot and not item.Name:find('Dropped_')) then return end;
        if (isSilver and item.Name ~= 'ChestSIlver' and not item.Name:find('Dropped_')) then return end;
        
        local hasSilver = item:GetAttribute('Silver') and item:GetAttribute('Silver') ~= 0;

        if (not isChestCoin and not isChestLoot) then
            if (not isSilver and hasSilver) then return end;
            if (isSilver and not hasSilver) then return end;
            if (isSilver and library.flags.safePickupSilver and item:GetAttribute('Silver') >= 2000) then return end;
        end;

        if (isChestLoot and item:IsA('BasePart')) then
            if (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')) then
                LocalPlayer.Character.HumanoidRootPart.CFrame = item.CFrame;
            end;
        else
            local touchInterest = item:FindFirstChildWhichIsA('TouchTransmitter');
            if (touchInterest) then 
                firetouchinterest(LocalPlayer.Character.HumanoidRootPart, item, 0);
            end;
        end;
    end;

    maid.newThrownChild = Thrown.ChildAdded:Connect(function(child)
        task.wait(0.05);
        
        local hasSilver = child:GetAttribute('Silver') and child:GetAttribute('Silver') ~= 0;
        
        if (library.flags.autoPickupSilver and hasSilver) then
            functions.pickupItem(child, {
                isSilver = true;
            });
        end;
        
        if (library.flags.autoPickupBags and not hasSilver) then
            functions.pickupItem(child, {
                isSilver = false;
            });
        end;

        if (library.flags.autoPickupChestLoot) then
            functions.pickupItem(child, {
                isChestLoot  = true;
            });
        end;
    end);
end;

do -- // Automation
    automation:AddDivider('Pickup')

    automation:AddToggle({
        text = 'Auto Pickup Bags',
        tip = 'Automatically picks up any Bags that get dropped.',
        callback = function(state)
            if (state) then
                for _, child in Thrown:GetChildren() do
                    local hasSilver = child:GetAttribute('Silver') and child:GetAttribute('Silver') ~= 0;
                    if (not hasSilver) then
                        functions.pickupItem(child, {
                            isSilver = false;
                        });
                    end;
                end;
            end;
        end
    })

    automation:AddToggle({
        text = 'Auto Pickup Silver',
        tip = 'Automatically picks up any silver that get dropped. [WARNING: THEY HAVE LOGS FOR SILVER PICKUPS]',
        callback = function(state)
            if (state) then
                for _, child in Thrown:GetChildren() do
                    local hasSilver = child:GetAttribute('Silver') and child:GetAttribute('Silver') ~= 0;
                    if (hasSilver) then
                        functions.pickupItem(child, {
                            isSilver = true;
                        });
                    end;
                end;
            end;
        end;
    });

    automation:AddToggle({
        text = 'Safe Pickup Silver',
        tip = 'Safely picks up silver (under 2,000 silver because 2,000+ triggers logs)', 
        callback = function(state)
            if (not library.flags.autoPickupSilver) then
               ToastNotif.new({
                    text = 'This feature requires Auto Pickup Silver to be enabled!',
                    duration = 5
                });
            end;
        end;
    });

    automation:AddToggle({
        text = 'Auto Pickup Chest Loot',
        tip = 'Automatically picks up any loot from chests',
        callback = function(state)
            if (state) then
                for _, child in Thrown:GetChildren() do
                    if (child and child:IsA('BasePart') and child.Name:find('Chest')) then
                        functions.pickupItem(child, {
                            isChestCoin = true;
                        });
                    end;
                end;
            end;
        end;
    });    
end;

do -- // Opens dialogue stuff
    function functions.buyItem(name)
        for _, child in NPCFolder:GetChildren() do
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
        for _, child in NPCFolder:GetChildren() do
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

    	misc:AddToggle({
		text = 'Disable Weather Effects',
		tip = 'Disables Weather Effects because Rain and Snow tank your FPS',
		callback = functions.disableWeatherEffects
	});
end;

function functions.fullBright(toggle)
    if (not toggle) then
        maid.fullBright = nil;
        if (oldAmbient) then
            Lighting.Ambient = oldAmbient;
            Lighting.Brightness = oldBrightness;
            oldAmbient = nil;
            oldBrightness = nil;
        end
        return;
    end;

    if (not maid.fullBright) then
        oldAmbient = Lighting.Ambient;
        oldBrightness = Lighting.Brightness;
    end;

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

local areaNames = {
    'Bossfight';
    'Boxing Bar';
    'Camp';
    'Castle';
    'Cliffs';
    'DungeonEntrance';
    'HideoutOrderly';
    'Loading';
    'SecretDoor';
    'Sky Islands';
    'Tavern';
}

do -- // Setup ESP Data
    playerClassesList = {
        -- // Chaotic Classes

        ['Brawler'] = {
            ['Active'] = {'Body Grinder', 'Bruising Drop', 'Rib Crusher', 'Swift Kick'};
        },
       
        ['Greatsword'] = {
            ['Active'] = {'Heart Thrust', 'Earth Shaker', 'Rising Cyclone'};
        },

        ['Assassin'] = {
            ['Active'] = {'Death Bound', 'Raijin', 'Toxic Slice', 'True Trickery'};
        },

        ['Ronin'] = {
            ['Active'] = {'Ruinous Burst', 'Favour from fang', 'Sly Shadow', 'Deep Slash'};
        },

        ['Bladesman'] = {
            ['Active'] = {'Twin Slashes', 'Deadly Cascade', 'Deep Slash'};
        },

        ['Wraith'] = {
            ['Active'] = {'Impulsing Staff', 'Midway Strike', 'Enchain', 'Rebound Haul', 'Destined Impact'};
            ['Passive'] = {'Chain Link'};
        },

        -- // Orderly Classes

        ['Monk'] = {
            ['Active'] = {'Spirit Palm', 'Loop Kicks', 'Ankle Breaker', 'Kickoff Leap'};
        },

        ['Lumen'] = {
            ['Active'] = {'Protege Solum', 'Sagitta Lucem', 'Laqueus Lucis'};
            ['Passive'] = {'Mage Training'};
        },

         ['Piandao'] = {
            ['Active'] = {'Blink', 'Lightning Slash', 'AfterImage'};
        }
     };
     
    Trinkets = {
        { 
            ['Name'] = 'Goblet', 
            ['MeshId'] = 'rbxassetid://13116112' 
        },

        { 
            ['Name'] = 'Amethyst', 
            ['MeshId'] = 'rbxassetid://%202877143560%20', 
            ['Color'] = Color3.fromRGB(167, 95, 209) 
        },

        { 
            ['Name'] = 'Diamond', 
            ['MeshId'] = 'rbxassetid://%202877143560%20', 
            ['Color'] = Color3.fromRGB(248, 248, 248) 
        },

        { 
            ['Name'] = 'Sapphire', 
            ['MeshId'] = 'rbxassetid://%202877143560%20', 
            ['Color'] = Color3.fromRGB(0, 0, 255) 
        },

        { 
            ['Name'] = 'Pure Diamond', 
            ['MeshId'] = 'rbxassetid://%202877143560%20', 
            ['Color'] = Color3.fromRGB(18, 238, 212) 
        },

        { 
            ['Name'] = 'Ruby', 
            ['MeshId'] = 'rbxassetid://%202877143560%20', 
            ['Color'] = Color3.fromRGB(255, 0, 0) 
        },

        {
            ['Name'] = 'Emerald', 
            ['MeshId'] = 'rbxassetid://%202877143560%20', 
            ['Color'] = Color3.fromRGB(31, 128, 29) 
        },

        { 
            ['Name'] = 'Opal', 
            ['MeshType'] = 'Sphere' 
        }, 

        { 
            ['Name'] = 'Scroll', 
            ['MeshId'] = 'rbxassetid://60791940' 
        },

        {
            ['Name'] = 'Ring', 
            ['MeshId'] = 'rbxassetid://%202637545558%20' 
        },
    };

    if (game.PlaceId == DUNGEON_PLACE_ID) then
        Chests = {
            {
                ['Name'] = 'Trinket',
            },

            {
                ['Name'] = 'Silver',
            },

            {
                ['Name'] = 'Gold',
            },
            
            {
                ['Name'] = 'Race Reroll',
            },

            {
                ['Name'] = 'Chest Food',
            },

            {
                ['Name'] = 'Blessing',
            },
        }
    else
        Chests = {
            {
                ['Name'] = 'Chest Coin'
            }
        }
    end; 
    
    Mobs = {
        {
            ['Name'] = 'Goblin';
        },

        {
            ['Name'] = '#HITBOX_SIMULATION';
        },

         {
            ['Name'] = 'Blue Orb';
        },

        {
            ['Name'] = 'Hobo';
        }
    }
end;


--[[
    CanOpen == serverSided boolean (to be able to open chest)
    opened == serverSided folder (to detect if chest is already opened)
]]

do -- // ESP Function Helpers
    function functions.getPlayerClass(player)
        if (not player) then return 'Freshie' end;
        local Backpack = player.Backpack;
        local classCounts = {};
        
        for className, classData in pairs(playerClassesList) do
            classCounts[className] = 0;
            
            for _, activeName in ipairs(classData.Active) do
                if (Backpack:FindFirstChild(activeName)) then
                    classCounts[className] = classCounts[className] + 1;
                end;
            end;
        end;
        
        local bestClass = 'Freshie';
        local highestCount = 0;
        
        for className, count in pairs(classCounts) do
            if (count > highestCount) then
                highestCount = count;
                bestClass = className;
            end;
        end;
        
        return highestCount > 0 and bestClass or 'Freshie';
     end;

    function functions.getTrinket(handle)
        if (not handle) then return nil end;
        local Mesh = handle:FindFirstChild('Mesh') or handle:FindFirstChildWhichIsA('SpecialMesh');
        if (not Mesh) then return nil end;

        local MeshId      = Mesh.MeshId;
        local MeshType    = Mesh.MeshType.Name;
        local HandleColor = handle.Color;

        if (MeshType == 'Sphere') then
            for _, trinket in Trinkets do
                if (trinket.Name == 'Opal') then return trinket end;
            end;
        end;

        for _, trinket in Trinkets do
            if (trinket.MeshId and trinket.MeshId == MeshId) then
                if (trinket.Color) then
                    if (HandleColor == trinket.Color) then
                        return trinket;
                    end;
                else
                    return trinket;
                end;
            end;
        end;

        local MeshIdNormal = tostring(MeshId):gsub('%D', '')
        for _, trinket in ipairs(Trinkets) do
            if (trinket.MeshId and tostring(trinket.MeshId):gsub('%D', '') == MeshIdNormal) then
                return trinket;
            end;
        end;

        return nil;
    end;
end;

do -- // ESP Functions
    local function formatMobName(mobName)
        if (not mobName:match('%.(.-)%d+')) then return mobName end;
        local allMobLetters = mobName:match('%.(.-)%d+'):gsub('_', ' '):split(' ');

        for i, v in next, allMobLetters do
            local partialLetters = v:split('');
            partialLetters[1] = partialLetters[1]:upper();

            allMobLetters[i] = table.concat(partialLetters);
        end;

        return table.concat(allMobLetters, ' ');
    end;

    function EntityESP:Plugin()
        local classText = '';

        if (library.flags.showClass) then
            local playerClass = functions.getPlayerClass(self._player);
            classText = ' [' .. playerClass .. ']';
        end;

        return {
            text = classText,
            playerName = self._playerName,
        };
    end;

    function functions.onNewTrinketAdded(spawnPart, espConstructor)
        if (spawnPart.Name ~= 'SPAWN') then return end;

        local Handle = FindFirstChild(spawnPart, 'Handle');
        if (not Handle) then return end;

        local Trinket = functions.getTrinket(Handle);
        if (not Trinket) then return end;

        local code = [[
            local Handle = ...;
            return setmetatable({}, {
                __index = function(_, p)
                    if (p == 'Position') then
                        return Handle.Position;
                    end;
                end,
            });
        ]];

        local espObj = espConstructor.new({ code = code, vars = { Handle } }, Trinket.Name);
 
        local connection;
        connection = Handle:GetPropertyChangedSignal('Parent'):Connect(function()
            if (not Handle.Parent) then
                espObj:Destroy();
                connection:Disconnect();
            end;
        end);
    end;

    function functions.onDroppedItemAdded(item, espConstructor)
        if (not item or not item.Name:find('Dropped_')) then return end;

        local itemName = item.Text.TextLabel.Text;
        
        local itemObj;
        
        if (item:IsA('BasePart') or item:IsA('MeshPart')) then
            itemObj = espConstructor.new(item, itemName);
        else
            local code = [[
                local item = ...;
                return setmetatable({}, {
                    __index = function(_, p)
                        if (p == 'Position') then
                            return item.PrimaryPart and item.PrimaryPart.Position or item.WorldPivot.Position
                        end;
                    end,
                });
            ]]

            itemObj = espConstructor.new({code = code, vars = {item}}, itemName);
        end;
        
        local connection;
        connection = item:GetPropertyChangedSignal('Parent'):Connect(function()
            if (not item.Parent) then
                itemObj:Destroy();
                connection:Disconnect();
            end;
        end);
    end;

    function functions.onNewMobAdded(mob, espConstructor)
        if (FindFirstChild(Players, mob.Name)) then return end;

        local editedMobName;

        if (mob.Name == 'generate') then
            if (FindFirstChild(Thrown, 'Chest1')) then
                editedMobName = 'Hobo';
            end;
        elseif (mob.Name == 'HITBOX_SIMULATION#') then
            if (FindFirstChild(mob, 'CaveDungeon') and FindFirstChild(mob, 'IsNPC') and FindFirstChild(mob, 'NoRagdoll')) then
                editedMobName = 'Blue Orb';
            end;
        end;

        local code = [[
            local mob = ...;
            local FindFirstChild = game.FindFirstChild;
            local FindFirstChildWhichIsA = game.FindFirstChildWhichIsA;

            return setmetatable({
                FindFirstChildWhichIsA = function(_, ...)
                    return FindFirstChildWhichIsA(mob, ...);
                end,
            }, {
                __index = function(_, p)
                    if (p == 'Position') then
                        local mobRoot = FindFirstChild(mob, 'HumanoidRootPart');
                        return mobRoot and mobRoot.Position;
                    end;
                end,
            })
        ]];

        local formattedName = formatMobName(editedMobName or mob.Name);
        local mobEsp = espConstructor.new({code = code, vars = {mob}}, formattedName);

        local connection;
        connection = mob:GetPropertyChangedSignal('Parent'):Connect(function()
            if (not mob.Parent) then
                connection:Disconnect();
                mobEsp:Destroy();
            end;
        end);
    end;

    function functions.onNewChestAdded(chest, espConstructor)
        if (not chest.Name:find('Chest')) then return end;
        if (chest.Name == 'ChestSIlver') then return end;
        local chestName = chest.Name;

        local isChestOpened = FindFirstChild(chest, 'Opened');
        if (isChestOpened and library.flags.hideOpenedChests) then return end;
     
        if (chestName == 'Chest1') then
            local typeOfChest = FindFirstChild(chest, 'Silver') or FindFirstChild(chest, 'Trinket');

            chestName = typeOfChest.Name or 'unknown type';
        elseif (chestName == 'Chest2') then
            chestName = 'Gold';
        elseif (chestName == 'ChestFood') then
            chestName = 'Chest Food';
        elseif (chestName == 'ChestRR') then
            chestName = 'Race Reroll';

            if (library.flags.raceRerollNotifier) then
                ToastNotif.new({
                    text = 'A Race Reroll has spawned!'
                });
            end;
        elseif (chestName == 'Chest Coin') then
            chestName = 'Chest Coin';
        elseif (chestName == 'ChestBlue') then
            chestName = 'Blessing';

            if (library.flags.blessingNotifier) then
                ToastNotif.new({
                    text = 'A Blessing has spawned!'
                });
            end;
        end;
        
        local chestObj;
        if (chest:IsA('BasePart') or chest:IsA('MeshPart')) then
            chestObj = espConstructor.new(chest, chestName);
        else
            local code = [[
                local chest = ...;
                return setmetatable({}, {
                    __index = function(_, p)
                        if (p == 'Position') then
                            return chest.PrimaryPart and chest.PrimaryPart.Position or chest.WorldPivot.Position
                        end;
                    end,
                });
            ]]

            chestObj = espConstructor.new({code = code, vars = {chest}}, chestName);
        end;
        
        local connection;
        connection = chest:GetPropertyChangedSignal('Parent'):Connect(function()
            if (not chest.Parent) then
                chestObj:Destroy();
                connection:Disconnect();
            end;
        end);

        local connection2;
        connection2 = chest.ChildAdded:Connect(function(child)
            if (not chest.Parent) then
                chestObj:Destroy();
                connection:Disconnect();
                connection2:Disconnect();
            end;

            if (library.flags.hideOpenedChests and child.Name == 'Opened') then
                chestObj:Destroy();
                connection:Disconnect();
                connection2:Disconnect();
            end;
        end);
    end;   

    function functions.onNewNpcAdded(npc, espConstructor)
        local npcName = npc.Name;

        local PurchaseInfo = FindFirstChild(npc, 'PurchaseInfo');
        if (PurchaseInfo) then npcName = PurchaseInfo.ItemName.Value .. ' [Purchasable]' end;
        
        local npcObj;
        if (npc:IsA('BasePart') or npc:IsA('MeshPart')) then
            npcObj = espConstructor.new(npc, npcName);
        else
            local code = [[
                local npc = ...;
                return setmetatable({}, {
                    __index = function(_, p)
                        if (p == 'Position') then
                            return npc.PrimaryPart and npc.PrimaryPart.Position or npc.WorldPivot.Position
                        end;
                    end,
                });
            ]]

            npcObj = espConstructor.new({code = code, vars = {npc}}, npcName);
        end;
        
        local connection;
        connection = npc:GetPropertyChangedSignal('Parent'):Connect(function()
            if (not npc.Parent) then
                npcObj:Destroy();
                connection:Disconnect();
            end;
        end);
    end;
end;

do -- // ESP Section
    function Utility:renderOverload(data)
        data.espSettings:AddToggle({
            text = 'Show Class'
        });

        local function makeList(folder, section)
            local seen = {};
            local list = {};

            if (typeof(folder) == "table" and not folder.ClassName) then
                for _, item in next, folder do
                    if (item.Name and not seen[item.Name]) then
                        seen[item.Name] = true;
                        table.insert(list, item.Name);
                    end;
                end;
            else
                for _, instance in next, folder:GetChildren() do
                    if (seen[instance.Name]) then continue end;

                    seen[instance.Name] = true;
                    table.insert(list, instance.Name);
                end;
            end;

            table.sort(list, function(a, b)
                return a < b;
            end);

            return Utility.map(list, function(name)
                local t = section:AddToggle({
                    text = name,
                    flag = string.format('Show %s', name),
                    state = true
                });

                t:AddColor({
                    text = string.format('%s Color', name),
                    color = Color3.fromRGB(255, 255, 255)
                });

                return t;
            end);
        end;


       makeESP({
            sectionName = 'Dropped Items',
            type = 'childAdded',
            args = Thrown,
            callback = functions.onDroppedItemAdded,
        });

        makeESP({
            sectionName = 'Trinkets',
            type = 'descendantAdded',
            args = workspace.TrinketSpawn,
            noColorPicker = true,
            callback = functions.onNewTrinketAdded,
            onLoaded = function(section)
                return {list = makeList(Trinkets, section)};
            end,
        });

        makeESP({
            sectionName = 'Mobs',
            type = 'childAdded',
            args = workspace.Live,
            callback = functions.onNewMobAdded,
            onLoaded = function(section)
                section:AddToggle({
                    text = 'Show Health',
                    flag = 'Mobs Show Health'
                });
                return {list = makeList(Mobs, section)};
            end
        });

        makeESP({
            sectionName = 'Chests',
            type = 'childAdded',
            args = workspace.Thrown,
            noColorPicker = true,
            callback = functions.onNewChestAdded,
            onLoaded = function(section)
                section:AddToggle({
                    text = 'Hide Opened Chests';
                });
                return {list = makeList(Chests, section)};
            end,
        });

        makeESP({
            sectionName = 'Npcs',
            type = 'childAdded',
            args = workspace.NPCs,
            noColorPicker = true,
            callback = functions.onNewNpcAdded,
            onLoaded = function(section)
                return {list = makeList(workspace.NPCs, section)};
            end,
        });
	end;
end;
