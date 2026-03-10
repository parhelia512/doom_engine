local lib = require("lib")

local int = lib.interaction()
int.listen(function()
    print("ha")
end)

world:get_decals(1)[1]:set_interact(int.fn)
