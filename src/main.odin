package main
//TASK(20260223-135227-270-n6-248): make a map editor

import "core:math"
import "core:log"
import "core:strings"
import "core:c"
import "core:c/libc"
import "base:runtime"

import rl "vendor:raylib"
import mu "vendor:microui"
import "rlmu"

import "windows"
import "engine"

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
PLAYER_CROUCH :: PLAYER_HEIGHT / 1.5

PLAYER_RADIUS::1


GOD:=false
DEBUG:=false
SHOWFPS:=false
EDITOR:=false


WINDOW_FOCUS:=false

//TASK(20260224-130850-786-n6-230): give the player a width

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
    s2.height=4.5
    s2.floor= 0
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
                middle=EngineTexture{"wall1", 0}
                })
    ))
    append(&world.lines, make_line(
            1,
            2,
            1,
            -1,
            false,
            make_line_texture_f(WallTexture{
                middle=EngineTexture{"wall1", Vec2{0, 2}}
                })
    ))

    append(&world.lines, make_line(
            3,
            4,
            -1,
            0,
            false,
            make_line_texture_b(WallTexture{
                middle=EngineTexture{"wall1", 0}
                })
    ))
    append(&world.lines, make_line(
            4,
            5,
            -1,
            1,
            false,
            make_line_texture_b(WallTexture{
                middle=EngineTexture{"wall1", Vec2{0, 2}}
                })
    ))


    append(&world.lines, make_line(
            0,
            3,
            -1,
            0,
            false,
            make_line_texture_b(WallTexture{
                middle=EngineTexture{"wall1", 0}
                })
    ))
    append(&world.lines, make_line(
            2,
            5,
            1,
            -1,
            false,
            make_line_texture_f(WallTexture{
                middle=EngineTexture{"wall2", Vec2{0, 2}}
                })
    ))

    append(&world.lines, make_line(
            1,
            4,
            0,
            1,
            true,
            make_line_texture_a(WallTexture{
                top=EngineTexture{"wall1", 0},
                bottom=EngineTexture{"wall1", 0},
            })
    ))
}

controls :: proc(player: ^engine.Player, world: ^engine.World) {
    using engine
    using rl
    move : Vec2
    rot : f32
    if IsKeyDown(.W) {
        move.y -= 1 
    }
    if IsKeyDown(.S) {
        move.y += 1 
    }
    if IsKeyDown(.A) {
        move.x -= 1 
    }
    if IsKeyDown(.D) {
        move.x += 1 
    }

    if IsKeyDown(.LEFT) {
        rot -= 1 
    }
    if IsKeyDown(.RIGHT) {
        rot += 1 
    }

    if IsKeyPressed(.F3) {
        GOD=!GOD
    }
    if IsKeyPressed(.F4) {
        DEBUG=!DEBUG
    }
    if(IsKeyPressed(.F2)) {
        SHOWFPS=!SHOWFPS
    }
    if(IsKeyPressed(.F5)) {
        EDITOR=!EDITOR
    }
    if WINDOW_FOCUS {
        WINDOW_FOCUS=false
        return
    }

    if IsKeyDown(.LEFT_SHIFT) {
        player.height = PLAYER_CROUCH
    } else {
        player.height = PLAYER_HEIGHT
    }

    wanted_y :=world.sectors[player.sector].floor
    if IsKeyDown(.SPACE) {
        if player.pos.y <= wanted_y {
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

    move_player(player, world, player.vel*Vec3{1, GRAVITY, 1}*dt)
    player.vel.x -= player.vel.x * FRICTION * dt
    player.vel.z -= player.vel.z * FRICTION * dt

    ceil_y := wanted_y+world.sectors[player.sector].height
    player_eye := player.pos.y + player.height

    //TASK(20260225-072207-926-n6-028): make width effect detection here
    if ceil_y-player_eye < 1 && !GOD {
        player.pos.y = ceil_y-player.height-1
        player.vel.y = 0
    }
    if player.pos.y < wanted_y {
        player.pos.y = wanted_y
        player.vel.y = 0
    }
    player_eye = player.pos.y + player.height
    if ceil_y-player_eye < 1 && !GOD {
        player.height = PLAYER_CROUCH
    }

    if mag(player.vel) > MAX_VEL {
        n := norm(player.vel.xz)*MAX_VEL
        player.vel.x = n.x 
        player.vel.z = n.y 
    } 
    //TASK(20260220-082010-127-n6-265): handle gravity
}

STEP_HEIGHT :: 1.5

get_shift :: proc(player, mov: engine.Vec2) -> engine.Vec2 {
    using engine
    return norm(mov-player)*PLAYER_RADIUS
}

//TASK(20260226-082305-756-n6-666): fix the bug where when the wall isn't axis aligned collisions break
move_player :: proc(player: ^engine.Player, world: ^engine.World, move: engine.Vec3) {
    if GOD {
        player.pos += move
        return
    }
    player.pos.y += move.y
    move:=move
    if math.abs(move.z) < 1e-6 {
        move.z = 0
    }
    if math.abs(move.x) < 1e-6 {
        move.x = 0
    }
    using engine 
    using rl
    e:f32=0.005
    player_eye:=player.pos.y+player.height

    newx := Vec2{player.pos.x + move.x, player.pos.z}
    shiftx:=get_shift(player.pos.xz, newx)
    collidex, infox := check_collide(player.pos.xz+shiftx, newx+shiftx, world)
    infox.point-=shiftx
    if collidex {
        if infox.is_portal {
            if infox.floor-player.pos.y >= STEP_HEIGHT+0.1 || infox.ceil-player_eye < 1{
                epsilon := math.sign_f32(infox.point.x-player.pos.x)*e
                player.pos.x = infox.point.x-epsilon
                player.vel.x = 0
            } else {
                player.pos.x = newx.x
            }
        } else {
            epsilon := math.sign_f32(infox.point.x-player.pos.x)*e
            player.pos.x = infox.point.x-epsilon
            player.vel.x = 0
        }
    } else {
        player.pos.x = newx.x
    }

    newz := Vec2{player.pos.x, player.pos.z + move.z}
    shiftz:=get_shift(player.pos.xz, newz)
    collidez, infoz := check_collide(player.pos.xz+shiftz, newz+shiftz, world)
    infoz.point-=shiftz
    if collidez {
        if infoz.is_portal {
            if infoz.floor-player.pos.y >= STEP_HEIGHT +0.1 || infoz.ceil-player_eye < 1{
                epsilon := math.sign_f32(infoz.point.y-player.pos.z)*e
                player.pos.z = infoz.point.y-epsilon
                player.vel.z = 0
            }else {
                player.pos.z = newz.y
            }
        } else {
            epsilon := math.sign_f32(infoz.point.y-player.pos.z)*e
            player.pos.z = infoz.point.y-epsilon
            player.vel.z = 0
        }
    } else {
        player.pos.z = newz.y
    }
}


update :: proc(player: ^engine.Player, world: ^engine.World) {
    controls(player, world) 
}

get_textures :: proc() {
    using engine
    gen_default(10, 10)
    set_texture("wall1", "./assets/textures/startan2.png", 10, 10)
    set_texture("wall2", "./assets/textures/startan3.png", 10, 10)
    set_texture("flat1", "./assets/flats/flat10.png", 10, 10)
    set_texture("flat2", "./assets/flats/flat1.png", 10, 10)
    set_texture("ceil1", "./assets/flats/flat5.png", 10, 10)
    set_texture("ceil2", "./assets/flats/ceil3_3.png", 10, 10)
}

draw_ui :: proc(world: ^engine.World) {
    ctx:=rlmu.begin_scope()
    windows.draw_console(ctx, &DEBUG, &WINDOW_FOCUS);
    draw_editor(ctx, &EDITOR, &WINDOW_FOCUS, world)
}

create_commands :: proc() {
    windows.add_command("toggle", proc(args: ..string) {
        varname:=args[0]
        switch varname {
        case "GOD":
            GOD = !GOD
        case "DEBUG":
            DEBUG=!DEBUG
        case "SHOWFPS":
            SHOWFPS=!SHOWFPS
        case "EDITOR":
            EDITOR=!EDITOR
        case "-l":
            windows.log_raw("AVAILABLE VARIABLES\n- GOD\n- DEBUG\n- SHOWFPS\n- EDITOR")
            return
        case:
            log.errorf("variable '%s' doesn't exist, run 'toggle -l' to get a list of all variables", varname)
            return
        }
        windows.log_rawf("toggled '%s'", varname)
    }, 1, 1)
}

rl_to_log :: proc"contextless"(level: rl.TraceLogLevel) -> (bool, log.Level) {
    #partial switch level {
    case rl.TraceLogLevel.INFO: return true, log.Level.Info
    case rl.TraceLogLevel.DEBUG: return true, log.Level.Debug
    case rl.TraceLogLevel.WARNING: return true, log.Level.Warning
    case rl.TraceLogLevel.ERROR: return true, log.Level.Error
    case rl.TraceLogLevel.FATAL: return true, log.Level.Fatal
    }
    return false, nil
}

logger:log.Logger

main :: proc() {
    logger = windows.logger(opts={.Level, .Terminal_Color})
    context.logger = logger
    rl.SetTraceLogCallback(proc"c"(level: rl.TraceLogLevel, text: cstring, args: ^c.va_list) {
        exist, level := rl_to_log(level)
        if !exist {
            return
        }
        context=runtime.default_context()
        context.logger = logger 
        buf: [1024]u8
        libc.vsprintf(&buf[0], text, args)
        log.log(level, string(buf[:]))
    })
    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    using rl
    using engine
    world: World

    create_commands()

    make_world(&world)
    player: Player
    player.pos = Vec3{-5, 0, 0}
    player.rot = math.PI/2
    player.height = PLAYER_HEIGHT
    InitWindow(WIDTH, HEIGHT, TITLE)
    defer CloseWindow()
    defer free_world(&world);

    ctx:=rlmu.init_scope()

    get_textures()
    SetExitKey(.KEY_NULL)

    for !WindowShouldClose() {
        update(&player, &world)
        BeginDrawing()
        ClearBackground(BLACK)
        render_world(&world, &player)
        if SHOWFPS {
            DrawFPS(10, 10)
        }

        draw_ui(&world)

        EndDrawing()
    }
}

