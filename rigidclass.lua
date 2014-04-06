local ffi = require("ffi")
local middle = require 'rmiddleclass'

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
    __len = function(t)
        return #idToTable[t.id]
    end
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
    
    --nil, boolean, number, string, function, userdata, thread, and table
}


local function setTable(self, key, newTable)
    self[key] = registerTable(newTable)
end

local function getTable(self, key)
    return idToTable[self[key].id]
end

local function assignTypes(class, types)
    class.__types = {}
    if class.super and class.super.__types then
        for name, typ in pairs(class.super.__types) do
            class.__types[name] = typ
        end
    end
    for typ, names in pairs(types) do
        if type(names) == 'string' then
            class.__types[names] = typ
        elseif type(names) == 'table' then
            for i = 1, #names do
                class.__types[names[i]] = typ
            end
        else
            error([[rigidclass type annotations table can only accept
            strings and tables as values.]])
        end
    end
end

local function sortByDecreasingAlignment(a, b)
    return a[3] > b[3]
end

local function setCTypes(types, mt)
    local tableMethodsCreated = false
    local cTypes = {}
    for k, v in pairs(types) do
        local cType = luaToCTypes[v]
        if cType ~= 'unsupported' then
            if cType == nil then
                error('Lua type "'..v..
                '" is not supported by rigidclass.')
            elseif cType == 'tableref' then
                local firstLetter = k:sub(0, 1):upper()
                local camel = firstLetter..k:sub(2)
                mt.__index['set'..camel] = function (self, newTable)
                    self[k] = registerTable(newTable)
                end
                mt.__index['get'..camel] = function (self)
                    return idToTable[self[k].id]
                end
                if not tableMethodsCreated then
                    mt.__index.setTable = setTable
                    mt.__index.getTable = getTable
                    tableMethodsCreated = true
                end
            end
            
            table.insert(cTypes,
            {
                cType, k,
                -- Determines the required alignment for the type
                -- in order to pack the parent struct to minimize
                -- wasted space in the struct. It's unnecessary to
                -- call this for every type, but fairly fast so we
                -- don't care.
                ffi.alignof(ffi.new(cType))
            })
        end
    end
    table.sort(cTypes, sortByDecreasingAlignment)
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
    for i = 1, #cTypes do
        s = s..cTypes[i][1]..' '..cTypes[i][2]..'; '
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

local function copyMeta(mt, super)
    -- We need a second metatable in order to define custom accessors
    -- for attributes of the class.
    if not super then
        return
    end
    local superMt = super.__instanceDict
    for k, v in pairs(superMt) do
        if not rawget(mt, k) then
            mt[k] = v
        end
    end
    return copyMeta(mt, super.super)
end

local function create(class, types)
    assert(type(class) == 'table')
    assert(type(class.name) == 'string')
    assert(type(types) == 'table')
    assignTypes(class, types)
    local mt = class.__instanceDict
    copyMeta(mt, class.super)
    setmetatable(mt,
    { 
        __index = function (t, k)
            if k == 'class' then
                return class
            end
        end,
    })
    mt.__tostring = __tostring
    define(class.name, class.__types, mt)
    class.__arrayName = class.name..'[?]'
    mt.new = new
    mt.allocate = allocate
    mt.getClass = function () return class end
    mt.isInstanceOf = isInstanceOf
    mt.array = array
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
    toRigid = toRigid,
    middle = middle,
},
{
    __call = function(_, typeAnnotations, name, ...)
        local class = middle(name, ...)
        return create(class, typeAnnotations)
    end
})
