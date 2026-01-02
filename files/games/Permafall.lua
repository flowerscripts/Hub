local library = sharedRequire('UILibrary.lua');

local column1, column2 = unpack(library.columns);

local functions = {};

local Players, RunService, UserInputService, HttpService, CollectionService, MemStorageService, Lighting = Services:Get('Players', 'RunService', 'UserInputService', 'HttpService', 'CollectionService', 'MemStorageService', 'Lighting');

local LocalPlayer = Players.LocalPlayer;
local playerMouse = LocalPlayer:GetMouse();

local maid = Maid.new();

local localCheats = column1:AddSection('Local Cheats');
local notifier = column1:AddSection('Notifier');
local playerMods = column1:AddSection('Player Mods');
local misc = column2:AddSection('Misc');
local visuals = column2:AddSection('Visuals');
local farms = column2:AddSection('Farms');
local inventoryViewer = column2:AddSection('Inventory Viewer');
