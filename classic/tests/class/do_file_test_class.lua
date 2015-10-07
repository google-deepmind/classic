require 'classic'

local DoFileTestClass = classic.class('DoFileTestClass')

function DoFileTestClass:_init(value)
  if value ~= 1 then
    error("Expected value = 1.")
  end
end

return DoFileTestClass

