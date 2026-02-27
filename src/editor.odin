package main
import mu "vendor:microui"
import rl "vendor:raylib"
import "rlmu"

import "core:log"
import "engine"

mode:=MODE.Point

editor_controls::proc(width, height: i32) {
    using rl
    if GetMouseY() < 0 || GetMouseX() < 0 || GetMouseX() > width || GetMouseY() > height {
        return
    }
    if IsKeyPressed(.ONE) {
        mode=MODE.Point
    }
    if IsKeyPressed(.TWO) {
        mode=MODE.Line
    }
}

MODE::enum {
    Point,
    Line,
}

translate :: proc(v: engine.Vec2, width, height: i32) -> engine.Vec2 {
    return v*5+engine.Vec2{
        f32(width/2),
        f32(height/2),
    }
}
untranslate :: proc(v: engine.Vec2, width, height: i32) -> engine.Vec2 {
    return (v-engine.Vec2{
        f32(width/2),
        f32(height/2),
    })/5
}

selectp:^engine.Vec2 = nil
offsetp: engine.Vec2


draw_editor_internals::proc(world: ^engine.World, width, height: i32) {
    using rl
    editor_controls(width, height)
    ClearBackground(BLACK)
    for line in world.lines {
        op1:=&world.points[line.p1]
        op2:=&world.points[line.p2]
        p1:=translate(op1^, width, height)
        p2:=translate(op2^, width, height)
        p1c:=WHITE
        p2c:=WHITE
        linec:=WHITE
        if mode == .Point{
            if selectp == nil {
                if CheckCollisionCircles(GetMousePosition(), 2, p1, 2) {
                    p1c=BLUE
                    if IsMouseButtonDown(.LEFT) {
                        selectp = op1 
                        offsetp=GetMousePosition()-p1
                    }
                } else if CheckCollisionCircles(GetMousePosition(), 2, p2, 2) {
                    p2c=BLUE
                    if IsMouseButtonDown(.LEFT) {
                        selectp = op2 
                        offsetp=GetMousePosition()-p2
                    }
                }
            } else {
                if selectp == op1 {
                    p1c=BLUE
                } else if selectp==op2 {
                    p2c=BLUE
                }
            } 
        } else if mode == .Line {
            if CheckCollisionCircleLine(GetMousePosition(), 2, p1, p2) {
                linec=BLUE
            }
        }
        DrawCircleV(p1, 2, p1c)
        DrawCircleV(p2, 2, p2c)
        DrawLineV(p1, p2, linec)
    }
    if mode == .Point {
        if selectp!=nil{
            if !IsMouseButtonDown(.LEFT) {
                selectp = nil
            } else {
                selectp^ = untranslate(GetMousePosition() - offsetp, width, height)
            }
        }

    }
}

editor_texture_width:i32 = 0
editor_texture_height:i32 = 0
editor_texture:rl.RenderTexture

draw_editor_window:: proc(ctx: ^mu.Context, render, has_focus: ^bool, world: ^engine.World) {
    window_width:=rl.GetRenderWidth()
    window_height:=rl.GetRenderHeight()
    if mu.window(ctx, "Editor", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}) {
        mu.layout_row(ctx, { -1 }, -25)

        mu.begin_panel(ctx, "Editor Panel")
        width:=mu.get_current_container(ctx).rect.w
        height:=mu.get_current_container(ctx).rect.h
        if editor_texture_width != width || editor_texture_height != height {
            if editor_texture_width != 0 {
                rl.UnloadRenderTexture(editor_texture)
            }
            editor_texture_height = height
            editor_texture_width = width
            editor_texture=rl.LoadRenderTexture(width, height)
        }
        text:=rlmu.draw_texture(ctx, &editor_texture.texture)
        x:=text.x
        y:=text.y
        mu.end_panel(ctx)

        rl.BeginTextureMode(editor_texture)
        rl.SetMouseOffset(-x, -y)
        draw_editor_internals(world, width, height)
        rl.SetMouseOffset(0, 0)
        rl.EndTextureMode()
        has_focus^ =ctx.hover_root!=nil||has_focus^
    } else {
        mu.get_container(ctx, "Editor").open=true
        render^ = false
    }
}

draw_editor:: proc(ctx: ^mu.Context, render, has_focus: ^bool, world: ^engine.World) {
    if !render^ {
        return
    }
    draw_editor_window(ctx, render, has_focus, world)
}
