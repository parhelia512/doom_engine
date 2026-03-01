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

//TASK(20260301-001613-540-n6-328): add sector mode
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


hoverp: ^engine.Vec2 

selectp: ^engine.Vec2 

dragp: ^engine.Vec2 
offsetp: engine.Vec2


HOVER_COLOR :: rl.BLUE
SELECTED_COLOR :: rl.RED

handle_collide_point::proc(p1, p2: engine.Vec2, cp1, cp2, cline: ^rl.Color, op1, op2: ^engine.Vec2) {
    using rl
    if hoverp == nil {
        if CheckCollisionCircles(p1, 2, GetMousePosition(), 2) {
            cp1^ = HOVER_COLOR
            hoverp = op1 
            if IsMouseButtonPressed(.RIGHT) {
                selectp = op1
            }
            if IsMouseButtonDown(.LEFT) {
                selectp = op1
                dragp = op1
                offsetp = GetMousePosition() - p1
            }
        } else if CheckCollisionCircles(p2, 2, GetMousePosition(), 2) {
            cp2^ = HOVER_COLOR
            hoverp = op2 
            if IsMouseButtonPressed(.RIGHT) {
                selectp = op2
            }
            if IsMouseButtonDown(.LEFT) {
                selectp = op2
                dragp = op2
                offsetp = GetMousePosition() - p2
            }
        }
    } else {
        if hoverp == op1 {
            cp1^ = HOVER_COLOR
        } else if hoverp == op2 {
            cp2^ = HOVER_COLOR
        }
    }
    if selectp == op1 {
        cp1^ = SELECTED_COLOR
    } else if selectp == op2 {
        cp2^ = SELECTED_COLOR
    }
}

hoverl := false

selectl: [2]^engine.Vec2 

dragl: [2]^engine.Vec2 
offsetl: [2]engine.Vec2

handle_collide_line::proc(p1, p2: engine.Vec2, cp1, cp2, cline: ^rl.Color, op1, op2: ^engine.Vec2) {
    using rl
    if !hoverl && CheckCollisionCircleLine(GetMousePosition(), 2, p1, p2) {
        hoverl = true
        cline^ = HOVER_COLOR

        if IsMouseButtonPressed(.RIGHT) {
            selectl = {op1, op2}
        }
        if IsMouseButtonDown(.LEFT) {
            selectl = {op1, op2}
            dragl = {op1, op2}
            offsetl = {GetMousePosition() - p1, GetMousePosition() - p2}
        }
    }

    if selectl[0] == op1 && selectl[1] == op2 {
        cline^ = SELECTED_COLOR
    } 
}

draw_editor_internals::proc(world: ^engine.World, width, height: i32) {
    using rl
    hoverp = nil
    hoverl = false
    editor_controls(width, height)
    ClearBackground(BLACK)
    for line in world.lines {
        op1:=&world.points[line.p1]
        op2:=&world.points[line.p2]
        p1:=translate(op1^, width, height)
        p2:=translate(op2^, width, height)

        cp1 := WHITE
        cp2 := WHITE
        cline := WHITE
        switch mode {
        case .Point:
            selectl = {nil, nil}
            dragl = {nil, nil}
            handle_collide_point(p1, p2, &cp1, &cp2, &cline, op1, op2)
        case .Line:
            dragp = nil
            selectp = nil
            handle_collide_line(p1, p2, &cp1, &cp2, &cline, op1, op2)
        }
        DrawCircleV(p1, 2, cp1)
        DrawCircleV(p2, 2, cp2)
        DrawLineV(p1, p2, cline)
    }
    switch mode {
    case .Point:
        if IsMouseButtonUp(.LEFT) {
            dragp = nil
        }
        if dragp != nil {
            dragp^ = untranslate(GetMousePosition()-offsetp, width, height)
        }
        if IsMouseButtonPressed(.RIGHT) && hoverp == nil {
            selectp = nil
        }
    case .Line:
        if IsMouseButtonUp(.LEFT) {
            dragl = {nil, nil}
        }
        if dragl[0] != nil && dragl[1] != nil {
            dragl[0]^ = untranslate(GetMousePosition()-offsetl[0], width, height)
            dragl[1]^ = untranslate(GetMousePosition()-offsetl[1], width, height)
        }
        if IsMouseButtonPressed(.RIGHT) && !hoverl {
            selectl = {nil, nil} 
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
