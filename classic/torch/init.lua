--[[ Compatibility layer to get new classes to work with torch serialization. ]]

require 'torch'
-- LUALINT global:classic
local classic = assert(classic,
                       "classic.torch may not be required before classic.")

classic._notify(classic.events.CLASSIC_TORCH_ENABLED)

classic._torchCompatibility = true

if not torch.Object then
  local Object = torch.class("torch.Object")
  Object.__tostring = nil
  Object.__init = function()
    -- torch.Object constructor
  end
  function Object:read(file, version_number)
    local obj = file:readObject()
    local klass = classic.getClass(obj._class)
    if klass == nil then
      error("Loading object of class '" .. obj._class
            .. "', but no such class has been registered.")
    end
    self._class = klass
    local methods = klass._methods
    if methods.__read and type(methods.__read) == 'function' then
      methods.__read(self, file, version_number)
      return self
    else
      for k, v in pairs(obj) do
        if k ~= '_class' then self[k] = v end
      end
    end
    return self
  end
  function Object:write(file)
    local var = {}
    local methods = self._class._methods
    if methods.__write and type(methods.__write) == 'function' then
      file:writeObject({_class = self._class:name()})
      methods.__write(self, file)
    else
      for k, v in pairs(self) do
        if k == '_class' then
          var[k] = v:name()
        else
          if file:isWritableObject(v) then
            var[k] = v
          else
            io.stderr:write(
                string.format('$ Warning: cannot write object field <%s>', k))
          end
        end
      end
      file:writeObject(var)
    end
    return self
  end
  function Object:__index(name)
    if name == '__init' then
      return Object.__init
    end
    if name == 'read' then
      return Object.read
    end
    if name == 'write' then
      return Object.write
    end
    -- Handle user __index method, if present.
    local klass = assert(rawget(self, '_class'), "missing _class")
    local methods = rawget(klass, '_methods')
    local method = methods[name]
    if method == nil and methods.__index ~= nil then
      return methods.__index(self, name)
    end

    -- If strictness enabled, and value is missing, throw an error.
    if rawget(self, '__classic_strict') and method == nil then
      error("Strictness violation: cannot access '" .. name ..
            "' on object of type " .. tostring(rawget(klass, '_name')), 2)
    end
    return method
  end
  function Object:__newindex(name, value)
    -- Handle user __newindex method, if present.
    local klass = rawget(self, '_class')
    if klass then
      local methods = rawget(klass, '_methods')
      if methods.__newindex then
        return methods.__newindex(self, name, value)
      end
    end

    -- If strictness enabled, throw an error.
    if rawget(self, '__classic_strict') then
      local klass = assert(rawget(self, '_class'), "missing _class")
      error("Strictness violation: cannot access '" .. name ..
            "' on object of type " .. tostring(rawget(klass, '_name')), 2)
    end

    -- Otherwise, just set the value normally.
    rawset(self, name, value)
  end
  function Object:__call__(...)
    local klass = assert(rawget(self, '_class'), "missing _class")
    local call = assert(rawget(klass, '_methods').__call,
                        "missing __call method")
    return call(self, ...)
  end
  function Object:__tostring()
    local klass = assert(rawget(self, '_class'), "missing _class")
    local toString = rawget(klass, '_methods').__tostring
    if not toString then
      return "[object of class " .. tostring(klass) .. "]"
    end
    return toString(self)
  end
  local metaStrings = {'add', 'sub', 'mul', 'div', 'pow', 'unm', 'concat', 'eq'}
  for _, meta in ipairs(metaStrings) do
    local defaultMetaFunc = Object['__' .. meta]
    Object['__' .. meta] = function(self, ...)
      local klass = assert(rawget(self, '_class'), "missing _class")
      local methods = assert(
        rawget(klass, '_methods'),
        "class has no _methods table."
      )
      local metaMethod = methods['__' .. meta]
      if metaMethod then return metaMethod(self, ...) end
      return defaultMetaFunc(self, ...)
    end
  end
end

classic._createObject = function(klass)
  local obj = torch.Object()
  rawset(obj, '_class', klass)
  return obj
end
