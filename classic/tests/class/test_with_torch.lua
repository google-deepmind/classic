local totem = require 'totem'
local tester = totem.Tester()
local classic = require 'classic'
require 'classic.torch'
local getmetatable = getmetatable
local common = require 'classic.tests.class.common'
local definitions = require 'classic.tests.class.definitions'
local utils = require 'classic.tests.class.utils'

local tests = common.generateTests(tester)

-- Add torch-specific tests.

function tests.torchTypename()
  local A = definitions.basicClass()
  local a = A("hello")
  tester:asserteq(torch.typename(a), "torch.Object", 'bad torch.typename')
end

function tests.torchSerializable()
  utils.withTempDir(function(tempDir)
    require 'torch'
    local filename = tempDir .. "/temp.t7"
    local A = definitions.basicClass()
    local object = A("hello")
    torch.save(filename, object)
    local loaded = torch.load(filename)
    tester:assertTableEq(object, loaded, 'reloaded table not the same')
    tester:assert(getmetatable(loaded), 'no metatable on reload')
    tester:asserteq(loaded:class():name(), "A",
                    'class():name() should work on reload')
    tester:asserteq(loaded:class(), A, 'class() should return correct class')
  end)
end

function tests.torchSerializableComposition()
  utils.withTempDir(function(tempDir)
    require 'torch'
    local filename = tempDir .. "/temp.t7"
    local A = definitions.basicClass()
    local B = definitions.differentClass()
    local a = A("hello")
    local b = B(a)
    torch.save(filename, b)
    local loaded = torch.load(filename)
    tester:assertTableEq(b, loaded, 'reloaded table not the same')
    tester:assert(getmetatable(loaded), 'no metatable on reload')
    tester:asserteq(loaded:class():name(), "B",
                    'class():name() should work on reload')
    tester:asserteq(loaded:class(), B,
                    'class() should return correct class')
    tester:asserteq(loaded:getX():class():name(), "A",
                    'getX():class():name() should work on reload')
    tester:asserteq(loaded:getX():class(), A,
                    'getX():class() should work on reload')
  end)
end

function tests.torchSerializableInheritance()
  utils.withTempDir(function(tempDir)
    require 'torch'
    local filenameBase = tempDir .. "/temp_base.t7"
    local filenameA = tempDir .. "/temp_a.t7"
    local filenameB = tempDir .. "/temp_b.t7"
    local Base, ChildA, ChildB = definitions.simpleHierarchy()
    do
      local base = Base()
      local a = ChildA("y")
      local b = ChildB("z")
      torch.save(filenameBase, base)
      torch.save(filenameA, a)
      torch.save(filenameB, b)
    end
    local loadedBase = torch.load(filenameBase)
    local loadedA = torch.load(filenameA)
    local loadedB = torch.load(filenameB)

    tester:asserteq(loadedBase:getX(), "base", "base method should work")
    tester:asserteq(loadedA:getX(), "base", "base method should work")
    tester:asserteq(loadedB:getX(), "base", "base method should work")
    tester:asserteq(loadedA:getY(), "y", "subclass method should work")
    tester:assert(loadedB.getZ, "subclass method should exist")
    tester:asserteq(loadedB:getZ(), "z", "subclass method should work")
    tester:asserteq(loadedA:class(), ChildA,
                    "instance should be right subclass")
    tester:asserteq(loadedB:class(), ChildB,
                    "instance should be right subclass")
    tester:asserteq(loadedA:class():parent(), Base, "parent should be correct")
    tester:asserteq(loadedB:class():parent(), Base, "parent should be correct")
  end)
end

function tests.torchSerializableDifferentClassInstance()
  utils.withTempDir(function(tempDir)
    require 'torch'
    local filename = tempDir .. "/temp.t7"
    do
      local A = definitions.basicClass()
      local object = A("hello")
      torch.save(filename, object)
      classic.deregisterClass("A")
    end
    local A = definitions.basicClass()
    local loaded = torch.load(filename)
    tester:asserteq(torch.typename(loaded),
                    "torch.Object", "bad typename on reload")
    tester:assert(getmetatable(loaded), 'no metatable on reload')
    tester:asserteq(loaded:class():name(), "A",
                    'class():name() should work on reload')
    tester:asserteq(loaded:class(), A, 'class() should return correct class')
  end)
end

function tests.torchSerializationReadWriteOverrides()
  utils.withTempDir(function(tempDir)
    require 'torch'
    local magic = 'FOO'
    local Foo = classic.class('Foo')
    function Foo:_init()
      self.state = 'original'
    end
    function Foo:__write(file)
      self.state = 'written'
      file:writeObject(magic)
    end
    function Foo:__read(file, version)
      local obj = file:readObject()
      tester:asserteq(type(obj), 'string')
      tester:asserteq(obj, magic)
      self.state = 'restored'
    end

    local foo = Foo()
    local filename = tempDir .. '/temp_foo.t7'
    torch.save(filename, foo)
    local restored = torch.load(filename)
    tester:asserteq(restored.state, 'restored')
  end)
end

return tester:add(tests):run()
