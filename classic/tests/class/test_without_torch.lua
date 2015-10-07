local totem = require 'totem'
local tester = totem.Tester()
local classic = require 'classic'
local common = require 'classic.tests.class.common'

local tests = common.generateTests(tester)

return tester:add(tests):run()
