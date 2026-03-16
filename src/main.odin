package main

import "core:math"
import "core:log"
import "core:strings"
import "core:c"
import "core:c/libc"
import "base:runtime"
import "core:os"

import rl "vendor:raylib"
import mu "vendor:microui"
import lua "vendor:lua/5.4"
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

controls :: proc(player: ^engine.Player, world: ^engine.World, state: ^lua.State) {
    move : engine.Vec2
    rot : f32
    if !WINDOW_FOCUS {
        if rl.IsKeyDown(.W) {
            move.y -= 1 
        }
        if rl.IsKeyDown(.S) {
            move.y += 1 
        }
        if rl.IsKeyDown(.A) {
            move.x -= 1 
        }
        if rl.IsKeyDown(.D) {
            move.x += 1 
        }

        if rl.IsKeyDown(.LEFT) {
            rot -= 1 
        }
        if rl.IsKeyDown(.RIGHT) {
            rot += 1 
        }
        if rl.IsKeyPressed(.E) {
            if player.decal != -1 && !EDITOR && player.decal < len(world.decals){
                engine.call_interaction(state, world.decals[player.decal].on_interact)
            }
        }
    }
    if rl.IsKeyPressed(.F3) {
        GOD=!GOD
    }
    if rl.IsKeyPressed(.F4) {
        DEBUG=!DEBUG
    }
    if rl.IsKeyPressed(.F2) {
        SHOWFPS=!SHOWFPS
    }
    if rl.IsKeyPressed(.F5) {
        EDITOR=!EDITOR
    }

    if rl.IsKeyDown(.LEFT_SHIFT) && !WINDOW_FOCUS {
        player.height = PLAYER_CROUCH
    } else {
        player.height = PLAYER_HEIGHT
    }

    if len(world.sectors) == 0 {
        return
    }
    wanted_y :=world.sectors[player.sector].floor
    if rl.IsKeyDown(.SPACE) && !WINDOW_FOCUS {
        if player.pos.y <= wanted_y {
            player.vel.y += JUMP_HEIGHT 
        }
    }

    dt := rl.GetFrameTime()
    player.rot += rot*dt*PLAYER_ROT_SPEED
    move = engine.norm(move);
    move = engine.rotate(move, player.rot)*PLAYER_SPEED;
    player.vel.x += move.x;
    player.vel.z += move.y;
    player.vel.y -= GRAVITY*dt;

    move_player(player, world, player.vel*engine.Vec3{1, GRAVITY, 1}*dt, state)
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

    if engine.mag(player.vel) > MAX_VEL {
        n := engine.norm(player.vel.xz)*MAX_VEL
        player.vel.x = n.x 
        player.vel.z = n.y 
    } 
    //TASK(20260220-082010-127-n6-265): handle gravity
    WINDOW_FOCUS = false
}

STEP_HEIGHT :: 1.5

get_shift :: proc(player, mov: engine.Vec2) -> engine.Vec2 {
    return engine.norm(mov-player)*PLAYER_RADIUS
}
//TASK(20260228-232552-080-n6-360): make collision detection less janky
move_player:: proc(player: ^engine.Player, world: ^engine.World, move: engine.Vec3, state: ^lua.State) {
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
    e:f32=0.005
    player_eye:=player.pos.y+player.height

    newx := engine.Vec2{player.pos.x + move.x, player.pos.z}
    shiftx:=get_shift(player.pos.xz, newx)
    collidex, infox := engine.check_collide(player.pos.xz, newx+shiftx, world)
    infox.point-=shiftx
    if collidex {
        engine.call_interaction(state, infox.interact)
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

    newz := engine.Vec2{player.pos.x, player.pos.z + move.z}
    shiftz:=get_shift(player.pos.xz, newz)
    collidez, infoz := engine.check_collide(player.pos.xz, newz+shiftz, world)
    infoz.point-=shiftz
    if collidez {
        engine.call_interaction(state, infoz.interact)
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


update :: proc(player: ^engine.Player, world: ^engine.World, state: ^lua.State) {
    controls(player, world, state) 
    if !EDITOR {
        engine.update_script(state, rl.GetFrameTime())
    }
}

draw_ui :: proc(world: ^engine.World, player: ^engine.Player, state: ^^lua.State) {
    ctx:=rlmu.begin_scope()
    windows.draw_console(ctx, &DEBUG, &WINDOW_FOCUS);
    draw_editor(ctx, &EDITOR, &WINDOW_FOCUS, world, player, state)
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

rl_to_log :: proc(level: rl.TraceLogLevel) -> (bool, log.Level) {
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
        context=runtime.default_context()
        context.logger = logger 
        exist, level := rl_to_log(level)
        if !exist {
            return
        }
        buf: [1024]u8
        libc.vsprintf(&buf[0], text, args)
        log.log(level, string(buf[:]))
    })
    rl.SetTraceLogLevel(rl.TraceLogLevel.WARNING)
    world: engine.World
    player: engine.Player
    state:^lua.State
    rl.InitWindow(WIDTH, HEIGHT, TITLE)
    if len(os.args) > 1 {
        engine.load_map_pack(&world, os.args[1], &player, &state, "map01")
    } else {
        engine.gen_default(10, 10)
    }

    defer if state != nil {engine.close(state, &world)}

    create_commands()

    player.height = PLAYER_HEIGHT
    defer rl.CloseWindow()
    defer engine.free_world(&world);

    ctx:=rlmu.init_scope()

    rl.SetExitKey(.KEY_NULL)

    for !rl.WindowShouldClose() {
        update(&player, &world, state)
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        if len(world.sectors) > 0 {
            engine.render_world(&world, &player)
        }
        if SHOWFPS {
            rl.DrawFPS(10, 10)
        }
        w:i32=20
        x:i32=WIDTH/2-w/2
        h:i32=2
        y:i32=HEIGHT/2-h/2

        w2:i32=h
        x2:i32=WIDTH/2-w2/2
        h2:i32=w
        y2:i32=HEIGHT/2-h2/2
        rl.DrawRectangle(x-2, y-2, w+4, h+4, rl.BLACK)
        rl.DrawRectangle(x2-2, y2-2, w2+4, h2+4, rl.BLACK)
        rl.DrawRectangle(x, y, w, h, rl.WHITE)
        rl.DrawRectangle(x2, y2, w2, h2, rl.WHITE)

        draw_ui(&world, &player, &state)

        rl.EndDrawing()
        imap, ok:=world.to_load.?
        if ok {
            engine.load_map_from_pack(&world, &player, &state, imap)
            delete(imap)
            world.to_load = nil
        }
    }
    engine.free_textures()
}

