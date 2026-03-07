package engine
import lua "vendor:lua/5.4"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:log"

lua_allocator :: proc "c" (ud: rawptr, ptr: rawptr, osize, nsize: c.size_t) -> (buf: rawptr) {
    old_size := int(osize)
    new_size := int(nsize)
    context = (^runtime.Context)(ud)^
    if ptr == nil {
        data, err := runtime.mem_alloc(new_size)
        return raw_data(data) if err == .None else nil
    } else {
        if nsize > 0 {
            data, err := runtime.mem_resize(ptr, old_size, new_size)
            return raw_data(data) if err == .None else nil
        } else {
            runtime.mem_free(ptr)
            return
        }
    }
}

update_fn:Maybe(c.int)

import "core:fmt"
add_function :: proc(state: ^lua.State, p: lua.CFunction, name: cstring) {
    lua.pushcfunction(state, p)
    lua.setfield(state, -2, name)
}


_ctx: runtime.Context
logger:log.Logger

get_sector::proc(state: ^lua.State, sector: ^Sector) {
    sectorp:= (^^Sector)(lua.newuserdata(state, size_of(^Sector)))
    sectorp^ = sector

    lua.L_newmetatable(state, "SectorMeta")

    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector := (cast(^^Sector)lua.touserdata(state, 1))^
        lua.pushnumber(state, lua.Number(sector.height))
        return 1 
    }, "get_height")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector := (cast(^^Sector)lua.touserdata(state, 1))^
        height :=cast(f32) lua.L_checknumber(state, 2)
        sector.height = height
        return 0 
    }, "set_height")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.setmetatable(state, -2)
}

load_file :: proc(file: string, world: ^World, allocator:=context.allocator, loggerf:=context.logger) -> ^lua.State {
    logger = loggerf
    _ctx = context
    str:=strings.clone_to_cstring(file, allocator)
    defer delete(str)
    state:=lua.newstate(lua_allocator, &_ctx)
    lua.L_openlibs(state)

    worldp:= (^^World)(lua.newuserdata(state, size_of(^World)))
    worldp^ = world

    lua.L_newmetatable(state, "WorldMeta")


    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        world := (cast(^^World)lua.touserdata(state, 1))^
        tag :=cast(u16) lua.L_checkinteger(state, 2)
        lua.newtable(state) 
        tablei:=1
        for i in 0..<len(world.sectors) {
            sector:=&world.sectors[i]
            if sector.tag == tag {
                get_sector(state, sector)
                lua.rawseti(state, -2, (lua.Integer)(tablei))
            }
        }
        return 1 
    }, "get_sectors")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        if lua.isfunction(state, 2) {
            if update_fn != nil {
                lua.L_unref(state, lua.REGISTRYINDEX, update_fn.?)
            }
            update_fn = lua.L_ref(state, lua.REGISTRYINDEX)
            log.info("added function")
        } else {
            log.error("expected function")
        }
        return 0 
    }, "set_update")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.setmetatable(state, -2)

    lua.setglobal(state, "world")

    lua.L_dofile(state, str)
    return state
}

update_script :: proc(state: ^lua.State, dt: f32) {
    val, c:=update_fn.?
    if c {
        lua.rawgeti(state, lua.REGISTRYINDEX, (lua.Integer)(val))
        lua.pushnumber(state, (lua.Number)(dt))
        lua.pcall(state, 1, 0, 0)
    }
}

close :: proc(state: ^lua.State) {
    if update_fn != nil {
        lua.L_unref(state, lua.REGISTRYINDEX, update_fn.?)
    }
    lua.close(state)
}
