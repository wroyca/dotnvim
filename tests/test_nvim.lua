local t = require ("mini.test")
local expect, eq = t.expect, t.expect.equality

-- Create test set.
--
local T = t.new_set ({
  hooks = {
    -- Reset config before each test.
    --
    pre_case = function ()
    end,
  }
})

return T
