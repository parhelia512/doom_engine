package engine
import rl "vendor:raylib"
import "core:fmt"
import "core:math"

//TASK(20260220-205008-328-n6-902): handle textures and flats

RAYLEN::1000

MAX_DEPTH:: 1000

RAYRES::4

FOV::math.PI/2

Info :: struct {
    dist: f32,
    height: f32,
    floor: f32,
    is_portal: bool,
    point: Vec2,
}

ray_collide :: proc(world: ^World, ray_start: Vec2, angle: f32) -> (bool, Info) {
    using rl
    info:=Info{
        dist=RAYLEN+1,
    }
    ray_end:=rotate_around(ray_start, ray_start+Vec2{0, -RAYLEN}, angle)
    for line in world.lines {
        p1:=world.points[line.p1]
        p2:=world.points[line.p2]
        sector_idx := (p2.x - p1.x)*(ray_start.y - p1.y) -
        (p2.y - p1.y)*(ray_start.x - p1.x) < 0? line.sb: line.sf 
        if sector_idx == -1 {
            continue
        }
        sector:=world.sectors[sector_idx]
        collision: Vec2
        collide:=CheckCollisionLines(p1, p2, ray_start, ray_end, &collision) 
        if collide {
            d:=dist(ray_start, collision)
            if d<info.dist {
                info = Info{
                    dist=d,
                    height=sector.height,
                    floor=sector.floor,
                    is_portal=line.portal,
                    point=collision,
                }
            }
        }
    }
    if info.dist == RAYLEN+1 {
        return false, info
    }
    return true, info
}

render_ray :: proc(world: ^World,
    player: ^Player,
    i: int,
    width: f32,
    angle: f32,
    screen_center_y: f32,
    projection_plane_dist: f32,
    ray_start:Vec2,
    max_depth: i32,
    add_dist: f32 =0
) -> (bool, Info) {
    if max_depth <= 0 {
        return false, Info{0, 0, 0, false, 0} 
    }
    using rl;
    x:= f32(i)*width
    collide, info:=ray_collide(world, ray_start, angle)
    if !collide {
        return collide, info
    }
    dist := (info.dist + add_dist) * math.cos_f32(angle - player.rot)
    player_eye := player.pos.y + player.height 

    ceiling_y := info.floor + info.height

    wall_top := screen_center_y - ((ceiling_y - player_eye) / dist) * projection_plane_dist
    wall_bottom := screen_center_y - ((info.floor - player_eye) / dist) * projection_plane_dist

    if info.is_portal {
        epsilon:f32=0.0001
        icollide, iinfo := render_ray(
            world, 
            player, 
            i, 
            width, 
            angle, 
            screen_center_y, 
            projection_plane_dist, 
            info.point+rotate(Vec2{0, -epsilon}, angle), 
            max_depth-1,
            info.dist + epsilon + add_dist
        )
        if !icollide {
            return collide, info
        }
        iceiling_y := iinfo.floor+iinfo.height
        if iceiling_y < ceiling_y {
            top := wall_top
            bottom:= screen_center_y - ((iceiling_y - player_eye) / dist) * projection_plane_dist
            DrawRectangle(
                i32(x),
                i32(top),
                i32(width),
                i32(bottom - top),
                WHITE,
            )
        }
        if iinfo.floor > info.floor {
            top:= screen_center_y - ((iinfo.floor - player_eye) / dist) * projection_plane_dist
            bottom:= wall_bottom
            DrawRectangle(
                i32(x),
                i32(top),
                i32(width),
                i32(bottom - top),
                WHITE,
            )
        }
        return collide, info
    }

    DrawRectangle(
        i32(x),
        i32(wall_top),
        i32(width),
        i32(wall_bottom - wall_top),
        WHITE,
    )
    return collide, info
}

render_world :: proc(world: ^World, player: ^Player) {
    using rl
    raynum:=math.floor_f32(f32(rl.GetScreenWidth())/RAYRES)
    delta_angle:=FOV/(raynum-1)
    width:=f32(rl.GetScreenWidth())/raynum
    projection_plane_dist := f32(rl.GetScreenWidth()/2) / math.tan_f32(FOV/2)
    screen_center_y := f32(rl.GetScreenHeight())/2
    for i := 0; f32(i) < raynum; i+=1 {
        angle := player.rot - FOV/2 + f32(i)*delta_angle
        collide, info := render_ray(world, player, i, width, angle, screen_center_y, projection_plane_dist, player.pos.xz, MAX_DEPTH)
        if collide {
            player.wanted_y = info.floor
        }
    }
}
