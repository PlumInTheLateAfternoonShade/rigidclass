local class = require 'middleclass'

time = require 'performance/time'

local A = class('A')

function A:initialize()
    self.num = 3
end

time('instance creation', function()
    local a = A:new()
end)

function A:foo()
    return 1
end

local a = A:new()

time('instance method invocation', function()
    a:foo()
end)

local B = class('B', A)

local b = B:new()

time('inherited method invocation', function()
    b:foo()
end)

function A.static:bar()
    return 2
end

time('class method invocation', function()
    A:bar()
end)

time('inherited class method invocation', function()
    B:bar()
end)
