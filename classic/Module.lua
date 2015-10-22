--[[ This is the module system - see README.md for discussion. ]]

local Module = {}

--[[ Creates a module of the given name.

Arguments:

 * `name` - string; the full name of the module.

Returns: a new Module object; the created module.

Example:

    local M = classic.module(...)
    M:class("ClassA")
    M:class("ClassB")
    M:submodule("utils")
    return M
]]
function Module:_init(name)
  classic._notify(classic.events.MODULE_INIT, name)
  rawset(self, '_name', name)
  rawset(self, '_submodules', {})
  rawset(self, '_classes', {})
  rawset(self, '_moduleFunctions', {})
  package.loaded[name] = self
end

--[[ Return this module's fully-qualified name as a string. ]]
function Module:name()
  return self._name
end

--[[ Declares that this module contains a submodule with the given name.

Arguments:

* `name` - name of the submodule being declared.

]]
function Module:submodule(name)
  if name == nil then
    error("Submodule name is missing.", 2)
  end
  if type(name) ~= 'string' then
    error("Submodule name must be a string.", 2)
  end
  if self._submodules[name] ~= nil then
    error("Already declared submodule " .. name .. ".", 2)
  end
  classic._notify(classic.events.MODULE_DECLARE_SUBMODULE, self, name)
  self._submodules[name] = true
end

--[[ Declare that this module contains a class with the given name.

Arguments:

* `name` - name of the class being declared.

]]
function Module:class(name)
  if name == nil then
    error("Class name is missing.", 2)
  end
  if type(name) ~= 'string' then
    error("Class name must be a string.", 2)
  end
  if self._classes[name] ~= nil then
    error("Already declared class " .. name .. ".", 2)
  end
  classic._notify(classic.events.MODULE_DECLARE_CLASS, self, name)
  self._classes[name] = true
end

--[[ Declare that this module contains a function with the given name.

Arguments:

* `name` - name of the function being declared.

]]
function Module:moduleFunction(name)
  if name == nil then
    error("Function name is missing.", 2)
  end
  if type(name) ~= 'string' then
    error("Function name must be a string.", 2)
  end
  if self._moduleFunctions[name] ~= nil then
    error("Already declared module function " .. name .. ".", 2)
  end
  classic._notify(classic.events.MODULE_DECLARE_FUNCTION, self, name)
  self._moduleFunctions[name] = true
end

--[[ This creates an iterator like pairs(), but which looks up each key in a
separate object.

Arguments:

* `obj` - object in which to look up keys.
* `tbl` - table from which to draw the keys.

Returns: Lua iterator over `(name, obj[name])` for each name in the keys of
         `tbl`.

]]
local function keyLookupIterator(obj, tbl)
  local iter = pairs(tbl)
  local _, name
  return function()
    name, _ = iter(tbl, name)
    if name then
      return name, obj[name]
    end
  end
end

--[[ Returns an iterator over submodules of the given module.

The iterator will yield pairs of (name, submodule).

]]
function Module:submodules()
  return keyLookupIterator(self, self._submodules)
end

--[[ Returns an iterator over classes in the module.

The iterator will yield pairs of (name, submodule).

]]
function Module:classes()
  return keyLookupIterator(self, self._classes)
end

--[[ Returns an iterator over functions in the module.

The iterator will yield pairs of (name, function).

]]
function Module:functions()
  return keyLookupIterator(self, self._moduleFunctions)
end

--[[ Lists the contents of this module.

This is a shortcut for classic.list(); see that function for details.

]]
function Module:list()
  assert(self ~= nil, "Module:list() needs to be called with a ':', not a '.'!")
  classic.list(self)
end

--[[ This is where we define the metamethods for Module objects.

In particular, we have special handling for indexing into a module.

]]
local Metamodule = {}

--[[ This handles looking things up in the module object.

There are several types of data that can live in a module: submodules, classes,
functions, and other data.  In the first three cases, we allow them to be loaded
lazily, which can be convenient for large modules that have a lot of
dependencies.

]]
function Metamodule.__index(self, key)
  if Module[key] then
    return Module[key]
  end
  local submodules = assert(rawget(self, "_submodules"), "missing _submodules")
  local classes = assert(rawget(self, "_classes"), "missing _classes")
  local functions = assert(rawget(self, "_moduleFunctions"),
                           "missing _moduleFunctions")
  if submodules[key] then
    local submodule = require(self._name .. "." .. key)
    if not classic.isModule(submodule) then
      error(tostring(key) .. " is not a module", 2)
    end
    rawset(self, key, submodule)
    return submodule
  end
  if classes[key] then
    local class = classic.getClass(self._name .. "." .. key)
    rawset(self, key, class)
    return class
  end
  if functions[key] then
    local func = require(self._name .. "." .. key)
    if not type(func) == 'function' then
      error(self._name .. "." .. tostring(key) .. " is not a function", 2)
    end
    rawset(self, key, func)
    return func
  end
  error("Module " .. self._name .. " does not contain '" .. key .. "'.", 2)
end

--[[ This allows setting of functions and data in the module.

Functions are name-checked and noted in the _moduleFunctions table; other data
are allowed to pass freely.

]]
function Metamodule.__newindex(self, key, value)
  if Module[key] then
    error("Member name '" .. key .. "' clashes with the general classic module"
          .. " function of the same name.", 2)
  end
  if self._moduleFunctions[key] then
    error("Overwriting function " .. key .. " in module " .. self._name, 2)
  end
  if self._submodules[key] then
    error("Overwriting submodule " .. key .. " in module " .. self._name, 2)
  end
  if self._classes[key] then
    error("Overwriting class " .. key .. " in module " .. self._name, 2)
  end
  if type(value) == 'function' then
    if key == nil then
      error("Function name should not be nil!", 2)
    end
    self._moduleFunctions[key] = value
  end
  rawset(self, key, value)
end

--[[ String representation of the module object. ]]
function Metamodule.__tostring(self)
  return "classic.module<" .. self._name .. ">"
end

--[[ This is a flag marking the object as being a classic module object, which
can then later be used for checking whether or not something is one. ]]
Metamodule.classicModule = true

--[[ We can create a new module object by calling

    local my_module = Module(name)

But users should create modules via classic.module().
]]
setmetatable(Module, {
  __call = function(self, namespace)
    local module = {}
    setmetatable(module, Metamodule)
    module:_init(namespace)
    return module
  end
})

return Module
