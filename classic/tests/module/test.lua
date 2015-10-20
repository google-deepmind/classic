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

function tests.naming()
  local function checkInvalidModuleName(name)
    tester:assertErrorPattern(function() classic.module(name) end, "not valid")
  end
  local function checkInvalidSubmoduleName(name)
    tester:assertErrorPattern(
        function()
          local module = classic.module("test_module")
          module:submodule(name)
        end,
        "Module names should be lower_case_with_underscores:")
  end
  local badModuleNames = {
      "123",
      "my_module!",
      "My Module",
      "my_moduleA",
      "MyModule",
      "my module",
      "myModule",
      "",
      "module.Submodule",
      "Module.submodule"
  }

  for _, name in ipairs(badModuleNames) do
    checkInvalidModuleName(name)
    checkInvalidSubmoduleName(name)
  end
  tester:assertErrorPattern(function() classic.module() end,
                            "Module name")


  local function checkInvalidClassName(name)
    tester:assertErrorPattern(
        function()
          local module = classic.module("test_module")
          module:class(name)
        end,
        "Class names should be UpperCaseCamelCase:")
  end

  local badClassNames = {
      "my_class",
      "myClass",
      "My_class",
      "MY_CLASS",
      "MY_CLASS",
      "Classy!",
      "Classy?",
      "My Class",
      "My.Class",
  }
  for _, name in ipairs(badClassNames) do
    checkInvalidClassName(name)
  end
  tester:assertErrorPattern(
      function()
        local m = classic.module("test_module")
        m:class()
      end,
      "Class name")

  local function checkInvalidFunctionName(name)
    tester:assertErrorPattern(
        function()
          local module = classic.module("test_module")
          module:moduleFunction(name)
        end,
        "Function name", "lazy declaration: " .. tostring(name))
  end

  local badFunctionNames = {
      "my_function",
      "MyFunction",
      "myFunction!",
      "my.function"
  }
  for _, name in ipairs(badFunctionNames) do
    checkInvalidFunctionName(name)
  end
  checkInvalidFunctionName(nil)
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

function tests.badNames()
  local module = classic.module("a")
  tester:assertErrorPattern(
      function() module:class() end,
      "Class name", "class name missing should error")
  tester:assertErrorPattern(
      function() module:class(3) end,
      "Class name", "number as class name should error")
  tester:assertErrorPattern(
      function() module:submodule() end,
      "Submodule name", "submodule name missing should error")
  tester:assertErrorPattern(
      function() module:submodule(3) end,
      "Submodule name", "number as submodule name should error")
  tester:assertErrorPattern(
      function() module:moduleFunction() end,
      "Function name", "module function name missing should error")
  tester:assertErrorPattern(
      function() module:moduleFunction(3) end,
      "Function name", "number as function name should error")
end

return tester:add(tests):run()
