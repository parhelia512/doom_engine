package engine;
//runtime types

Line :: struct {
    p1, p2: int,
    portal: bool,
    sf, sb: int,
}

Sector :: struct {
    floor: f32,
    height: f32,
}

World :: struct {
    lines: [dynamic]Line,
    points: [dynamic]Vec2,
    sectors: [dynamic]Sector,
}

Player :: struct {
    pos, vel: Vec3,
    rot: f32,
    wanted_y: f32,
    height: f32,
}

