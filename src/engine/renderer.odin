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
    line_text: WallTexture,
    bottom_text: WallTexture,
    top_text: WallTexture,
    p1,
    p2: Vec2,
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
        isback := (p2.x - p1.x)*(ray_start.y - p1.y) -
        (p2.y - p1.y)*(ray_start.x - p1.x) < 0
        sector_idx := isback? line.sb: line.sf 
        if sector_idx == -1 {
            continue
        }
        sector:=world.sectors[sector_idx]
        collision: Vec2
        collide:=CheckCollisionLines(p1, p2, ray_start, ray_end, &collision) 
        if collide {
            d:=dist(ray_start, collision)
            if d<info.dist {
                t:=isback?line.texture.back:line.texture.front
                info = Info{
                    dist=d,
                    height=sector.height,
                    floor=sector.floor,
                    is_portal=line.portal,
                    point=collision,
                    line_text=t.middle,
                    bottom_text=t.bottom,
                    top_text=t.top,
                    p1=isback?p2:p1,
                    p2=isback?p1:p2,
                }
            }
        }
    }
    if info.dist == RAYLEN+1 {
        return false, info
    }
    return true, info
}

draw_rect :: proc(
    x, y, width, height: i32,
    wall_texture: WallTexture,
    wall_dist,
    wall_height: f32,
    p1, p2, hit_point: Vec2,
) {
    using rl;

    if wall_texture.texture == "" {
        return
    }
    tex_data := get_texture(wall_texture.texture)
    tex := tex_data.texture

    wall_vec := p2 - p1
    wall_len_sq := dot(wall_vec, wall_vec)

    hit_vec := hit_point - p1

    u := dot(hit_vec, wall_vec) / wall_len_sq

    u += wall_texture.offset.x / tex_data.width

    u = u - math.floor(u)

    tex_x := i32(u * f32(tex.width))

    v := wall_texture.offset.y / tex_data.height
    v = v - math.floor(v)
    tex_y := v * f32(tex.height)
    scale := wall_height / tex_data.height
    source_height := f32(tex.height) * scale

    source := rl.Rectangle{
        x = f32(tex_x),
        y = tex_y,
        width = 1,
        height = source_height 
    }

    dest := rl.Rectangle{
        x = f32(x),
        y = f32(y),
        width = f32(width),
        height = f32(height)
    }

    rl.DrawTexturePro(
        tex,
        source,
        dest,
        rl.Vector2{0, 0},
        0,
        rl.WHITE
    )
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
        return false, Info{0, 0, 0, false, 0, WallTexture{}, WallTexture{}, WallTexture{}, 0, 0} 
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

    height:=info.height

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
            draw_rect(
                i32(x),
                i32(top),
                i32(width),
                i32(bottom - top),
                info.top_text,
                dist,
                ceiling_y-iceiling_y,
                info.p1,
                info.p2,
                info.point,
            )
            height -= ceiling_y-iceiling_y
            wall_top=bottom
        }
        if iinfo.floor > info.floor {
            top:= screen_center_y - ((iinfo.floor - player_eye) / dist) * projection_plane_dist
            bottom:= wall_bottom
            draw_rect(
                i32(x),
                i32(top),
                i32(width),
                i32(bottom - top),
                info.bottom_text,
                dist,
                iinfo.floor-info.floor,
                info.p1,
                info.p2,
                info.point,
            )
            wall_bottom=top
            height-=iinfo.floor-info.floor
        }
    }

    draw_rect(
        i32(x),
        i32(wall_top),
        i32(width),
        i32(wall_bottom - wall_top),
        info.line_text,
        dist,
        height,
        info.p1,
        info.p2,
        info.point,
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
