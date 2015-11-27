local classic = require 'classic'
local definitions = {}

function definitions.withDefaultConstructor()
  local A = classic.class("A")
  function A:getValue()
    return 1
  end
  return A
end

function definitions.basicClass()
  local A = classic.class("A")
  function A:_init(x)
    self.x = assert(x)
  end
  function A:getX()
    return self.x
  end
  function A:_privateMethod()
    return self.x
  end
  return A
end

function definitions.similarClass()
  local A = classic.class("A")
  function A:_init(x)
    self.x = assert(x)
  end
  function A:getX()
    return self.x, 1
  end
  return A
end

function definitions.differentClass()
  local B = classic.class("B")
  function B:_init(x)
    self.x = assert(x)
  end
  function B:getX()
    return self.x
  end
  return B
end

function definitions.simpleHierarchy()
  local Base = classic.class("Base")
  function Base:_init()
    self._x = "base"
  end
  function Base:getX()
    return self._x
  end

  local ChildA, super = classic.class("ChildA", Base)
  function ChildA:_init(y)
    super._init(self)
    self._y = assert(y)
  end
  function ChildA:getY()
    return self._y
  end

  local ChildB, superB = classic.class("ChildB", Base)
  function ChildB:_init(z)
    superB._init(self)
    self._z = assert(z)
  end
  function ChildB:getZ()
    return self._z
  end

  return Base, ChildA, ChildB
end

function definitions.twoLevelHierarchy()
    local Base = classic.class("Base")
    function Base:_init(x)
        self._x = x
    end
    function Base:getX()
        return self._x
    end
    local Child, superA = classic.class("Child", Base)
    function Child:_init(x, y)
        self._y = y
        superA._init(self, x)
    end
    function Child:getY()
        return self._y
    end
    local Grandchild, superB = classic.class("Grandchild", Child)
    function Grandchild:_init(x, y, z)
        self._z = z
        superB._init(self, x, y)
    end
    function Grandchild:getZ()
        return self._z
    end
    return Base, Child, Grandchild
end

function definitions.hierarchyWithStringParent()
  local Base = classic.class("Base")
  function Base:_init()
    self._x = "base"
  end
  function Base:getX()
    return self._x
  end

  local ChildA, super = classic.class("ChildA", "Base")
  function ChildA:_init(y)
    super._init(self)
    self._y = assert(y)
  end
  function ChildA:getY()
    return self._y
  end
  return Base, ChildA
end

function definitions.hierarchyWithAbstractBase()
  local AbstractBase = classic.class("AbstractBase")
  AbstractBase:mustHave("foo")
  local GoodSubclass = classic.class("GoodSubclass", AbstractBase)
  function GoodSubclass:_init()
  end
  function GoodSubclass:foo()
    return "I have implemented it, so there."
  end
  local BadSubclass = classic.class("BadSubclass", AbstractBase)
  function BadSubclass:_init()
  end
  function BadSubclass:bar()
    return "I have not implemented all my pure methods. For shame."
  end
  return AbstractBase, GoodSubclass, BadSubclass
end

function definitions.classWithMixin()
  local M = classic.class("M")
  function M:getY()
    return self._y
  end
  local C = classic.class("C")
  function C:_init(y)
    self._y = y
  end
  C:include("M")
  return C, M
end

function definitions.dispatchToSubclass()
    local A = classic.class("A")
    function A:_init(instanceB)
        self.name = 'A'
        self:register(instanceB)
    end

    function A:register(instanceB)
        instanceB.target = self
        self.B = instanceB
    end
    function A:whoami()
        return "Parent; " .. self.name
    end

    local SubA, super = classic.class("SubA", A)
    function SubA:_init(instanceB)
        super._init(self, instanceB)
        self.name = 'SubA'
    end
    function SubA:whoami()
        return "Child; " .. self.name
    end

    local B = classic.class("B")
    function B:_init()
        self.target = {}
        self.name = 'B'
    end
    function B:callme()
        return self.target:whoami()
    end

    return A, SubA, B
end

function definitions.BadInit()
  local A = classic.class("A")
  function A:__init()
  end
  return A
end

return definitions
