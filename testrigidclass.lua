local rigidclass = require 'rigidclass'
local class = require 'middleclass'

local Fruit = rigidclass(
{
    sweetness = 'number',
    edible = 'boolean',
    subtable = 'table',
}, 'Fruit') -- 'Fruit' is the class' name

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

local Lemon = rigidclass({}, 'Lemon', Fruit) -- subclassing

function Lemon:initialize(sweetness, color, edible, subtable)
    -- invoking the superclass' initializer
    Fruit.initialize(self, sweetness, color, edible, subtable)
end

local lemon = Lemon:new(0, 'yellow', true, { name = 'bob' })

assert(not lemon:isSweet()) -- false
assert(lemon.edible) -- true
assert(lemon.subtable.name == 'bob')
lemon.subtable.name = 'frederick'
lemon.subtable.num = 5
assert(lemon.subtable.name == 'frederick')
assert(lemon.subtable.num == 5)
for k, v in pairs(lemon.getClass()) do
    print(k, v)
end
print(lemon.getClass().static.sweetness_threshold)
print(tostring(lemon))
print(lemon:isInstanceOf(Lemon))
print(lemon.getClass():isSubclassOf(Fruit))
