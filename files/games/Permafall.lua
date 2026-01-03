print('Creating ESP for:', trinketData.Name)

local code = [[
    local handle = ...;
    return setmetatable({}, {
        __index = function(_, p)
            if (p == 'Position') then
                return handle.Position;
            end;
        end,
    });
]];

print('Handle type check:', typeof(descendant), descendant:IsA('BasePart'))
print('Handle position:', descendant.Position)

local espObj = espConstructor.new({ code = code, vars = { descendant } }, trinketData.Name);
print('ESP object created:', espObj)
print('ESP object _id:', espObj._id)
print('ESP object _tag:', espObj._tag)
print('ESP object _showFlag:', espObj._showFlag)
print('ESP object _colorFlag:', espObj._colorFlag)
