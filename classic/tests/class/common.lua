-- LUALINT global:classic
local classic = assert(classic,
                       "test_common assumes classic has already been required")

local definitions = require 'classic.tests.class.definitions'
local utils = require 'classic.tests.class.utils'

-- Since Totem may require 'sys' when the tests are run, and this declares a
-- global, we'll get it out of the way now, so that it doesn't cause a false
-- positive when we want to check that we're not polluting the global
-- namespace. Similarly, Torch may require 'lfs'.
require 'sys'
require 'lfs'
local pollutedGlobals = {}
setmetatable(_G, {
  __newindex = function(t, k)
    pollutedGlobals[#pollutedGlobals + 1] = k
  end
})

local test_common = {}

function test_common.generateTests(tester)

  local tests = {}

  function tests.testDefaultConstructor()
    local A = definitions.withDefaultConstructor()
    local a
    tester:assertNoError(function() a = A() end,
                         "default constructor should work")
    tester:assertne(a, nil, "object should not be nil")
    tester:asserteq(a:getValue(), 1, "method should work")
    classic.deregisterAllClasses()
  end

  function tests.basicFunctionality()
    local A = definitions.basicClass()
    local B = definitions.differentClass()
    local x_1 = "hello"
    local x_2 = "goodbye"
    local x_3 = "foo"
    local obj_1 = A(x_1)
    local obj_2 = A(x_2)
    local obj_3 = B(x_3)
    tester:asserteq(obj_1.x, x_1, "obj1 attribute should work")
    tester:asserteq(obj_1:getX(), x_1, "obj1 method should work")
    tester:assert(obj_1:classIs(A), "obj1 classIs should work")
    tester:assert(A:isClassOf(obj_1), "obj1 isClassOf should work")
    tester:asserteq(obj_1:class(), A, "obj1 class() should work")
    tester:asserteq(obj_1:class():name(), "A", "obj1 bad class name")

    tester:asserteq(obj_2.x, x_2, "obj2 attribute should work")
    tester:asserteq(obj_2:getX(), x_2, "obj2 method should work")
    tester:assert(obj_2:classIs(A), "obj2 classIs should work")
    tester:assert(A:isClassOf(obj_2), "obj2 isClassOf should work")
    tester:assert(obj_2:classIs(A), "obj2 class() should work")
    tester:asserteq(obj_2:class():name(), "A", "obj2 bad class name")

    tester:assert(classic.isClass(A), "isClass should work")
    tester:assert(classic.isClass(B), "isClass should work")
    tester:assert(not classic.isClass(nil), "isClass should work")
    tester:assert(not classic.isClass(234), "isClass should work")
    tester:assert(not classic.isClass("string"), "isClass should work")
    tester:assert(not classic.isClass(obj_1), "isClass should work")
    tester:assert(not classic.isClass(obj_3), "isClass should work")

    tester:assert(classic.isObject(obj_1), "isObject should work")
    tester:assert(classic.isObject(obj_2), "isObject should work")
    tester:assert(classic.isObject(obj_3), "isObject should work")
    tester:assert(not classic.isObject(A), "isObject should work")
    tester:assert(not classic.isObject(B), "isObject should work")
    tester:assertError(function() classic.isObject(nil) end,
                       "isObject should work")
    tester:assert(not classic.isObject(17), "isObject should work")
    tester:assert(not classic.isObject("string"), "isObject should work")
    tester:assert(not classic.isObject({}), "isObject should work")

    local as = {}
    for k = 1, 10 do
      table.insert(as, A(k))
    end
    for k = 1, 10 do
      tester:asserteq(as[k]:getX(), k, "bad attribute with multiple instances")
    end

    classic.deregisterAllClasses()
  end

  function tests.checkBadCalls()
    tester:assertErrorPattern(function() classic:class("A") end, "colon",
                              "classic:class() should error")
    tester:assertErrorPattern(function() classic.class() end, "name",
                              "class with no name should error")
    local A = definitions.basicClass()
    local a = A("x")
    tester:assertErrorPattern(function() A.methods() end, "colon",
                              "methods() call with missing self should error")
    tester:assertErrorPattern(function() classic:strict() end, "colon",
                              "classic:strict() should error")
    tester:assertErrorPattern(function() classic:strict({}) end, "colon",
                              "classic:strict() should error")
    tester:assertErrorPattern(function() classic.strict() end, "missing",
                              "classic.strict(nil) should error")
    classic.deregisterAllClasses()
  end

  function tests.inheritance()
    local Base, ChildA, ChildB = definitions.simpleHierarchy()
    local base = Base()
    local a = ChildA("y")
    local b = ChildB("z")
    tester:asserteq(base:getX(), "base", "base method should work")
    tester:asserteq(a:getX(), "base", "base method should work")
    tester:asserteq(b:getX(), "base", "base method should work")
    tester:assert(a.getY, "subclass method should exist")
    tester:asserteq(a:getY(), "y", "subclass method should work")
    tester:assert(b.getZ, "subclass method should exist")
    tester:asserteq(b:getZ(), "z", "subclass method should work")
    tester:asserteq(a:class(), ChildA, "instance should be right subclass")
    tester:asserteq(b:class(), ChildB, "instance should be right subclass")
    tester:assert(ChildA.parent, "parent() method should exist")
    tester:asserteq(ChildA:parent(), Base, "parent should be correct")
    tester:asserteq(ChildB:parent(), Base, "parent should be correct")
    tester:assert(Base:isSubclassOf(Base), "isSubclassOf should work")
    tester:assert(ChildA:isSubclassOf(Base), "isSubclassOf should work")
    tester:assert(ChildB:isSubclassOf(Base), "isSubclassOf should work")
    tester:assert(not ChildB:isSubclassOf(ChildA), "isSubclassOf should work")
    tester:assert(not ChildA:isSubclassOf(ChildB), "isSubclassOf should work")
    tester:assert(ChildA:isSubclassOf(ChildA), "isSubclassOf should work")
    tester:assert(ChildB:isSubclassOf(ChildB), "isSubclassOf should work")

    classic.deregisterAllClasses()
  end

  function tests.inheritanceWithString()
    local Base, ChildA = definitions.hierarchyWithStringParent()
    local base = Base()
    local a = ChildA("y")
    tester:asserteq(base:getX(), "base", "base method should work")
    tester:asserteq(a:getX(), "base", "base method should work")
    tester:assert(a.getY, "subclass method should exist")
    tester:asserteq(a:getY(), "y", "subclass method should work")
    tester:asserteq(a:class(), ChildA, "instance should be right subclass")
    tester:assert(ChildA.parent, "parent() method should exist")
    tester:asserteq(ChildA:parent(), Base, "parent should be correct")
    tester:assert(Base:isSubclassOf(Base), "isSubclassOf should work")
    tester:assert(ChildA:isSubclassOf(Base), "isSubclassOf should work")

    tester:assert(classic.isClass(Base), "isClass should work")
    tester:assert(classic.isClass(ChildA), "isClass should work")
    tester:assert(not classic.isClass(a), "isClass should work")
    tester:assert(not classic.isClass({}), "isClass should work")

    classic.deregisterAllClasses()
  end

  function tests.repeatedDefinitions()
    local A = definitions.basicClass()
    A.attribute = 3
    local instance = A(1)
    tester:asserteq(instance.x, 1)

    local A1
    tester:assertNoError(function() A1 = definitions.basicClass() end,
    "declaring same class twice should not fail")
    tester:asserteq(A1:name(), "A", "name() should work on redeclared class")
    tester:asserteq(A1.attribute, 3, "class attributes should transfer")
    A1.otherAttribute = 4
    tester:asserteq(A.otherAttribute, 4, "class attributes should transfer")
    instance = A1(2)
    tester:asserteq(instance.x, 2)

    tester:assertErrorPattern(
        function() definitions.similarClass() end,
        ".*defining.*",
        "declaring different class with same name should fail")
    classic.deregisterAllClasses()
  end

  function tests.reflection()
    local A = definitions.basicClass()
    local a = A("x")
    local methods = A:methods()
    tester:assertne(methods['getX'], nil, "methods() did not work")
    classic.deregisterAllClasses()
  end

  function tests.strict()
    local A = definitions.basicClass()
    local x = "x"
    local a = A(x)
    local b = A(x)
    classic.strict(a)
    tester:asserteq(a.x, x, "valid attribute should work")
    tester:asserteq(a:getX(), x, "valid method should work")
    tester:assert(a:classIs(A), "classIs should work")
    tester:assert(A:isClassOf(a), "isClassOf should work")
    tester:asserteq(a:class(), A, "class() should work")
    tester:assertErrorPattern(
        function() return a.nonesuch end,
        "Strictness violation",
        "invalid attribute read")
    tester:assertErrorPattern(
        function() a.nonesuch = 3 end,
        "Strictness violation",
        "invalid attribute write")
    tester:assertErrorPattern(
        function() a:nonesuch() end,
        "Strictness violation",
        "invalid method access")
    tester:asserteq(b.x, x, "valid attribute should work")
    tester:assertNoError(
        function() return b.nonesuch end,
        "undeclared attribute should work")
    tester:assertNoError(
        function() b.nonesuch = 4 end,
        "undeclared attribute should work")
    tester:asserteq(b.nonesuch, 4,
        "undeclared attribute should work")

    classic.deregisterAllClasses()
  end

  function tests.abstractClass()
    local AbstractBase, GoodSubclass, BadSubclass
        = definitions.hierarchyWithAbstractBase()

    tester:assertError(function() AbstractBase() end,
    "instantiate abstract should throw error")

    tester:assertNoError(function() GoodSubclass() end,
    "instantiate good subclass should not throw error")

    tester:assertError(function() BadSubclass() end,
    "instantiate bad subclass should throw error")

    classic.deregisterAllClasses()
  end

  function tests.doNotPolluteGlobals()
    local A = definitions.basicClass()
    local a = A("x")
    tester:assert(#pollutedGlobals == 0,
    table.concat {
      "polluted the global table! (with ",
      table.concat(pollutedGlobals, ","),
      ")"
    })
    classic.deregisterAllClasses()
  end

  function tests.mixins()
    local A, M = definitions.classWithMixin()
    local a = A("y")
    tester:asserteq(a:getY(), "y", "mixin method should work")
    classic.deregisterAllClasses()
  end

  function tests.twoLevelHierarchy()
      local Base, Child, Grandchild = definitions.twoLevelHierarchy()
      local x = "x"
      local y = "y"
      local z = "z"
      local a = Base(x)
      local b = Child(x, y)
      local c = Grandchild(x, y, z)
      tester:asserteq(a:getX(), x, "x is wrong in base")
      tester:asserteq(b:getX(), x, "x is wrong in child")
      tester:asserteq(c:getX(), x, "x is wrong in grandchild")
      tester:asserteq(b:getY(), y, "y is wrong in child")
      tester:asserteq(c:getY(), y, "y is wrong in grandchild")
      tester:asserteq(c:getZ(), z, "z is wrong in grandchild")
      classic.deregisterAllClasses()
  end

  function tests.dispatchToSubclass()
      local A, SubA, B = definitions.dispatchToSubclass()

      local b1 = B()
      local a1 = A(b1)
      tester:asserteq(b1:callme(), "Parent; A")

      local b2 = B()
      local a2 = SubA(b2)
      tester:asserteq(b2:callme(), "Child; SubA")

      local b3 = B()
      local a3 = SubA(b3)
      a3:register(a3.B)
      tester:asserteq(b3:callme(), "Child; SubA")
      classic.deregisterAllClasses()
  end

  function tests.call()
    local VALUE = 1
    local A = classic.class("A")
    function A:__call(x)
      return VALUE + x
    end
    local a = A()
    tester:asserteq(a(2), VALUE + 2, "__call does not work")
    classic.deregisterAllClasses()
  end

  function tests.toString()
    local A = classic.class("A")
    function A:__tostring()
      return "foo"
    end
    local a = A()
    tester:asserteq(tostring(a), "foo", "tostring does not work")
    classic.deregisterAllClasses()
  end

  function tests.detectBadInit()
    tester:assertErrorPattern(function() definitions.BadInit() end,
                              "_init", "should detect constructor mistake")
    classic.deregisterAllClasses()
  end

  function tests.classAttributes()
    local A = classic.class("A")
    function A:foo()
      return 2
    end
    function A:bar()
      return self:class().baz
    end
    A.baz = 3

    local a = A()
    tester:asserteq(A.baz, 3, 'test class attribute')
    tester:asserteq(a:foo(), 2, 'test method')
    tester:asserteq(a:bar(), 3, 'test method with class attribute')

    function A.static.myMethod(x)
      return x + 1
    end

    tester:assertErrorPattern(function()
      A.myMethod = 3
    end, "naming conflict", "check name clash with static method")

    tester:assertErrorPattern(function()
      A.name = "foo"
    end, "naming conflict", "check name clash with global class method")

    classic.deregisterAllClasses()
  end

  function tests.staticMethods()
    local A = classic.class("A")
    function A.static:myClassMethod(x)
      return x + 3
    end
    function A.static.myStaticMethod(x)
      return x + 4
    end

    tester:asserteq(A.myStaticMethod(2), 6, "test calling static method")
    tester:asserteq(A:myClassMethod(2), 5, "test calling static method")

    local a = A()
    tester:assertErrorPattern(function() a:myStaticMethod(3) end,
                              "attempt to call method",
                              "check bad call - on instance with colon")
    tester:assertErrorPattern(function() a.myStaticMethod(3) end,
                              "attempt to call field",
                              "check bad call - on instance without colon")

    tester:assertErrorPattern(function()
      A.myThing = 3
      function A.static.myThing(x)
      end
    end, "naming conflict", "check name clash with class attribute")

    tester:assertErrorPattern(function()
      function A.static.name(x)
      end
    end, "naming conflict", "check name clash with global class method")

    tester:assertErrorPattern(function()
      function A.static.static(x)
      end
    end, "forbidden", "check name clash with 'static'")

    classic.deregisterAllClasses()
  end

  function tests.withDoFile()
    local file = 'classic/tests/class/do_file_test_class.lua'

    local doFileTestClass = dofile(file)
    doFileTestClass(1)

    local doFileTestClass = dofile(file)
    doFileTestClass(1)

    classic.deregisterAllClasses()
  end

  function tests.badParents()
    tester:assertErrorPattern(
        function()
          local A = classic.class("A", 2)
        end, "parent", "number as parent should fail")
    tester:assertErrorPattern(
        function()
          local A = classic.class("B", false)
        end, "parent", "boolean false as parent should fail")

    classic.deregisterAllClasses()
  end

  function tests.abstract()
    local A = classic.class("A")
    tester:assert(not A:abstract(), "class should not be abstract")
    A:mustHave("missingMethod")
    tester:assert(A:abstract(), "class should be abstract")
    classic.deregisterAllClasses()
  end

  function tests.mustHave()
    local A = classic.class("A")
    A:mustHave("missingMethod")
    tester:assertErrorPattern(function() A() end, "mustHave",
                              "missing mustHave should error")
    function A:missingMethod()
    end
    tester:assertNoError(function() A() end, "should not error")
    tester:assertErrorPattern(function() A:mustHave() end, "string")

    classic.deregisterAllClasses()
  end


  function tests.mathMetamethods()
    local A = classic.class('A')
    local randomMap = {}
    -- each metamethod will be overridden to return a unique random value.
    for _, meta in ipairs{'add', 'sub', 'mul', 'div', 'pow', 'unm', 'concat'} do
      local unif = torch.rand(1)[1]
      A['__' .. meta] = function(self, ...) return unif end
      randomMap[meta] = unif -- keep track of stored random value
    end
    local a = A()
    tester:asserteq(a + 0, randomMap['add'], 'failed to override __add')
    tester:asserteq(a - 0, randomMap['sub'], 'failed to override __sub')
    tester:asserteq(a * 0, randomMap['mul'], 'failed to override __mul')
    tester:asserteq(a / 0, randomMap['div'], 'failed to override __div')
    tester:asserteq(a ^ 0, randomMap['pow'], 'failed to override __pow')
    tester:asserteq(-a, randomMap['unm'], 'failed to override __unm')
    tester:asserteq(a .. 0, randomMap['concat'], 'failed to override __concat')
    classic.deregisterAllClasses()
  end

  return tests
end

return test_common
