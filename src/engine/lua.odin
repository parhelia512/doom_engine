package engine
import lua "vendor:lua/5.4"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:log"
import "core:os/os2"
import "core:path/filepath"

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

update_fn:[dynamic]c.int

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
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil {
            log.error("expected Sector as first arg")
            return 0
        }
        lua.pushnumber(state, lua.Number(sector.height))
        return 1 
    }, "get_height")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil{
            log.error("expected Sector as first arg")
            return 0
        }
        height :=cast(f32) lua.L_checknumber(state, 2)
        sector.height = height
        return 0 
    }, "set_height")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil{
            log.error("expected Sector as first arg")
            return 0
        }
        lua.pushnumber(state, lua.Number(sector.floor))
        return 1 
    }, "get_floor")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil{
            log.error("expected Sector as first arg")
            return 0
        }
        floor :=cast(f32) lua.L_checknumber(state, 2)
        sector.floor = floor
        return 0 
    }, "set_floor")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.pushstring(state, "SectorMeta")
    lua.setfield(state, -2, "__name")    
    lua.setmetatable(state, -2)
}

get_check::proc(state: ^lua.State, $T:typeid, userdata:cstring)->^T {
    if !lua.isuserdata(state, 1) {
        return nil
    }
    if lua.getmetatable(state, 1) != 0 {
        lua.getfield(state, -1, "__name")
        name := lua.tostring(state, -1) 
        lua.pop(state, 2)
        if name == userdata  {
            return (cast(^^T)lua.touserdata(state, 1))^
        }
    }
    return nil
}

get_decal::proc(state: ^lua.State, decal: ^Decal) {
    decalp:= (^^Decal)(lua.newuserdata(state, size_of(^Decal)))
    decalp^ = decal 

    lua.L_newmetatable(state, "DecalMeta")

    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        decal:=get_check(state, Decal, "DecalMeta") 
        if decal== nil{
            log.error("expected Decal as first arg")
            return 0
        }
        if lua.isfunction(state, 2) {
            ref, ok := decal.on_interact.?
            if ok {
                lua.L_unref(state, lua.REGISTRYINDEX, ref)
            }
            decal.on_interact = lua.L_ref(state, lua.REGISTRYINDEX)
        } else {
            log.error("expected function")
        }
        return 0 
    }, "set_interact")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        decal:=get_check(state, Decal, "DecalMeta") 
        if decal== nil{
            log.error("expected Decal as first arg")
            return 0
        }
        str:=strings.clone_to_cstring(decal.texture)
        defer delete(str)
        lua.pushstring(state, str)
        return 1
    }, "get_texture")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        decal:=get_check(state, Decal, "DecalMeta") 
        if decal== nil{
            log.error("expected Decal as first arg")
            return 0
        }
        texture :=cast(string) lua.L_checkstring(state, 2)
        decal.texture = texture
        return 1
    }, "set_texture")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.pushstring(state, "DecalMeta")
    lua.setfield(state, -2, "__name")    
    lua.setmetatable(state, -2)
}

load_file :: proc(file: string, world: ^World, dir: string, allocator:=context.allocator, loggerf:=context.logger) -> ^lua.State {
    logger = loggerf
    _ctx = context
    str:=strings.clone_to_cstring(file, allocator)
    defer delete(str)
    state:=lua.newstate(lua_allocator, &_ctx)
    lua.L_openlibs(state)

    path, error :=os2.get_executable_directory(context.allocator)
    defer delete(path)
    npath:=filepath.dir(path)
    defer delete(npath)
    nnpath:=filepath.join({npath, "libs"}) 
    defer delete(nnpath)
    add_lua_path(state, nnpath)
    add_lua_path(state, dir)
    if pack != nil {
        path:=filepath.join({pack.?, "libs"}) 
        defer delete(npath)
        add_lua_path(state, path)
    }

    worldp:= (^^World)(lua.newuserdata(state, size_of(^World)))
    worldp^ = world

    lua.L_newmetatable(state, "WorldMeta")


    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        world:=get_check(state, World, "WorldMeta") 
        if world== nil{
            log.error("expected World as first arg")
            return 0
        }
        tag :=cast(u16) lua.L_checkinteger(state, 2)
        lua.newtable(state) 
        tablei:=1
        for i in 0..<len(world.sectors) {
            sector:=&world.sectors[i]
            if sector.tag == tag {
                get_sector(state, sector)
                lua.rawseti(state, -2, (lua.Integer)(tablei))
                tablei+=1
            }
        }
        return 1 
    }, "get_sectors")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        world:=get_check(state, World, "WorldMeta") 
        if world== nil{
            log.error("expected World as first arg")
            return 0
        }
        tag :=cast(u16) lua.L_checkinteger(state, 2)
        lua.newtable(state) 
        tablei:=1
        for i in 0..<len(world.decals) {
            decal:=&world.decals[i]
            if decal.tag == tag {
                get_decal(state, decal)
                lua.rawseti(state, -2, (lua.Integer)(tablei))
                tablei+=1
            }
        }
        return 1 
    }, "get_decals")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        world:=get_check(state, World, "WorldMeta") 
        if world== nil{
            log.error("expected World as first arg")
            return 0
        }
        if lua.isfunction(state, 2) {
            append(&update_fn, lua.L_ref(state, lua.REGISTRYINDEX))
        } else {
            log.error("expected function")
        }
        return 0 
    }, "add_task")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.pushstring(state, "WorldMeta")
    lua.setfield(state, -2, "__name")    
    lua.setmetatable(state, -2)

    lua.setglobal(state, "world")

    if lua.L_dofile(state, str) != 0 {
        log.error(lua.tostring(state, -1))
        lua.pop(state, -1)
    }
    return state
}

call_decal :: proc(state: ^lua.State, world: ^World, decal: int) {
    if decal < 0 || decal >= len(world.decals) {
        return
    }
    fn, ok:=world.decals[decal].on_interact.?
    if !ok {
        return
    }
    lua.rawgeti(state, lua.REGISTRYINDEX, (lua.Integer)(fn))
    if lua.pcall(state, 0, 1, 0) != 0 {
        log.error(lua.tostring(state, -1))
        lua.pop(state, -1)
    } else {
        lua.pop(state, -1)
    }
}

update_script :: proc(state: ^lua.State, dt: f32) {
    remove:=make([dynamic]int)
    defer delete(remove)
    for idx in 0..<len(update_fn) {
        i:=update_fn[idx]
        lua.rawgeti(state, lua.REGISTRYINDEX, (lua.Integer)(i))
        lua.pushnumber(state, (lua.Number)(dt))
        if lua.pcall(state, 1, 1, 0) != 0 {
            log.error(lua.tostring(state, -1))
            lua.pop(state, -1)
            append(&remove, idx)
            continue
        }
        if lua.isboolean(state, -1) {
            b := lua.toboolean(state, -1)
            lua.pop(state, -1)
            if b {
                append(&remove, idx)
            }
        }
    }
    del := 0
    for i in remove {
        ordered_remove(&update_fn, i-del)
        del+=1
    }
}

add_lua_path :: proc(state: ^lua.State, dir: string) {
    lua.getglobal(state, "package")
    lua.getfield(state, -1, "path")
    old_path := lua.tostring(state, -1)
    lua.pop(state, 1)

    opath := strings.clone_from_cstring(old_path)
    defer delete(opath)
    p1:=filepath.join({dir, "?.lua"})
    defer delete(p1)
    p2:=filepath.join({dir, "?", "init.lua"})
    defer delete(p2)
    new_path := strings.join({opath, ";", p2, ";", p1}, "")
    defer delete(new_path)
    npath := strings.clone_to_cstring(new_path)
    defer delete(npath)
    lua.pushstring(state, npath)
    lua.setfield(state, -2, "path")
    lua.pop(state, 1)
}

close :: proc(state: ^lua.State, world: ^World) {
    for i in update_fn {
        lua.L_unref(state, lua.REGISTRYINDEX, i)
    }
    for i in 0..<len(world.decals) {
        ref, ok := world.decals[i].on_interact.?
        world.decals[i].on_interact = nil
        if ok {
            lua.L_unref(state, lua.REGISTRYINDEX, ref)
        }
    }
    delete(update_fn)
    lua.close(state)
}

freeref_def :: proc(state: ^lua.State, ref: c.int) {
    lua.L_unref(state, lua.REGISTRYINDEX, ref)
}

freeref_maybe:: proc(state: ^lua.State, ref: Maybe(c.int)) {
    if ref == nil {
        return
    }
    lua.L_unref(state, lua.REGISTRYINDEX, ref.?)
}

freeref::proc{freeref_def, freeref_maybe}

