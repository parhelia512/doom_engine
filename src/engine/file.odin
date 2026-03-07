package engine

import "core:os"
import "core:log"
import "core:strings"
import "core:io"
import "core:encoding/cbor"
import "core:math"

save_world::proc(world: ^World, file: string) {
    handle, ferr:=os.open(file, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0o666)
    defer os.close(handle)
	log.assertf(ferr == nil, "fopen error: %v", ferr)

    val, err := cbor.marshal(world^, cbor.ENCODE_FULLY_DETERMINISTIC)
	log.assertf(err == nil, "marshal error: %v", err)
    defer delete(val)
    os.write(handle, val)
}

load_world::proc(world:^World, file:string, player: ^Player) {
    handle, ferr:=os.open(file, os.O_RDONLY)
    defer os.close(handle)
	log.assertf(ferr == nil, "fopen error: %v", ferr)
    stream:=os.stream_from_handle(handle)
    reader:=io.to_reader(stream)
    free_world(world)
    err := cbor.unmarshal(reader, world)
	log.assertf(err == nil, "marshal error: %v", err)
    player.pos.x = world.player_start.x
    player.pos.z = world.player_start.y
    player.rot = math.to_radians_f32(f32(world.player_start_rot))
}

