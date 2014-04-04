local ffi = require("ffi")
ffi.cdef[[
typedef struct { double red, green, blue, alpha; } rgba_pixel;
]]

local floor = math.floor

local function image_ramp_green(n)
    local img = {}
    local f = 255/(n-1)
    for i=0,n-1 do
        img[i] = ffi.new("rgba_pixel")
        img[i].green = i*f
        img[i].alpha = 255
    end
    return img
end

local function image_to_grey(img, n)
    for i=0,n-1 do
        local y = 0.3*img[i].red + 0.59*img[i].green + 0.11*img[i].blue
        img[i].red = y; img[i].green = y; img[i].blue = y
    end
end

local N = 400*400
local img = image_ramp_green(N)
local startTime = os.clock()
for i=1,1000 do
    image_to_grey(img, N)
end
local endTime = os.clock()
print("c", endTime - startTime)
