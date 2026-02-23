package main

import "core:fmt"
import rl "vendor:raylib"
import "engine"
import "core:math"


WIDTH::1700
HEIGHT::1000
TITLE :: "DOOM"

PLAYER_SPEED :: 3
PLAYER_ROT_SPEED :: math.PI / 2
FRICTION :: 5
MAX_VEL :: 5
GRAVITY :: 6 
JUMP_HEIGHT :: 2.5 

PLAYER_HEIGHT::5


make_line :: proc(
    p1, p2: int,
    sf:int = -1,
    sb: int = -1,
    portal:bool = false,
    texture: engine.LineTexture = engine.LineTexture{},
)->engine.Line {
    return engine.Line {
        p1=p1,
        p2=p2,
        sf=sf,
        sb=sb,
        portal=portal,
        texture=texture,
    } 
}

make_line_texture_f :: proc(s:engine.WallTexture)->engine.LineTexture {
    return engine.LineTexture {
        front=s
    }
}
make_line_texture_b :: proc(s:engine.WallTexture)->engine.LineTexture {
    return engine.LineTexture {
        back=s
    }
}
make_line_texture_a :: proc(s:engine.WallTexture)->engine.LineTexture {
    return engine.LineTexture {
        back=s,
        front=s,
    }
}
make_line_texture_fb :: proc(f, b:engine.WallTexture)->engine.LineTexture {
    return engine.LineTexture {
        front=f,
        back=b,
    }
}

make_world :: proc(world: ^engine.World) {
    using engine
    append(&world.points, Vec2{-10, -5})
    append(&world.points, Vec2{0, -5})
    append(&world.points, Vec2{10, -5})

    append(&world.points, Vec2{-10, 5})
    append(&world.points, Vec2{0, 5})
    append(&world.points, Vec2{10, 5})

    s1:Sector
    s1.height=10
    s1.floor= 0
    s1.floor_text = EngineTexture{"flat1", 0}
    s1.ceil_text= EngineTexture{"ceil1", 0}

    s2:Sector
    s2.height=10 
    s2.floor= -1
    s2.floor_text = EngineTexture{"flat2", 0}
    s2.ceil_text= EngineTexture{"ceil2", 0}

    append(&world.sectors, s1)
    append(&world.sectors, s2)

    append(&world.lines, make_line(
            0,
            1,
            0,
            -1,
            false,
            make_line_texture_f(WallTexture{
                middle=EngineTexture{"wall", 0}
                })
    ))
    append(&world.lines, make_line(
            1,
            2,
            1,
            -1,
            false,
            make_line_texture_f(WallTexture{
                middle=EngineTexture{"wall", Vec2{0, 1}}
                })
    ))

    append(&world.lines, make_line(
            3,
            4,
            -1,
            0,
            false,
            make_line_texture_b(WallTexture{
                middle=EngineTexture{"wall", 0}
                })
    ))
    append(&world.lines, make_line(
            4,
            5,
            -1,
            1,
            false,
            make_line_texture_b(WallTexture{
                middle=EngineTexture{"wall", Vec2{0, 1}}
                })
    ))


    append(&world.lines, make_line(
            0,
            3,
            -1,
            0,
            false,
            make_line_texture_b(WallTexture{
                middle=EngineTexture{"wall", 0}
                })
    ))
    append(&world.lines, make_line(
            2,
            5,
            1,
            -1,
            false,
            make_line_texture_f(WallTexture{
                middle=EngineTexture{"wall", Vec2{0, 1}}
                })
    ))

    append(&world.lines, make_line(
            1,
            4,
            0,
            1,
            true,
            make_line_texture_a(WallTexture{
                top=EngineTexture{"wall", 0},
                bottom=EngineTexture{"wall", 0},
            })
    ))
}

controls :: proc(player: ^engine.Player) {
    using engine
    using rl
    move : Vec2
    rot : f32
    if IsKeyDown(KeyboardKey.W) {
        move.y -= 1 
    }
    if IsKeyDown(KeyboardKey.S) {
        move.y += 1 
    }
    if IsKeyDown(KeyboardKey.A) {
        move.x -= 1 
    }
    if IsKeyDown(KeyboardKey.D) {
        move.x += 1 
    }

    if IsKeyDown(KeyboardKey.LEFT) {
        rot -= 1 
    }
    if IsKeyDown(KeyboardKey.RIGHT) {
        rot += 1 
    }
    if IsKeyDown(KeyboardKey.LEFT_SHIFT) {
        player.height = PLAYER_HEIGHT / 1.5
    } else {
        player.height = PLAYER_HEIGHT
    }
    if IsKeyDown(KeyboardKey.SPACE) {
        if player.pos.y <= player.wanted_y {
            player.vel.y += JUMP_HEIGHT 
        }
    }

    dt := GetFrameTime()
    player.rot += rot*dt*PLAYER_ROT_SPEED
    move = norm(move);
    move = rotate(move, player.rot)*PLAYER_SPEED;
    player.vel.x += move.x;
    player.vel.z += move.y;
    player.vel.y -= GRAVITY*dt;

    player.pos += player.vel*Vec3{1, GRAVITY, 1}*dt
    player.vel.x -= player.vel.x * FRICTION * dt
    player.vel.z -= player.vel.z * FRICTION * dt

    if player.pos.y < player.wanted_y {
        player.pos.y = player.wanted_y
        player.vel.y = 0
    }

    if mag(player.vel) > MAX_VEL {
        n := norm(player.vel.xz)*MAX_VEL
        player.vel.x = n.x 
        player.vel.z = n.y 
    } 
    //TASK(20260220-082010-127-n6-265): handle gravity
}

update :: proc(player: ^engine.Player, world: ^engine.World) {
    controls(player) 
}

get_textures :: proc() {
    using engine
    gen_default(10, 10)
    set_texture("wall", "./assets/textures/startan2.png", 10, 10)
    set_texture("flat1", "./assets/flats/flat10.png", 10, 10)
    set_texture("flat2", "./assets/flats/flat1.png", 10, 10)
    set_texture("ceil1", "./assets/flats/flat5.png", 10, 10)
    set_texture("ceil2", "./assets/flats/ceil3_3.png", 10, 10)
}

main :: proc() {
    using rl
    using engine
    world: World
    make_world(&world)
    player: Player
    player.pos = Vec3{-5, 0, 0}
    player.rot = math.PI/2
    player.height = PLAYER_HEIGHT
    InitWindow(WIDTH, HEIGHT, TITLE)
    get_textures()
    SetExitKey(KeyboardKey.KEY_NULL)
    for !WindowShouldClose() {
        update(&player, &world)
        BeginDrawing()
        ClearBackground(BLACK)
        render_world(&world, &player)
        DrawFPS(10, 10)
        EndDrawing()
    }
    CloseWindow()

    free_world(&world);
}

