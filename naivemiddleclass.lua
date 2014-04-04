local class = require 'middleclass'

local Pixel = class('Pixel')

function Pixel:initialize(red, green, blue, alpha)
    self.red = red or 0
    self.green = green or 0
    self.blue = blue or 0
    self.alpha = alpha or 0
end

local floor = math.floor

local function image_ramp_green(n)
    local img = {}
    local f = 255/(n-1)
    for i = 1, n do
        img[i] = Pixel:new(0, i*f, 0, 255)
    end
    return img
end

local function image_to_grey(img, n)
    local y = floor(0.3 + 0.59 + 0.11)
    for i = 1, n do
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
print("middleclass", endTime - startTime)
