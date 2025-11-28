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
local Signal = sharedRequire('utils/Signal.lua');
local basicHelper = sharedRequire('utils/helpers/basics.lua');

if (game.PlaceId == 3661577685) then
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

local Players, RunService, UserInputService, HttpService, CollectionService = Services:Get('Players', 'RunService', 'UserInputService', 'HttpService', 'CollectionService');
local LocalPlayer = Players.LocalPlayer;

local maid = Maid.new();
local entityEspList = {};


local localcheats = column1:AddSection('Local Cheats');
local misccheats = column1:AddSection('Misc');
local combatcheats = column2:AddSection('Combat Cheats');
local playercheats = column2:AddSection('Player Cheats');


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

localcheats:AddDivider("Movement");


localcheats:AddToggle({
    text = 'Fly',
    callback = functions.fly

});

localcheats:AddSlider({
    flag = 'Fly Hack Value', 
    min = 16, 
    max = 200, 
    value = 0, 
    textpos = 2});
localcheats:AddToggle({
    text = 'Speedhack',
    callback = functions.speedHack
});
localcheats:AddSlider({
    flag = 'Speed Hack Value', 
    min = 16, 
    max = 200, 
    value = 0, 
    textpos = 2});
localcheats:AddToggle({
    text = 'Infinite Jump',
    callback = functions.infiniteJump
});
localcheats:AddSlider({
    flag = 'Infinite Jump Height', 
    min = 50, 
    max = 250, 
    value = 0, 
    textpos = 2});




localcheats:AddDivider("Notifiers");


local playerSpectating;
local playerSpectatingLabel;

do -- // Setup Leaderboard Spectate
    local lastUpdateAt = 0;

    function setCameraSubject(subject)
        if (subject == LocalPlayer.Character) then
            playerSpectating = nil;
            CollectionService:RemoveTag(LocalPlayer, 'ForcedSubject');

            if (playerSpectatingLabel) then
                playerSpectatingLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
                playerSpectatingLabel = nil;
            end;

            maid.spectateUpdate = nil;
            return;
        end;

        CollectionService:AddTag(LocalPlayer, 'ForcedSubject');
        workspace.CurrentCamera.CameraSubject = subject;

        maid.spectateUpdate = task.spawn(function()
            while task.wait() do
                if (tick() - lastUpdateAt < 5) then continue end;
                lastUpdateAt = tick();
                task.spawn(function()
                    LocalPlayer:RequestStreamAroundAsync(workspace.CurrentCamera.CFrame.Position);
                end);
            end;
        end);
    end;

    UserInputService.InputBegan:Connect(function(inputObject)
        if (inputObject.UserInputType ~= Enum.UserInputType.MouseButton1 or not LocalPlayer:FindFirstChild('PlayerGui') or not LocalPlayer.PlayerGui:FindFirstChild('LeaderboardGui')) then return end;

        local newPlayerSpectating;
        local newPlayerSpectatingLabel;

        for _, v in next, LocalPlayer.PlayerGui.Leaderboard.ScrollingFrame:GetChildren() do
            if (v:IsA('Frame') and v:FindFirstChild('PlayerName')) then
                local filteredName = string.gsub(v.PlayerName.Text, ' ', '');
                newPlayerSpectating = filteredName;
                newPlayerSpectatingLabel = v.PlayerName;
                break;
            end;
        end;

        if (not newPlayerSpectating) then return end;

        if (playerSpectatingLabel) then
            playerSpectatingLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
        end;

        playerSpectatingLabel = newPlayerSpectatingLabel;
        playerSpectatingLabel.TextColor3 = Color3.fromRGB(255, 0, 0);

        if (newPlayerSpectating == playerSpectating or newPlayerSpectating == LocalPlayer.Name) then
            setCameraSubject(LocalPlayer.Character);
        else
            print('spectating new player');
            playerSpectating = newPlayerSpectating;

            local player = Players:FindFirstChild(playerSpectating);

            if (not player or not player.Character or not player.Character.PrimaryPart) then
                print('player not found', player);
                setCameraSubject(LocalPlayer.Character);
                return;
            end;

            setCameraSubject(player.Character);
        end;
    end);

    TextLogger.setCameraSubject = setCameraSubject;
end;

do --// Notifier
    local moderatorIDs = {283890177,421391593,5127995337,42235130,1001242712,56721213,38307780,138249029,1041867508,95410360,1459923763,1696452029,150269473,1321098453,45453121,276142024,123755248,585228735,3489954641}
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


    localcheats:AddToggle({
        text = 'Player Proximity Check',
        tip = 'Gives you a warning when a player is close to you',
        callback = functions.playerProximityCheck
    });
end



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

local function onNewMobAdded(mob, espConstructor)
    local validMobNames = {
        "#HITBOX_SIMULATION",
        "_Dungeon",
        "HITBOX_SIMULATION",
    }
    local CollectionService = game:GetService("CollectionService")

    local foundMobs = {}
    for i, model in pairs(game:GetService("Workspace"):WaitForChild("Live"):GetChildren()) do

        for i, string in ipairs(validMobNames) do
            if string.find(model.Name,string) then
                table.insert(foundMobs,model)

                CollectionService:AddTag(model, "Mob")
            end
        end
    end
    if (not CollectionService:HasTag(mob, 'Mob')) then return end;

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

    if (formattedName == 'Megalodaunt Legendary' and library.flags.artifactNotifier) then
        ToastNotif.new({text = 'A red sharko has spawned, go check songseeker!'});
    end;

    local connection;
    connection = mob:GetPropertyChangedSignal('Parent'):Connect(function()
        if (not mob.Parent) then
            connection:Disconnect();
            mobEsp:Destroy();
        end;
    end);
end;

local function onNewNpcAdded(npc, espConstructor)
    local npcObj;
    if (npc:IsA('BasePart') or npc:IsA('MeshPart')) then
        npcObj = espConstructor.new(npc, npc.Name);
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

        npcObj = espConstructor.new({code = code, vars = {npc}}, npc.Name);
    end;

    local connection;
    connection = npc:GetPropertyChangedSignal('Parent'):Connect(function()
        if (not npc.Parent) then
            npcObj:Destroy();
            connection:Disconnect();
        end;
    end);
end;

makeESP({
    sectionName = 'Mobs',
    type = 'childAdded',
    args = workspace.Live,
    callback = onNewMobAdded,
    onLoaded = function(section)
        section:AddToggle({
            text = 'Show Health',
            flag = 'Mobs Show Health'
        });
    end
});

local function onNewAwardAdded(award, espConstructor)
    local validMobNames = {
        "Award",
    }
    local CollectionService = game:GetService("CollectionService")

    local foundMobs = {}
    for i, model in pairs(game:GetService("Workspace"):GetChildren()) do

        for i, string in ipairs(validMobNames) do
            if string.find(model.Name,string) then
                table.insert(foundMobs,model)
                CollectionService:AddTag(model, "award")
            end
        end
    end
    if (not CollectionService:HasTag(award, 'award')) then return end;

    local code = [[
                local award = ...;
                return setmetatable({}, {
                    __index = function(_, p)
                        if (p == 'Position') then
                            return award.PrimaryPart and award.PrimaryPart.Position or award.WorldPivot.Position
                        end;
                    end,
                });
            ]]

    local formattedName = formatMobName(award:WaitForChild('BillboardGui').TextLabel);
    local awardEsp = espConstructor.new({code = code, vars = {award}}, formattedName);

    if (formattedName == 'Blessing') then
        ToastNotif.new({text = 'A blessing has spawned!'});
    end;

    local connection;
    connection = award:GetPropertyChangedSignal('Parent'):Connect(function()
        if (not award.Parent) then
            connection:Disconnect();
            awardEsp:Destroy();
        end;
    end);
end;

makeESP({
    sectionName = 'Award',
    type = 'childAdded',
    args = workspace,
    callback = onNewAwardAdded,
});

makeESP({
    sectionName = 'NPCs',
    type = 'childAdded',
    args = workspace.NPCs,
    callback = onNewNpcAdded
});

getrenv().Tmea =
    makeESP({
        sectionName = 'Terra Mea',
        type = 'childAdded',
        args = workspace.Thrown,
        callback = function(value)
            onLoaded = function(section)
                if value then
                getrenv().Tmea = true
            else
                getrenv().Tmea = false
            end;
            end;
        end;
    });
workspace.Thrown.ChildAdded:Connect(function(child)
    if child.Name == "TRAPlol!" then
        if (not getrenv().Tmea) then return end
        local changed
        local c
        c = child:GetPropertyChangedSignal("Transparency"):Connect(function()
            child.Transparency = 0.2
        end)
        changed = child.Changed:Connect(function()
            if not child:IsDescendantOf(workspace.Thrown) then
                changed:Disconnect()
                c:Disconnect()
            end
        end)
    end
end)



--- MISC AREA!!
----------------
function functions.serverHop(bypass)
    if(bypass or library:ShowConfirm('Are you sure you want to switch server?')) then
        xpcall(
            function()
                local module = loadstring(game:HttpGet"https://raw.githubusercontent.com/jayisstargazing/stargazing/main/serverhop")()

                module:Teleport(game.PlaceId)
            end,
            function(err)
                warn("An error occurred: " .. tostring(err))
            end
        )
    end;
end;

function functions.Respawn(resp)
    if(resp or library:ShowConfirm('Are you sure you want to respawn?')) then

        game.Players.LocalPlayer.Character.Humanoid.Health = 0
    end
end

function functions.InstantLog()
    local Player = game:GetService("Players")
    Player.LocalPlayer:Kick("Instant Logged")
end;
function functions.RemoveSpellZones()
    for _, part in pairs(workspace:GetChildren()) do
        if part:IsA("BasePart") and part.Name == "NoSpellZone" then
            part:Destroy()
        end;
    end;
end;

function functions.FindOutDays()
    local days =  game:GetService("Players").LocalPlayer.PlayerGui.DayCount.Value
    ToastNotif.new({
        text = ('Your day count is [%s]'):format(days),
        duration = 5,
    });
end;

function functions.FindOutWeather()
    local Weather = game:GetService("Workspace").Weather.Value
    ToastNotif.new({
        text = ('The weather is [%s]'):format(Weather),
        duration = 5,
    });
end;

function functions.noStun(toggle)
    if(not toggle) then
        maid.noStun   = nil;
        maid.noStunBv = nil;
        return;
    end;

    maid.noStun = RunService.Heartbeat:Connect(function()
        local playerData = Utility:getPlayerData();
        local humanoid, rootPart = playerData.humanoid, playerData.primaryPart;
        if (not humanoid or not rootPart) then return end;

        if (library.flags.fly or library.flags.blatantNoStun) then
            maid.noStunBv = nil;
            return;
        end;

        maid.noStunBv = maid.noStunBv or Instance.new('BodyVelocity');
        maid.noStunBv.MaxForce = Vector3.new(100000, 0, 100000);

        if (not CollectionService:HasTag(maid.noStunBv, 'AllowedBM')) then
            CollectionService:AddTag(maid.noStunBv, 'AllowedBM');
        end;

        maid.noStunBv.Parent = not library.flags.fly and rootPart or nil;
        maid.noStunBv.Velocity = (humanoid.MoveDirection.Magnitude ~= 0 and humanoid.MoveDirection or gethiddenproperty(humanoid, 'WalkDirection')) * if (LocalPlayer.Character.Values.Running.Value) then 26 else 16;
    end);
end;

function functions.blatantNoStun(toggle)
    if(not toggle) then
        maid.blatantNoStun = nil;
        maid.blatantNoStunBv = nil;
        return;
    end;

    maid.blatantNoStun = RunService.Heartbeat:Connect(function()
        local playerData = Utility:getPlayerData();
        local humanoid, rootPart = playerData.humanoid, playerData.primaryPart;
        if (not humanoid or not rootPart) then return end;

        if (library.flags.fly or library.flags.noStun) then
            maid.blatantNoStunBv = nil;
            return;
        end;

        maid.blatantNoStunBv = maid.blatantNoStunBv or Instance.new('BodyVelocity');
        maid.blatantNoStunBv.MaxForce = Vector3.new(100000, 0, 100000);

        if (not CollectionService:HasTag(maid.blatantNoStunBv, 'AllowedBM')) then
            CollectionService:AddTag(maid.blatantNoStunBv, 'AllowedBM');
        end;

        maid.blatantNoStunBv.Parent = not library.flags.fly and rootPart or nil;
        maid.blatantNoStunBv.Velocity = (humanoid.MoveDirection.Magnitude ~= 0 and humanoid.MoveDirection or gethiddenproperty(humanoid, 'WalkDirection')) * 26;
    end);
end;

function functions.antiFire(toggle)
    if(not toggle) then
        maid.antiFire = nil;
        return;
    end;
    
    maid.antiFire = LocalPlayer.Character.Values.OnFire.Changed:Connect(function(boolean)
        if(boolean) then
            local args = { 
                [1] = Enum.KeyCode.S,
                [2] = CFrame.new(1804.400390625, 7528.03076171875, -2765.593505859375) * CFrame.Angles(-2.143744468688965, -1.2413746118545532, -2.1692001819610596),
                [3] = {}
            }
            game:GetService("ReplicatedStorage").Dash:FireServer(unpack(args))
        end;
    end);
end;

function functions.antiVoidFire(toggle)
    if(not toggle) then
        maid.antiVoidFire = nil;
        return;
    end;

    maid.antiVoidFire = RunService.Heartbeat:Connect(function()
        if (LocalPlayer.Character:FindFirstChild('VoidFire')) then
            LocalPlayer.Character:FindFirstChild('VoidFire'):Destroy();
        end;
    end);
end;

function functions.antiConfused(toggle)
    if(not toggle) then
        maid.antiConfused = nil;
        return;
    end;

    maid.antiConfused = RunService.Heartbeat:Connect(function()
        if (LocalPlayer.Character:FindFirstChild('Confused')) then
            LocalPlayer.Character:FindFirstChild('Confused'):Destroy();
        end;
    end);
end;

function functions.antiHeal(toggle)
    if(not toggle) then
         maid.antiHeal = nil;
        return;
    end;

    maid.antiHeal = RunService.Heartbeat:Connect(function()
        if (LocalPlayer.Character:FindFirstChild('NoAbsoluteHeal')) then
            LocalPlayer.Character:FindFirstChild('NoAbsoluteHeal'):Destroy();
        end;
    end);
end;

function functions.noFallDamage(toggle)
    if(not toggle) then
         maid.noFallDamage = nil;
        return;
    end;

    maid.noFallDamage = RunService.Heartbeat:Connect(function()
        if (ReplicatedStorage:FindFirstChild('FallDamage')) then
            ReplicatedStorage:FindFirstChild('FallDamage'):Destroy();
        end;
    end);
end;

function functions.noBlur(toggle)
        if(not toggle) then
         maid.noBlur = nil;
        return;
    end;

    maid.noBlur = RunService.Heartbeat:Connect(function()
        if (Lighting:FindFirstChild('rawr')) then
            Lighting:FindFirstChild('rawr'):Destroy();
        end;
    end);
end;

misccheats:AddButton({
    text = 'Server Hop',
    tip = 'Jumps to any other server, non region dependant',
    callback = functions.serverHop
});

misccheats:AddButton({
    text = 'Respawn',
    tip = 'Respawns the player (Kills them)',
    callback = functions.Respawn
});

misccheats:AddButton({
    text = 'Remove No Spell Zones',
    tip = 'Removes the no spell zone areas such as the bar.',
    callback = functions.RemoveSpellZones
})

misccheats:AddButton({
    text = 'Find Out Days',
    tip = 'Find out the days of the player.',
    callback = functions.FindOutDays
});


misccheats:AddButton({
    text = 'Find Out Weather',
    tip = 'Find out the weather of the server.',
    callback = functions.FindOutWeather
});


misccheats:AddBind({
    text = 'Instant Log', 
    callback = functions.InstantLog, 
    mode = 'hold', 
    nomouse = true});

getrenv().IsLord =
    misccheats:AddToggle({
        text = 'Lord of House',
        callback = function(value)
            if value then
            getrenv().IsLord = true
        else
            getrenv().IsLord = false
        end;
        end;
    });

getrenv().IsLord = false
local connection
connection = game:GetService("RunService").RenderStepped:Connect(function()
    if (not getrenv().IsLord) then return end
    game:GetService("Players").LocalPlayer.leaderstats.HouseOwner.Value = true
    if getrenv().IsLord == false then
        game:GetService("Players").LocalPlayer.leaderstats.HouseOwner.Value = false

    end;
end);

function functions.NameChanger(toggle)
    if toggle == false then
        getrenv().NameChanger = false;
    else
        getrenv().NameChanger = true;
    end;
end;

misccheats:AddToggle({
    text = 'Name Changer',
    tip = 'Change the names of your character',
    callback = functions.NameChanger
})

if getrenv().NameChanger == false then
misccheats:AddBox({
    text = 'First Name',
    tip = 'Change the first name of your character [client]',
    callback = function(value)
        LocalPlayer.leaderstats.FirstName.Value = value
    end;
});
misccheats:AddBox({
    text = 'Last Name',
    tip = 'Change the last name of your character [client]',
    callback = function(value)
        LocalPlayer.leaderstats.LastName.Value = value
    end;
});
misccheats:AddBox({
    text = 'Title',
    tip = 'Change the title of your character [client]',
    callback = function(value)
        LocalPlayer.leaderstats.Title.Value = value
    end;
});
end;


combatcheats:AddDivider("Combat Settings");
print("before do")
do -- One Shot NPCs
    local mobs = {};

    local function getAnyPart(model)
        for _, obj in ipairs(model:GetDescendants()) do
            if (obj.Name == 'HumanoidRootPart') then
                return obj;
            end;
            if obj:IsA('BasePart') then
                return obj;
            end;
        end;
        return nil;
    end;


    local NetworkOneShot = {};
    NetworkOneShot.__index = NetworkOneShot;

    function NetworkOneShot.new(mob)
        local self = setmetatable({},NetworkOneShot);

        self._maid = Maid.new();
        self.char = mob;

        self._maid:GiveTask(mob.Destroying:Connect(function()
            self:Destroy();
        end));

        self.hrp = getAnyPart(mob);

        mobs[mob] = self;
        return self;
    end;

    function NetworkOneShot:Update()
        if (not self.hrp or not self.hrp.Parent or self.hrp.Parent.Parent ~= workspace) then return end;

        local hasOwnership = isnetworkowner(self.hrp);

        -- store previous state
        if self._hadOwnership == nil then
            self._hadOwnership = false;
        end;

        if (hasOwnership and not self._hadOwnership) then
            print('[NetworkOneShot] Gained network ownership for', self.char.Name);
        elseif (not hasOwnership and self._hadOwnership) then
            print('[NetworkOneShot] Lost network ownership for', self.char.Name);
        end;

        self._hadOwnership = hasOwnership;

        if hasOwnership then
            self.char:PivotTo(CFrame.new(self.hrp.Position.X, workspace.FallenPartsDestroyHeight - 100000, self.hrp.Position.Z));
        end;
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

    local valid = {
        ['Angel Eye'] = true;
        ['HITBOX_SIMULATION'] = true;
        ['HITBOX_SIMULATION#'] = true;
        ['_DungeonClone'] = true;
        ['Terra Mob']     = true;
        ['Swarm']         = true;
        ['Poison Orb']    = true;
        ['Dark Eye']      = true;
        ['Flame Beast']   = true;
        ['Worm']          = true;
        ['Big Worm']      = true;
    };

    Utility.listenToChildAdded(workspace, function(obj)
        task.wait(0.2);
        if (obj == LocalPlayer.Character) then return; end;
        if (not valid[obj.Name]) then return; end;
        NetworkOneShot.new(obj);
    end);

    Utility.listenToChildAdded(workspace.Live, function(obj)
        task.wait(0.2);
        if (obj == LocalPlayer.Character) then return; end;
        if (not valid[obj.Name]) then return; end;
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



combatcheats:AddToggle({
    text = 'One Shot Mobs',
    tip = 'This feature randomly works sometimes and causes them to die [BROKEN RIGHT NOW DONT USE]',
    callback = functions.networkOneShot
});

playercheats:AddDivider("Player Settings");

playercheats:AddToggle({
    text = 'No Stun',
    callback = functions.noStun
});

playercheats:AddToggle({
    text = 'Blatant No Stun',
    callback = functions.blatantNoStun
});

playercheats:AddDivider('Removals');

playercheats:AddToggle({
    text = 'Anti Fire',
    callback = functions.antiFire
});

playercheats:AddToggle({
    text = 'Anti Void-Fire',
    callback = functions.antiVoidFire
});

playercheats:AddToggle({
    text = 'Anti Confused',
    callback = functions.antiConfused
});

playercheats:AddToggle({
    text = 'Anti Heal',
    tip = 'Absolute heal during dungeon.',
    callback = functions.antiHeal
});


playercheats:AddToggle({
    text = 'No Fall Damage',
    callback = noFallDamage
});


playercheats:AddToggle({
    text = 'No Blur',
    callback = functions.noBlur
});

local VisualsMisc = column2:AddSection('Visuals');
VisualsMisc:AddDivider("Game Visuals");
local Lighting = game:GetService("Lighting")

local lastFogDensity = 0;
function functions.noFog(t)
    if not t then Lighting.Atmosphere.Density = lastFogDensity; maid.noFog = nil; return; end

    maid.noFog = Lighting.Atmosphere:GetPropertyChangedSignal('Density'):Connect(function()
        Lighting.Atmosphere.Density = 0;
    end);

    lastFogDensity = Lighting.Atmosphere.Density;
    Lighting.Atmosphere.Density = 0;
end

local oldAmbient, oldBritghtness = Lighting.Ambient, Lighting.Brightness;
function functions.fullBright(toggle)
    if(not toggle) then
        maid.fullBright = nil;
        Lighting.Ambient, Lighting.Brightness = oldAmbient, oldBritghtness;
        return
    end;

    oldAmbient, oldBritghtness = Lighting.Ambient, Lighting.Brightness;
    maid.fullBright = Lighting:GetPropertyChangedSignal('Ambient'):Connect(function()
        Lighting.Ambient = Color3.fromRGB(255, 255, 255);
        Lighting.Brightness = 1;
    end);
    Lighting.Ambient = Color3.fromRGB(255, 255, 255);
end;

function functions.noBlur(t)
    Lighting.Blur.Enabled = not t;
end

do -- // Visuals
    VisualsMisc:AddToggle({
        text = 'Full Bright',
        callback = functions.fullBright
    })VisualsMisc:AddSlider({
        flag = 'Full Bright Value',
        textpos = 2,
        min = 0,
        max = 10,
        value = 1,
    });
end;

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
    itemColors[7] = Color3.new(1, 0.61568599999999996, 0);
    itemColors[6] = Color3.new(1, 0, 0);
    itemColors[4] = Color3.new(0.82745100000000005, 0.466667, 0.207843);
    itemColors[0] = Color3.new(1, 1, 1);
    itemColors[5] = Color3.new(0.33333299999999999, 0, 1);
    itemColors[999] = Color3.new(0.792156, 0.792156, 0.792156);

    local function getToolType(tool)
        if (tool:FindFirstChild("PrimaryWeapon"))then
            return 0;
        elseif (tool:FindFirstChild("Skill")) then
            return 3;
        elseif (tool:FindFirstChild("Tool") or tool.Parent.Name == "Intagibility" or tool.Parent.Name == "Abyssal Grasp") then
            return 6;
        elseif (tool:FindFirstChild("Spell")) then
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
