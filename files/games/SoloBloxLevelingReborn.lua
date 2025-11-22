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

local BlockUtils = sharedRequire('utils/BlockUtils.lua');
local TextLogger = sharedRequire('classes/TextLogger.lua');
local fromHex = sharedRequire('utils/fromHex.lua');
local toCamelCase = sharedRequire('utils/toCamelCase.lua');
local Webhook = sharedRequire('utils/Webhook.lua');
local Signal = sharedRequire('utils/Signal.lua');


local column1, column2 = unpack(library.columns);

local ReplicatedStorage, Players, RunService, CollectionService, Lighting, UserInputService, VirtualInputManager, TeleportService, MemStorageService, TweenService, HttpService, Stats, NetworkClient, GuiService = Services:Get(
	'ReplicatedStorage',
	'Players',
	'RunService',
	'CollectionService',
	'Lighting',
	'UserInputService',
	'VirtualInputManager',
	'TeleportService',
	'MemStorageService',
	'TweenService',
	'HttpService',
	'Stats',
	'NetworkClient',
	'GuiService'
);

-- TODO: make this rewrote into auto pickup
--local droppedItemsNames = originalFunctions.jsonDecode(HttpService, sharedRequire('@games/SBLItemNames.json'));

local LocalPlayer = Players.LocalPlayer;
local playerMouse = LocalPlayer:GetMouse();

local myRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart');

local functions = {};

-- // If main menu then reject the load
if (game.PlaceId == 12214593747) then
    ToastNotif.new({
        text = 'Script will not run in menu!',
        duration = 5
    })
      task.delay(0.005, function()
        library:Unload();
    end);
    return;
end;

local LocalPlayer = Players.LocalPlayer;
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();

local maid = Maid.new();
local entityEspList = {};


local localcheats = column1:AddSection('Local Cheats');
local combatcheats = column1:AddSection('Combat Cheats');
local autofarmsection = column2:AddSection('Auto Farm');


-- // #Slop
local function getKey(name)
    for _, child in ReplicatedStorage:GetDescendants() do
        if (child:IsA('RemoteEvent') and child.Name == name) then
            return child;
        end;
    end;
end;

-- // Remotes

local GateEvent = getKey('GateEvent');
local ClassEvent = getKey('Class_Event');
local MageEvent = getKey('Mage');
local AttackEvent = getKey('Mage_Combat_Event');
local DamageEvent = getKey('Mage_Combat_Damage_Event');
local SkillEvent = getKey('Mage_Skill_Event');
local DropEvent = getKey('DropEvent')

-- // Dungeon Extra

local DungeonHelper = {
    ["D-Rank"] = { ["PlaceID"] = {125357995526125,127569336430170}, ["MobsName"] = {'KARDING','HORIDONG','MAGICARABAO'} },
    ["C-Rank"] = { ["PlaceID"] = {83492604633635,71377998784000}, ["MobsName"] = {'WOLFANG','METALIC FANG','DAREWOLF','MONKEYKONG','UNDERWORLD SERPENT', 'FANGORA', 'RAGNOK', 'TWINKLE', 'DARKFIRE', 'GOBLINS TYRANT'} },
}

-- 71377998784000 other c-rank placeid (removed due to not being nearly as abusable)
-- subway - 83492604633635

------------

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

            if (not CollectionService:HasTag(maid.speedHackBv, 'AllowedBM')) then
                CollectionService:AddTag(maid.speedHackBv, 'AllowedBM');
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

            if (not CollectionService:HasTag(maid.flyBv, 'AllowedBM')) then
                CollectionService:AddTag(maid.flyBv, 'AllowedBM');
            end;

            maid.flyBv.Parent = rootPart;
            maid.flyBv.Velocity = camera.CFrame:VectorToWorldSpace(ControlModule:GetMoveVector() * library.flags.flyHackValue);
        end);
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
    
    function functions.DungeonStats(Rank)
        if Rank and DungeonHelper[Rank].PlaceID then 
            return DungeonHelper[Rank].PlaceID
        end
        local MobFolder = workspace:WaitForChild("WalkingNPC")
        local foundMob = false

        for _, mob in ipairs(MobFolder:GetChildren()) do
            if (mob:IsA('Highlight')) then continue; end;
            if mob then
                local tag = mob.HumanoidRootPart.Health.ImageLabel:FindFirstChild("TextLabel")
                local mobName = tostring(tag.Text)
                if table.find(DungeonHelper["D-Rank"].MobsName, mobName) then
                    getgenv().DungeonRank = 'D-Rank';
                    return "D-Rank"
                elseif table.find(DungeonHelper["C-Rank"].MobsName, mobName) then
                    getgenv().DungeonRank = 'C-Rank';
                    return "C-Rank" 
                end
            end
        end
    end

    function functions.createDungeon(UserID, Difficulty, Level, PlaceIdTable, DungeonRank)
        local TeleportArguments = {
            'Teleport',
            UserID,
            {
                DIFFICULTY = Difficulty or 'Hard',
                LEVEL = Level or 90,
                PlaceID = PlaceIdTable or {
                    71377998784000,
                    83492604633635
                },
                RANK = Rank or 'C-Rank'
            }
        };

        if (GateEvent) then
            GateEvent:FireServer(unpack(TeleportArguments))
        end;
    end;

    function functions.GetHoverPosition(mobPos)
        local method = getgenv().HoverMethod or "Normal"
        local dist = getgenv().HoverDistance or 5

        if method == "Normal" then
            return mobPos
        elseif method == "Up" then
            return mobPos + Vector3.new(0, dist, 0)
        elseif method == "Down" then
            return mobPos - Vector3.new(0, dist, 0)
        elseif method == "Underground" then
            return mobPos - Vector3.new(0, 100, 0)
        end

        return mobPos
    end

    function functions.ReturnToGround()
        if myRootPart then
            myRootPart.CFrame = CFrame.new(myRootPart.Position.X, 5, myRootPart.Position.Z)
        end
    end

    function functions.HitMob(MobRoot)
        if not (MobRoot and MobRoot.Parent) then return end


        if not LocalPlayer.Character or not myRootPart then return end
        myRootPart = Character.HumanoidRootPart;

        AttackEvent:FireServer(
            Character,
            1,
            "Mage",
            MobRoot.Position,
            Vector3.yAxis,
            MobRoot.Position,
            Vector3.yAxis,
            "Attack"
        )
        AttackEvent:FireServer(
            Character,
            2,
            "Mage",
            MobRoot.Position,
            Vector3.yAxis,
            MobRoot.Position,
            Vector3.yAxis,
            "Attack"
        )

        DamageEvent:FireServer(
            "Damage_Event_Combat",
            {
                char = Character,
                dodgedtable = MobRoot,
                blockedtable = MobRoot,
                perfecttable = MobRoot,
                hittedtable = MobRoot,
                class = "Mage",
                skill = "Combat",
                playerid = LocalPlayer.UserId
            }
        )

        SkillEvent:FireServer(
            Character,
            "Mage7",
            "Mage",
            MobRoot.Position,
            Vector3.yAxis,
            MobRoot.Position,
            Vector3.yAxis
        )
    end

    local cutsczene = false

    function functions.AutoFarmMob(toggle)
         if (not toggle) then 
            getgenv().autoFarmMob = false;
            return; 
        end;

        getgenv().autoFarmMob = true;

        while (getgenv().autoFarmMob) do
            task.wait(0.05);

            local gates = workspace:FindFirstChild("Gates")
            if not gates then return end

            for _, gate in ipairs(gates:GetDescendants()) do
                if gate:IsA("BasePart") and gate.Name == "Gate1" then
                    firetouchinterest(myRootPart, gate, 0)
                    task.wait(0.05)
                    firetouchinterest(myRootPart, gate, 1)
                end
            end

            local MobFolder = workspace:WaitForChild("WalkingNPC")
                
            local foundMob = false
            for _, model in ipairs(MobFolder:GetChildren()) do
                if (model:IsA('Highlight')) then continue; end;
                local mob = model:FindFirstChild("HumanoidRootPart")
                if mob and model.Name == "Mobs5" and not cutsczene then
                    getgenv().HoverMethod = "Up"
                    local newPos = functions.GetHoverPosition(mob.Position)
                    myRootPart.CFrame = CFrame.new(newPos)

                    task.wait(5);
                    cutsczene = true
                end
                if mob then
                    foundMob = true

                    local newPos = functions.GetHoverPosition(mob.Position)
                    myRootPart.CFrame = CFrame.new(newPos)

                    functions.HitMob(mob)
                end
            end
            if workspace:FindFirstChild("CloseRank") then
                local oldCFrame = myRootPart.CFrame;
                task.wait(2);
                myRootPart.CFrame = CFrame.new(workspace:FindFirstChild("CloseRank").Position);
                task.wait(2);
                local closeRank = workspace:FindFirstChild("CloseRank")
                for _, obj in closeRank:GetDescendants() do
                    if obj:IsA("ProximityPrompt") then
                        obj:InputHoldBegin();
                    end
                end
                task.wait(2);
                myRootPart.CFrame = oldCFrame;
            end

            if (not foundMob and not cutsczene) then
                local FinalGate = workspace.Gates:FindFirstChild('Gate5') or workspace.Gates:FindFirstChild('Gate4');

                if (FinalGate and not workspace:FindFirstChild('CloseRank')) then
                    myRootPart.CFrame = CFrame.new(FinalGate.Position)
                    task.wait(10)
                end;
            end;   
        end;
    end;
end;       

localcheats:AddDivider('Movement');


localcheats:AddToggle({
    text = 'Fly',
    callback = functions.fly

});

localcheats:AddSlider({
    flag = 'Fly Hack Value', 
    min = 16, 
    max = 500, 
    value = 0, 
    textpos = 2});
localcheats:AddToggle({
    text = 'Speedhack',
    callback = functions.speedHack
});
localcheats:AddSlider({
    flag = 'Speed Hack Value', 
    min = 16, 
    max = 500, 
    value = 0, 
    textpos = 2});
localcheats:AddToggle({
    text = 'Infinite Jump',
    callback = functions.infiniteJump
});
localcheats:AddSlider({
    flag = 'Infinite Jump Height', 
    min = 50, 
    max = 500, 
    value = 0, 
    textpos = 2});



localcheats:AddDivider("Notifiers");

do --// Notifier
    local moderatorIDs = {
        -- // Developers

        74592177, -- renzo
        2711295294, -- raynee

        -- // Moderators / Administrators
        
        1943552960, -- enko
        3458254657, -- yno
        732367598, -- mei

        -- // Contributors

        279933005, -- Vatsug
        3195344379, -- ColdLikeAhki
        21992269, -- Hilgrimz (Big Contributor)
        474810592, -- ciansire22
        403928181, -- Soryuu
        175682610, -- Dawn
    }
    
    local asset = "rbxassetid://367453005"
    local modJoinSound = Instance.new("Sound")

    modJoinSound.SoundId = asset
    modJoinSound.Parent = workspace


    local function onPlayerAdded(player)
        local playerId = player.UserId
        local playerName = player.Name
        if table.find(moderatorIDs, playerId) then 
            modJoinSound:Play()
            ToastNotif.new({
                text = ('Moderator joined [%s]'):format(playerName),
            });
        end
    end

    game.Players.PlayerAdded:Connect(onPlayerAdded)

    local function onPlayerRemoving(player)
        local playerId = player.UserId
        local playerName = player.Name
        if table.find(moderatorIDs, playerId) then 
            modJoinSound:Play()
            ToastNotif.new({
                text = ('Moderator left [%s]'):format(playerName),
            });
        end
    end

    game.Players.PlayerRemoving:Connect(onPlayerRemoving)



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

                if (distance < 250 and not table.find(notifSend, rootPart)) then
                    table.insert(notifSend, rootPart);
                    ToastNotif.new({
                        text = string.format('%s is nearby [%d]', v.Name, distance),
                        duration = 30
                    });
                elseif (distance > 450 and table.find(notifSend, rootPart)) then
                    table.remove(notifSend, table.find(notifSend, rootPart))
                    ToastNotif.new({
                        text = string.format('%s is no longer nearby [%d]', v.Name, distance),
                        duration = 30
                    });
                end;
            end;
        end);
    end;


    localcheats:AddToggle({
        text = 'Player Proximity Check',
        tip = 'Gives you a warning when a player is close to you',
        callback = functions.playerProximityCheck
    });
end

do -- // Combat Cheats Section
    combatcheats:AddDivider('Player');

    local HoverMethodBox = combatcheats:AddList({
    values = { "Normal", "Up", "Down", "Underground" },
    text = "Hover Method",
    tip = "How your character positions relative to mobs",

    callback = function(val)
        getgenv().HoverMethod = val
    end
})
getgenv().HoverMethod = "Normal"
local HoverSlider = combatcheats:AddSlider({
    text = "Hover Distance (Y)",
    value = 5,
    min = -50,
    max = 50,
    tip = "How far above/below mobs you hover",

    callback = function(val)
        getgenv().HoverDistance = val
    end
})

getgenv().HoverDistance = 5

combatcheats:AddToggle({
    text = "Auto Farm Mobs",
    default = false,
    callback = functions.AutoFarmMob
})

combatcheats:AddToggle({
    text = "[Vis]skillspam",
    default = false,
    callback = function(state)
        getgenv().AntiSkillSpam = state
    end
})
workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and child.Name == "Blizzmancer" and getgenv().AntiSkillSpam then
        child:Destroy()
    end
end)
end;

do -- // Auto Farm Section
    autofarmsection:AddDivider('Teleport to Dungeon');

    autofarmsection:AddList({
        text = "Dungeon Rank",
        values = {
            'E-Rank',
            'D-Rank',
            'C-Rank'
        },
		multiselect = false,

        callback = function(value)
            getgenv().SelectedRank = value;
        end;
    })

     autofarmsection:AddList({
        text = 'Select Dungeon',
        values = {
            'Prison [D Rank]',
            'Rock [D Rank]',
            'Subway [C Rank]',
            'Goblin [C Rank]',
        },
		multiselect = true,

        callback = function(value)
            print(value);
        end;
    })


    autofarmsection:AddList({
        text = 'Dungeon Difficulty',
        values = {
            'Easy',
            'Medium',
            'Hard'
        },
		multiselect = false,

        callback = function(value)
            getgenv().SelectedDifficulty = value;
        end;
    })

    autofarmsection:AddToggle({
        text = 'Auto Start Dungeon',
        tip = 'Put script within Auto Execute.',
        callback = function(value)
            if (value) then
                if (game.PlaceId == 119482438738938) then -- city
                    functions.fly(true);
                    myRootPart.CFrame = CFrame.new(200, -100, 200);
                    task.wait(5);
                    if (not value) then return end;
                    functions.createDungeon(LocalPlayer.UserId, getgenv().SelectedDifficulty, nil, functions.DungeonStats(getgenv().SelectedRank), getgenv().SelectedRank)
                end;
            end;
        end;
    })

    autofarmsection:AddButton({
        text = 'Create & Start Dungeon',
        tip = 'Teleports to a custom made dungeon.',
        callback = function()
            functions.createDungeon(LocalPlayer.UserId, getgenv().SelectedDifficulty, nil, functions.DungeonStats(getgenv().SelectedRank), getgenv().SelectedRank)
        end;
	}); 

end;
