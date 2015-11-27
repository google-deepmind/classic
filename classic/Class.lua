local classic = assert(classic, 'metaclass should not be required directly')

-- Argument checking: check that self was correctly passed.
local function checkSelf(self, name)
  if type(self) ~= 'table' then
    error(name .. "() must be called on a class. Did you forget the colon?", 3)
  end
end

-- Argument checking: check that a string argument was correctly passed.
local function checkStringArg(str, name)
  if type(str) ~= 'string' then
    error(name .. "() expects a string argument, but got "
          .. tostring(type(str)) .. ".", 3)
  end
end

local Class = {}

--[[ Creates a new Class object.

This should not be called by user code directly - use `classic.class()` instead.

Arguments:

* `name` - Lua string containing the desired name of the class.
* `parent` - a classic class (optional).

Returns: a new classic class.

]]
function Class:_init(name, parent)
  local methods = {}
  local requiredMethods = {}
  local finalMethods = {}
  local classAttributes = {}
  local staticMethods = {}

  setmetatable(classAttributes, {
      __newindex = function(tbl, attributeName, attributeValue)
        if attributeName == 'static' then
          error("Defining a class attribute called 'static' in " .. name
                .. " is forbidden because it causes ambiguity.", 2)
        end
        if rawget(staticMethods, attributeName) then
          error("A naming conflict was detected in " .. name
                .. ": you are trying to set a class attribute '"
                .. attributeName .. " that has the same name as an existing "
                .. "static method.", 2)
        end
        if rawget(Class, attributeName) then
          error("A naming conflict was detected in " .. name
                .. ": you are trying to set a class attribute '"
                .. attributeName .. " that has the same name as one of the "
                .. " methods that are available on all class objects. This is "
                .. "forbidden because it causes ambiguity when you try to"
                .. " call it", 2)
        end
        rawset(tbl, attributeName, attributeValue)
      end
  })


  setmetatable(staticMethods, {
      __newindex = function(tbl, method, definition)
        if method == 'static' then
          error("Defining a static method called 'static' in " .. name
                .. " is forbidden because it causes ambiguity.", 2)
        end
        if rawget(classAttributes, method) then
          error("A naming conflict was detected in " .. name
                .. ": you are trying to define a static method '" .. method
                .. "' that has the same name as an existing class attribute.",
                2)
        end
        if rawget(Class, method) then
          error("A naming conflict was detected in " .. name
                .. ": you are trying to define a static method '" .. method
                .. "' that has the same name as one of the methods that are "
                .. "available on all class objects. This is forbidden because "
                .. "it causes ambiguity when you try to call it.", 2)
        end
        rawset(tbl, method, definition)
      end
  })
  rawset(self, '_name', name)
  rawset(self, '_parent', parent)
  rawset(self, '_methods', methods)
  rawset(self, '_classAttributes', classAttributes)
  rawset(self, '_requiredMethods', requiredMethods)
  rawset(self, '_finalMethods', finalMethods)
  rawset(self, 'static', staticMethods)

  -- Apply inheritance if necessary.
  if parent ~= nil then
    -- Copy instance methods from parent to the new class.
    for name, func in pairs(rawget(parent, '_methods')) do
      if methods[name] == nil then
        methods[name] = func
      end
    end
    -- Inherit any 'mustHave' settings.
    for _, methodName in ipairs(rawget(parent, '_requiredMethods')) do
      table.insert(requiredMethods, methodName)
    end
    -- Inherit any 'final' settings.
    for methodName, _ in pairs(rawget(parent, '_finalMethods')) do
      finalMethods[methodName] = true
    end
  end

  -- These methods are callable on all classic objects. We implement them for
  -- this class here.
  local Object = {
    class = function(obj) return self end,
    classIs = function(obj, otherKlass)
      return self == otherKlass
    end,
  }

  setmetatable(methods, {__index = Object})
end

--[[ Returns the name of the class.

Arguments: none.

Returns:

1. Lua string.

]]
function Class:name()
  return self._name
end

--[[ Returns the parent of the class.

Arguments: none.

Returns: classic.Class, or nil if there is no parent

]]
function Class:parent()
  return self._parent
end

--[[ Checks whether a given object is of precisely this class's type.

This does not traverse the inheritance tree at all.

Arguments:

* `obj` - an instance of a classic class.

Returns: boolean; true if the object is an instance of this particular class.

]]
function Class:isClassOf(x)
  return self == x:class()
end

--[[ Checks whether a given class is an ancestor of this class in the
inheritance tree.

Arguments:

* `class` - a classic class.

Returns: boolean; true if self is a subtype of the given class.

]]
function Class:isSubclassOf(klass)
  if self == klass then
    return true
  end
  local parent = rawget(self, '_parent')
  if parent then
    return parent:isSubclassOf(klass)
  end
  return false
end

--[[ Returns a table giving access to the parent's methods.

For convenience, rather than calling super(), you will probably want to use the

    local MyClass, super = classic.class("MyClass")

shortcut.

Parent methods can then be called like so:

    super.myMethod(self, opts)

**Note the need to pass in the instance of the object, 'self', explicitly!**

However, if you wanted to do it the long way, you could do:

    MyClass:super().myMethod(self, opts)

Arguments: none.

Returns:

 * a Lua table. Indexing into the table with a valid parent method name will
                return the corresponding function. Indexing with invalid names
                or assigning to the table will throw an error.

]]
function Class:super()
  local parent = self._parent
  if not parent then
    error(table.concat{"super() called, but ",
               self:name(), " has no parent!"}, 2)
  end
  local parentProxy = {}
  for name, method in pairs(parent._methods) do
    parentProxy[name] = function(arg1, ...)
      if arg1 == parentProxy then
        error("Misuse of Super object! Do not call it with a colon. " ..
              "Correct way: Super." .. name .. "(self, ...)", 2)
      end
      return method(arg1, ...)
    end
  end
  setmetatable(parentProxy, {
    __index = function(tbl, key)
      error(table.concat{
            "Trying to call method '", key, "' via super(), but the parent ",
            "class (", parent:name(), ") has no such method."}, 2)
    end,
    __newindex = function(tbl, key, value)
      error(table.concat{"Trying to assign to a value via super(),",
            " but this is not allowed!"}, 2)
    end,
  })
  return parentProxy
end

--[[ Returns a Lua string which corresponds uniquely to the content of the class
definition - i.e. the actual bytecode of the methods therein.

This may be useful for serialization.

Arguments: none.

Returns: Lua string; as described above.

]]
function Class:hash()
  local hashes = {}
  for k, v in pairs(self) do
    local hash
    if type(v) == 'function' then
      table.insert(hashes, k .. string.dump(v))
    else
      table.insert(hashes, k .. v)
    end
  end
  return table.concat(hashes)
end

--[[ To be used during class definition: indicates that neither this class, nor
any subclass of it, may be instantiated - unless a method with the given name
has been defined.

Simply, this is useful if you want to specify that certain methods are left to
be implemented by subclasses, and should not be omitted.

Arguments:

 * `methodName` - Lua string containing a valid method name.

Returns: none.

]]
function Class:mustHave(methodName)
  checkSelf(self, 'mustHave')
  checkStringArg(methodName, 'mustHave')
  local requiredMethods = rawget(self, '_requiredMethods')
  table.insert(requiredMethods, methodName)
end

--[[ Marks a method as 'final'.

This can be used during class definition to indicate that a particular method
should *not* be overridden by subclasses, or in classes that include this class
as a mixin.

Any subsequent attempt to do so will trigger an error.

Arguments:

 * `methodName` - Lua string containing a valid method name.

Returns: none.

]]
function Class:final(methodName)
  checkSelf(self, 'final')
  checkStringArg(methodName, 'final')

  local methods = rawget(self, '_methods')
  if methods[methodName] == nil then
    error("attempted to mark method '" .. methodName ..
          "' as final, but no method of that name has been declared yet.", 2)
  end
  local finalMethods = rawget(self, '_finalMethods')
  finalMethods[methodName] = true
end

--[[ Checks whether a given method name is marked as 'final'.

Arguments:

 * `methodName` - Lua string containing a valid method name.

Returns: boolean; true if the method name is final, and false otherwise.

]]
function Class:methodIsFinal(methodName)
  checkSelf(self, 'methodIsFinal')
  checkStringArg(methodName, 'methodIsFinal')
  local finalMethods = rawget(self, '_finalMethods')
  return finalMethods[methodName] ~= nil
end


--[[ Returns a table of methods for this class (excluding private methods).

This can be used to iterate over all methods of a class, or to call a method of
the class on some other object, for example.

Arguments: none.

Returns: Lua table, mapping from method name to function.

]]
function Class:methods()
  checkSelf(self, 'methods')
  local methods = {}
  for name, func in pairs(self._methods) do
    if type(func) == 'function' and string.sub(name, 1, 1) ~= "_"
        and Class[name] == nil then
      methods[name] = func
    end
  end
  return methods
end

--[[ Returns a table of methods for this class, including private methods.

This can be used to iterate over all methods of a class, or to call a method of
the class on some other object, for example.

Arguments: none.

Returns: Lua table, mapping from method name to function.

]]
function Class:allMethods()
  checkSelf(self, 'methods')
  local methods = {}
  for name, func in pairs(self._methods) do
    if type(func) == 'function' and Class[name] == nil then
      methods[name] = func
    end
  end
  return methods
end

--[[ Creates an object; an instance of this class.

Generally you'd want to call this the short way:

    local obj = MyClass(opts)

But if you really wanted to, you could equivalently do:

    local obj = MyClass:instantiate(opts)

This will call the constructor (_init) if one has been defined.

Note that the details of this object's metatable and internals depend on whether
Torch compatibility mode is enabled! In general, these internals may be subject
to change, and you should aim not to rely on them.

Arguments:

* `...` - any arguments to be passed to the constructor.

Returns: a new object, whose type is this class.

]]
function Class:instantiate(...)
  checkSelf(self, 'instantiate')
  assert(self ~= nil, "badly formed constructor call")

  local parent = rawget(self, '_parent')
  local methods = rawget(self, '_methods')
  local requiredMethods = rawget(self, '_requiredMethods')

  for _, methodName in ipairs(requiredMethods) do
    if methods[methodName] == nil then
      error("You cannot instantiate " .. self._name
      .. " since " .. methodName .. "() is marked as"
      .. " *mustHave*, yet has not been implemented.")
    end
  end

  local obj = classic._createObject(self)
  local constructor = methods._init
  if constructor ~= nil then
    constructor(obj, ...)
  end
  return obj
end

--[[ Adds the contents of the given class to this class's definition.

This is less commonly used, but provides a way of reusing functionality via a
with a weaker relationship than inheritance. This is akin to mixins, or traits,
in other languages.

Arguments:

* `class` - another classic class to include.

Returns: none.

]]
function Class:include(klass)
  if type(klass) == 'string' then
    klass = classic.getClass(klass)
  end
  assert(klass ~= nil, "invalid class include")

  -- Methods provided by the mixin are copied to the including class.
  local methods = rawget(self, '_methods')
  local otherMethods = rawget(klass, '_methods')
  for name, func in pairs(otherMethods) do
    if methods[name] ~= nil then
      error("method conflict: trying to include " .. name .. "() from "
            .. klass:name() .. ", but a method of that name already exists.", 2)
    end
    methods[name] = func
  end

  -- Methods required by the mixin are also required by the including class.
  local requiredMethods = rawget(self, '_requiredMethods')
  local otherRequiredMethods = rawget(klass, '_requiredMethods')
  for _, name in pairs(otherRequiredMethods) do
    table.insert(requiredMethods, name)
  end

  -- Methods marked final should also be final in the including class.
  local finalMethods = rawget(self, '_finalMethods')
  local otherFinalMethods = rawget(klass, '_finalMethods')
  for name, _ in pairs(otherFinalMethods) do
    finalMethods[name] = true
  end

end

--[[ Checks whether the class is abstract.

In other words, does it have any methods marked 'mustHave' that are not
implemented.

Arguments: none.

Returns: boolean; true if abstract, false if not.

]]
function Class:abstract()
  local methods = rawget(self, '_methods')
  local requiredMethods = rawget(self, '_requiredMethods')
  for _, methodName in ipairs(requiredMethods) do
    if methods[methodName] == nil then
      return true
    end
  end
  return false
end

local Metaclass = {}

--[[ This provides the shortcut whereby we can instantiate MyClass by calling it
as if it were a function:

    local instance = MyClass()

]]
function Metaclass.__call(self, ...)
  return self:instantiate(...)
end

--[[ This handles looking things up in the class object. There are several types
of data that live in the class. We store them separately so that they don't get
mixed up, but this means that we need to look in several places to find a value.

]]
function Metaclass.__index(self, name)

  -- If looking for the 'static' table that is used for defining static methods,
  -- return that.
  local static = rawget(self, 'static')
  if name == 'static' then
    return static
  end

  -- If looking for a static method, return that.
  local staticMethod = rawget(static, name)
  if staticMethod then
    return staticMethod
  end

  -- If looking for a class attribute, return that.
  local classAttributes = rawget(self, '_classAttributes')
  if classAttributes[name] ~= nil then
    return classAttributes[name]
  end

  -- If looking for one of the global class methods, return that.
  if Class[name] ~= nil then
    return Class[name]
  end

  error(tostring(name)
        .. " is neither a static method, a class attribute, nor a global class "
        .. "method.", 2)
end

--[[ This handles defining new things in the class. Things defined directly on
the class must either be class attributes, or instance methods. Static methods
must be defined through the 'static' table and so do not come through this
function.
]]
function Metaclass.__newindex(self, name, value)

  -- If it's not a function, it's a class attribute.
  if type(value) ~= 'function' then
    rawget(self, '_classAttributes')[name] = value
    classic._notify(classic.events.CLASS_SET_ATTRIBUTE, self, name, value)
  end

  -- Otherwise, we're defining an instance method (the normal case).
  -- We have a check for the constructor name, because it's easy to accidentally
  -- define the constructor with the wrong name and get confused, otherwise.
  if name == '__init' or name == 'init' then
    error("did you mean _init?")
  end

  -- Check that we're not trying to override a final method.
  local parent = rawget(self, '_parent')
  local methods = rawget(self, '_methods')
  if (parent and parent:methodIsFinal(name)) or
      (self:methodIsFinal(name) and rawget(methods, name) ~= nil) then
    error("Attempted to define method '" .. name .. "' in class '" ..
          self._name .. "', but '" .. name .. "' is marked as final.", 2)
  end

  rawset(methods, name, value)
  classic._notify(classic.events.CLASS_DEFINE_METHOD, self, name, value)
end

--[[ String representation of the class object. ]]
function Metaclass.__tostring(self)
  return table.concat{"classic.class<",
  tostring(rawget(self, '_name')), ">"}
end

--[[ This is a flag marking the object as being a classic class object, which
can then later be used for checking whether or not something is one. ]]
Metaclass.classicClass = true

--[[ We can create a new class object by calling

    local MyClass = Class(name, parent)

But users should create classes via classic.class().
]]
setmetatable(Class, {
  __call = function(self, options)
    local name = options.name
    if name == nil then
      error("Missing option when creating class: 'name'.", 3)
    end
    if type(name) ~= 'string' then
      error("Expected class name to be a string.", 3)
    end
    local parent = options.parent
    -- Parent classes may be specified either by passing a class object
    -- directly, or by passing the name of a class as a string.
    if parent ~= nil and type(parent) == 'string' then
      parent = classic.getClass(parent)
    end

    if parent ~= nil then
      if not classic.isClass(parent) then
        error("parent is not a class", 3)
      end
    end

    local klass = {}
    setmetatable(klass, Metaclass)
    Class._init(klass, name, parent or nil)

    classic._notify(classic.events.CLASS_INIT, name)
    return klass
  end

})

return Class
