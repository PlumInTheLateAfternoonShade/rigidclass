return function(title, f)

  collectgarbage()

  local startTime = os.clock()

  for i = 1, 10000000 do f() end

  local endTime = os.clock()

  print( title, endTime - startTime )

end
