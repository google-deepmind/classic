classic = {}
local torch = require 'torch'

--[[ This is the list of events that can be hooked into by callbacks.

Call `classic.addCallback()` if you want to be notified when one of these
happens.
]]
classic.events = {
    -- A new class is initialized. Callback is passed the name.
    CLASS_INIT = 1,

    -- An attribute is first set in a class. Callback is passed the class object
    -- and the attribute name and value.
    CLASS_SET_ATTRIBUTE = 2,

    -- A method is defined in a class. Callback is passed the class object and
    -- the method name and function.
    CLASS_DEFINE_METHOD = 3,

    -- A new module is initialized. Callback is passed the module name.
    MODULE_INIT = 4,

    -- A class is added to a module. Callback is passed the module object and
    -- class name.
    MODULE_DECLARE_CLASS = 5,

    -- A submodule is added to a module. Callback is passed the module object
    -- and submodule name.
    MODULE_DECLARE_SUBMODULE = 6,

    -- A function is added to a module. Callback is passed the module object and
    -- function name.
    MODULE_DECLARE_FUNCTION = 7,

    -- classic.torch is enabled. Callback is not passed anything.
    CLASSIC_TORCH_ENABLED = 8,

    -- A class is loaded whose name does not match the name it was loaded
    -- with. Callback is passed the class's actual name and the name it was
    -- loaded with.
    CLASS_REQUIRE_NAME_MISMATCH = 9
}
setmetatable(classic.events, {
    __index = function(t, k) error(k .. " is not a valid classic event!") end})
classic._callbacks = {}

--[[ Register a callback function to be called whenever some particular event
occurs in classic.

This can be used to extend the functionality of classic to fit your needs. For
instance, you might want to log particular events, for debugging, or enforce a
certain way of naming classes.

Arguments:

* `event` - an event ID, from the `classic.events` table.
* `func` - a callback function. The arguments it is passed depend on the event.
]]
function classic.addCallback(event, func)
  assert(event and type(event) == 'number',
         "classic.addCallback() requires an event ID as its first argument.")
  assert(func and type(func) == 'function',
         "classic.addCallback() requires a callback function as its second " ..
         "argument.")
  if classic._callbacks[event] == nil then
    classic._callbacks[event] = {}
  end
  table.insert(classic._callbacks[event], func)
end

--[[ Call any registered callbacks for the specified event, passing in the given
arguments.

Arguments:

* `event` - an event ID, from the `classic.events` table.
* `...` - additional arguments to be passed to the callbacks.
]]
function classic._notify(event, ...)
  if classic._callbacks[event] then
    for _, callback in ipairs(classic._callbacks[event]) do
      callback(...)
    end
  end
end

local Class = require 'classic.Class'
local Module = require 'classic.Module'

--[[ Creates a new module.

Arguments:

* `name` - a string containing the name of the module.

Returns: `module` - a Module object.
]]
function classic.module(name)
  if name == nil then
    error("Module name is missing.", 2)
  end
  if name == classic then
    error("classic:module() with a colon is wrong; use classic.module() " ..
          "instead", 2)
  end
  if type(name) ~= 'string' then
    error('Expected module name to be a string.', 2)
  end
  return Module(name)
end

--[[ Creates a new class.

Arguments:

* `name` - string containing the name of the class.
* `parent` - a parent class object, to inherit from.

Returns:

1. `class` - a Class object, upon which you can define functions
2. `super` - an object for calling methods of the parent class
]]
function classic.class(name, parent)
  if name == nil then
    error("must provide a class name!", 2)
  end
  if name == classic then
    error("classic:class() with a colon is wrong; use classic.class() instead",
          2)
  end
  if type(name) ~= 'string' then
    error("class name should be a string!", 2)
  end
  if parent and (type(parent) ~= 'string' and not classic.isClass(parent)) then
    error("expected parent to be either a string or a classic class", 2)
  end
  local registeredClass = classic._registry[name]
  if registeredClass ~= nil then
    return classic._dummyClass(registeredClass)
  end

  local cls = Class{
    name = name,
    parent = parent
  }
  classic._registerClass(name, cls)
  if parent ~= nil then
      return cls, cls:super()
  end
  return cls
end

--[[ Tests whether something is an instance of a classic Class.

Arguments:

* `data` - some Lua data; not nil.

Returns: boolean; true if the data is a classic object.
]]
function classic.isObject(object)
  if object == nil then
    error("classic.isObject(): no object given.", 2)
  end
  if type(object) ~= 'table' then
    return false
  end
  local ok, isObject = pcall(
      function()
        if type(object.class) ~= 'function' then
          return false
        end
        local klass = object:class()
        return classic.isClass(klass)
      end)
  return ok and isObject
end

--[[ Makes an object 'strict' - i.e. it will throw an error when later getting
or setting any attributes that did not exist when the object was made strict.

This can be used to catch problems with typos in object attribute names.

Arguments:

* `object` - an instance of a classic class.
]]
function classic.strict(object, ...)
  if select('#', ...) ~= 0 or object == classic then
    error("strict() should have exactly one argument - maybe you used a " ..
          "colon instead of a dot?")
  end
  assert(object ~= nil, "classic.strict is missing an object to make strict")
  if classic._torchCompatibility then
    rawset(object, '__classic_strict', true)
    return
  end
  assert(classic.isObject(object), "classic.strict only works on classic " ..
                                   "objects")
  local index = getmetatable(object).__index
  setmetatable(object, {
    __index = function(t, k)
      local item = index[k]
      if item ~= nil then
        return item
      end
      error("Strictness violation: cannot access '" .. k ..
            "' on object of type " .. tostring(object:class():name()), 2)
    end,
    __newindex = function(t, k, v)
      local name = t.name and t:name() or "unknown"
      error("Strictness violation: object of type " .. name
            .. " was made strict, but you are trying to add an"
            .. " attribute called " .. tostring(k) .. " to it.")
    end
  })
end

--[[ Find a class by name.

If the class is already loaded, it will be returned. Otherwise, it will be
loaded and then returned.

Arguments:

* `name` - string; full name of the desired class.

Returns: classic.Class object.
]]
function classic.getClass(name)
  if type(name) ~= 'string' then
    error("classic.getClass() expected string as first argument.", 2)
  end
  local klass = classic._registry[name]
  if klass ~= nil then
    return klass
  end
  return classic._loadClass(name)
end

--[[ Remove the specified class from classics registry of loaded classes.

This is mainly useful for testing.

Arguments:

* `name` - full name of the class to be removed.
]]
function classic.deregisterClass(name)
  if type(name) ~= 'string' then
    error("classic.deregisterClass() expected string as first argument", 2)
  end
  if classic._registry[name] == nil then
    error("Cannot deregister class '" .. name
          .. "' because it has not been registered")
  end
  classic._registry[name] = nil
end

--[[ Test whether the given object is a classic.Class object.

Arguments:

* `obj` - some Lua Data

Returns: boolean; true if the object is a classic class.
]]
function classic.isClass(obj)
  if not type(obj) == "table" then
    return false
  end
  local meta = getmetatable(obj)
  if type(meta) ~= 'table' or not meta.classicClass then
    return false
  end
  return true
end

--[[ Tests whether the given object is a classic.Module object.

Arguments:

* `obj` - some Lua Data

Returns: boolean
]]
function classic.isModule(obj)
  if not type(obj) == 'table' then
    return false
  end
  local meta = getmetatable(obj)
  if type(meta) ~= 'table' or not meta.classicModule then
    return false
  end
  return true
end

--[[ Empty classic's table of loaded classes.

This is mainly useful for testing.
]]
function classic.deregisterAllClasses()
  classic._registry = {}
end

local function indent(level)
    return string.rep("|  ", level)
end

--[[ Recursively lists the contents of a module.

Arguments:

* `obj`   - a module
* `level` - indentation level to begin at (default: 0)

Returns: none (output is printed to stdout)
]]
function classic.list(obj, level)
  level = level or 0
  print(indent(level) .. tostring(obj))
  if classic.isModule(obj) then
    for name, module in obj:submodules() do
      classic.list(module, level + 1)
    end
    for name, class in obj:classes() do
      classic.list(class, level + 1)
    end
    for name, moduleFunction in obj:functions() do
      print(indent(level + 1) ..
            'function<' .. obj:name() .. '.' .. name .. '>')
    end
  end
end

function classic._loadClass(name)
  local ok, value = pcall(require, name)
  if not ok then
    local err = value
    error("Cannot load class " .. name .. ": " .. err, 2)
  end
  if value == true then
    value = classic._registry[name]
  end
  assert(classic.isClass(value) or torch.typename(value),
         "Loaded " .. name .. " but it is not a class")
  local klass = value
  if klass:name() ~= name then
    classic._notify(
        classic.events.CLASS_REQUIRE_NAME_MISMATCH, klass:name(), name)
  end
  return klass
end

function classic._registerClass(name, klass)
  if type(name) ~= 'string' then
    error("Expected class name to be a string.", 2)
  end
  if not classic.isClass(klass) then
    error("Trying to register class that was not correctly formed.", 2)
  end
  if name ~= klass._name then
    error("Trying to register a class with a name other than its " ..
          "assigned name.")
  end
  if classic._registry[name] ~= nil then
    if classic._registry[name] ~= klass then
      error("A class with the name '" .. name .. "' has already been " ..
            "registered.")
    end
  end
  classic._registry[name] = klass
end


function classic._init()
  -- Global class lookup table.
  classic._registry = {}

  -- By default, we are not compatible with torch.save().
  -- To get compatibility, require 'classic.torch'.
  classic._torchCompatibility = false

  classic._createObject = function(klass)

    local methods = klass._methods
    local index = methods

    -- Handle user-provided __index function, if present.
    local indexFunc = methods.__index
    if indexFunc then
      index = function(tbl, name)
        local method = methods[name]
        if method ~= nil then
          return method
        end
        return indexFunc(tbl, name)
      end
    end

    local obj = {}
    setmetatable(obj, {
      __add = klass._methods.__add,
      __call = klass._methods.__call,
      __concat = klass._methods.__concat,
      __div = klass._methods.__div,
      __index = index,
      __mul = klass._methods.__mul,
      __newindex = klass._methods.__newindex,
      __pow = klass._methods.__pow,
      __sub = klass._methods.__sub,
      __tostring = klass._methods.__tostring,
      __unm = klass._methods.__unm,
      __eq = klass._methods.__eq,
    })
    return obj
  end
end

--[[ The following exists in order to allow repeated definition of a class,
*provided* the subsequent definitions match the first one. This is a bit of an
odd feature, but it is convenient in Lua development to be able to re-evaluate
one's source files so as to avoid going through a lengthier build or install
process.

The way we allow this with some degree of safety is to arrange things such that
classic.class() will, on invocations *after* the first one for a given class
name, return a 'dummy class' instead of a real new class. This dummy class
behaves like normal, except that if you try to define its methods differently
from the original, it will throw an error.

This behaviour may be subject to change in the future.
]]
function classic._dummyClass(klass)

  local dummy = {}
  local methods = rawget(klass, '_methods')
  setmetatable(dummy, {
    __call = function(self, ...)
      return klass(...)
    end,

    __index = function(t, k)
      local method = rawget(t, k)
      if method ~= nil then
        return method
      end
      return klass[k]
    end,

    __newindex = function(tbl, name, value)

      -- Handle class attributes.
      if type(value) ~= 'function' then
        klass[name] = value
        return
      end

      if methods[name] == nil then
        error("You are defining a version of class " .. klass:name()
              .. " which conflicts with a previously-defined version. (Method "
              .. name .. " was not present, before)", 2)
      end

      if string.dump(methods[name]) ~= string.dump(value) then
        error("You are defining a version of class " .. klass:name()
              .. " which conflicts with a previously-defined version. (Method "
              .. name .. " is defined differently in the two versions.)", 2)
      end

      return rawset(tbl, name, value)
    end,
  })

  return dummy
end

classic._init()

return classic
