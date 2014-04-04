local rigidclass = require 'rigidclass'
local class = require 'middleclass.middleclass'

local Fruit = class('Fruit') -- 'Fruit' is the class' name

function Fruit:initialize(sweetness, color, edible, subtable)
    self.sweetness = sweetness or 0
    --self.color = color or ''
    self.edible = edible or false
    self.subtable = rigidclass.registerTable(
        subtable or { name = 'carol' })
end

Fruit.static.sweetness_threshold = 5 -- class variable (also admits methods)

function Fruit:isSweet()
    return self.sweetness > Fruit.sweetness_threshold
end

local Lemon = class('Lemon', Fruit) -- subclassing

function Lemon:initialize(sweetness, color, edible, subtable)
    -- invoking the superclass' initializer
    Fruit.initialize(self, sweetness, color, edible, subtable)
end

Lemon = rigidclass.toRigid(Lemon)

local lemon = Lemon:new(0, 'yellow', true, { name = 'bob' })

assert(not lemon:isSweet()) -- false
assert(lemon.edible) -- true
assert(lemon.subtable.name == 'bob')
lemon.subtable.name = 'frederick'
lemon.subtable.num = 5
assert(lemon.subtable.name == 'frederick')
assert(lemon.subtable.num == 5)
