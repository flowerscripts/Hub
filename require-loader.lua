getgenv().syn = {}
getgenv().comm_channels = {}
syn.create_comm_channel = function() -- credit to MirayXS or whoever made SynapseToScriptWare.lua
    local id = game:GetService("HttpService"):GenerateGUID(false)
    local bindable = Instance.new("BindableEvent")
    local object = newproxy(true)
    getmetatable(object).__index = function(_, i)
        if i == "bro" then
            return bindable
        end
    end
    local event = setmetatable({
        __OBJECT = object
    }, {
        __type = "SynSignal",
        __index = function(self, i)
            if i == "Connect" then
                return function(_, callback)
                    return self.__OBJECT.bro.Event:Connect(callback)
                end
            elseif i == "Fire" then
                return function(_, ...)
                    return self.__OBJECT.bro:Fire(...)
                end
            end
        end,
        __newindex = function()
            erroruiconsole("SynSignal table is readonly.")
        end
    })
    comm_channels[id] = event
    return id, event
end

syn.get_comm_channel = function(id)
    local channel = comm_channels[id]
    if not channel then
        erroruiconsole("bad argument #1 to 'get_comm_channel' (invalid communication channel)")
    end
    return channel
end


getgenv().isSynapseV3 = not not gethui;

getgenv().disableenvprotection = function() end;
getgenv().enableenvprotection = function() end;

getgenv().SX_VM_CNONE = function() end;

local __scripts = {};
getgenv().__scripts = __scripts;

local HttpService = game:GetService('HttpService');
local originalRequire = require;
local cachedRequires = {};
_G.cachedRequires = cachedRequires;

-- main require function
local function customRequire(url)
    if (typeof(url) ~= 'string' or not checkcaller()) then
        return originalRequire(url);
    end;

    local requestData = request({
        Url = string.format('http://rukiascripts.xyz/%s', url),
        Method = 'GET'
    });

    if (not requestData.Success) then
        error(string.format('[Loader] Couldn\'t fetch %s (%s %s)', url, tostring(requestData.StatusCode), tostring(requestData.StatusMessage)), 0);
    end;

    local scriptContent = requestData.Body;
    local extension = url:match('.+%w+%p(%w+)');

    if (extension ~= 'lua') then
        return scriptContent;
    end;

    local scriptFunction, syntaxError = loadstring(scriptContent, url);
    if (not scriptFunction) then
        error(string.format('[Loader] Syntax error in %s: %s', url, tostring(syntaxError)), 0);
    end;

    return scriptFunction();
end;

local function customRequireShared(fileName)
    local fullPath = string.format('files/%s', fileName);

    if (not cachedRequires[fileName]) then
        cachedRequires[fileName] = customRequire(fullPath);
    end;

    return cachedRequires[fileName];
end;

local gameList = HttpService:JSONDecode(customRequire('gameList.json'));

getgenv().customRequire = customRequire;
getgenv().sharedRequire = customRequireShared;

getgenv().rukiaHubV1Ran = false;
getgenv().scriptKey,getgenv().websiteKey='29be76a3-ad9f-4c27-aa3a-e78590f61971','8b21dab5-1432-4620-bf61-735fcfd240df';

local function GAMES_SETUP()
    local gameName = gameList[tostring(game.GameId)];
    if (not gameName) then return warn('no custom game for this game'); end;
    sharedRequire(string.format('games/%s.lua', gameName:gsub('%s', '')));
end;

getgenv().GAMES_SETUP = GAMES_SETUP;

customRequire('script-loader.lua');
