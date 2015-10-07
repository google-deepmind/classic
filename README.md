# classic - Class and module system for Lua.

`classic` is a simple class system for Lua.
Its features include:

 * named classes; nesting of names permitted
 * does not pollute the global namespace
 * compatibility with torch.save / torch.load
 * reflection
 * 'fat' inheritance, mixins
 * strictifiability
 * interfaces
 * sourcing the same definition twice is permitted

## Usage

### Basic usage

```lua
local classic = require 'classic'

local MyClass = classic.class("MyClass")

function MyClass:_init(opts)
  self.x = opts.x
end

function MyClass:getX()
  return self.x
end

local instance_a = MyClass{x = 3}
local instance_b = MyClass{x = 4}
print(instance_a, instance_a:getX())
print(instance_b, instance_b:getX())
```

### Inheritance

```lua
local classic = require 'classic'

local Base = classic.class("Base")
function Base:_init()
  self._x = "base"
end

function Base:getX()
  return self._x
end

local Child, super = classic.class("Child", Base)

function Child:_init(y)
  super._init(self) -- call the superconstructor, *passing in self*
  self._y = assert(y)
end

function Child:getY()
  return self._y
end

local obj = Child("y")
print(obj:getY()) -- y
print(obj:getX()) -- base
print(obj:class():isSubclassOf(Base)) -- true
```

### Reflection

```lua
print(instance_a:class():name())
print(instance_a:class():methods())
```

### Torch IO Compatibility

Note: you must require `classic.torch` for classic classes to work properly with
torch serialization!

```lua
local classic = require 'classic'
require 'classic.torch'

local A = classic.class("A")
function A:foo()
  return 3
end

local a = A()
torch.save("a.t7", a)
local loaded = torch.load("a.t7")
print(a:foo())
```

After having required `classic.torch`, custom `__read`/`__write` methods can now
be added to the class (as regular methods rather than metamethods). `torch.load`
and `torch.save` will invoke these methods if present, as the `read`/`write`
metamethods used in `torch.class` instances.

### Strictness

```lua
local classic = require 'classic'

local A = classic.class("A")

local a = A()
classic.strict(a)

-- Error!
print(a.thisAttributHasATypo)
```

### Class attributes

You can store data on class objects - for example, if you want to share
something between all instances of that class. Note only that you cannot store a
function as a class attribute, as that is indistinguisable from defining an
instance method.

```lua
local classic = require 'classic'

local A = classic.class("A")
A.var = 3
print(A.var)
```

### Static methods

You can define static methods, which pertain to the class as a whole
rather than any particular instance. Static methods do not receive any instance
or class object in their parameters, and are declared and called with a '.'.

```lua
local classic = require 'classic'

local A = classic.class("A")

function A.static.myStaticMethod(x)
  return x
end

print(A.myStaticMethod(3))
```

### Modules

As well as the class system, classic has a way of defining modules.
**You don't have to use the module system to use the class system.**
However, it can be a clean way of organising your code and reducing boilerplate.

The rule that it asks you to abide by is as follows: each class should be
defined in its own file, and the filename is what determines the name of the
class.

The best way of explaining this is with an example.

Here is a typical top-level classic module definition:

```lua
local classic = require 'classic'

local my_project = classic.module(...)
my_project:class("MyClass")
my_project:submodule("utils")
return my_project
```

Now, if you save this in "my_project/init.lua", it can be loaded as usual via

```lua
local my_project = require 'my_project'
```

and when the code is run, the `...` symbol in the aforementioned module
definition will be set to the require name: 'my_project'.

This pattern both ensures that your module's name is set correctly, and
saves you typing it lots of times.

The name of the local variable you use when defining the module does not actually
matter - so you could equally well write:

```lua
local classic = require 'classic'

local M = classic.module(...)
M:class("MyClass")
M:submodule("utils")
return M
```

which some may find preferable. With this approach, renaming a module is simply
a matter of renaming the directory that contains it.

Now, what about these 'class' and 'submodule' calls? These simply outline the
things the module contains. The calls **do not** load the things they refer to;
they just register the fact that they exist. The advantage of this is that
code can use something from a module without having to load the whole thing.
This includes code in the module itself.

So, `M:class("MyClass")` says that `require 'my_project.MyClass'` is going to
return the definition of that class. Similarly `M:submodule("utils")` says that
there is a submodule that can be loaded by calling `require 'my_project.utils'`.

With this in mind, we just need to define the corresponding objects in the right
places - note that we can use the `...` trick again to save writing the full
names everywhere.

In `my_project/MyClass.lua`, we write:

```lua
local MyClass = classic.class(...)
function MyClass:_init(opts)
  self.x = opts.x
end

return MyClass
```

and in `my_project/utils/init.lua`, we write:

```lua
local utils = classic.module(...)
local my_project = require 'my_project'

function utils.makeTestObject()
  return my_project.MyClass{x=3}
end

return utils
```

We could just as well have saved this as `my_project/utils.lua`, but using a
separate subdirectory leaves more opportunity for expanding the utils submodule
without resulting in a single large file.

Note that in the utils submodule, we referred to MyClass by requiring
'my_project', and 'my_project' itself contains 'utils' - but this does not
result in a circular dependency! This is because the declaration of 'utils' in
'my_project' does not cause 'utils' to actually be loaded. Only when somebody
accesses 'my_project.utils' will the definition really be loaded. This pattern
can make things cleaner in large projects.

You can even specify that individual functions should be loaded lazily, if you
want to use this pattern everywhere in a project:

```lua
local utils = classic.module('utils')
utils:moduleFunction('myFunction')
return utils
```

This assumes that `require 'utils.myFunction'` will return the function in
question.

### Adding torch.class instances to classic modules

In module definition:

```lua
MyModule = classic.module(...)  -- note: this is global.

local MyClass = torch.class('MyModule.MyClass')

MyClass:__init(opts)
  self.x = opts.x
end
```

and in client code:

```lua
local my_project = require 'path.to.MyModule'
local obj = my_project.MyClass{x = 1}
```
