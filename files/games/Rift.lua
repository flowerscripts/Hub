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

local Map = workspace.Map;

local Merchant = Map.Merchant;
local Traders = Map.Traders;

local oldAmbient, oldBrightness;

local myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');

local killBricks = {};

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
        params.FilterDescendantsInstances = {workspace.Mobs};
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
                for _, entity in next, workspace.Mobs:GetChildren() do
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
        if (not self.hrp or not isnetworkowner(self.hrp) or not self.hrp.Parent or self.hrp.Parent.Parent ~= workspace.Mobs) then return end;
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

    Utility.listenToChildAdded(workspace.Mobs, function(obj)
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

	localCheats:AddToggle({
		text = 'No Clip',
		callback = functions.noClip
	});

	localCheats:AddToggle({
		text = 'Click Destroy',
		tip = 'Everything you click on will be destroyed (client sided)',
		callback = functions.clickDestroy
	});

	localCheats:AddBind({text = 'Go To Ground', callback = functions.goToGround, mode = 'hold', nomouse = true});

	localCheats:AddDivider("Gameplay-Assist");

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

local validMobs = {
    {
        ['Name'] = 'Bandit Alchemist'
    },

    {
        ['Name'] = 'Bandit Brute'
    },

    {
        ['Name'] = 'Bandit Swordsman'
    },

    {
        ['Name'] = 'Bandit Leader Morra'
    },
}

do -- // Entity ESP
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

    local function onNewMobAdded(mob, espConstructor)
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

        local formattedName = formatMobName(mob.Name);
        local mobEsp = espConstructor.new({code = code, vars = {mob}}, formattedName);

        local connection;
        connection = mob:GetPropertyChangedSignal('Parent'):Connect(function()
            if (not mob.Parent) then
                connection:Disconnect();
                mobEsp:Destroy();
            end;
        end);
    end;

    
    makeESP({
        sectionName = 'Mobs',
        type = 'childAdded',
        args = workspace.Mobs,
        callback = onNewMobAdded,
        onLoaded = function(section)
            section:AddToggle({
                text = 'Show Health',
                flag = 'Mobs Show Health'
            });
            return {list = makeList(validMobs, section)};
        end
    });
end;
