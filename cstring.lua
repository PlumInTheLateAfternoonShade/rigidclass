local ffi = require 'ffi'
ffi.cdef[[
typedef struct { uint8_t s[3]; } cstring;
]]
local cstring = ffi.metatype('cstring',
{
    __index = function(t, k)
        return ffi.string(t.s, 3)
    end,
    __newindex = function(t, k, v)
        t['_s'] = v
    end
})
local str = ffi.new('cstring')
str.s = '333'
assert(str._s == '333')
local s = str._s
assert(s == '333')
s = '444'
str.s = s
assert(str._s == '444')
