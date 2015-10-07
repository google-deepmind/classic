local stringx = require 'pl.stringx'
local utils = {}

function utils.withTempDir(func)
  local givenTestDir = os.getenv("TEST_TMPDIR")
  if givenTestDir then
    -- TODO(horgan): may need to create a tmp dir below the given path.
    func(givenTestDir)
  else
    local dir = require 'pl.dir'
    local file = io.popen("mktemp -d -t classic_XXXXXX")
    local tmpDir = stringx.strip(file:read("*all"))
    file:close()
    func(tmpDir)
    dir.rmtree(tmpDir)
  end
end

return utils
