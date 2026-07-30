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

local cloneref = cloneref or function(object) return object end;

-- Services
local Players, ReplicatedStorage, RunService, UserInputService, Lighting, MemStorageService, TeleportService, HttpService, TweenService, VirtualInputManager = Services:Get('Players', 'ReplicatedStorage', 'RunService', 'UserInputService', 'Lighting', 'MemStorageService', 'TeleportService', 'HttpService', 'TweenService', 'VirtualInputManager');

Players = cloneref(Players);
ReplicatedStorage = cloneref(ReplicatedStorage);
RunService = cloneref(RunService);
UserInputService = cloneref(UserInputService);
Lighting = cloneref(Lighting);
TeleportService = cloneref(TeleportService);
TweenService = cloneref(TweenService);
VirtualInputManager = cloneref(VirtualInputManager);

local MAIN_PLACE_ID = 10266164381;

-- Attach To Back
local ATTACH_MAX_RANGE = 300;
local ATTACH_TWEEN_SPEED = 100;
local ATTACH_MIN_STEP = 0.5;
local ATTACH_MOVER_FORCE = Vector3.new(1e9, 1e9, 1e9);

-- Auto Farm
local BOSS_NAMES = {
    'Barbarit', 'Chakra Knight', 'Haku', 'Hyuga', 'Isobu', 'Lava Snake', 'Lavarossa',
    'Manda', 'Matatabi', 'Samurai', 'Shukaku', 'Tairock', 'Wood Golem', 'Wooden Golem'
};

--[[
    Every boss has a fixed swing cooldown, so clicking faster than this just gets
    dropped by the server. Fast enough to never miss a window, no slider needed
]]
local AUTO_FARM_SWING_DELAY = 0.1;
local AUTO_FARM_DEFAULT_HEIGHT = 0;
local AUTO_FARM_DEFAULT_SPACE = 0;

-- Sentinel row in the boss list that means 'whichever boss is closest'
local AUTO_FARM_NEAREST = 'Nearest';

local RESPAWN_SETTLE_TIME = 1;
local BOSS_SCAN_TIME = 8;
local BOSS_HOP_TIME = 15;

--[[
    Trinkets show up a few seconds after the boss actually dies, so the farm loop hangs
    around the corpse for this long instead of leaving for the next boss. An occupied
    trinket spawn keeps it there up to the max, in case the drop is late
]]
local REWARD_SPAWN_WAIT = 12;
local REWARD_SPAWN_WAIT_MAX = 35;

--[[
    Safe Teleport. Animation ids we bail out on, filled from the Teleport Animation Ids
    box or straight off a row in the animation logger. The defaults are Wooden Golem's
    three slams
]]
local DEFAULT_TELEPORT_ANIMATIONS = '111592213267733, 116907126244057, 120758909308511';

local SAFE_TELEPORT_STEP = 0.1;
local SAFE_TELEPORT_BUFFER = 0.35;
local SAFE_TELEPORT_MAX_TIME = 15;

local coverAnimations = {};

--[[
    Auto Block. Sound names that mean a heavy attack is coming. SnakeBite is Manda's,
    HeavyPunchCharge is everyone's, and both play well before the hit lands
]]
local DEFAULT_BLOCK_SOUNDS = 'SnakeBite, HeavyPunchCharge';
local blockSounds = {};

local function setBlockSounds(text)
    table.clear(blockSounds);

    for soundName in string.gmatch(text or '', '[%w_]+') do
        blockSounds[soundName] = true;
    end;
end;

--[[
    Auto Parry. Animations that get blocked the instant they start rather than on a
    sound cue. The default is Haku's parryable
]]
local DEFAULT_PARRY_ANIMATIONS = '7298826950';
local PARRY_MIN_HOLD = 0.3;

local parryAnimations = {};

local function setParryAnimations(text)
    table.clear(parryAnimations);

    for animId in string.gmatch(text or '', '%d+') do
        parryAnimations[animId] = true;
    end;
end;

local function addParryAnimation(animId)
    if (not animId or parryAnimations[animId]) then return end;

    parryAnimations[animId] = true;

    -- Mirror it back into the box so the config remembers it next session
    local box = library.options.parryAnimationIds;
    if (not box or not box.SetValue) then return end;

    local ids = {};

    for id in next, parryAnimations do
        table.insert(ids, id);
    end;

    table.sort(ids);
    box:SetValue(table.concat(ids, ', '));
end;

local function setCoverAnimations(text)
    table.clear(coverAnimations);

    for animId in string.gmatch(text or '', '%d+') do
        coverAnimations[animId] = true;
    end;
end;

local function addCoverAnimation(animId)
    if (not animId or coverAnimations[animId]) then return end;

    coverAnimations[animId] = true;

    -- Mirror it back into the box so the config remembers it next session
    local box = library.options.teleportAnimationIds;
    if (not box or not box.SetValue) then return end;

    local ids = {};

    for id in next, coverAnimations do
        table.insert(ids, id);
    end;

    table.sort(ids);
    box:SetValue(table.concat(ids, ', '));
end;

local bossLookup = {};
local bossNames = {AUTO_FARM_NEAREST};

--[[
    Every boss is a different size, so each one remembers its own parking spot.
    Keyed by boss key, with the '' entry holding the fallback for bosses you
    haven't tuned yet
]]
local bossOffsets = {
    [''] = {
        height = AUTO_FARM_DEFAULT_HEIGHT,
        space = AUTO_FARM_DEFAULT_SPACE
    }
};

-- Boss names turn up spaced, unspaced, and with numbers tacked on, so only compare letters
local function normalizeName(name)
    return string.lower((string.gsub(name, '%A', '')));
end;

--[[
    The same boss shows up as 'Haku', 'Haku Boss' and 'HakuBoss2' depending on
    whether you're looking at the model, the rewards drop or a duplicate spawn, so
    everything that has to match a boss by name goes through this
]]
local function bossKey(name)
    if (not name or name == AUTO_FARM_NEAREST) then return '' end;

    return (string.gsub(normalizeName(name), 'boss$', ''));
end;

-- What the farm loop parks by: the target's own config, or the shared fallback
local function getBossOffsets(bossName)
    return bossOffsets[bossKey(bossName)] or bossOffsets[''];
end;

-- What the sliders write to. 'Nearest' edits the fallback every boss starts on
local function getEditableOffsets(bossName)
    local key = bossKey(bossName);

    if (not bossOffsets[key]) then
        local fallback = bossOffsets[''];

        bossOffsets[key] = {
            height = fallback.height,
            space = fallback.space
        };
    end;

    return bossOffsets[key];
end;

local function addBossName(name)
    name = string.match(name, '^%s*(.-)%s*$');

    local key = bossKey(name);
    if (key == '' or bossLookup[key]) then return end;

    bossLookup[key] = true;

    -- Bosses we learn at runtime still need a row in the per boss config list
    local bossList = library.options.autoFarmBoss;

    if (bossList and bossList.hasInit) then
        -- AddValue writes into bossNames itself, since the list shares the table
        bossList:AddValue(name);
    else
        table.insert(bossNames, name);
    end;

    -- Nearest stays pinned to the top, the actual bosses sort under it
    table.sort(bossNames, function(a, b)
        if (a == AUTO_FARM_NEAREST or b == AUTO_FARM_NEAREST) then
            return a == AUTO_FARM_NEAREST;
        end;

        return a < b;
    end);
end;

for _, bossName in next, BOSS_NAMES do
    addBossName(bossName);
end;

if (game.PlaceId ~= MAIN_PLACE_ID) then
    return ToastNotif.new({text = 'Script will not run in lobby.'});
end;

-- UI Init
local column1, column2 = unpack(library.columns);

local localCheats = column1:AddSection('Local Cheats');
local visualCheats = column1:AddSection('Visual Cheats');
local teleportCheats = column2:AddSection('Teleport Cheats');
local miscCheats = column2:AddSection('Misc Cheats');

-- Utility Functions
local IsA = clonefunction(game.IsA);
local FindFirstChild = clonefunction(game.FindFirstChild);
local FindFirstChildWhichIsA = clonefunction(game.FindFirstChildWhichIsA);

-- Variables
local chatLogger = TextLogger.new({
	title = 'Chat Logger',
	-- buttons = {'Spectate', 'Copy Username', 'Copy User Id', 'Copy Text'}
});

local animLogger = TextLogger.new({
    title = 'Animation Logger',
    buttons = {'Copy Animation Id', 'Add To Parry List', 'Add To Teleport List', 'Add To Ignore List', 'Delete Log', 'Clear All'}
});

animLogger.ignoreList = {};

local localPlayer = Players.LocalPlayer;

local funcs = {};

local maid = Maid.new();

library.unloadMaid:GiveTask(function()
    maid:DoCleaning();
end);

local remotes = ReplicatedStorage:WaitForChild('Events', 10);
if (not remotes) then
    return ToastNotif.new({text = 'Failed to load: ReplicatedStorage.Events is missing.'});
end;

local dataEvent, dataFunction = remotes:WaitForChild('DataEvent', 10), remotes:WaitForChild('DataFunction', 10);
if (not dataEvent or not dataFunction) then
    return ToastNotif.new({text = 'Failed to load: Events.DataEvent / Events.DataFunction is missing.'});
end;

local gameManagerModule = ReplicatedStorage:WaitForChild('GameManager', 10);
local gameManagerLoaded, gameManager = false, nil;

if (gameManagerModule) then
    gameManagerLoaded, gameManager = pcall(require, gameManagerModule);
end;

if (not gameManagerLoaded or typeof(gameManager) ~= 'table') then
    warn('[Bloodlines] Failed to load GameManager, purchasable items will be empty.', gameManager);
    gameManager = {Items = {}};
end;

local localPlayerData = Utility:getPlayerData();

local chakraPoints = {};
local npcs = {};
local mobs = {};
local purchasableItems = {};
local itemNames = {};

local loadSound;
local inDanger = false;

-- Functions
do
    -- Anti Cheat Bypass / No Fall Damage
    do
        local oldNamecall;

        oldNamecall = hookmetamethod(game, '__namecall', function(self, ...)
            local method = getnamecallmethod();

            if (self == dataEvent and (method == 'FireServer' or method == 'fireServer')) then
                local action = ...;

                if (typeof(action) == 'string' and string.lower(action) == 'banme') then
                    return warn('[Bloodlines] Blocked a BanMe remote call.');
                end;
            elseif (method == 'FindFirstChild' and library.flags.noFallDamage and not checkcaller()) then
                local childName = ...;

                if (childName == 'NegateFall') then
                    return true;
                end;
            end;

            return oldNamecall(self, ...);
        end);
    end;

    -- Remove Kill Bricks
    do
        local KILL_BRICKS_NAMES = {'LavarossaVoid', 'Void'};
        local killBricks = {};

        local function onDescendantAdded(object)
            if (not table.find(KILL_BRICKS_NAMES, object.Name)) then return end;

            table.insert(killBricks, {
                part = object,
                oldParent = object.Parent
            });

            if (library.flags.noKillBricks) then
                object.Parent = nil;
            end;
        end;

        function funcs.noKillBricks(state)
            for _, killBrick in next, killBricks do
                if (not killBrick.part) then continue end;

                killBrick.part.Parent = not state and killBrick.oldParent or nil;
            end;
        end;

        library.OnLoad:Connect(function()
            for _, v in next, workspace:GetDescendants() do
                if (table.find(KILL_BRICKS_NAMES, v.Name)) then
                    task.spawn(onDescendantAdded, v);
                end;
            end;

            maid.killBricksListener = workspace.DescendantAdded:Connect(onDescendantAdded);
        end);
    end;

    -- Chat Logger
    do
        local function onPlayerChatted(player, message)
            local timeText = DateTime.now():FormatLocalTime('H:mm:ss', 'en-us');
            local playerName = player.Name;
            local playerIngName = player:GetAttribute('CharacterName') or 'N/A';

            message = ('[%s] [%s] [%s] %s'):format(timeText, playerName, playerIngName, message);

            chatLogger:AddText({
                text = message,
                player = player
            });
        end;

        task.spawn(function()
            local chatEvents = ReplicatedStorage:WaitForChild('DefaultChatSystemChatEvents', 20);
            local messageDoneFiltering = chatEvents and chatEvents:WaitForChild('OnMessageDoneFiltering', 20);

            if (not messageDoneFiltering) then
                return warn('[Bloodlines] Legacy chat events not found, chat logger will stay empty.');
            end;

            maid.chatLoggerListener = messageDoneFiltering.OnClientEvent:Connect(function(messageData)
                local player, message = Players:FindFirstChild(messageData.FromSpeaker), messageData.Message;
                if (not player or not message) then return end;

                onPlayerChatted(player, message);
            end);
        end);

        function funcs.chatLogger(state)
            chatLogger:SetVisible(state);
        end;

        chatLogger.OnUpdate:Connect(function(updateType, vector)
            library.configVars['chatLogger' .. updateType] = tostring(vector);
        end);

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
    end;

    -- Danger Check
    do
        dataEvent.OnClientEvent:Connect(function(eventType, ...)
            if (eventType == 'InDanger') then
                if (not inDanger and library.flags.dangerNotifier) then
                    ToastNotif.new({text = 'You are now in danger.', duration = 5});
                end;

                inDanger = true;
            elseif (eventType == 'OutOfDanger') then
                if (inDanger and library.flags.dangerNotifier) then
                    ToastNotif.new({text = 'You are no longer in danger.', duration = 5});
                end;

                inDanger = false;
            end;
        end);
    end;

    -- Danger Checks Features (Reset Character, Instant Log)
    do
        function funcs.resetCharacter()
            local character = localPlayerData.character;
            if (not character) then return end;

            if (library:ShowConfirm('Are you sure you want to reset character?')) then
                character:BreakJoints();
            end;
        end;

        function funcs.instantLog()
            if (inDanger) then return ToastNotif.new({text = 'You can not do this right now. You are in danger.'}) end;

            localPlayer:Kick('');
            task.wait(2.5);
            game:Shutdown();
        end;
    end;

    -- Visuals Features
    do
        local oldFogEnd = Lighting.FogEnd;
        local oldBrightness = Lighting.Brightness;
        local oldClockTime = Lighting.ClockTime;

        function funcs.noRain(state)
            if (not state) then
                maid.noRainLoop = nil;
                return;
            end;

            maid.noRainLoop = task.spawn(function()
                local raining = ReplicatedStorage:WaitForChild('Raining', 10);

                if (not raining) then
                    return warn('[Bloodlines] ReplicatedStorage.Raining not found, no rain disabled.');
                end;

                while true do
                    raining.Value = '';
                    task.wait();
                end;
            end);
        end;

        function funcs.noFog(state)
            if (not state) then
                Lighting.FogEnd = oldFogEnd;
                maid.noFog = nil;
                return;
            end;

            maid.noFog = RunService.RenderStepped:Connect(function()
                Lighting.FogEnd = 9999999999;
            end);
        end;

        function funcs.fullBright(state)
            if (not state) then
                Lighting.Brightness = oldBrightness;
                maid.fullBright = nil;
                return;
            end;

            maid.fullBright = RunService.RenderStepped:Connect(function()
                Lighting.Brightness = library.flags.brightnessLevel;
            end);
        end;

        local clockTimes = {
            Morning = 6.3,
            Afternoon = 14,
            Evening = 18,
            Night = 0
        };

        function funcs.timeChanger(state)
            if (not state) then
                Lighting.ClockTime = oldClockTime;
                maid.timeChanger = nil;
                return;
            end;

            maid.timeChanger = RunService.RenderStepped:Connect(function()
                Lighting.ClockTime = clockTimes[library.flags.timeOfDay] or oldClockTime;
            end);
        end;
    end;

    -- ESP Objects
    local npcsESP = createBaseESP('npcs', {});
    local mobsESP = createBaseESP('mobs', {});
    local areasESP = createBaseESP('areas', {});
    local itemsESP = createBaseESP('items', {});
    local chakraPointsESP = createBaseESP('chakraPoints', {});

    -- Teleports
    do
        local chakraPointsInstances = {};

        local chakraPointsFolder = workspace:WaitForChild('ChakraPoints', 10);

        if (not chakraPointsFolder) then
            warn('[Bloodlines] workspace.ChakraPoints not found, chakra point teleports disabled.');
        end;

        for _, chakraPoint in next, chakraPointsFolder and chakraPointsFolder:GetChildren() or {} do
            local pointName = FindFirstChild(chakraPoint, 'PointName');
            local main = FindFirstChild(chakraPoint, 'Main');
            if (not pointName or not main) then continue end;

            table.insert(chakraPoints, pointName.Value);
            chakraPointsInstances[pointName.Value] = main.Position;

            chakraPointsESP.new(main, pointName.Value);
        end;

        table.sort(chakraPoints);

        function funcs.teleportToChakraPoint()
            local rootPart = localPlayerData.rootPart;
            if (not rootPart) then return end;

            local pos = chakraPointsInstances[library.flags.chakraPoint];
            if (not pos) then return ToastNotif.new({text = 'That chakra point no longer exists.'}) end;

            rootPart.CFrame = CFrame.new(pos - Vector3.new(0, 0, 5), pos);
        end;

        function funcs.teleportToPlayer()
            local player = Utility:getPlayerData(library.flags.playerTeleport);
            if (not player or not player.rootPart) then return end;

            local rootPart = localPlayerData.rootPart;
            if (not rootPart) then return end;

            rootPart.CFrame = player.rootPart.CFrame;
        end;
    end;

    -- Areas
    do
        local locations = workspace:WaitForChild('Locations', 10);

        if (not locations) then
            warn('[Bloodlines] workspace.Locations not found, areas ESP disabled.');
        end;

        for _, v in next, locations and locations:GetChildren() or {} do
            areasESP.new(v, v.Name);
        end;
    end;

    -- Workspace Entities (NPCs, Mobs, Pickupables, Attachables)
    do
        local npcsList = {};
        local mobsList = {};
        local pickupList = {};

        -- TrinketSpawn part -> {occupied, lastVisitAt}, filled from the boss rewards models
        local trinketSpawns = {};

        -- rootPart -> 'player' | 'mob' | 'npc', so attach to back can filter by what you actually want
        local attachTargets = {};

        local function onNpcAdded(object)
            local npcValue = object:WaitForChild('NPC', 10);
            if (not npcValue or not object.Parent) then return end;

            local rootPart = FindFirstChild(object, 'HumanoidRootPart') or FindFirstChild(object, 'Main');
            if (not rootPart) then return end;

            --[[
                Some bosses (Haku) ship with the Dialog tag even though they fight
                back, so bosses are always treated as combat mobs
            ]]
            local kind = bossLookup[bossKey(object.Name)] and 'Combat' or npcValue.Value;

            if (kind == 'Dialog') then
                table.insert(npcs, object.Name);
                npcsList[object.Name] = object;
                attachTargets[rootPart] = 'npc';

                local npcESP = npcsESP.new(rootPart, object.Name);

                object.Destroying:Connect(function()
                    table.remove(npcs, table.find(npcs, object.Name));
                    npcsList[object.Name] = nil;
                    attachTargets[rootPart] = nil;
                    npcESP:Destroy();
                end);
            elseif (kind == 'Combat') then
                -- onEntityAdded may have already tagged this as a player, we know better
                attachTargets[rootPart] = 'mob';

                local mobName = object.Name;

                -- Unlike dialog NPCs there can be a dozen of the same mob, so track them as a set per name
                if (not table.find(mobs, mobName)) then
                    table.insert(mobs, mobName);
                    table.sort(mobs);
                end;

                mobsList[mobName] = mobsList[mobName] or {};
                mobsList[mobName][rootPart] = true;

                local mobESP = mobsESP.new(rootPart, object.Name);

                object.Destroying:Connect(function()
                    attachTargets[rootPart] = nil;
                    mobsList[mobName][rootPart] = nil;
                    mobESP:Destroy();
                end);
            end;
        end;

        local function onPickupableAdded(object, isReward)
            local pickupable = object:WaitForChild('Pickupable', 10);
            if (not pickupable) then return end;

            local id = object:WaitForChild('ID', 10);
            if (not id or not object.Parent) then return end;

            pickupList[object] = {
                id = id,
                lastPickupAt = 0,
                isReward = isReward
            };

            local itemESP = itemsESP.new(object, object.Name);

            object.Destroying:Connect(function()
                pickupList[object] = nil;
                itemESP:Destroy();
            end);
        end;

        --[[
            Safe Teleport. Bosses telegraph everything with an animation, so when one we
            flagged starts playing we teleport flat out behind the boss and sit there
            until the move is over. Both farm loops watch coverUntil so they don't drag
            us straight back into it
        ]]
        local coverUntil = 0;

        local function moveBehind(rootPart)
            local myRootPart = localPlayerData.rootPart;
            if (not myRootPart or not rootPart.Parent) then return false end;

            -- Behind them in their own space, so we end up out of the swing arc
            local goalPos = (rootPart.CFrame * CFrame.new(0, library.flags.safeTeleportHeight, library.flags.safeTeleportDistance)).Position;

            -- Keep facing them so we can read the next move and swing the moment we're back
            myRootPart.CFrame = CFrame.lookAt(goalPos, rootPart.Position);

            return true;
        end;

        local function takeCover(rootPart, animationTrack)
            if (not moveBehind(rootPart)) then return end;

            -- Safe Teleport Time is the minimum stay, the animation itself extends it
            coverUntil = os.clock() + library.flags.safeTeleportTime;

            if (not animationTrack) then return end;

            --[[
                Ride the animation out instead of guessing at a duration, following the
                boss's back the whole way in case it turns or walks through us. The cap
                is there for tracks that never report stopping
            ]]
            task.spawn(function()
                local deadline = os.clock() + SAFE_TELEPORT_MAX_TIME;

                while (animationTrack.IsPlaying and library.flags.safeTeleport and os.clock() < deadline) do
                    coverUntil = math.max(coverUntil, os.clock() + SAFE_TELEPORT_BUFFER);

                    if (not moveBehind(rootPart)) then break end;

                    task.wait(SAFE_TELEPORT_STEP);
                end;

                -- One last beat so we aren't swinging into the tail of the move
                coverUntil = math.max(coverUntil, os.clock() + SAFE_TELEPORT_BUFFER);
            end);
        end;

        local function isTakingCover()
            return os.clock() < coverUntil;
        end;

        --[[
            Auto Grip. A downed enemy carries Settings.Knocked, and the finisher is a B
            press at point blank range, so park on their root part and hit it. gripUntil
            keeps auto farm from yanking us back to its parking offset mid grip
        ]]
        local GRIP_HOLD_TIME = 0.5;
        local GRIP_COOLDOWN = 1.5;
        local GRIP_SCAN_DELAY = 0.2;

        local gripUntil = 0;
        local lastGripAt = {};

        local function isGripping()
            return os.clock() < gripUntil;
        end;

        local function isKnocked(model)
            local settings = FindFirstChild(model, 'Settings');
            local knocked = settings and FindFirstChild(settings, 'Knocked');

            return knocked and knocked.Value == true;
        end;

        local function gripTarget(rootPart)
            local model = rootPart.Parent;
            local myRootPart = localPlayerData.rootPart;
            if (not myRootPart or not model) then return end;

            -- The grip animation needs a moment, so don't spam B at the same body
            if (os.clock() - (lastGripAt[model] or 0) < GRIP_COOLDOWN) then return end;

            lastGripAt[model] = os.clock();
            gripUntil = os.clock() + GRIP_HOLD_TIME;

            myRootPart.CFrame = CFrame.new(rootPart.Position);
            task.wait();

            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.B, false, game);
            task.wait();
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.B, false, game);
        end;

        function funcs.autoGrip(state)
            if (not state) then
                maid.autoGrip = nil;
                return;
            end;

            maid.autoGrip = task.spawn(function()
                while (library.flags.autoGrip) do
                    local myRootPart = localPlayerData.rootPart;

                    if (myRootPart) then
                        for rootPart in next, attachTargets do
                            local model = rootPart.Parent;
                            if (not model or not isKnocked(model)) then continue end;
                            if ((rootPart.Position - myRootPart.Position).Magnitude > library.flags.autoGripRange) then continue end;

                            gripTarget(rootPart);
                            break;
                        end;
                    end;

                    task.wait(GRIP_SCAN_DELAY);
                end;
            end);
        end;

        --[[
            Auto Block. Dangerous moves announce themselves before they land, either with
            a sound (Manda's SnakeBite, anyone's HeavyPunchCharge) or with a wind up
            animation (Haku's parryable), so block goes down the frame we see one and
            stays down until it's over
        ]]
        local blockHolds = 0;

        -- Binds can be a key or a mouse button, so send whichever the user picked
        local function setBlockHeld(held)
            local bind = library.options.blockKey;
            local key = bind and bind.key;
            if (not key) then return end;

            if (key == 'MouseButton1' or key == 'MouseButton2') then
                VirtualInputManager:SendMouseButtonEvent(0, 0, key == 'MouseButton1' and 0 or 1, held, game, 0);
                return;
            end;

            local gotKeyCode, keyCode = pcall(function()
                return Enum.KeyCode[key];
            end);

            if (not gotKeyCode or not keyCode) then return end;

            VirtualInputManager:SendKeyEvent(held, keyCode, false, game);
        end;

        --[[
            Presses block right away and holds it until isStillGoing() says the threat is
            over. Reference counted so two overlapping threats can't release each other
            early, and capped so a threat that vanishes mid-swing never sticks block down
        ]]
        local function holdBlockWhile(isStillGoing, minHoldTime)
            blockHolds += 1;

            if (blockHolds == 1) then
                setBlockHeld(true);
            end;

            local deadline = os.clock() + library.flags.autoBlockMaxTime;
            local minUntil = os.clock() + (minHoldTime or 0);

            repeat
                task.wait(0.05);
            until ((os.clock() >= minUntil and not isStillGoing()) or os.clock() > deadline);

            blockHolds -= 1;

            if (blockHolds <= 0) then
                blockHolds = 0;
                setBlockHeld(false);
            end;
        end;

        -- One hook per entity, shared by the animation logger, safe teleport and auto block
        local function onAnimationPlayed(object, rootPart, animationTrack)
            local animation = animationTrack.Animation;
            local animId = animation and string.match(tostring(animation.AnimationId), '%d+') or 'unknown';

            local myRootPart = localPlayerData.rootPart;
            if (not myRootPart) then return end;

            local distance = (myRootPart.Position - rootPart.Position).Magnitude;
            local kind = attachTargets[rootPart] or 'player';

            --[[
                Parries come first and without a task.spawn wrapper around the decision,
                so block is already down by the time this frame ends
            ]]
            if (library.flags.autoBlock and parryAnimations[animId] and distance <= library.flags.autoBlockRange) then
                task.spawn(holdBlockWhile, function()
                    return animationTrack.IsPlaying and library.flags.autoBlock;
                end, PARRY_MIN_HOLD);
            end;

            if (library.flags.safeTeleport and kind == 'mob' and coverAnimations[animId] and distance <= library.flags.safeTeleportRange) then
                takeCover(rootPart, animationTrack);
            end;

            if (not library.flags.animationLogger) then return end;
            if (animLogger.ignoreList[animId] or distance > library.flags.animLoggerMaxRange) then return end;

            animLogger:AddText({
                text = string.format('Animation <font color=\'#2ecc71\'>%s</font> played from <font color=\'#3498db\'>%s</font> [%s]', animId, object.Name, kind),
                animationId = animId
            });
        end;

        local function onEntityAdded(object)
            if (object == localPlayer.Character) then return end;

            local humanoid = object:WaitForChild('Humanoid', 10);
            if (not humanoid) then return end;

            local rootPart = object:WaitForChild('HumanoidRootPart', 10);
            if (not rootPart or not object.Parent) then return end;

            -- onNpcAdded classifies NPCs properly, so only claim this one if it hasn't already
            if (not attachTargets[rootPart] and not FindFirstChild(object, 'NPC')) then
                attachTargets[rootPart] = 'player';
            end;

            maid[humanoid] = humanoid.AnimationPlayed:Connect(function(animationTrack)
                onAnimationPlayed(object, rootPart, animationTrack);
            end);

            object.Destroying:Connect(function()
                attachTargets[rootPart] = nil;
                maid[humanoid] = nil;
            end);
        end;

        -- Sounds hang off parts, attachments or the model itself depending on the move
        local function getSoundPosition(sound)
            local parent = sound.Parent;
            if (not parent) then return nil end;

            if (IsA(parent, 'BasePart')) then
                return parent.Position;
            end;

            if (IsA(parent, 'Attachment')) then
                return parent.WorldPosition;
            end;

            if (IsA(parent, 'Model')) then
                local part = parent.PrimaryPart or FindFirstChildWhichIsA(parent, 'BasePart', true);
                return part and part.Position or nil;
            end;

            return nil;
        end;

        local function onSoundPlayed(sound)
            if (not library.flags.autoBlock or not blockSounds[sound.Name]) then return end;

            local myRootPart = localPlayerData.rootPart;
            if (not myRootPart) then return end;

            -- A sound with no position is global, so it's aimed at us either way
            local soundPosition = getSoundPosition(sound);

            if (soundPosition and (soundPosition - myRootPart.Position).Magnitude > library.flags.autoBlockRange) then
                return;
            end;

            ToastNotif.new({text = string.format('Blocking %s.', sound.Name)});

            task.spawn(holdBlockWhile, function()
                return sound.Parent and sound.IsPlaying and library.flags.autoBlock;
            end);
        end;

        local function onSoundAdded(object)
            if (not IsA(object, 'Sound')) then return end;

            --[[
                Bosses reuse their sound instances, so Played is what we really watch.
                A sound cloned in already playing never fires it, hence the second check
            ]]
            maid[object] = object.Played:Connect(function()
                onSoundPlayed(object);
            end);

            object.Destroying:Connect(function()
                maid[object] = nil;
            end);

            if (object.IsPlaying) then
                task.spawn(onSoundPlayed, object);
            end;
        end;

        --[[
            Attack sounds live under the target's HumanoidRootPart, and the map holds a
            few thousand descendants, so only the Sound instances get a listener
        ]]
        maid.soundListener = workspace.DescendantAdded:Connect(onSoundAdded);

        library.OnLoad:Connect(function()
            for _, object in next, workspace:GetDescendants() do
                if (IsA(object, 'Sound')) then
                    onSoundAdded(object);
                end;
            end;
        end);

        function funcs.animationLogger(state)
            animLogger:SetVisible(state);
        end;

        animLogger.OnClick:Connect(function(action, context)
            if (action == 'Copy Animation Id') then
                setclipboard(context.animationId);
            elseif (action == 'Add To Parry List') then
                addParryAnimation(context.animationId);
                ToastNotif.new({text = string.format('Blocking animation %s from now on.', context.animationId)});
            elseif (action == 'Add To Teleport List') then
                addCoverAnimation(context.animationId);
                ToastNotif.new({text = string.format('Teleporting away from animation %s from now on.', context.animationId)});
            elseif (action == 'Add To Ignore List') then
                animLogger.ignoreList[context.animationId] = true;
            elseif (action == 'Delete Log') then
                context:Destroy();
            elseif (action == 'Clear All') then
                for _, log in next, animLogger.logs do
                    log.label:Destroy();
                end;

                table.clear(animLogger.logs);
                table.clear(animLogger.allLogs);
            end;
        end);

        --[[
            Killing a boss drops a <BossName>Rewards model holding TrinketSpawn parts.
            A spawn only has loot on it once an Occupied value shows up underneath, and
            that happens seconds after the death, so we watch for it instead of reading
            the model once
        ]]
        local function watchTrinketSpawn(part)
            if (not IsA(part, 'BasePart') or not string.match(part.Name, '^TrinketSpawn')) then return end;

            local data = {lastVisitAt = 0, occupied = false};
            trinketSpawns[part] = data;

            local function onChildAdded(child)
                if (child.Name == 'Occupied') then
                    data.occupied = true;
                end;
            end;

            for _, child in next, part:GetChildren() do
                onChildAdded(child);
            end;

            local connections = {
                part.ChildAdded:Connect(onChildAdded),

                -- Occupied going away means somebody already took it
                part.ChildRemoved:Connect(function(child)
                    if (child.Name == 'Occupied') then
                        data.occupied = false;
                    end;
                end),

                part.Destroying:Connect(function()
                    trinketSpawns[part] = nil;
                    maid[part] = nil;
                end)
            };

            maid[part] = function()
                for _, connection in next, connections do
                    connection:Disconnect();
                end;
            end;
        end;

        local function onRewardsAdded(model)
            local bossName = string.match(model.Name, '^(.+)Rewards$');
            if (not bossName) then return end;

            -- Every rewards drop is named after a boss, so learn names we didn't hardcode
            addBossName((string.gsub(bossName, '%s*[Bb]oss%s*$', '')));

            maid[model] = Utility.listenToDescendantAdded(model, function(object)
                if (not IsA(object, 'BasePart')) then return end;

                watchTrinketSpawn(object);

                -- Anything under here that is a real pickupable gets an id we can ask for
                task.spawn(onPickupableAdded, object, true);
            end);

            model.Destroying:Connect(function()
                maid[model] = nil;
            end);
        end;

        local function onWorkspaceChildAdded(object)
            if (IsA(object, 'BasePart')) then
                return onPickupableAdded(object);
            end;

            if (not IsA(object, 'Model')) then return end;

            task.spawn(onRewardsAdded, object);
            task.spawn(onNpcAdded, object);
            task.spawn(onEntityAdded, object);
        end;

        maid.workspaceListener = Utility.listenToChildAdded(workspace, onWorkspaceChildAdded);

        -- Plenty of mobs share a name, so pick whichever one of them is closest
        local function getNearestMob(myPosition, mobName)
            local closest, closestDistance = nil, math.huge;

            for mobRootPart in next, mobsList[mobName] or {} do
                if (not mobRootPart.Parent) then continue end;

                local distance = (mobRootPart.Position - myPosition).Magnitude;

                if (distance < closestDistance) then
                    closest, closestDistance = mobRootPart, distance;
                end;
            end;

            return closest;
        end;

        function funcs.teleportToNPC()
            local npcName = library.flags.npcTeleport;
            local npc = npcsList[npcName];
            if (not npc) then return ToastNotif.new({text = 'That NPC is not loaded in this server.'}) end;

            local rootPart = localPlayerData.rootPart;
            if (not rootPart) then return end;

            local main = npc.PrimaryPart or FindFirstChild(npc, 'Main') or FindFirstChildWhichIsA(npc, 'BasePart', true);
            if (not main) then return end;

            rootPart.CFrame = CFrame.new(main.Position + Vector3.new(0, 0, -5), main.Position);
        end;

        function funcs.teleportToMob()
            local rootPart = localPlayerData.rootPart;
            if (not rootPart) then return end;

            local closest = getNearestMob(rootPart.Position, library.flags.mobTeleport);

            if (not closest) then
                return ToastNotif.new({text = 'No mob by that name is alive right now.'});
            end;

            rootPart.CFrame = CFrame.new(closest.Position + Vector3.new(0, 0, -5), closest.Position);
        end;

        -- The server ignores a second PickUp on the same item this quickly
        local PICKUP_COOLDOWN = 1;

        -- How long to stand on a trinket spawn, and how long before it's worth revisiting
        local TRINKET_VISIT_TIME = 0.35;
        local TRINKET_REVISIT_COOLDOWN = 2;

        --[[
            Sweeps up what a boss dropped. Occupied trinket spawns come first since that
            value is the only reliable sign loot actually landed there, then anything
            that also registered as a normal pickupable gets asked for by id
        ]]
        local function hasPendingRewards()
            for part, data in next, trinketSpawns do
                if (data.occupied and part.Parent) then return true end;
            end;

            return false;
        end;

        local function collectRewardDrops(myRootPart)
            for part, data in next, trinketSpawns do
                if (not data.occupied or not part.Parent) then continue end;
                if (os.clock() - data.lastVisitAt < TRINKET_REVISIT_COOLDOWN) then continue end;

                data.lastVisitAt = os.clock();
                myRootPart.CFrame = CFrame.new(part.Position);

                -- Standing on it is what makes the game hand the trinket over
                task.wait(TRINKET_VISIT_TIME);

                myRootPart = localPlayerData.rootPart;
                if (not myRootPart or not library.flags.autoFarm) then return end;
            end;

            for object, data in next, pickupList do
                if (not data.isReward or not object.Parent) then continue end;
                if (tick() - data.lastPickupAt < PICKUP_COOLDOWN) then continue end;

                data.lastPickupAt = tick();

                myRootPart.CFrame = CFrame.new(object.Position);
                task.wait();

                dataEvent:FireServer('PickUp', data.id.Value);

                myRootPart = localPlayerData.rootPart;
                if (not myRootPart or not library.flags.autoFarm) then return end;
            end;
        end;

        function funcs.autoPickup(state)
            if (not state) then
                maid.autoPickup = nil;
                return;
            end;

            local lastRanAt = 0;

            maid.autoPickup = RunService.Heartbeat:Connect(function()
                local rootPart = localPlayerData.rootPart;
                if (not rootPart or tick() - lastRanAt < 0.1) then return end;
                lastRanAt = tick();

                local myPosition = rootPart.Position;
                local maxDistance = library.flags.autoPickupRange;

                for object, data in next, pickupList do
                    if (tick() - data.lastPickupAt < PICKUP_COOLDOWN) then continue end;
                    if ((myPosition - object.Position).Magnitude > maxDistance) then continue end;

                    data.lastPickupAt = tick();
                    dataEvent:FireServer('PickUp', data.id.Value);
                end;
            end);
        end;

        local ATTACH_KIND_FLAGS = {
            player = 'attachToPlayers',
            mob = 'attachToMobs',
            npc = 'attachToNpcs'
        };

        -- Finds the closest enabled target to us that's still inside attach range
        local function getClosestEntity(myRootPart)
            local myPosition = myRootPart.Position;
            local closest, closestDistance = nil, math.huge;

            for rootPart, kind in next, attachTargets do
                if (not rootPart.Parent or rootPart == myRootPart) then continue end;
                if (not library.flags[ATTACH_KIND_FLAGS[kind]]) then continue end;

                local distance = (rootPart.Position - myPosition).Magnitude;

                if (distance < ATTACH_MAX_RANGE and distance < closestDistance) then
                    closest, closestDistance = rootPart, distance;
                end;
            end;

            return closest;
        end;

        --[[
            Resolves what attach to back should lock onto. Locked modes ignore the
            range limit on purpose so you can pull yourself across the map
        ]]
        local function getAttachTarget(myRootPart)
            local mode = library.flags.attachMode;

            if (mode == 'Locked Player') then
                local targetData = Utility:getPlayerData(library.flags.attachPlayer);
                local rootPart = targetData and targetData.rootPart;

                return rootPart ~= myRootPart and rootPart or nil;
            end;

            if (mode == 'Locked Mob') then
                return getNearestMob(myRootPart.Position, library.flags.attachMob);
            end;

            return getClosestEntity(myRootPart);
        end;

        --[[
            Where to sit relative to a target. The offset is applied in the target's
            own space, then we pitch/yaw straight at them so hitboxes still line up
            when the height offset puts us above or below them. Attach to back and
            auto farm keep their own offsets, since farming wants more breathing room
        ]]
        local function getAttachCFrame(targetCF, height, space)
            local offsetCF = targetCF * CFrame.new(0, height, space);
            local goalPos = offsetCF.Position;
            local toTarget = targetCF.Position - goalPos;

            -- lookAt with two identical points gives a NaN rotation
            if (toTarget.Magnitude <= ATTACH_MIN_STEP) then
                return offsetCF;
            end;

            --[[
                Sitting dead above/below them makes the default up vector parallel to
                the look direction, which is also NaN, so borrow the target's facing
            ]]
            local flat = Vector3.new(toTarget.X, 0, toTarget.Z);
            local up = flat.Magnitude <= ATTACH_MIN_STEP and targetCF.LookVector or Vector3.yAxis;

            return CFrame.lookAt(goalPos, targetCF.Position, up);
        end;

        --[[
            Snapping the root part around every frame leaves the character with
            leftover momentum and the humanoid fighting us over the rotation, which
            is what makes it flail and slide off. A zero velocity BodyVelocity eats
            the momentum and a BodyGyro pins the orientation we picked, so the pitch
            onto the target holds instead of being levelled out
        ]]
        local function createAttachMovers(rootPart)
            local bodyVelocity = Instance.new('BodyVelocity');
            bodyVelocity.Name = 'AttachVelocity';
            bodyVelocity.Velocity = Vector3.zero;
            bodyVelocity.MaxForce = ATTACH_MOVER_FORCE;
            bodyVelocity.P = 10000;
            bodyVelocity.Parent = rootPart;

            local bodyGyro = Instance.new('BodyGyro');
            bodyGyro.Name = 'AttachGyro';
            bodyGyro.MaxTorque = ATTACH_MOVER_FORCE;
            bodyGyro.P = 300000;
            bodyGyro.D = 1000;
            bodyGyro.CFrame = rootPart.CFrame;
            bodyGyro.Parent = rootPart;

            return bodyVelocity, bodyGyro;
        end;

        -- Keeps one pair of movers alive on whatever root part we currently own
        local function createMoverPool()
            local pool = {};
            local currentRootPart, bodyVelocity, bodyGyro, humanoid;

            function pool.apply(rootPart, goalCF)
                -- Respawning hands us a brand new root part, so rebuild on it
                if (rootPart ~= currentRootPart or not bodyGyro or not bodyGyro.Parent) then
                    pool.clear();

                    currentRootPart = rootPart;
                    bodyVelocity, bodyGyro = createAttachMovers(rootPart);

                    -- Auto rotate would snap our yaw back off the target on any movement input
                    humanoid = localPlayerData.humanoid;

                    if (humanoid) then
                        humanoid.AutoRotate = false;
                    end;
                end;

                bodyVelocity.Velocity = Vector3.zero;
                bodyGyro.CFrame = goalCF;
            end;

            function pool.clear()
                if (bodyVelocity) then
                    bodyVelocity:Destroy();
                end;

                if (bodyGyro) then
                    bodyGyro:Destroy();
                end;

                if (humanoid and humanoid.Parent) then
                    humanoid.AutoRotate = true;
                end;

                currentRootPart, bodyVelocity, bodyGyro, humanoid = nil, nil, nil, nil;
            end;

            return pool;
        end;

        library.OnKeyPress:Connect(function(input, gpe)
            if (gpe or not library.options.attachToBack) then return end;

            local key = library.options.attachToBack.key;
            if (input.KeyCode.Name ~= key and input.UserInputType.Name ~= key) then return end;

            local myRootPart = localPlayerData.rootPart;
            if (not myRootPart) then return end;

            local closest;

            -- Keep looking while the key is held, in case nothing is in range yet
            repeat
                closest = getAttachTarget(myRootPart);
                if (closest) then break end;

                task.wait();
            until (input.UserInputState == Enum.UserInputState.End);

            if (not closest or input.UserInputState == Enum.UserInputState.End) then return end;

            local movers = createMoverPool();

            maid.attachToBackMovers = function()
                movers.clear();
            end;

            maid.attachToBack = RunService.Heartbeat:Connect(function()
                -- The character can respawn while we're attached, so re-grab the root part every frame
                local rootPart = localPlayerData.rootPart;

                if (not rootPart or not closest.Parent) then
                    maid.attachToBack = nil;
                    maid.attachToBackTween = nil;
                    maid.attachToBackMovers = nil;
                    return;
                end;

                -- Safe teleport put us out of range on purpose, don't tween back in yet
                if (isTakingCover()) then
                    maid.attachToBackTween = nil;
                    return;
                end;

                local goalCF = getAttachCFrame(closest.CFrame, library.flags.attachToBackHeight, library.flags.attachToBackSpace);
                movers.apply(rootPart, goalCF);

                local distance = (goalCF.Position - rootPart.Position).Magnitude;
                local tween = TweenService:Create(rootPart, TweenInfo.new(distance / ATTACH_TWEEN_SPEED, Enum.EasingStyle.Linear), {
                    CFrame = goalCF
                });

                tween:Play();

                maid.attachToBackTween = function()
                    tween:Cancel();
                end;
            end);
        end);

        library.OnKeyRelease:Connect(function(input)
            if (not library.options.attachToBack) then return end;

            local key = library.options.attachToBack.key;
            if (input.KeyCode.Name ~= key and input.UserInputType.Name ~= key) then return end;

            maid.attachToBack = nil;
            maid.attachToBackTween = nil;
            maid.attachToBackMovers = nil;
        end);

        --[[
            Picks a living boss anywhere in the server, nearest first. Regular mobs are
            never worth the swings, and there's no range limit because we teleport onto
            the target anyway. Picking a name in the boss list farms only that boss
        ]]
        local function getFarmTarget(myPosition)
            local wantedKey = bossKey(library.flags.autoFarmBoss);
            local closest, closestDistance = nil, math.huge;

            for rootPart, kind in next, attachTargets do
                local model = rootPart.Parent;
                if (kind ~= 'mob' or not model) then continue end;

                local modelKey = bossKey(model.Name);
                if (not bossLookup[modelKey]) then continue end;
                if (wantedKey ~= '' and modelKey ~= wantedKey) then continue end;

                local humanoid = FindFirstChildWhichIsA(model, 'Humanoid');
                if (not humanoid or humanoid.Health <= 0) then continue end;

                local distance = (rootPart.Position - myPosition).Magnitude;

                if (distance < closestDistance) then
                    closest, closestDistance = rootPart, distance;
                end;
            end;

            return closest;
        end;

        -- Remembered so we can walk back to the grind spot after respawning
        local lastFarmPosition;

        --[[
            Parks us on the target using its offsets, then swings with a real left
            click. Going through VirtualInputManager means the game fires its own
            CheckMeleeHit, so we never touch the remote ourselves.

            Holding the spot runs on Heartbeat while the swings run on their own
            cooldown loop, otherwise we'd only correct our position once per swing and
            spend the gap between them drifting off the boss
        ]]
        function funcs.autoFarm(state)
            if (not state) then
                maid.autoFarm = nil;
                maid.autoFarmHold = nil;
                maid.autoFarmMovers = nil;
                return;
            end;

            local movers = createMoverPool();
            local target;

            --[[
                Set when the boss we were on dies, so we stay for the trinkets it owes us.
                Occupied spawns extend the wait, up to the hard deadline that keeps a spawn
                we can't actually loot from parking us there forever
            ]]
            local rewardDeadline = 0;
            local rewardHardDeadline = 0;
            local hadTarget = false;

            -- True while we're sitting in the sky waiting on regen
            local retreating = false;

            maid.autoFarmMovers = function()
                movers.clear();
            end;

            --[[
                Hovers straight up out of reach and stays there until we've healed back
                past the resume threshold, instead of giving up on the farm entirely
            ]]
            local function retreatAndHeal(healthPercent)
                retreating = true;
                target = nil;

                ToastNotif.new({text = string.format('Health at %d%%, pulling out to heal.', healthPercent), duration = 5});

                local goalCF;

                while (library.flags.autoFarm and library.flags.autoFarmRetreatOnLowHealth) do
                    local rootPart = localPlayerData.rootPart;

                    -- Died on the way out, the respawn handler takes it from here
                    if (not rootPart) then break end;

                    -- Anchored to where we first pulled out, so we don't drift up forever
                    goalCF = goalCF or CFrame.new(rootPart.Position + Vector3.new(0, library.flags.autoFarmRetreatHeight, 0));

                    movers.apply(rootPart, goalCF);
                    rootPart.CFrame = goalCF;

                    local _, _, currentHealth = Utility:getCharacter();
                    if (not currentHealth or currentHealth >= library.flags.autoFarmResumeHealth) then break end;

                    task.wait(0.25);
                end;

                retreating = false;
                movers.clear();

                ToastNotif.new({text = 'Healed up, back to farming.'});
            end;

            maid.autoFarmHold = RunService.Heartbeat:Connect(function()
                local myRootPart = localPlayerData.rootPart;
                if (not myRootPart or not target or not target.Parent) then return end;

                --[[
                    Mid safe teleport the movers keep us parked out of reach, mid grip we
                    need to stay on the body, and mid retreat we're healing in the sky, so
                    leave the position alone in all three cases
                ]]
                if (isTakingCover() or isGripping() or retreating) then return end;

                local offsets = getBossOffsets(target.Parent.Name);
                local goalCF = getAttachCFrame(target.CFrame, offsets.height, offsets.space);

                movers.apply(myRootPart, goalCF);
                myRootPart.CFrame = goalCF;
            end);

            maid.autoFarm = task.spawn(function()
                while (library.flags.autoFarm) do
                    local myRootPart = localPlayerData.rootPart;
                    local _, _, healthPercent = Utility:getCharacter();

                    -- Pull out before swinging, otherwise we trade the last hit and die anyway
                    if (library.flags.autoFarmRetreatOnLowHealth and healthPercent and healthPercent <= library.flags.autoFarmRetreatHealth) then
                        retreatAndHeal(healthPercent);
                        continue;
                    end;

                    -- While the last kill still owes us trinkets we don't go looking for a new boss
                    local waitingForRewards = os.clock() < rewardDeadline
                        or (os.clock() < rewardHardDeadline and hasPendingRewards());
                    target = (not waitingForRewards) and myRootPart and getFarmTarget(myRootPart.Position) or nil;

                    if (isTakingCover()) then
                        -- Riding out a telegraphed move, no swinging and no wandering off
                    elseif (target) then
                        lastFarmPosition = target.Position;
                        hadTarget = true;

                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0);
                        task.wait();
                        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0);
                    elseif (myRootPart) then
                        -- Nothing left to hit, so let go and go bank what the boss dropped
                        movers.clear();

                        if (hadTarget) then
                            hadTarget = false;
                            rewardDeadline = os.clock() + REWARD_SPAWN_WAIT;
                            rewardHardDeadline = os.clock() + REWARD_SPAWN_WAIT_MAX;
                        end;

                        collectRewardDrops(myRootPart);
                    end;

                    task.wait(AUTO_FARM_SWING_DELAY);
                end;
            end);
        end;

        --[[
            You respawn miles from the grind spot, so the farm loop would just idle
            out of range forever. Drag ourselves back to where we last hit something
        ]]
        Utility.onLocalCharacterAdded:Connect(function(playerData)
            if (not library.flags.autoFarmReturnOnDeath or not lastFarmPosition) then return end;
            if (not library.flags.autoFarm) then return end;

            local rootPart = playerData.rootPart or playerData.character:WaitForChild('HumanoidRootPart', 10);
            if (not rootPart) then return end;

            -- The character isn't done loading the frame it spawns, moving it too early gets undone
            task.wait(RESPAWN_SETTLE_TIME);
            if (not rootPart.Parent or not library.flags.autoFarm) then return end;

            rootPart.CFrame = CFrame.new(lastFarmPosition + Vector3.new(0, 0, -5), lastFarmPosition);
            ToastNotif.new({text = 'Returned to the farm spot.'});
        end);
    end;

    -- ESP UI
    do
        function Utility:renderOverload(data)
            local mobsSection = data.column1:AddSection('Mobs');
            local itemsSection = data.column1:AddSection('Items');
            local npcsSection = data.column2:AddSection('NPCs');
            local areasSection = data.column2:AddSection('Areas');
            local chakraSection = data.column2:AddSection('Chakra Points');

            local function makeFor(section, flagName, espObject)
                section:AddToggle({
                    text = 'Enable',
                    flag = flagName,
                    callback = function (state)
                        if (not state) then
                            maid['update' .. flagName .. 'esp'] = nil;
                            espObject:UnloadAll();
                            return;
                        end;

                        maid['update' .. flagName .. 'esp'] = RunService.RenderStepped:Connect(function()
                            espObject:UpdateAll();
                        end);
                    end;
                });

                section:AddToggle({
                    text = 'Show Distance',
                    flag = flagName .. ' Show Distance'
                });

                section:AddSlider({
                    text = 'Max Distance',
                    flag = flagName .. ' Max Distance',
                    min = 100,
                    value = 100000,
                    max = 100000,
                    float = 100,
                    textpos = 2
                });

                -- Fallback color for anything in this category without its own picker
                section:AddColor({
                    text = `{flagName} Color`,
                    color = Color3.new(1, 1, 1)
                });
            end;

            -- Per-name show filter + color picker, same as Permafall's trinkets
            local function makeNameList(section, names)
                for _, name in next, names do
                    section:AddToggle({
                        text = name,
                        flag = `Show {name}`,
                        state = true
                    }):AddColor({
                        text = `{name} Color`,
                        color = Color3.new(1, 1, 1)
                    });
                end;
            end;

            makeFor(npcsSection, 'Npcs', npcsESP);
            makeFor(mobsSection, 'Mobs', mobsESP);
            makeFor(areasSection, 'Areas', areasESP);
            makeFor(itemsSection, 'Items', itemsESP);
            makeFor(chakraSection, 'Chakra Points', chakraPointsESP);

            if (#itemNames > 0) then
                itemsSection:AddDivider('Per Item');
                makeNameList(itemsSection, itemNames);
            end;

            mobsSection:AddToggle({
                text = 'Show Health',
                flag = 'Mobs Show Health'
            });
        end;
    end;

    -- Player ESP Plugin
    do
        function EntityESP:Plugin()
            local characterNameText = '';

            if (library.flags.showCharacterName) then
                local player = self._player;
                local characterName = player and player:GetAttribute('CharacterName');

                if (characterName) then
                    characterNameText = ` [{characterName}]`;
                end;
            end;

            return {
                text = characterNameText,
                playerName = self._playerName
            };
        end;
    end;

    do -- // Download Assets
        local assetsList = {'ModeratorJoin.mp3', 'ModeratorLeft.mp3'};
        local audios = {};

        local apiEndpoint = 'https://rukiascripts.xyz/';

        for i, v in next, assetsList do
            audios[v] = AudioPlayer.new({
                url = `{apiEndpoint}{v}`,
                volume = 10,
                forcedAudio = true
            });
        end;

        function loadSound(soundName: string): ()
            if ((soundName == 'ModeratorJoin.mp3' or soundName == 'ModeratorLeft.mp3') and not library.flags.modNotifier) then
                return;
            end;

            audios[soundName]:Play();
        end;
    end;

        -- Add Purchasable Items
    do
        for itemName, item in next, gameManager.Items do
            if (item.Buyabble) then
                table.insert(purchasableItems, itemName);
            end;
        end;
    end;
    
    -- Mod Detector
    do
        local GROUP_ID = 7450839;

        Utility.onPlayerAdded:Connect(function(player)
            local success, rank = pcall(originalFunctions.getRankInGroup, player, GROUP_ID);
            if (not success or rank == 0) then return end;

            ToastNotif.new({
                text = string.format('Moderator detected [%s]', player.Name)
            });

            if (library.flags.moderatorSoundAlert) then
                loadSound('ModeratorJoin.mp3');
            end;

            player.Destroying:Connect(function()
                ToastNotif.new({
                    text = string.format('Moderator left [%s]', player.Name)
                });

                if (library.flags.moderatorSoundAlert) then
                    loadSound('ModeratorLeft.mp3');
                end;
            end);
        end);
    end;

    -- Right Click Spectate
    do
        Utility.onLocalCharacterAdded:Connect(function(playerData)
            local clientGui = localPlayer.PlayerGui:WaitForChild('ClientGui', 10);
            if (not clientGui) then return end;

            local playerList = clientGui.Mainframe.PlayerList.List;
            local lastSpectating;
            local lastSpectatingObject;

            local function spectate(player, obj)
                local targetData = Utility:getPlayerData(player);
                if (not targetData) then return end;

                local playerHumanoid = targetData.humanoid;

                if (not player or lastSpectating == player) then
                    if (lastSpectatingObject) then
                        lastSpectatingObject.PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255);
                        lastSpectatingObject = nil;
                    end;

                    lastSpectating = nil;

                    local humanoid = localPlayerData.humanoid;
                    if (not humanoid) then return end;

                    workspace.CurrentCamera.CameraSubject = humanoid;
                    return;
                end;

                if (lastSpectatingObject) then
                    lastSpectatingObject.PlayerName.TextColor3 = Color3.fromRGB(255, 255, 255);
                end;

                lastSpectatingObject = obj;
                lastSpectating = player;

                if (player ~= localPlayer) then
                    obj.PlayerName.TextColor3 = Color3.fromRGB(255, 0, 0);
                end;

                workspace.CurrentCamera.CameraSubject = playerHumanoid;
            end;

            local function onChildAdded(obj)
                local playerName = obj:WaitForChild('RealName', 10);
                if (not playerName) then return end;

                obj.InputBegan:Connect(function(inputObject)
                    if (inputObject.UserInputType ~= Enum.UserInputType.MouseButton2) then return end;

                    local humanoid = localPlayerData.humanoid;
                    if (not humanoid) then return spectate() end;

                    local player = Players:FindFirstChild(playerName.Value);
                    if (not player) then return spectate() end;

                    -- Attempt to spectate player
                    spectate(player, obj);
                end);
            end;

            Utility.listenToChildAdded(playerList, onChildAdded);
        end);
    end;

    -- Server Hopping
    do
        local SERVER_LIST_KEY = 'thunderStormServerList';

        local function fetchServerList()
            local serverListData = {};
            local cursor = '';
            local attempts = 0;

            while (true) do
                local success, serverList = pcall(request, {
                    Url = string.format('https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&cursor=%s', MAIN_PLACE_ID, cursor)
                });

                if (not success or not serverList.Success) then
                    attempts += 1;
                    if (attempts > 5) then break end;

                    task.wait(2);
                    continue;
                end;

                local decoded;
                success, decoded = pcall(HttpService.JSONDecode, HttpService, serverList.Body);
                if (not success or typeof(decoded) ~= 'table') then break end;

                for _, server in next, decoded.data or {} do
                    if (server.id == game.JobId) then continue end;

                    table.insert(serverListData, server.id);
                end;

                if (not decoded.nextPageCursor or not decoded.data) then break end;

                cursor = decoded.nextPageCursor;
                task.wait(0.5);
            end;

            return serverListData;
        end;

        -- Server list is cached across teleports so we don't hop back into servers we already tried
        local function getServerList()
            local cached = MemStorageService:HasItem(SERVER_LIST_KEY) and MemStorageService:GetItem(SERVER_LIST_KEY);

            if (cached) then
                local success, decoded = pcall(HttpService.JSONDecode, HttpService, cached);
                if (success and typeof(decoded) == 'table' and #decoded > 0) then
                    return decoded;
                end;
            end;

            local serverList = fetchServerList();
            MemStorageService:SetItem(SERVER_LIST_KEY, HttpService:JSONEncode(serverList));

            return serverList;
        end;

        local function saveServerList(serverList)
            MemStorageService:SetItem(SERVER_LIST_KEY, HttpService:JSONEncode(serverList));
        end;

        function funcs.serverHop()
            local serverList = getServerList();

            if (#serverList == 0) then
                return ToastNotif.new({text = 'Could not find any other server to hop to.'});
            end;

            local serverId = table.remove(serverList, math.random(1, #serverList));
            saveServerList(serverList);

            ToastNotif.new({text = 'Hopping to a new server...'});
            dataEvent:FireServer('ServerTeleport', serverId);
        end;

        function funcs.findThunderstormServer(state)
            if (not state) then
                maid.thunderstormFinder = nil;
                return;
            end;

            maid.thunderstormFinder = task.spawn(function()
                ToastNotif.new({text = 'Thunderstorm Server Finder is running!'});

                local thunderStorm = workspace:WaitForChild('Thunderstorm', 5);

                if (thunderStorm) then
                    return ToastNotif.new({text = 'Found thunderstorm in this server!'});
                end;

                ToastNotif.new({text = 'No thunderstorm was found on this server, finding new server...'});

                local serverList = getServerList();

                while (library.flags.thunderstormServerFinder) do
                    if (#serverList == 0) then
                        serverList = fetchServerList();

                        if (#serverList == 0) then
                            ToastNotif.new({text = 'Ran out of servers to hop to, stopping.'});
                            break;
                        end;
                    end;

                    local serverId = table.remove(serverList, math.random(1, #serverList));
                    saveServerList(serverList);

                    dataEvent:FireServer('ServerTeleport', serverId);
                    task.wait(15);
                end;
            end);
        end;

        --[[
            Bosses aren't a named singleton like Thunderstorm is, so we poll workspace
            for a bit instead. They can also spawn in after we land
        ]]
        local function waitForBoss()
            local deadline = os.clock() + BOSS_SCAN_TIME;

            repeat
                for _, object in next, workspace:GetChildren() do
                    if (bossLookup[bossKey(object.Name)]) then
                        return object.Name;
                    end;
                end;

                task.wait(0.5);
            until (os.clock() > deadline);

            return nil;
        end;

        function funcs.findBossServer(state)
            if (not state) then
                maid.bossFinder = nil;
                return;
            end;

            maid.bossFinder = task.spawn(function()
                ToastNotif.new({text = 'Boss Server Finder is running!'});

                local boss = waitForBoss();

                if (boss) then
                    return ToastNotif.new({text = string.format('Found %s in this server!', boss), duration = 5});
                end;

                ToastNotif.new({text = 'No boss was found on this server, finding new server...'});

                local serverList = getServerList();

                while (library.flags.bossServerFinder) do
                    if (#serverList == 0) then
                        serverList = fetchServerList();

                        if (#serverList == 0) then
                            ToastNotif.new({text = 'Ran out of servers to hop to, stopping.'});
                            break;
                        end;
                    end;

                    local serverId = table.remove(serverList, math.random(1, #serverList));
                    saveServerList(serverList);

                    dataEvent:FireServer('ServerTeleport', serverId);
                    task.wait(BOSS_HOP_TIME);
                end;
            end);
        end;
    end;

    -- Chakra Sense Alert
    do
        local function onChildAdded(obj)
            local function onChildAdded2(obj2)
                if (obj2.Name == 'Chakra Sense' and library.flags.chakraSenseNotifier) then
                    ToastNotif.new({
                        text = string.format('%s has chakra sense', obj.Name)
                    });
                end;
            end;

            Utility.listenToChildAdded(obj, onChildAdded2);
        end;

        library.OnLoad:Connect(function()
            local cooldowns = ReplicatedStorage:WaitForChild('Cooldowns', 10);

            if (not cooldowns) then
                return warn('[Bloodlines] ReplicatedStorage.Cooldowns not found, chakra sense alert disabled.');
            end;

            maid.cooldownsListener = Utility.listenToChildAdded(cooldowns, onChildAdded);
        end);
    end;

    function funcs.fly(toggle: boolean): ()
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
            
            maid.flyBv.Parent = rootPart;
            maid.flyBv.Velocity = camera.CFrame:VectorToWorldSpace(ControlModule:GetMoveVector() * library.flags.flyHackValue);
        end);
    end;


    function funcs.infiniteJump(state)
        if (not state) then
            maid.infiniteJump = nil;
            return;
        end;

        maid.infiniteJump = UserInputService.JumpRequest:Connect(function()
            local humanoid = localPlayerData.humanoid;
            if (not humanoid) then return end;

            humanoid:ChangeState(Enum.HumanoidStateType.Jumping);
        end);
    end;

    function funcs.speedHack(toggle)
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

            maid.speedHackBv.Parent = not library.flags.fly and rootPart or nil;
            maid.speedHackBv.Velocity = (humanoid.MoveDirection.Magnitude ~= 0 and humanoid.MoveDirection or gethiddenproperty(humanoid, 'WalkDirection')) * library.flags.speedHackValue;
        end);
    end;

    function funcs.noClip(state)
        if (not state) then
            maid.noClipStep = nil;
            return;
        end;

        maid.noClipStep = RunService.Stepped:Connect(function()
            -- Utility keeps localPlayerData.parts up to date, so we don't have to walk the character every frame
            local parts = localPlayerData.parts;
            if (not parts) then return end;

            debug.profilebegin('NoClip');

            for _, part in next, parts do
                if (part.CanCollide) then
                    part.CanCollide = false;
                end;
            end;

            debug.profileend();
        end);
    end;

    function funcs.removeFF()
        local character = localPlayerData.character;
        if (not character) then return end;

        local forceField = FindFirstChildWhichIsA(character, 'ForceField');
        if (not forceField) then return end;

        forceField:Destroy();
    end;
end;

-- Add Features To UI
localCheats:AddDivider('Movement');

localCheats:AddToggle({
    text = 'Fly',
    callback = funcs.fly
});
localCheats:AddSlider({
    min = 16,
    max = 1000,
    flag = 'Fly Hack Value',
    textpos = 2
});

localCheats:AddToggle({
    text = 'Speedhack',
    callback = funcs.speedHack
});
localCheats:AddSlider({
    min = 16,
    max = 1000,
    flag = 'Speed Hack Value',
    textpos = 2
});

localCheats:AddToggle({
    text = 'Infinite Jump',
    callback = funcs.infiniteJump
});

localCheats:AddToggle({
    text = 'No Clip',
    callback = funcs.noClip
});

localCheats:AddDivider('Attach To Back');

localCheats:AddBind({
    text = 'Attach To Back',
    mode = 'hold',
    tip = 'Hold to tween onto your target.'
});

localCheats:AddList({
    text = 'Attach Mode',
    values = {'Nearest', 'Locked Player', 'Locked Mob'},
    tip = 'Locked modes ignore the range limit, so you can pull yourself in from anywhere.'
});

localCheats:AddList({text = 'Attach Player', playerOnly = true});
localCheats:AddList({text = 'Attach Mob', values = mobs});

localCheats:AddToggle({text = 'Attach To Players', state = true, tip = 'Nearest mode only.'});
localCheats:AddToggle({text = 'Attach To Mobs', state = true, tip = 'Nearest mode only.'});
localCheats:AddToggle({text = 'Attach To Npcs', tip = 'Nearest mode only. Dialog NPCs never move, so this is off by default.'});

localCheats:AddSlider({
    text = 'Attach To Back Height',
    min = -100,
    value = 0,
    max = 100,
    textpos = 2
});

localCheats:AddSlider({
    text = 'Attach To Back Space',
    min = -100,
    value = 2,
    max = 100,
    textpos = 2
});

localCheats:AddDivider('Auto Farm');

localCheats:AddToggle({
    text = 'Auto Farm',
    callback = funcs.autoFarm,
    tip = 'Parks on the nearest living boss anywhere in the server and left clicks.'
});

--[[
    Picks which boss to farm, and which boss the height/space sliders below belong to,
    so you can tune a parking spot per boss and switch between them without losing the
    last one. Nearest farms every boss and edits the offsets they all start on
]]
localCheats:AddList({
    text = 'Auto Farm Boss',
    values = bossNames,
    tip = 'The boss to farm, and the one the sliders below configure.',
    callback = function(bossName)
        local heightSlider, spaceSlider = library.options.autoFarmHeight, library.options.autoFarmSpace;

        -- This can fire while the menu is still building, before the sliders are drawn
        if (not heightSlider or not heightSlider.SetValue or not spaceSlider) then return end;

        local offsets = getEditableOffsets(bossName);

        heightSlider:SetValue(offsets.height, true);
        spaceSlider:SetValue(offsets.space, true);
    end
});

local autoFarmHeightSlider = localCheats:AddSlider({
    text = 'Auto Farm Height',
    min = -100,
    max = 100,
    textpos = 2,
    tip = 'How far above the selected boss to sit. We still aim down at it.',
    callback = function(value)
        getEditableOffsets(library.flags.autoFarmBoss).height = value;
    end
});

local autoFarmSpaceSlider = localCheats:AddSlider({
    text = 'Auto Farm Space',
    min = -100,
    max = 100,
    textpos = 2,
    tip = 'How far behind the selected boss to park. Raise it if you end up inside it.',
    callback = function(value)
        getEditableOffsets(library.flags.autoFarmBoss).space = value;
    end
});

--[[
    The library pins any slider with a negative min to 0, so seed the real defaults
    straight onto the options. They're picked up by the deferred init, or overwritten
    by your config if you saved one
]]
autoFarmHeightSlider.value = AUTO_FARM_DEFAULT_HEIGHT;
autoFarmSpaceSlider.value = AUTO_FARM_DEFAULT_SPACE;

library.flags[autoFarmHeightSlider.flag] = AUTO_FARM_DEFAULT_HEIGHT;
library.flags[autoFarmSpaceSlider.flag] = AUTO_FARM_DEFAULT_SPACE;

localCheats:AddToggle({
    text = 'Auto Farm Return On Death',
    state = true,
    tip = 'Teleports back to the last boss you hit after respawning.'
});

localCheats:AddToggle({
    text = 'Auto Farm Retreat On Low Health',
    state = true,
    tip = 'Hovers out of reach until you regen instead of stopping the farm.'
});

localCheats:AddSlider({
    text = 'Auto Farm Retreat Health',
    min = 5,
    value = 35,
    max = 95,
    textpos = 2,
    tip = 'Health percent that sends you up to heal.'
});

localCheats:AddSlider({
    text = 'Auto Farm Resume Health',
    min = 10,
    value = 90,
    max = 100,
    textpos = 2,
    tip = 'Health percent to heal back to before dropping onto the boss again.'
});

localCheats:AddSlider({
    text = 'Auto Farm Retreat Height',
    min = 50,
    value = 500,
    max = 2000,
    textpos = 2,
    tip = 'How far straight up to hover while healing.'
});

localCheats:AddDivider('Auto Grip');

localCheats:AddToggle({
    text = 'Auto Grip',
    callback = funcs.autoGrip,
    tip = 'Teleports onto anything with Settings.Knocked set and presses B to grip it.'
});

localCheats:AddSlider({
    text = 'Auto Grip Range',
    min = 10,
    value = 150,
    max = 500,
    textpos = 2,
    tip = 'Only grip knocked targets this close.'
});

localCheats:AddDivider('Safe Teleport');

localCheats:AddToggle({
    text = 'Safe Teleport',
    tip = 'Teleports behind the boss the moment it starts one of the animations you flagged.'
});

localCheats:AddBox({
    text = 'Teleport Animation Ids',
    value = DEFAULT_TELEPORT_ANIMATIONS,
    tip = 'Animation ids to run from, comma separated. Grab them from the Animation Logger.',
    callback = setCoverAnimations
});

localCheats:AddSlider({
    text = 'Safe Teleport Range',
    min = 20,
    value = 120,
    max = 500,
    textpos = 2,
    tip = 'Only react to animations from mobs this close.'
});

localCheats:AddSlider({
    text = 'Safe Teleport Distance',
    min = 10,
    value = 60,
    max = 300,
    textpos = 2,
    tip = 'How far behind the boss to land.'
});

localCheats:AddSlider({
    text = 'Safe Teleport Height',
    min = 0,
    value = 20,
    max = 200,
    textpos = 2,
    tip = 'Extra height on the landing spot, for moves that track along the ground.'
});

localCheats:AddSlider({
    text = 'Safe Teleport Time',
    min = 0.5,
    value = 2,
    max = 10,
    float = 0.1,
    textpos = 2,
    tip = 'How long to stay out before auto farm parks you back on the boss.'
});

localCheats:AddDivider('Auto Block');

localCheats:AddToggle({
    text = 'Auto Block',
    tip = 'Holds block while a flagged wind up sound is playing near you.'
});

localCheats:AddBind({
    text = 'Block Key',
    key = 'F',
    tip = 'The key or mouse button this game blocks with.'
});

localCheats:AddBox({
    text = 'Block Sound Names',
    value = DEFAULT_BLOCK_SOUNDS,
    tip = 'Sound names to block through, comma separated. They sit under the target\'s root part.',
    callback = setBlockSounds
});

localCheats:AddBox({
    text = 'Parry Animation Ids',
    value = DEFAULT_PARRY_ANIMATIONS,
    tip = 'Animation ids to block the instant they start, comma separated. Defaults to Haku\'s.',
    callback = setParryAnimations
});

localCheats:AddSlider({
    text = 'Auto Block Range',
    min = 20,
    value = 150,
    max = 500,
    textpos = 2,
    tip = 'Only react to sounds this close.'
});

localCheats:AddSlider({
    text = 'Auto Block Max Time',
    min = 0.5,
    value = 5,
    max = 15,
    float = 0.1,
    textpos = 2,
    tip = 'Safety cap, so a sound that dies mid playback can never leave block stuck down.'
});

localCheats:AddDivider('Pickups');

localCheats:AddToggle({text = 'Auto Pickup', callback = funcs.autoPickup});

localCheats:AddSlider({
    text = 'Auto Pickup Range',
    min = 5,
    value = 50,
    max = 250,
    textpos = 2
});

localCheats:AddDivider('Protection');

localCheats:AddToggle({text = 'No Kill Bricks', callback = funcs.noKillBricks});
localCheats:AddToggle({text = 'No Fall Damage'});

localCheats:AddDivider('Notifiers');

localCheats:AddToggle({text = 'Moderator Sound Alert'});
localCheats:AddToggle({text = 'Chakra Sense Notifier', state = true});
localCheats:AddToggle({text = 'Danger Notifier', state = true});

localCheats:AddDivider('Chat Logger');

localCheats:AddToggle({text = 'Chat Logger', callback = funcs.chatLogger});
localCheats:AddToggle({text = 'Chat Logger Auto Scroll'});

localCheats:AddDivider('Animation Logger');

localCheats:AddToggle({
    text = 'Animation Logger',
    callback = funcs.animationLogger,
    tip = 'Logs animation ids from everything nearby, with buttons to copy them or flag them for safe teleport.'
});

localCheats:AddSlider({
    text = 'Anim Logger Max Range',
    min = 10,
    value = 100,
    max = 500,
    textpos = 2,
    tip = 'Only log animations from entities this close.'
});

localCheats:AddDivider('Character');

localCheats:AddButton({text = 'Reset Character', callback = funcs.resetCharacter});
localCheats:AddButton({text = 'Remove ForceField', callback = funcs.removeFF});
localCheats:AddBind({text = 'Instant Log', nomouse = true, callback = funcs.instantLog});

visualCheats:AddDivider('ESP');

visualCheats:AddToggle({text = 'Show Character Name', state = true, tip = 'Shows the in-game character name on the player ESP.'});

visualCheats:AddDivider('World');

visualCheats:AddToggle({text = 'No Fog', callback = funcs.noFog});
visualCheats:AddToggle({text = 'No Rain', callback = funcs.noRain});

visualCheats:AddToggle({text = 'Full Bright', callback = funcs.fullBright});

visualCheats:AddSlider({
    text = 'Brightness Level',
    min = 1,
    value = 5,
    max = 10,
    float = 0.1,
    textpos = 2
});

visualCheats:AddToggle({text = 'Time Changer', callback = funcs.timeChanger});

visualCheats:AddList({
    text = 'Time Of Day',
    values = {'Morning', 'Afternoon', 'Evening', 'Night'}
});

teleportCheats:AddDivider('Chakra Points');
teleportCheats:AddList({text = 'Chakra Point', values = chakraPoints});
teleportCheats:AddButton({text = 'Teleport To', callback = funcs.teleportToChakraPoint});

teleportCheats:AddDivider('NPCs');
teleportCheats:AddList({text = 'NPCs', flag = 'NPC Teleport', values = npcs});
teleportCheats:AddButton({text = 'Teleport To', callback = funcs.teleportToNPC});

teleportCheats:AddDivider('Mobs');
teleportCheats:AddList({text = 'Mobs', flag = 'Mob Teleport', values = mobs});
teleportCheats:AddButton({text = 'Teleport To', callback = funcs.teleportToMob});

teleportCheats:AddDivider('Players');
teleportCheats:AddList({text = 'Players', flag = 'Player Teleport', playerOnly = true});
teleportCheats:AddButton({text = 'Teleport To', callback = funcs.teleportToPlayer});

miscCheats:AddToggle({text = 'Thunderstorm Server Finder', callback = funcs.findThunderstormServer});

miscCheats:AddToggle({
    text = 'Boss Server Finder',
    callback = funcs.findBossServer,
    tip = 'Hops until a server has one of the known bosses spawned.'
});

miscCheats:AddButton({text = 'Server Hop', callback = funcs.serverHop});
