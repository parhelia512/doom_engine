package engine;

import "core:mem"
import rl "vendor:raylib"

WallTextures :: struct {
    top,
    middle,
    bottom: WallTexture
}
LineTexture :: struct {
    front: WallTextures,
    back: WallTextures,
}
WallTexture :: struct {
    texture: string,
    offset: Vec2,
}

Line :: struct {
    p1, p2: int,
    portal: bool,
    sf, sb: int,
    texture: LineTexture,
}

Sector :: struct {
    floor: f32,
    height: f32,
}

World :: struct {
    lines: [dynamic]Line,
    points: [dynamic]Vec2,
    sectors: [dynamic]Sector,
}

Player :: struct {
    pos, vel: Vec3,
    rot: f32,
    wanted_y: f32,
    height: f32,
}

free_world :: proc(world: ^World) {
    clear(&world.sectors)
    clear(&world.lines)
    clear(&world.points)
}

