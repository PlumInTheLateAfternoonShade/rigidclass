local ffi = require("ffi")
local middle = require 'middleclass'

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
    table = 'tableref',
    string = 'unsupported', --TODO
    unsupported = 'unsupported',
    boolean = 'bool',
    bool = 'bool',
    uint8_t = 'uint8_t'
}

local function setCTypes(types, mt)
    local setTableMethodCreated = false
    local cTypes = {}
    for k, v in pairs(types) do
        local cType = luaToCTypes[v]
        if cType ~= 'unsupported' then
            if cType == nil then
                error('Lua type "'..v..
                '" is not supported by rigidclass.')
            elseif cType == 'tableref' then
                local firstLetter = k:sub(0, 1):upper()
                local camel = 'set'..firstLetter..k:sub(2)
                mt.__index[camel] = function (self, newTable)
                    self[k] = registerTable(newTable)
                end
                if not setTableMethodCreated then
                    mt.__index.setTable = function (self, k, newTable)
                        self[k] = registerTable(newTable)
                    end
                    setTableMethodCreated = true
                end
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

local function define(name, types, mt)
    ffi.cdef(buildDefString(setCTypes(types, mt), name))
end

local function array(self, n)
    return ffi.new(self.getClass().__arrayName, n)
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

local function __tostring(self)
    return "instance of " .. tostring(self.getClass())
end

local function isInstanceOf(self, aClass)
    local class = self.getClass()
    return (type(self) == 'table' or type(self) == 'cdata') and
    type(class) == 'table' and
    type(aClass) == 'table' and
    ( aClass == class or
    type(aClass.isSubclassOf) == 'function' and
    class:isSubclassOf(aClass)
    )
end

local function create(class, types)
    assert(type(class) == 'table')
    assert(type(class.name) == 'string')
    assert(type(types) == 'table')
    class.__types = {}
    if class.super and class.super.__types then
        for name, typ in pairs(class.super.__types) do
            class.__types[name] = typ
        end
    end
    for name, typ in pairs(types) do
        class.__types[name] = typ
    end
    local mt = class.__instanceDict
    define(class.name, class.__types, mt)
    class.__arrayName = class.name..'[?]'
    class.__types = types
    mt.__index.new = new
    mt.__index.allocate = allocate
    mt.__index.getClass = function () return class end
    mt.__index.isInstanceOf = isInstanceOf
    mt.__index.array = array
    mt.__tostring = __tostring
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
    toRigid = toRigid,
    middle = middle,
},
{
    __call = function(_, typeAnnotations, name, ...)
        local class = middle(name, ...)
        return create(class, typeAnnotations)
    end
})
