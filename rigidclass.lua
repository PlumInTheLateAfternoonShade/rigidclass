local ffi = require("ffi")

local function makeWeakTable(mode)
    return setmetatable({}, { __mode = mode })
end

-- used for storing references to Lua tables in C structs.
-- credit to Demetri 
-- http://www.freelists.org/post/luajit/Possible-to-store-a-reference-to-a-lua-table-in-an-ffi-struct,2
local currentId = 0
local idToTable = makeWeakTable('v')

ffi.cdef[[typedef struct { int id; } tableref]]
local tableref = ffi.metatype('tableref',
{
    __index = function (t, k)
        return idToTable[t.id][k]
    end,
    __newindex = function (t, k, v)
        idToTable[t.id][k] = v
    end,
    __pairs = function (t)
        return pairs(idToTable[t.id])
    end,
    __ipairs = function (t)
        return ipairs(idToTable[t.id])
    end,
})

local function registerTable(tbl)
    currentId = currentId + 1
    idToTable[currentId] = tbl
    return tableref(currentId)
end

local luaToCTypes =
{
    number = 'double',
    table = 'tableref', --TODO
    cdata = 'tableref', --TODO
    string = 'unsupported', --TODO
    unsupported = 'unsupported',
    boolean = 'bool',
}

local function setCTypes(types)
    local cTypes = {}
    for k, v in pairs(types) do
        local cType = luaToCTypes[v]
        if cType ~= 'unsupported' then
            if cType == nil then
                error('Lua type "'..v..
                '" is not supported by rigidclass.')
            end
            cTypes[k] = cType
        end
    end
    return cTypes
end

local function getTypes(object)
    local types = {}
    for k, v in pairs(object) do
        if k == 'class' then
            types[k] = 'unsupported'
        else
            types[k] = type(v)
        end
    end
    return types
end

local function buildDefString(cTypes, name)
    local s = 'typedef struct { '
    for k, v in pairs(cTypes) do
        s = s..v..' '..k..'; '
    end
    s = s..'} '..name..';'
    print(s)
    return s
end

local function define(name, types)
    ffi.cdef(buildDefString(setCTypes(types), name))
end

local function allocate(self)
    assert(type(self) == 'table', "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
    return ffi.new(self.name)
end

local function new(self, ...)
    local instance = self:allocate()
    instance:initialize(...)
    return instance
end

local function create(class, types)
    assert(type(class) == 'table')
    assert(type(class.name) == 'string')
    assert(type(types) == 'table')
    define(class.name, types)
    local mt = class.__instanceDict
    mt.__index.new = new
    mt.__index.allocate = allocate
    ffi.metatype(class.name, mt)
    return class
end

local function toRigid(class)
    assert(type(class) == 'table')
    local dummyObject = class:new()
    return create(class, getTypes(dummyObject))
end

return setmetatable(
{
    registerTable = registerTable,
    toRigid = toRigid
},
{
    __call = function(_, class, typeAnnotations)
        return create(class, typeAnnotations)
    end
})
