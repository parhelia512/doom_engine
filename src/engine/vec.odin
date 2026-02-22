package engine;
import "core:math"

Vec2 :: [2]f32 
Vec3 :: [3]f32

@private
vec2mag :: proc(v: Vec2) -> f32 {
    return math.sqrt_f32(v.x*v.x + v.y*v.y)
}

@private
vec2norm :: proc(v: Vec2) -> Vec2 {
    mag:=vec2mag(v)
    if mag == 0 {
        return 0
    }
    return v / mag
}

@private
vec2dist :: proc(a, b: Vec2) -> f32{
    x :=(a.x-b.x)
    y :=(a.y-b.y)
    return math.sqrt_f32(x*x+y*y)
}

@private
vec3mag :: proc(v: Vec3) -> f32 {
    return math.sqrt_f32(v.x*v.x + v.y*v.y + v.z*v.z)
}

@private
vec3norm :: proc(v: Vec3) -> Vec3 {
    mag:=vec3mag(v)
    if mag == 0 {
        return 0
    }
    return v / mag
}

@private
vec3dist :: proc(a, b: Vec3) -> f32{
    x :=(a.x-b.x)
    y :=(a.y-b.y)
    z :=(a.z-b.z)
    return math.sqrt_f32(x*x+y*y+z*z)
}

mag :: proc{vec2mag, vec3mag}
norm :: proc{vec2norm, vec3norm}
dist :: proc{vec2dist, vec3dist}

rotate :: proc(v: Vec2, angle: f32) -> Vec2 {
    x := v.x*math.cos(angle) - v.y*math.sin(angle)
    y := v.x*math.sin(angle) + v.y*math.cos(angle)
    return Vec2{x, y}
}

rotate_around :: proc(origin, v: Vec2, angle: f32) -> Vec2 {
    v:=rotate(v-origin, angle)+origin
    return v
}

dot :: proc(a, b: Vec2) -> f32 {
    return a.x * b.x + a.y * b.y
}

