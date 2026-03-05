package engine

import "core:os"
import "core:log"
import "core:strings"
import "core:encoding/cbor"

save_world::proc(world: ^World, file: string) {
    handle, ferr:=os.open(file, os.O_RDWR)
	log.assertf(ferr == nil, "fopen error: %v", ferr)

    val, err:= cbor.marshal(world^, cbor.ENCODE_FULLY_DETERMINISTIC)
	log.assertf(err == nil, "marshal error: %v", err)
    defer delete(val)
    os.write(handle, val)
}

