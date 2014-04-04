local ffi = require("ffi")

local function makeWeakTable(mode)
    return setmetatable({}, { __mode = mode })
end

-- used for storing references to Lua tables in C structs.
-- credit to Demetri 
-- http://www.freelists.org/post/luajit/Possible-to-store-a-reference-to-a-lua-table-in-an-ffi-struct,2
local currentId = 0
local tableToId = makeWeakTable('k')
local idToTable = makeWeakTable('v')

local function registerTable(tbl)
    currentId = currentId + 1
    tableToId[tbl] = currentId
    idToTable[currentId] = tbl
    return currentId
end

ffi.cdef[[typedef struct { int id; } tableref]]
local tableref = ffi.metatype('tableref',
{
    __index = function (t, k)
        return idToTable[t.id][k]
    end,
    __newindex = function (t, k, v)
        idToTable[t.id][k] = v
    end,
})

local t = tableref(1)
local blah = t.n



local luaToCTypes =
{
    number = 'double',
    table = 'unsupported', --TODO
    string = 'unsupported', --TODO
    boolean = 'bool'

}

local function determineCTypes(object)
    local cTypes = {}
    for k, v in pairs(object) do
        local cType = luaToCTypes[type(v)]
        if cType ~= 'unsupported' then
            if cType == nil then
                error('Lua type "'..type(v)..
                '" is not supported by rigidclass.')
            end
            cTypes[k] = cType
        end
    end
    return cTypes
end

local function buildDefString(cTypes, name)
    local s = 'typedef struct { '
    for k, v in pairs(cTypes) do
        s = s..v..' '..k..'; '
    end
    s = s..'} '..name..';'
    return s
end

local function define(name, dummyObject)
    ffi.cdef(buildDefString(determineCTypes(dummyObject), name))
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

return function(class)
    assert(type(class) == 'table')
    assert(type(class.name) == 'string')
    local dummyObject = class:new()
    define(class.name, dummyObject)
    local mt = getmetatable(dummyObject)
    mt.__index.new = new
    mt.__index.allocate = allocate
    ffi.metatype(class.name, mt)
    return class
end
