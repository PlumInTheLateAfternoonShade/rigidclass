local Pixel = require 'rigidclass' ({ red = 'uint8_t', green = 'uint8_t',
  blue = 'uint8_t', alpha = 'uint8_t', }, 'Pixel')

function Pixel:image_to_grey()
    local y = 0.3*self.red + 0.59*self.green + 0.11*self.blue
    self.red = y; self.green = y; self.blue = y
end

local function image_ramp_green(n)
    local img = Pixel:array(n)
    local f = 255/(n-1)
    for i = 0, n - 1 do
        img[i].green = i*f
        img[i].alpha = 255
    end
    return img
end

local N = 400*400
local img = image_ramp_green(N)
local startTime = os.clock()
for i = 1, 1000 do
    for j = 0, N - 1 do
        img[j]:image_to_grey()
    end
end
local endTime = os.clock()
print("rigidclass", endTime - startTime)
