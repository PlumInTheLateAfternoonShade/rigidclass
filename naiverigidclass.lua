local rigidclass = require 'rigidclass'
local floor = math.floor

local Pixel = rigidclass(
{ number = { 'red', 'green', 'blue', 'alpha'} }, 'Pixel')

function Pixel:initialize(red, green, blue, alpha)
    self.red = red or 0
    self.green = green or 0
    self.blue = blue or 0
    self.alpha = alpha or 0
end

function Pixel:image_to_grey()
    local y = floor(0.3*self.red + 0.59*self.green + 0.11*self.blue)
    self.red = y; self.green = y; self.blue = y
end

local function image_ramp_green(n)
    local img = {}
    local f = 255/(n-1)
    for i = 1, n do
        img[i] = Pixel:new(0, i*f, 0, 255)
    end
    return img
end

local N = 400*400
local img = image_ramp_green(N)
local startTime = os.clock()
for i=1,1000 do
    for j = 1, N do
        img[j]:image_to_grey()
    end
end
local endTime = os.clock()
print("rigidclass", endTime - startTime)
