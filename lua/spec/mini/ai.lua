---@module "mini.ai"

---@type LazyPluginSpec
local Spec = {
	"mini.ai", virtual = true, event = "VeryLazy",

	opts = function ()
		local gen_ai_spec = require ("mini.extra").gen_ai_spec
		return {
			custom_textobjects = {
				B = gen_ai_spec.buffer (),
			},
		}
	end,
}

return Spec
