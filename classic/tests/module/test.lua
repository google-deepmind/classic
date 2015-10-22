local totem = require 'totem'
local classic = require 'classic'
local tester = totem.Tester()
local tests = totem.TestSuite()

local function simpleModule()
  local A = classic.class("simple_module.A")
  local B = classic.class("simple_module.B")
  local submodule = classic.module("simple_module.simple_submodule")
  local module = classic.module("simple_module")
  module:class("A")
  module:class("B")
  module:submodule("simple_submodule")
  module.testVar = 3
  function module.testFunc()
    return 4
  end
  return module, A, B
end


function tests.simple()
  local module, A, B = simpleModule()

  tester:asserteq(module:name(), "simple_module", 'test name()')
  tester:asserteq(package.loaded[module:name()], module, 'test package.loaded')
  tester:asserteq(module.testVar, 3, 'test module variable')
  tester:asserteq(module.testFunc(), 4, 'test module function')

  local classes = {}
  for k, v in module:classes() do
    classes[k] = v
  end
  tester:assertTableEq(classes, {A = A, B = B}, 'test classes()')

  local submodules = {}
  for k, v in module:submodules() do
    submodules[k] = v
  end

  tester:assertTableEq(submodules, {simple_submodule = module.simple_submodule},
                       'test submodules()')

  local functions = {}
  for k, v in module:functions() do
    functions[k] = v
  end
  tester:assertTableEq(functions, {testFunc = module.testFunc},
                       'test functions()')
  tester:assert(type(module.testFunc) == 'function',
                "module.testFunc should be function")

  tester:assert(classic.isModule(module), 'test isModule')
  tester:assert(not classic.isModule(A), 'test isModule')

end


function tests.callbacks()
  local gotName = nil
  local gotClassName = nil
  local gotSubmoduleName = nil
  local gotFunctionName = nil
  local function initCallback(name) gotName = name end
  classic.addCallback(classic.events.MODULE_INIT, initCallback)
  local M = classic.module("my_module")
  tester:asserteq(gotName, "my_module")
  tester:asserteq(gotClassName, nil)
  local function classCallback(module, name) gotClassName = name end
  classic.addCallback(classic.events.MODULE_DECLARE_CLASS, classCallback)
  M:class("MyClass")
  tester:asserteq(gotClassName, "MyClass")
  local function submoduleCallback(module, name) gotSubmoduleName = name end
  classic.addCallback(classic.events.MODULE_DECLARE_SUBMODULE,
                      submoduleCallback)
  tester:asserteq(gotSubmoduleName, nil)
  M:submodule("my_submodule")
  tester:asserteq(gotSubmoduleName, "my_submodule")
  tester:assertErrorPattern(function() return classic.events.BLAH_BLAH end,
                            "classic event", "invalid event should error")
  local function functionCallback(module, name) gotFunctionName = name end
  classic.addCallback(classic.events.MODULE_DECLARE_FUNCTION,
                      functionCallback)
  tester:asserteq(gotFunctionName, nil)
  M:moduleFunction("myFunction")
  tester:asserteq(gotFunctionName, "myFunction")
end

return tester:add(tests):run()
