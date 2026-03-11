package main
import mu "vendor:microui"
import rl "vendor:raylib"
import lua "vendor:lua/5.4"
import "rlmu"

import "core:log"
import "core:math"
import "core:fmt"
import "core:strings"

import "engine"

import nfd "./nativefiledialog/"

mode:=MODE.Point

//TASK(20260305-141521-337-n6-054): fix bug in editor

create_file_path::proc(allocator:=context.allocator) -> Maybe(string) {
    nfd.Init()
    defer nfd.Quit()
    path: cstring
    filters := ([1]nfd.Filter_Item { { "map", "map" } })
    args := nfd.Save_Dialog_Args {
        filter_list = raw_data(filters[:]),
        filter_count = len(filters)
    }
    result := nfd.SaveDialogU8_With(&path, &args)
    switch result {
    case .Okay: {
        defer nfd.FreePathU8(path)
        s, e := strings.clone_from_cstring(path) 
        log.assertf(e==nil, "string err %s", e)
        return s
    }
case .Cancel:
    return nil
case .Error: 
    return nil
    }
    return nil
}
load_file_path::proc(allocator:=context.allocator) -> Maybe(string) {
    nfd.Init()
    defer nfd.Quit()
    path: cstring
    filters := ([1]nfd.Filter_Item { { "map", "map" } })
    args := nfd.Open_Dialog_Args {
        filter_list = raw_data(filters[:]),
        filter_count = len(filters)
    }
    result := nfd.OpenDialogU8_With(&path, &args)
    switch result {
    case .Okay: {
        defer nfd.FreePathU8(path)
        s, e := strings.clone_from_cstring(path) 
        log.assertf(e==nil, "string err %s", e)
        return s
    }
case .Cancel:
    return nil
case .Error: 
    return nil
    }
    return nil
}
dir_file_path::proc(allocator:=context.allocator) -> Maybe(string) {
    nfd.Init()
    defer nfd.Quit()
    path: cstring
    args := nfd.Pick_Folder_Args {
        
    }
    result := nfd.PickFolderU8_With(&path, &args)
    switch result {
    case .Okay: {
        defer nfd.FreePathU8(path)
        s, e := strings.clone_from_cstring(path) 
        log.assertf(e==nil, "string err %s", e)
        return s
    }
case .Cancel:
    return nil
case .Error: 
    return nil
    }
    return nil
}

remove_line_point::proc(point: ^engine.Vec2, world: ^engine.World) ->bool {
    idx:=-1
    for i in 0..<len(world.points) {
        if &world.points[i] == point {
            idx = i
            break
        }
    }
    return remove_line(idx, world)
}

remove_line_point_idx::proc(idx: int, world: ^engine.World) ->bool {
    if idx == -1 {
        return false
    }
    end_at :=-1
    checks := make([dynamic]Maybe(bool), len(world.points))
    defer delete(checks)
    i := 0
    for i <len(world.lines) {
        p1 := &world.lines[i].p1
        p2 := &world.lines[i].p2
        cont1:=false
        cont2:=false
        if p1^ > idx {
            p1^-=1
            cont1 = true
        }
        if p2^ > idx {
            p2^-=1
            cont2 = true
        }
        //this is its position for after idx gets deleted
        if checks[p1^] != nil {
            checks[p1^] = true
        }
        if checks[p2^] != nil {
            checks[p2^] = true 
        }
        if p1^ == idx && !cont1 {
            ordered_remove(&world.lines, i)
            if checks[p2^] == nil {
                checks[p2^] = false
            } 
            end_at = i
        } else if p2^ == idx && !cont2 {
            ordered_remove(&world.lines, i)
            if checks[p1^] == nil {
                checks[p1^] = false
            } 
            end_at = i
        } else {
            i+=1
        }
    }
    ordered_remove(&world.points, idx)
    if end_at == -1 {
        end_at = len(world.lines)
    }
    for i in 0..<end_at {
        p1 := world.lines[i].p1
        p2 := world.lines[i].p2
        if checks[p1] != nil {
            checks[p1] = true
        }
        if checks[p2] != nil {
            checks[p2] = true
        }
    }
    del:=0
    for i in 0..<len(checks) {
        val := checks[i]
        if val == nil || val==true {
            continue
        }
        ordered_remove(&world.points, i-del)
        del+=1
    }
    return true
}

is_point_used::proc(point: int, world:^engine.World)-> bool {
    for line in world.lines {
        if line.p1 == point || line.p2 == point {
            return true
        }
    }
    return false
}

remove_line_line::proc(point: [2]^engine.Vec2, world: ^engine.World)->bool {
    idx := -1
    check:=[2]int{-1, -1}
    for i in 0..<len(world.lines) {
        op1:=&world.points[world.lines[i].p1]
        op2:=&world.points[world.lines[i].p2]
        if point[0] == op1 && point[1] == op2 {
            idx = i
            check = {world.lines[i].p1, world.lines[i].p2}
            break
        }
    }
    if idx == -1 {
        return false
    }
    ordered_remove(&world.lines, idx)
    first := math.min(check[0], check[1])
    second := math.max(check[0], check[1])
    if first >= 0 {
        if !is_point_used(first, world) {
            ordered_remove(&world.points, first)
            if second > first {
                second-=1
            }
        }
    }
    if second < 0 {
        return true;
    }
    if !is_point_used(second, world) {
        ordered_remove(&world.points, second)
    }
    return true
}

remove_line::proc {remove_line_point, remove_line_line, remove_line_point_idx}

remove_sector::proc(idx: int, world: ^engine.World) ->bool {
    if idx == -1 {
        return false
    }
    ordered_remove(&world.sectors, idx)
    for i in 0..<len(world.lines) {
        sf:=&world.lines[i].sf
        sb:=&world.lines[i].sb
        if sf^ == idx {
            sf^=-1
        }
        if sb^ == idx {
            sb^=-1
        }
        if sf^ > idx {
            sf^-=1
        }
        if sb^ > idx {
            sb^-=1
        }
    }
    return true
}

editor_controls::proc(width, height: i32, world: ^engine.World, player: ^engine.Player, state: ^^lua.State) {
    using rl
    if IsKeyPressed(.ONE) {
        line_maker_type = .NONE
        mode=MODE.Point
    }
    if IsKeyPressed(.TWO) {
        line_maker_type = .NONE
        mode=MODE.Line
    }
    if IsKeyPressed(.THREE) {
        line_maker_type = .NONE
        mode=MODE.Player
    }
    if IsKeyPressed(.FOUR) {
        line_maker_type = .NONE
        mode=MODE.Decal
    }
    if IsKeyPressed(.S) && IsKeyDown(.LEFT_CONTROL) {
        s:=create_file_path()
        if s != nil {
            defer delete(s.?)
            engine.save_world(world, s.?)
        }
    }
    if IsKeyPressed(.L) && IsKeyDown(.LEFT_CONTROL) {
        if IsKeyDown(.LEFT_SHIFT) {
            s:=dir_file_path()
            if s != nil {
                defer delete(s.?)
                engine.load_map(world, s.?, player, state)
            }
        } else if IsKeyDown(.LEFT_ALT) {
            s:=dir_file_path()
            if s != nil {
                defer delete(s.?)
                engine.load_map_pack(world, s.?, player, state, "map01")
            }
        } else {
            s:=load_file_path()
            if s != nil {
                defer delete(s.?)
                engine.load_world(world, s.?, player)
            }
        }
    }
    if IsKeyPressed(.ESCAPE) {
        line_maker_type = .NONE
    }
    switch mode {
    case .Decal:
    case .Point:
        if (IsKeyPressed(.BACKSPACE) || IsKeyPressed(.DELETE)) && selectp != nil {
            remove_line(selectp, world) 
            selectp = nil
        }
        if IsKeyPressed(.P) {
            hover := get_line_hover(world, width, height)
            if hover != -1 {
                line:=&world.lines[hover]
                p1:=line.p1
                p2:=line.p2
                c:=len(world.points)
                append(&world.points, untranslate(GetMousePosition(), width, height)) 
                nl := engine.Line{
                    p1 = c,
                    p2 = p2,
                    portal = line.portal,
                    sb = line.sb,
                    sf = line.sf,
                    texture = line.texture,
                }
                dist := engine.dist(world.points[p1], world.points[c])*5
                nl.texture.back.top.offset.x = dist
                nl.texture.back.middle.offset.x = dist
                nl.texture.back.bottom.offset.x = dist
                nl.texture.front.top.offset.x = dist
                nl.texture.front.middle.offset.x = dist
                nl.texture.front.bottom.offset.x = dist
                append(&world.lines, nl) 
                line.p2 = c
            }
        }
    case .Line:
        if (IsKeyPressed(.BACKSPACE) || IsKeyPressed(.DELETE)) && selectl[0] != nil && selectl[1] != nil {
            remove_line(selectl, world) 
            selectl = {nil, nil}
        }
        if IsKeyPressed(.L) && line_maker_type == .NONE && !IsKeyDown(.LEFT_CONTROL) {
            if IsKeyDown(.LEFT_SHIFT) || IsKeyDown(.RIGHT_SHIFT) {//add line to pre-existing points
                line_maker_type = .POINT
                line_maker_point = -1
            } else { //create line and points
                line_maker_type = .LINE
                line_maker_line = nil
            }
        }
    case .Player:
    }
}

LineMakerType :: enum {
    LINE,
    POINT,
    NONE,
}

line_maker_type := LineMakerType.NONE

line_maker_point:int = -1 
line_maker_line:Maybe(engine.Vec2)= nil

//TASK(20260301-001613-540-n6-328): add sector mode
MODE::enum {
    Player,
    Point,
    Line,
    Decal,
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

handle_collide_point::proc(p1, p2: engine.Vec2, cp1, cp2, cline: ^rl.Color, op1, op2: ^engine.Vec2, focus: bool) {
    using rl
    if hoverp == nil && focus && dragp == nil {
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

hovers := -1
selects := -1

get_line_hover::proc(world: ^engine.World, width, height: i32)->int {
    using rl
    for i in 0..<len(world.lines) {
        line:=world.lines[i]
        p1:=translate(world.points[line.p1], width, height)
        p2:=translate(world.points[line.p2], width, height)
        if CheckCollisionCircleLine(GetMousePosition(), 2, p1, p2) {
            return i
        }
    }
    return -1
}

handle_collide_line::proc(p1, p2: engine.Vec2, cp1, cp2, cline: ^rl.Color, op1, op2: ^engine.Vec2, focus: bool) {
    using rl
    if !hoverl && CheckCollisionCircleLine(GetMousePosition(), 2, p1, p2) && focus && dragl=={nil, nil} {
        hoverl = true
        cline^ = HOVER_COLOR

        if IsMouseButtonPressed(.RIGHT) && line_maker_type == .NONE {
            selectl = {op1, op2}
        }
        if IsMouseButtonDown(.LEFT) && line_maker_type == .NONE {
            selectl = {op1, op2}
            dragl = {op1, op2}
            offsetl = {GetMousePosition() - p1, GetMousePosition() - p2}
        }
    }

    if selectl[0] == op1 && selectl[1] == op2 {
        cline^ = SELECTED_COLOR
    } 
}

get_idx::proc($T: typeid, arr:^[dynamic]T, val: T)->int {
    for i in 0..<len(arr) {
        if arr[i] == val {
            return i
        }
    }
    return -1
}

draw_line_maker_line :: proc(world: ^engine.World, width, height: i32) {
    using rl
    if line_maker_line == nil {
        if IsMouseButtonPressed(.LEFT) {
            line_maker_line = GetMousePosition()
        }
        return
    }
    DrawLineV(line_maker_line.?, GetMousePosition(), WHITE)
    if IsMouseButtonPressed(.LEFT) {
        line_maker_type = .NONE
        p1 := len(world.points)
        append(&world.points, untranslate(line_maker_line.?, width, height))
        p2 := len(world.points)
        append(&world.points, untranslate(GetMousePosition(), width, height))
        append(&world.lines, engine.Line{
            p1=p1,
            p2=p2,
            sf=-1,
            sb=-1,
        })
    }
}

get_point_hover :: proc(world: ^engine.World, width, height: i32) -> int {
    using rl
    for i in 0..<len(world.points) {
        point:=translate(world.points[i], width, height)
        if CheckCollisionCircles(point, 2, GetMousePosition(), 2) {
            return i
        }
    }
    return -1
}

draw_line_maker_point :: proc(world: ^engine.World, width, height: i32) {
    using rl;
    if line_maker_point == -1 {
        if IsMouseButtonPressed(.LEFT) {
            line_maker_point = get_point_hover(world, width, height)
        }
        return
    }
    p1 := line_maker_point
    p2 := get_point_hover(world, width, height)
    if p2 == -1 {
        DrawLineV(translate(world.points[p1], width, height), GetMousePosition(), WHITE)
        p2:=len(world.points)
        if IsMouseButtonPressed(.LEFT) {
            append(&world.points, untranslate(GetMousePosition(), width, height))
            line_maker_type = .NONE
            append(&world.lines, engine.Line{
                p1=p1,
                p2=p2,
                sf=-1,
                sb=-1,
            })
        }
    } else {
        DrawLineV(translate(world.points[p1], width, height), translate(world.points[p2], width, height), WHITE)
        if IsMouseButtonPressed(.LEFT) {
            line_maker_type = .NONE
            append(&world.lines, engine.Line{
                p1=p1,
                p2=p2,
                sf=-1,
                sb=-1,
            })
        }
    }
}

selectd:=-1

draw_editor_internals::proc(world: ^engine.World, width, height: i32, focus: bool, player: ^engine.Player, state: ^^lua.State) {
    using rl
    hoverp = nil
    hoverl = false
    if focus {
        editor_controls(width, height, world, player, state)
    }
    ClearBackground(BLACK)
    i:=0
    for line in world.lines {
        op1:=&world.points[line.p1]
        op2:=&world.points[line.p2]
        p1:=translate(op1^, width, height)
        p2:=translate(op2^, width, height)

        cp1 := WHITE
        cp2 := WHITE
        cline := WHITE
        if (hovers != -1 && (line.sf == hovers || line.sb == hovers)) || (selects != -1 && (line.sf == selects || line.sb == selects)) {
            cp1 = GREEN
            cp2 = GREEN
            cline = GREEN
        }
        switch mode {
        case .Decal:
            selectl = {nil, nil}
            dragl = {nil, nil}
            dragp = nil
            selectp = nil
            if hoverld == i {
                cp1 = GREEN
                cp2 = GREEN
                cline = GREEN
            }
        case .Point:
            selectl = {nil, nil}
            dragl = {nil, nil}
            selectd = -1
            handle_collide_point(p1, p2, &cp1, &cp2, &cline, op1, op2, focus)
        case .Line:
            dragp = nil
            selectp = nil
            selectd = -1
            handle_collide_line(p1, p2, &cp1, &cp2, &cline, op1, op2, focus)
        case .Player:
            selectl = {nil, nil}
            dragl = {nil, nil}
            dragp = nil
            selectp = nil
            selectd = -1
            dp:=translate(world.player_start, width, height)
            DrawCircleV(dp, 2, PURPLE)
            DrawLineV(dp, dp+engine.rotate(engine.Vec2{0, -10}, math.to_radians_f32(f32(world.player_start_rot))), PURPLE)
            if IsMouseButtonPressed(.LEFT) && focus {
                world.player_start = untranslate(GetMousePosition(), width, height)
            }
        }
        DrawCircleV(p1, 2, cp1)
        DrawCircleV(p2, 2, cp2)
        DrawLineV(p1, p2, cline)
        //draw normal
        dir := p2 - p1
        normal := engine.Vec2{-dir.y, dir.x}
        length := 5
        normal = normal / math.sqrt(normal.x*normal.x + normal.y*normal.y) * f32(length)
        mid := (p1 + p2) / 2
        DrawLineV(mid, mid + normal, RED)
        i+=1
    }
    hovers = -1
    switch line_maker_type {
    case .NONE:
    case .POINT:
        draw_line_maker_point(world, width, height)
    case .LINE:
        draw_line_maker_line(world, width, height)
    }
    if !focus {
        dragl = {nil, nil}
        dragp = nil
        return
    }
    switch mode {
    case .Decal:
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
    case .Player:
    }
}

editor_texture_width:i32 = 0
editor_texture_height:i32 = 0
editor_texture:rl.RenderTexture

draw_editor_window:: proc(ctx: ^mu.Context, render, has_focus: ^bool, world: ^engine.World, player: ^engine.Player, state: ^^lua.State) {
    window_width:=rl.GetRenderWidth()
    window_height:=rl.GetRenderHeight()
    if mu.window(ctx, "Editor", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}) {
        mu.layout_row(ctx, { -1 }, -1)

        text:=mu.layout_next(ctx)
        if editor_texture_width != text.w|| editor_texture_height != text.h{
            if editor_texture_width != 0 {
                rl.UnloadRenderTexture(editor_texture)
            }
            editor_texture_height = text.h 
            editor_texture_width = text.w 
            editor_texture=rl.LoadRenderTexture(text.w, text.h)
        }
        mu.layout_set_next(ctx, text, false)
        rlmu.draw_texture(ctx, &editor_texture.texture)
        x:=text.x
        y:=text.y

        rl.BeginTextureMode(editor_texture)
        rl.SetMouseOffset(-x, -y)
        draw_editor_internals(
            world, 
            text.w,
            text.h,
            ctx.hover_root == mu.get_current_container(ctx) &&
            rl.GetMouseX()>=0 && 
            rl.GetMouseX()<=text.w&& 
            rl.GetMouseY()>=0 && 
            rl.GetMouseY()<=text.h, 
            player,
            state
        )
        rl.SetMouseOffset(0, 0)
        rl.EndTextureMode()
        has_focus^ =ctx.hover_root!=nil||has_focus^
    } else {
        mu.get_container(ctx, "Editor").open=true
        render^ = false
    }
}

get_line :: proc(line: [2]^engine.Vec2, world: ^engine.World) -> ^engine.Line {
    if line[0] == nil || line[1] == nil {
        return nil
    }
    for i in 0..<len(world.lines) {
        wline:=&world.lines[i]
        p1:=&world.points[wline.p1]
        p2:=&world.points[wline.p2]
        if line[0] == p1 && line[1] == p2 {
            return wline
        }
    }
    return nil
}

texture_dropdown :: proc(ctx: ^mu.Context, label: string, button_label: ^string) {
    if mu.popup(ctx, label) {
        if .SUBMIT in mu.button(ctx, "") {
            mu.get_current_container(ctx).open = false
            button_label^ = ""
        }
        for key, _ in engine.textures {
            if .SUBMIT in mu.button(ctx, key) {
                mu.get_current_container(ctx).open = false
                button_label^ = key
            }
        } 
    }
    if .SUBMIT in mu.button(ctx, button_label^)  {
        mu.open_popup(ctx, label)
    }
}

slide_int_t::proc($T:typeid, ctx: ^mu.Context, number: ^T, step: T, formatstr: string, min, max: T) -> mu.Result_Set {
    @static t:f32
    mu.push_id(ctx, uintptr(number));
    t=f32(number^)
    a:=mu.slider(ctx, &t, f32(min), f32(max), f32(step), formatstr)
    number^ = T(t)
    mu.pop_id(ctx)
    return a
}

slide_int_int::proc(ctx: ^mu.Context, number: ^int, step: int, formatstr: string, min, max: int)->mu.Result_Set {
    return slide_int_t(int, ctx, number, step, formatstr, min, max)
}
slide_int_u16::proc(ctx: ^mu.Context, number: ^u16, step: u16, formatstr: string, min, max: u16)->mu.Result_Set {
    return slide_int_t(u16, ctx, number, step, formatstr, min, max)
}

number_u16::proc(ctx: ^mu.Context, number: ^u16, step: u16, min, max: u16, formatstr: string) -> mu.Result_Set {
    @static t:f32
    mu.push_id(ctx, uintptr(number));
    t=f32(number^)
    a:=mu.number(ctx, &t, f32(step), formatstr)
    if t < f32(min) {
        t = f32(min)
    }
    if t > f32(max) {
        t = f32(max)
    }
    number^ = u16(t)
    mu.pop_id(ctx)
    return a
}

slide_int::proc{slide_int_t, slide_int_int, slide_int_u16}

hover_begin :: proc(ctx: ^mu.Context, name: string) -> bool {
    id := mu.get_id(ctx, name)
    s:[100]byte
    mu.begin_panel(ctx, fmt.bprint(s[:], "panel", name))
    rect := mu.get_current_container(ctx).rect

    mu.update_control(ctx, id, rect)

    return ctx.hover_id == id
}

hover_end :: proc(ctx: ^mu.Context) {
    mu.end_panel(ctx)
}

draw_line_window:: proc(ctx: ^mu.Context, has_focus: ^bool, world: ^engine.World) {
    line:=get_line(selectl, world) 
    if line == nil {
        selectl = {nil, nil}
        return
    }
    window_width:=rl.GetRenderWidth()
    window_height:=rl.GetRenderHeight()
    if mu.window(ctx, "Line Editor", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}) {
        if .ACTIVE in mu.treenode(ctx, "TEXTURE") {
            if .ACTIVE in mu.treenode(ctx, "FRONT") {
                if .ACTIVE in mu.treenode(ctx, "TOP") {
                    texture_dropdown(ctx, "TEXTURE_FRONT_TOP_TEXTURE", &line.texture.front.top.texture)
                    mu.number(ctx, &line.texture.front.top.offset.x, .5, "offset x: %.1f")
                    mu.number(ctx, &line.texture.front.top.offset.y, .5, "offset y: %.1f")
                    if ctx.hover_root == mu.get_current_container(ctx) {
                        mu.checkbox(ctx, "anchor bottom", &line.texture.front.top.anchor_bottom)
                    } else {
                        p:=line.texture.front.top.anchor_bottom
                        mu.checkbox(ctx, "anchor bottom", &p)
                    }
                }
                if .ACTIVE in mu.treenode(ctx, "MIDDLE") {
                    texture_dropdown(ctx, "TEXTURE_FRONT_MIDDLE_TEXTURE", &line.texture.front.middle.texture)
                    mu.number(ctx, &line.texture.front.middle.offset.x, .5, "offset x: %.1f")
                    mu.number(ctx, &line.texture.front.middle.offset.y, .5, "offset y: %.1f")
                    if ctx.hover_root == mu.get_current_container(ctx) {
                        mu.checkbox(ctx, "anchor bottom", &line.texture.front.middle.anchor_bottom)
                    } else {
                        p:=line.texture.front.middle.anchor_bottom
                        mu.checkbox(ctx, "anchor bottom", &p)
                    }
                }
                if .ACTIVE in mu.treenode(ctx, "BOTTOM") {
                    texture_dropdown(ctx, "TEXTURE_FRONT_BOTTOM_TEXTURE", &line.texture.front.bottom.texture)
                    mu.number(ctx, &line.texture.front.bottom.offset.x, .5, "offset x: %.1f")
                    mu.number(ctx, &line.texture.front.bottom.offset.y, .5, "offset y: %.1f")
                    if ctx.hover_root == mu.get_current_container(ctx) {
                        mu.checkbox(ctx, "anchor bottom", &line.texture.front.bottom.anchor_bottom)
                    } else {
                        p:=line.texture.front.bottom.anchor_bottom
                        mu.checkbox(ctx, "anchor bottom", &p)
                    }
                }
            }
            if .ACTIVE in mu.treenode(ctx, "BACK") {
                if .ACTIVE in mu.treenode(ctx, "TOP") {
                    texture_dropdown(ctx, "TEXTURE_BACK_TOP_TEXTURE", &line.texture.back.top.texture)
                    mu.number(ctx, &line.texture.back.top.offset.x, .5, "offset x: %.1f")
                    mu.number(ctx, &line.texture.back.top.offset.y, .5, "offset y: %.1f")
                    if ctx.hover_root == mu.get_current_container(ctx) {
                        mu.checkbox(ctx, "anchor bottom", &line.texture.back.top.anchor_bottom)
                    } else {
                        p:=line.texture.back.top.anchor_bottom
                        mu.checkbox(ctx, "anchor bottom", &p)
                    }
                }
                if .ACTIVE in mu.treenode(ctx, "MIDDLE") {
                    texture_dropdown(ctx, "TEXTURE_BACK_MIDDLE_TEXTURE", &line.texture.back.middle.texture)
                    mu.number(ctx, &line.texture.back.middle.offset.x, .5, "offset x: %.1f")
                    mu.number(ctx, &line.texture.back.middle.offset.y, .5, "offset y: %.1f")
                    if ctx.hover_root == mu.get_current_container(ctx) {
                        mu.checkbox(ctx, "anchor bottom", &line.texture.back.middle.anchor_bottom)
                    } else {
                        p:=line.texture.back.middle.anchor_bottom
                        mu.checkbox(ctx, "anchor bottom", &p)
                    }
                }
                if .ACTIVE in mu.treenode(ctx, "BOTTOM") {
                    texture_dropdown(ctx, "TEXTURE_BACK_BOTTOM_TEXTURE", &line.texture.back.bottom.texture)
                    mu.number(ctx, &line.texture.back.bottom.offset.x, .5, "offset x: %.1f")
                    mu.number(ctx, &line.texture.back.bottom.offset.y, .5, "offset y: %.1f")
                    if ctx.hover_root == mu.get_current_container(ctx) {
                        mu.checkbox(ctx, "anchor bottom", &line.texture.back.bottom.anchor_bottom)
                    } else {
                        p:=line.texture.back.bottom.anchor_bottom
                        mu.checkbox(ctx, "anchor bottom", &p)
                    }
                }
            }
        }
        if ctx.hover_root == mu.get_current_container(ctx) {
            mu.checkbox(ctx, "portal", &line.portal)
        } else {
            p:=line.portal
            mu.checkbox(ctx, "portal", &p)
        }
        if line.portal {
            if ctx.hover_root == mu.get_current_container(ctx) {
                mu.checkbox(ctx, "portal solid", &line.portal_solid)
            } else {
                p:=line.portal_solid
                mu.checkbox(ctx, "portal solid", &p)
            }
        }
        if .SUBMIT in mu.button(ctx, "Flip Normal") {
            t:=line.p1
            line.p1 = line.p2
            line.p2 = t
            tp:=selectl[0]
            selectl[0] = selectl[1]
            selectl[1] = tp
        }
        mu.layout_row(ctx, { -1 }, 30)
        if hover_begin(ctx, "front sector") {
            hovers = line.sf
        }
        mu.layout_row(ctx, { -150, 5 , -1 }, 0)
        slide_int(ctx, &line.sf, 1, "front sector: %.0f", -1, len(world.sectors)-1)
        mu.layout_next(ctx)
        if .SUBMIT in mu.button(ctx, "Edit Front Sector") {
            selects = line.sf
        }
        hover_end(ctx)
        if hover_begin(ctx, "back sector") {
            hovers = line.sb
        }
        mu.layout_row(ctx, { -150, 5 , -1 }, 0)
        slide_int(ctx, &line.sb, 1, "back sector: %.0f", -1, len(world.sectors)-1)
        mu.layout_next(ctx)
        if .SUBMIT in mu.button(ctx, "Edit Back Sector") {
            selects = line.sb
        }
        hover_end(ctx)
        if .SUBMIT in mu.button(ctx, "New Sector") {
            append(&world.sectors, engine.Sector {
                floor=0,
                height=10,
            })
        }
        number_u16(ctx, &line.tag, 1, 0, 65535, "tag: %.0f")
    } else {
        mu.get_container(ctx, "Line Editor").open=true
        selectl = {nil, nil}
    }
}

get_sector :: proc(world: ^engine.World, sector: int) -> ^engine.Sector {
    if sector == -1 || sector >= len(world.sectors) {
        return nil
    }
    return &world.sectors[sector]
}

draw_sector_window:: proc(ctx: ^mu.Context, has_focus: ^bool, world: ^engine.World) {
    sector:=get_sector(world, selects)
    if sector == nil {
        selects = -1
        return
    }
    window_width:=rl.GetRenderWidth()
    window_height:=rl.GetRenderHeight()
    if mu.window(ctx, "Sectors Editor", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}) {
        mu.layout_row(ctx, {-1}, 0)
        if .ACTIVE in mu.treenode(ctx, "Texture") {
            if .ACTIVE in mu.treenode(ctx, "Ceiling") {
                texture_dropdown(ctx, "Texture Ceiling", &sector.ceil_text.texture)
                mu.number(ctx, &sector.ceil_text.offset.x, .5, "offset x: %.1f")
                mu.number(ctx, &sector.ceil_text.offset.y, .5, "offset y: %.1f")
            }
            if .ACTIVE in mu.treenode(ctx, "Floor") {
                texture_dropdown(ctx, "Texture Floor", &sector.floor_text.texture)
                mu.number(ctx, &sector.floor_text.offset.x, .5, "offset x: %.1f")
                mu.number(ctx, &sector.floor_text.offset.y, .5, "offset y: %.1f")
            }
        }
        mu.number(ctx, &sector.floor, .5, "floor y: %.1f")
        mu.number(ctx, &sector.height, .5, "height: %.1f")
        if .SUBMIT in mu.button(ctx, "Delete Sector") {
            remove_sector(selects, world)
            selects = -1
        }
        number_u16(ctx, &sector.tag, 1, 0, 65535, "tag: %.0f")
    } else {
        mu.get_container(ctx, "Sectors Editor").open=true
        selects = -1
    }
}
draw_player_window:: proc(ctx: ^mu.Context, has_focus: ^bool, world: ^engine.World) {
    if mode != .Player{
        return
    }
    window_width:=rl.GetRenderWidth()
    window_height:=rl.GetRenderHeight()
    if mu.window(ctx, "Player Editor", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}, {.NO_CLOSE}) {
        mu.layout_row(ctx, {-1}, 0)
        slide_int(ctx, &world.player_start_rot, 1, "rotation: %.0f", 0, 360)
    }
}

hoverld := -1

draw_decal_window:: proc(ctx: ^mu.Context, has_focus: ^bool, world: ^engine.World, state: ^lua.State) {
    if mode != .Decal {
        return
    }
    window_width:=rl.GetRenderWidth()
    window_height:=rl.GetRenderHeight()
    if mu.window(ctx, "Decal Editor", mu.Rect{window_width/2-700/2, window_height/2-500/2, 700, 500}, {.NO_CLOSE}) {
        mu.layout_row(ctx, {-1}, 25)
        slide_int(ctx, &selectd, 1, "Decal: %.0f", 0, len(world.decals)-1)
        mu.begin_panel(ctx, "buttons")
        w:=mu.get_current_container(ctx).rect.w/2-10
        mu.layout_row(ctx, {w,1,w}, -1)
        selectd = math.clamp(selectd, 0, len(world.decals)-1)
        if .SUBMIT in mu.button(ctx, "add") {
            selectd = len(world.decals)
            append(&world.decals, engine.Decal{
                wall=-1,
                part=.Middle,
            })
        }
        mu.layout_next(ctx)
        if .SUBMIT in mu.button(ctx, "remove") {
            engine.freeref(state, world.decals[selectd].on_interact)
            ordered_remove(&world.decals, selectd)
        }
        mu.end_panel(ctx)
        selectd = math.clamp(selectd, 0, len(world.decals)-1)
        hoverld=-1
        if selectd < len(world.decals) && selectd>=0{
            if hover_begin(ctx, "line") {
                hoverld = world.decals[selectd].wall
            }
            mu.layout_row(ctx, {-1}, 0)
            slide_int(ctx, &world.decals[selectd].wall, 1, "wall: %.0f", -1, len(world.lines)-1)
            hover_end(ctx)
            mu.number(ctx, &world.decals[selectd].offset.x, .5, "offset x: %.1f")
            mu.number(ctx, &world.decals[selectd].offset.y, .5, "offset y: %.1f")
            number_u16(ctx, &world.decals[selectd].tag, 1, 0, 65535, "tag: %.0f")
            if ctx.hover_root == mu.get_current_container(ctx) {
                mu.checkbox(ctx, "on back", &world.decals[selectd].on_back)
            } else {
                p:=world.decals[selectd].on_back
                mu.checkbox(ctx, "on back", &p)
            }
            texture_dropdown(ctx, "Decal Texture", &world.decals[selectd].texture)
            line_part_dropdown(ctx, "Line Part", &world.decals[selectd].part)
        } 
    }
}

line_part_dropdown :: proc(ctx: ^mu.Context, label: string, button_label: ^engine.LinePart) {
    if mu.popup(ctx, label) {
        for part, _ in engine.LinePart {
            sb:=strings.builder_make()
            fmt.sbprint(&sb, part)
            string:=strings.to_string(sb)
            defer delete(string)
            if .SUBMIT in mu.button(ctx, string) {
                button_label^=part
                mu.get_current_container(ctx).open = false
            }
        }
    }
    sb:=strings.builder_make()
    fmt.sbprint(&sb, button_label^)
    string:=strings.to_string(sb)
    defer delete(string)
    if .SUBMIT in mu.button(ctx, string)  {
        mu.open_popup(ctx, label)
    }
}

draw_editor:: proc(ctx: ^mu.Context, render, has_focus: ^bool, world: ^engine.World, player: ^engine.Player, state: ^^lua.State) {
    if !render^ {
        return
    }
    draw_editor_window(ctx, render, has_focus, world, player, state)
    draw_line_window(ctx, has_focus, world)
    draw_sector_window(ctx, has_focus, world)
    draw_player_window(ctx, has_focus, world)
    draw_decal_window(ctx, has_focus, world, state^)
}
