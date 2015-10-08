package = "classic"
version = "scm-1"
description = {
    summary = "Class system",
    detailed = [[ Classic is a class system for Lua. ]]
}

source = {
    url = "git://github.com/deepmind/classic.git",
    branch = 'master'
}

dependencies = { "torch >= 7.0", "totem" }

build = {
    type = 'builtin',
    modules = {
        classic = "classic/init.lua",
        ["classic.Class"] = "classic/Class.lua",
        ["classic.Module"] = "classic/Module.lua",
        ["classic.torch"] = "classic/torch/init.lua",

        ["classic.tests.class.common"] = "classic/tests/class/common.lua",
        ["classic.tests.class.definitions"] = "classic/tests/class/definitions.lua",
        ["classic.tests.class.utils"] = "classic/tests/class/utils.lua",

        ["classic.tests.module.test"] = "classic/tests/module/test.lua",
    },
}
