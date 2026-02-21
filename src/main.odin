package main

import "core:fmt"
import rl "vendor:raylib"
import "engine"
import "core:math"

WIDTH::1280
HEIGHT::720
TITLE :: "DOOM"

PLAYER_SPEED :: 3
PLAYER_ROT_SPEED :: math.PI / 2
FRICTION :: 5
MAX_VEL :: 5
GRAVITY :: 6 
JUMP_HEIGHT :: 2.5 

PLAYER_HEIGHT::5

make_world :: proc(world: ^engine.World) {
    fmt.println(WIDTH, HEIGHT)
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

    s2:Sector
    s2.height= 10
    s2.floor= -1

    append(&world.sectors, s1)
    append(&world.sectors, s2)

    append(&world.lines, Line{0, 1, false, 0, -1})
    append(&world.lines, Line{1, 2, false, 1, -1})

    append(&world.lines, Line{3, 4, false, -1, 0})
    append(&world.lines, Line{4, 5, false, -1, 1})


    append(&world.lines, Line{0, 3, false, -1, 0})
    append(&world.lines, Line{2, 5, false, 1, -1})

    append(&world.lines, Line{1, 4, true, 0, 1})
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
        if player.pos.y == player.wanted_y {
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
    SetExitKey(KeyboardKey.KEY_NULL)
    for !WindowShouldClose() {
        update(&player, &world)
        BeginDrawing()
        ClearBackground(BLACK)
        render_world(&world, &player)
        EndDrawing()
    }
    CloseWindow()
}

