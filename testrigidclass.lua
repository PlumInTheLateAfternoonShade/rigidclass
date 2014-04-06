local rigidclass = require 'rigidclass'

local Fruit = rigidclass(
{
    number = 'sweetness',
    boolean = 'edible',
    table = 'subtable',
}, 'Fruit') -- 'Fruit' is the class' name

function Fruit:initialize(sweetness, color, edible, subtable)
    -- @double
    self.sweetness = sweetness or 0 -- @double
    --self.color = color or '' -- @string
    self.edible = edible or false --    @boolean
    self:setSubtable(subtable or { name = 'carol' })
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

function Lemon:lemonFunc()

end

local lemon = Lemon:new(0, 'yellow', true, { name = 'bob' })

assert(not lemon:isSweet()) -- false
assert(lemon.edible) -- true
assert(lemon.subtable.name == 'bob')
lemon.subtable.name = 'frederick'
lemon.subtable.num = 5
assert(lemon.subtable.name == 'frederick')
assert(lemon.subtable.num == 5)
for k, v in pairs(lemon.subtable) do
    assert((k == 'name' and v == 'frederick') or 
           (k == 'num' and v == 5))
end
assert(#lemon.subtable == 0)
table.insert(lemon:getSubtable(), 2)
assert(#lemon.subtable == 1)
assert(lemon['subtable'].num == 5)
print('class members')
for k, v in pairs(lemon.getClass()) do
    print(k, v)
end
print('instancedict members')
for k, v in pairs(lemon.getClass().__instanceDict) do
    print(k, v)
end
assert(lemon.getClass().static.sweetness_threshold == 5)
print(tostring(lemon))
assert(lemon:isInstanceOf(Lemon))
assert(lemon.getClass():isSubclassOf(Fruit))
print(lemon.class)
