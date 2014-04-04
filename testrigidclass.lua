local rigidclass = require 'rigidclass'
local class = require 'middleclass.middleclass'

local Fruit = class('Fruit') -- 'Fruit' is the class' name

function Fruit:initialize(sweetness, color, edible)
    self.sweetness = sweetness or 0
    --self.color = color or ''
    self.edible = edible or false
end

Fruit.static.sweetness_threshold = 5 -- class variable (also admits methods)

function Fruit:isSweet()
    return self.sweetness > Fruit.sweetness_threshold
end

local Lemon = class('Lemon', Fruit) -- subclassing

function Lemon:initialize(sweetness, color, edible)
    -- invoking the superclass' initializer
    Fruit.initialize(self, sweetness, color, edible)
end

Lemon = rigidclass(Lemon)

local lemon = Lemon:new(0, 'yellow', true)

print(lemon:isSweet()) -- false
print(lemon.edible) -- true
