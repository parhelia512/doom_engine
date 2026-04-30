package engine

import "core:os"
import "core:log"
import "core:strings"
import "core:io"
import "core:encoding/cbor"
import "core:encoding/json"
import lua "vendor:lua/5.4"
import "core:math"
import rl "vendor:raylib"

import "core:path/filepath"

save_world::proc(world: ^World, file: string) {
    handle, ferr:=os.open(file, os.O_RDWR|os.O_CREATE|os.O_TRUNC, os.Permissions_All)
    defer os.close(handle)
	log.assertf(ferr == nil, "fopen error: %v", ferr)

    val, err := cbor.marshal(world^, cbor.ENCODE_FULLY_DETERMINISTIC)
	log.assertf(err == nil, "marshal error: %v", err)
    defer delete(val)
    os.write(handle, val)
}

load_world::proc(world:^World, file:string, player: ^Player) {
    world.to_load = nil;
    handle, ferr:=os.open(file, os.O_RDONLY)
    defer os.close(handle)
	log.assertf(ferr == nil, "fopen error: %v", ferr)
    stream:=os.to_stream(handle)
    reader:=io.to_reader(stream)
    free_world(world)
    err := cbor.unmarshal(reader, world)
    free_all(context.temp_allocator)
	log.assertf(err == nil, "marshal error: %v", err)
    player.pos.x = world.player_start.x
    player.pos.z = world.player_start.y
    player.rot = math.to_radians_f32(f32(world.player_start_rot))
    log.infof("loaded map %s", file)
}

load_map :: proc(world: ^World, path:string, player:^Player, state: ^^lua.State) {
    map_file,_:=filepath.join({path, "map.map"}, context.allocator) 
    defer delete(map_file)
    code_file,_:=filepath.join({path, "init.lua"}, context.allocator) 
    defer delete(code_file)

    if os.exists(map_file) {
        load_world(world, map_file, player)
    } else {
        log.error("file doesn't exist")
        return
    }
    if state^ != nil {
        close(state^, world)
        state^=nil
    }
    if os.exists(code_file) {
        state^=load_file(code_file, world, path)
        log.infof("loaded lua file %s", code_file)
    }
}

pack:Maybe(string)

TextureD :: struct {
    path: string,
    width, height: f32,
}

load_map_pack :: proc(world: ^World, path:string, player:^Player, state: ^^lua.State, default_map: string) {
    //handle textures
    free_textures()
    textures = make(map[string]TextureData)
    mp:map[string]TextureD 
    defer delete(mp)

    json_file, _:=filepath.join({path, "textures", "map.json"}, context.allocator)
    defer delete(json_file)

    handle, ferr:=os.open(json_file, os.O_RDONLY)
    log.assertf(ferr == nil, "fopen error: %v", ferr)
    defer os.close(handle)
    data,_ := os.read_entire_file(handle, context.allocator)
    defer delete(data)
    err := json.unmarshal(data, &mp)
    free_all(context.temp_allocator)
	log.assertf(err == nil, "marshal error: %v", err)
    gen_default(10, 10)
    for k, v in mp {
        defer delete(v.path)
        path,_:=filepath.join({path, "textures", v.path}, context.allocator)
        defer delete(path)
        set_texture(k, path, v.width, v.height)
    }
    pack=path

    //load map
    load_map_from_pack(world, player, state, default_map)
}


load_map_from_pack :: proc(world: ^World, player:^Player, state: ^^lua.State, imap: string) {
    path, ok := pack.? 
    log.assert(ok, "no map pack available")
    map_file,_:=filepath.join({path, "maps", imap}, context.allocator)
    defer delete(map_file)
    load_map(world, map_file, player, state)
}

