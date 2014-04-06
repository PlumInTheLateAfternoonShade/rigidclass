local types = setmetatable({},
{ 
    __index = function(t, k)
        return function (...)
            return { k, {...}}
        end
    end
})

print(types.double('sweetness', 'size'))
