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
local tableToId = makeWeakTable('k')

ffi.cdef[[typedef int tableref]]

local luaToCTypes =
{
    number = 'double',
    table = 'tableref',
    string = 'uint8_t*', --TODO
    unsupported = 'unsupported',
    boolean = 'bool',
    bool = 'bool',
    uint8_t = 'uint8_t'
    
    --nil, boolean, number, string, function, userdata, thread, and table
}

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

local function getUniqueIdentifier(originalIdentifier)
    return originalIdentifier..tostring(math.random()):sub(3)
end

local indexer, newIndexer

local function setCTypes(types, mt, class)
    local tableMethodsCreated = false
    indexer = {}
    newIndexer = {}
    local cTypes = {}
    for k, v in pairs(types) do
        local cType = luaToCTypes[v]
        if cType ~= 'unsupported' then
            local adjK = k
            if cType == nil then
                error('Lua type "'..v..
                '" is not supported by rigidclass.')
            elseif cType == 'tableref' then
                adjK = getUniqueIdentifier(k)
                indexer[k] = function(tbl, key)
                    return idToTable[tbl[adjK]]
                end
                newIndexer[k] = function(tbl, key, val)
                    if tableToId[val] then
                        tbl[adjK] = tableToId[val]
                    else
                        currentId = currentId + 1
                        idToTable[currentId] = val
                        tableToId[val] = currentId
                        tbl[adjK] = currentId
                    end
                end
            elseif cType == 'uint8_t*' then
                adjK = getUniqueIdentifier(k)
                indexer[k] = function(tbl, key)
                    return ffi.string(tbl[adjK])
                end
                newIndexer[k] = function(tbl, key, val)
                    local cstring = ffi.new('uint8_t[?]', #val + 1)
                    ffi.copy(cstring, val)
                    tbl[adjK] = cstring
                end
            end
            
            table.insert(cTypes,
            {
                cType, adjK,
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
    --print(s)
    return s
end

local function define(name, types, mt, class)
    ffi.cdef(buildDefString(setCTypes(types, mt, class), name))
end

local function array(self, n)
    return ffi.new(self.getClass().__arrayName, n)
end

local function allocate(self)
    assert(type(self) == 'table', "Make sure that you are using 'Class:allocate' instead of 'Class.allocate'")
    return ffi.new(self.name)
    --[[if self.__cachedType then
        return self.__cachedType()
    else
        self.__cachedType = ffi.typeof(ffi.new(self.name))
        return self.__cachedType()
    end]]--
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
    -- We need a function __index to handle getting and setting of
    -- certain Lua types, but for inheritance we need the table __index.
    -- Instead of editing the metatable of the
    -- superclass, we copy methods into this class' metatable instead.
    -- This bloats the size of class metatables, but since there's only
    -- one per class, not one per instance, it's not a huge deal.
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
    mt.__tostring = __tostring
    define(class.name, class.__types, mt, class)
    class.__arrayName = class.name..'[?]'
    mt.new = new
    mt.allocate = allocate
    mt.getClass = function () return class end
    mt.isInstanceOf = isInstanceOf
    mt.array = array
    mt.__newindex = function (t, k, v)
            if newIndexer[k] then
                return newIndexer[k](t, k, v)
            else
                rawset(t, k, v)
            end
        end
    setmetatable(mt,
    {
        __index = function (t, k)
            if indexer[k] then
                return indexer[k](t, k)
            elseif k == 'class' then
                return class
            else
                rawget(t, k)
            end
        end,
    })
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
