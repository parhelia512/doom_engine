package engine;
import "core:math"
import "core:log"

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


@private
vec2mag2 :: proc(v: Vec2) -> f32 {
    return v.x*v.x + v.y*v.y
}

@private
vec2dist2 :: proc(a, b: Vec2) -> f32{
    x :=(a.x-b.x)
    y :=(a.y-b.y)
    return x*x+y*y
}

@private
vec3mag2 :: proc(v: Vec3) -> f32 {
    return v.x*v.x + v.y*v.y + v.z*v.z
}


@private
vec3dist2 :: proc(a, b: Vec3) -> f32{
    x :=(a.x-b.x)
    y :=(a.y-b.y)
    z :=(a.z-b.z)
    return x*x+y*y+z*z
}

mag :: proc{vec2mag, vec3mag}
mag2 :: proc{vec2mag2, vec3mag2}
norm :: proc{vec2norm, vec3norm}
dist :: proc{vec2dist, vec3dist}
dist2 :: proc{vec2dist2, vec3dist2}

rotate :: proc(v: Vec2, angle: f32) -> Vec2 {
    if angle == 0 {
        return v;
    }
    x := v.x*math.cos(angle) - v.y*math.sin(angle)
    y := v.x*math.sin(angle) + v.y*math.cos(angle)
    return Vec2{x, y}
}

rotate_around :: proc(origin, v: Vec2, angle: f32) -> Vec2 {
    if angle == 0 {
        return v
    }
    v:=rotate(v-origin, angle)+origin
    return v
}

dot :: proc(a, b: Vec2) -> f32 {
    return a.x * b.x + a.y * b.y
}

angle :: proc(a: Vec2) -> f32 {
    return math.atan2(a.y, a.x)
}

angle_around :: proc(a, origin: Vec2) -> f32 {
    return angle(a-origin)
}

