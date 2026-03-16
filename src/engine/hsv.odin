package engine
import "core:math"
import rl "vendor:raylib"

hsv_to_color::proc(hsv:HSV)->rl.Color {
    return rl.ColorFromHSV(hsv[0], hsv[1], hsv[2])
}

HSV :: [3]f32 

btv::proc(a, b, c: Vec2, p: Vec3)->Vec2 {
    return p.x*a + p.y*b + p.z*c
}

vtb::proc(a, b, c, p: Vec2)->(Vec3,bool) {
    v0 := b - a
    v1 := c - a
    v2 := p - a

    d00 := dot(v0, v0)
    d01 := dot(v0, v1)
    d11 := dot(v1, v1)
    d20 := dot(v2, v0)
    d21 := dot(v2, v1)

    denom := d00*d11 - d01*d01

    v := (d11*d20 - d01*d21) / denom
    w := (d00*d21 - d01*d20) / denom
    u := f32(1 - v - w)

    return {u, v, w}, u>=0&&v>=0&&w>=0
}

btsv :: proc(b: Vec3)->(f32, f32){
    svmap:=[3][2]f32{{1, 1}, {0, 1}, {0, 0}}
    sv:Vec2
    for i in 0..<3 {
        sv+=svmap[i]*b[i]
    }
    return sv.x, sv.y
}
svtb :: proc(s, v: f32) -> Vec3 {
    return Vec3{
        s,
        v - s,
        1 - v,
    }
}

tri_fn::proc(p:Vec2, d:rawptr);

draw_tri::proc(a, b, c, center: Vec2, hue: f32, offset: f32=0, fn:Maybe(tri_fn)=nil, data:rawptr=nil) {
    min:=Vec2{center.x-offset, center.y-offset} 
    max:=Vec2{center.x+offset, center.y+offset} 
    min.x = math.max(0, min.x)
    min.y = math.max(0, min.y)
    max.x = math.min(f32(rl.GetScreenWidth()), max.x)
    max.y = math.min(f32(rl.GetScreenHeight()), max.y)
    fn, ok := fn.?

    for x in min.x..=max.x{
        for y in min.y..=max.y {
            v, n:=vtb(a, b, c, {x, y})
            if n {
                s, v := btsv(v)
                c:=rl.ColorFromHSV(hue,s, v)
                rl.DrawPixelV({x, y}, c)
            } else if ok {
                fn({x, y}, data)
            }
        }
    }
}

get_tri_points::proc(center: Vec2, r: f32, e:f32)->(Vec2,Vec2,Vec2) {
    a:f32=e/180*math.PI
    p:[3]Vec2
    for i in 0..<3 {
        p[i]=rotate({0, -r}, a)+center
        a+=2*math.PI/3
    }
    return p.x, p.y, p.z
}

ColorPickerDataExtra :: struct {
    r, o: f32,
    c: Vec2,
}
ColorDragType::enum{
    None,
    Tri,
    Ring,
}
ColorPickerData::struct {
    drag:ColorDragType
}

clamp_bary :: proc(b: Vec3, n:=false) -> Vec3 {
    if n {
        return b
    }
    b:=b
    b.x = math.max(b.x, 0)
    b.y = math.max(b.y, 0)
    b.z = math.max(b.z, 0)

    s := b.x + b.y + b.z
    if s > 0 {
        b /= s
    }

    return b
}


color_picker::proc(hsv:^HSV, center: Vec2, r:f32, o:f32, data: ^ColorPickerData, focus:=true) {
    //keep float in the range [0, 360)
    for hsv[0] < 0 {
        hsv[0] += 360
    }
    for hsv[0] >= 360 {
        hsv[0] -= 360
    }
    edata:=ColorPickerDataExtra{r, o, center}
    a, b, c := get_tri_points(center, r, hsv[0]) 
    draw_tri(a, b, c, center, hsv[0], r+o, proc(p:Vec2, d: rawptr) {
        d:=cast(^ColorPickerDataExtra)d
        d2:=dist2(d.c, p)
        if d2 > d.r*d.r && d2 < (d.r+d.o)*(d.r+d.o) {
            c:=rl.ColorFromHSV(angle_around(p, d.c)/math.PI*180+90, 1, 1)
            rl.DrawPixelV(p, c)
        }
    }, &edata)
    if rl.IsMouseButtonPressed(.LEFT) && focus {
        mouse := rl.GetMousePosition() 
        b, n:=vtb(a, b, c, mouse)
        if n {
            data.drag = .Tri
            s, v := btsv(b)
            hsv[1]= s
            hsv[2]= v
        } else {
            d2:=dist2(center, mouse)
            if d2 > r*r && d2 < (r+o)*(r+o) {
                c:=angle_around(mouse, center)/math.PI*180+90
                data.drag = .Ring
                hsv[0] = c
            }
        }
    }
    if rl.IsMouseButtonReleased(.LEFT) {
        data.drag = .None
    }
    switch data.drag {
    case .None:
    case .Tri:
        mouse := rl.GetMousePosition() 
        b, n := vtb(a, b, c, mouse)
        nb:=clamp_bary(b, n)
        s, v := btsv(nb)
        hsv[1]= s
        hsv[2]= v
    case .Ring:
        mouse := rl.GetMousePosition()
        ang := angle_around(mouse, center)

        hsv[0] = ang / math.PI * 180 + 90
    }
    ce:=btv(a, b, c, svtb(hsv[1], hsv[2]))
    s:f32=8
    rl.DrawRectangleV(ce-(s)/2, {s, s}, rl.BLACK)
    rl.DrawRectangleV(ce-(s-2)/2, {s-2, s-2}, rl.WHITE)
    rl.DrawRectangleV(ce-(s-4)/2, {s-4, s-4}, rl.ColorFromHSV(hsv[0], hsv[1], hsv[2]))

    //I just learned odin allows unicode characters for idents too
    þ:f32=hsv.x/180*math.PI
    þ2:f32=(hsv.x+1)/180*math.PI
    re:=rotate_around(center, {0, -r}+center, þ)
    oe:=rotate_around(center, {0, -(r+o)}+center, þ)
    rl.DrawLineV(re, oe, rl.WHITE)
    re=rotate_around(center, {0, -r}+center, þ2)
    oe=rotate_around(center, {0, -(r+o)}+center, þ2)
    rl.DrawLineV(re, oe, rl.BLACK)
}
