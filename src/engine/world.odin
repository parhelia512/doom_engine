package engine;

import rl "vendor:raylib"
import "core:math"

WallTexture :: struct {
    top,
    middle,
    bottom: EngineTexture
}
LineTexture :: struct {
    front: WallTexture,
    back: WallTexture,
}
EngineTexture :: struct {
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
    floor_text: EngineTexture,
    ceil_text: EngineTexture,
}

World :: struct {
    lines: [dynamic]Line,
    points: [dynamic]Vec2,
    sectors: [dynamic]Sector,
}

Player :: struct {
    pos, vel: Vec3,
    rot: f32,
    sector: int,
    height: f32,
}

free_world :: proc(world: ^World) {
    clear(&world.sectors)
    clear(&world.lines)
    clear(&world.points)
}

CollisionInfo :: struct {
    p1,
    p2,
    point: Vec2,
    is_portal: bool,
    ceil,
    floor: f32,
}

check_collide :: proc(ray_start, ray_end: Vec2, world: ^World) -> (bool, CollisionInfo) {
    using rl
    collide_:=false
    dist_:f32=math.inf_f32(1)
    info:=CollisionInfo{}
    for line in world.lines {
        p1:=world.points[line.p1]
        p2:=world.points[line.p2]
        isback := (p2.x - p1.x)*(ray_start.y - p1.y) -
        (p2.y - p1.y)*(ray_start.x - p1.x) < 0
        sector_idx:=isback? line.sb: line.sf
        if sector_idx == -1 {
            continue
        }
        collision: Vec2
        collide:=CheckCollisionLines(p1, p2, ray_start, ray_end, &collision) 
        if collide {
            d:=dist(ray_start, collision)
            if d<dist_ {
                dist_=d
                collide_ = true
                info = CollisionInfo {
                    p1=p1,
                    p2=p2,
                    point=collision,
                    is_portal=line.portal
                } 
                if line.portal {
                    back_idx := isback? line.sf: line.sb 
                    if back_idx == -1 {
                        continue
                    }
                    sectorb:=world.sectors[back_idx]
                    info.floor = sectorb.floor
                    info.ceil = sectorb.height+sectorb.floor
                }
            }
        }
    }
    return collide_, info
}
