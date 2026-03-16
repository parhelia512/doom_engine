package engine
import lua "vendor:lua/5.4"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:log"
import "core:os"
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

update_fn:[dynamic]c.int=nil

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
        if sector == nil {
            log.error("expected Sector as first arg")
            return 0
        }
        lua.pushnumber(state, lua.Number(sector.tint[0]))
        return 1 
    }, "get_tint_h")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil {
            log.error("expected Sector as first arg")
            return 0
        }
        lua.pushnumber(state, lua.Number(sector.tint[1]))
        return 1 
    }, "get_tint_s")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil {
            log.error("expected Sector as first arg")
            return 0
        }
        lua.pushnumber(state, lua.Number(sector.tint[2]))
        return 1 
    }, "get_tint_v")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil{
            log.error("expected Sector as first arg")
            return 0
        }
        h:=cast(f32) lua.L_checknumber(state, 2)
        sector.tint[0]= h
        return 0 
    }, "set_tint_h")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil{
            log.error("expected Sector as first arg")
            return 0
        }
        s:=cast(f32) lua.L_checknumber(state, 2)
        sector.tint[1]= s
        return 0 
    }, "set_tint_s")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        sector :=get_check(state, Sector, "SectorMeta") 
        if sector == nil{
            log.error("expected Sector as first arg")
            return 0
        }
        v :=cast(f32) lua.L_checknumber(state, 2)
        sector.tint[2] =v 
        return 0 
    }, "set_tint_v")
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
get_check_v::proc(state: ^lua.State, $T:typeid, userdata:cstring)->^T {
    if !lua.isuserdata(state, 1) {
        return nil
    }
    if lua.getmetatable(state, 1) != 0 {
        lua.getfield(state, -1, "__name")
        name := lua.tostring(state, -1) 
        lua.pop(state, 2)
        if name == userdata  {
            return (cast(^T)lua.touserdata(state, 1))
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
        ctexture := lua.L_checkstring(state, 2)
        delete(decal.texture)
        texture:= strings.clone_from_cstring(ctexture) 
        decal.texture = texture
        return 1
    }, "set_texture")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.pushstring(state, "DecalMeta")
    lua.setfield(state, -2, "__name")    
    lua.setmetatable(state, -2)
}

get_line::proc(state: ^lua.State, line: ^Line) {
    linep:= (^^Line)(lua.newuserdata(state, size_of(^Line)))
    linep^ = line

    lua.L_newmetatable(state, "LineMeta")

    add_function(state, proc"c"(state: ^lua.State)->c.int{
        context=runtime.default_context()
        context.logger = logger 
        line:=get_check(state, Line, "LineMeta") 
        if line == nil{
            log.error("expected line as first arg")
            return 0
        }
        if lua.isfunction(state, 2) {
            ref, ok := line.on_collide.?
            if ok {
                lua.L_unref(state, lua.REGISTRYINDEX, ref)
            }
            line.on_collide= lua.L_ref(state, lua.REGISTRYINDEX)
        } else {
            log.error("expected function")
        }
        return 0 
    }, "on_collide")

    lua.pushvalue(state, -1)
    lua.setfield(state, -2, "__index")
    lua.pushstring(state, "LineMeta")
    lua.setfield(state, -2, "__name")    
    lua.setmetatable(state, -2)
}
WorldData::struct {
    world: ^World,
    player: ^Player,
}

load_file :: proc(file: string, world: ^World, dir: string, allocator:=context.allocator, loggerf:=context.logger) -> ^lua.State {
    update_fn=make([dynamic]c.int)
    logger = loggerf
    _ctx = context
    str:=strings.clone_to_cstring(file, allocator)
    defer delete(str)
    state:=lua.newstate(lua_allocator, &_ctx)
    lua.L_openlibs(state)

    path, error :=os.get_executable_directory(context.allocator)
    defer delete(path)
    npath:=filepath.dir(path)
    defer delete(npath)
    nnpath, _:=filepath.join({npath, "libs"}, context.allocator) 
    defer delete(nnpath)
    add_lua_path(state, nnpath)
    add_lua_path(state, dir)
    if pack != nil {
        path, _:=filepath.join({pack.?, "libs"}, context.allocator) 
        defer delete(path)
        add_lua_path(state, path)
    }

    worldp:^WorldData = (^WorldData)(lua.newuserdata(state, size_of(WorldData)))
    worldp.world = world

    lua.L_newmetatable(state, "WorldMeta")


    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        worldd := get_check_v(state, WorldData, "WorldMeta") 
        if worldd== nil{
            log.error("expected World as first arg")
            return 0
        }
        world:=worldd.world
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
        worldd := get_check_v(state, WorldData, "WorldMeta") 
        if worldd== nil{
            log.error("expected World as first arg")
            return 0
        }
        world:=worldd.world
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
        worldd := get_check_v(state, WorldData, "WorldMeta") 
        if worldd== nil{
            log.error("expected World as first arg")
            return 0
        }
        world:=worldd.world
        tag :=cast(u16) lua.L_checkinteger(state, 2)
        lua.newtable(state) 
        tablei:=1
        for i in 0..<len(world.lines) {
            line:=&world.lines[i]
            if line.tag == tag {
                get_line(state, line)
                lua.rawseti(state, -2, (lua.Integer)(tablei))
                tablei+=1
            }
        }
        return 1 
    }, "get_lines")
    add_function(state, proc"c"(state: ^lua.State) -> c.int{
        context=runtime.default_context()
        context.logger = logger 
        worldd := get_check_v(state, WorldData, "WorldMeta") 
        if worldd== nil{
            log.error("expected World as first arg")
            return 0
        }
        world:=worldd.world
        if lua.isfunction(state, 2) {
            append(&update_fn, lua.L_ref(state, lua.REGISTRYINDEX))
        } else {
            log.error("expected function")
        }
        return 0 
    }, "add_task")
    add_function(state, proc"c"(state: ^lua.State) -> c.int {
        context=runtime.default_context()
        context.logger = logger 
        worldd := get_check_v(state, WorldData, "WorldMeta") 
        if worldd== nil{
            log.error("expected World as first arg")
            return 0
        }
        world:=worldd.world
        player:=worldd.player
        imap_:=lua.L_checkstring(state, 2)
        imap:=strings.clone_from_cstring(imap_)
        world.to_load = imap
        return 0 
    }, "load_map")

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

call_interaction :: proc(state: ^lua.State, int: Maybe(c.int)) {
    fn, ok := int.?
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
        freeref(state, update_fn[i-del])
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
    p1, _:=filepath.join({dir, "?.lua"}, context.allocator)
    defer delete(p1)
    p2, _:=filepath.join({dir, "?", "init.lua"}, context.allocator)
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
    delete(update_fn)
    lua.close(state)
}

freeref_def :: proc(state: ^lua.State, ref: c.int) {
    lua.L_unref(state, lua.REGISTRYINDEX, ref)
}

freeref_maybe:: proc(state: ^lua.State, ref: Maybe(c.int)) {
    ref, ok := ref.?
    if !ok {
        return
    }
    lua.L_unref(state, lua.REGISTRYINDEX, ref)
}

freeref::proc{freeref_def, freeref_maybe}

