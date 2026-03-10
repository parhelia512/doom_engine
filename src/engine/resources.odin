package engine
import rl "vendor:raylib"
import "core:strings"
import "core:log"

TextureData :: struct {
    texture: rl.Texture,
    width, height: f32,
}

textures:map[string]TextureData

@private
DEFAULT_NAME::"__default"

gen_default::proc(width, height:f32) {
    _, ok := textures[DEFAULT_NAME] 
    if ok {
        return
    }
    using rl
    image := GenImageColor(8, 8, BLACK)
    defer UnloadImage(image)
    for x in 0..<8 {
        for y in 0..<8 {
            if x%2 == y%2 {
                ImageDrawPixel(&image, i32(x), i32(y), PURPLE);
            }
        }
    }
    texture := LoadTextureFromImage(image)
    if DEFAULT_NAME in textures {
        UnloadTexture(textures[DEFAULT_NAME].texture)
    }
    textures[DEFAULT_NAME] = TextureData {
        texture=texture,
        width=width,
        height=height,
    }
}

get_texture::proc(name: string) -> TextureData {
    text, ok := textures[name] 
    if ok {
        return text
    }
    dtext, dok := textures[DEFAULT_NAME] 
    if dok {
        return dtext
    }
    panic("default texture doesn't exist")
}

set_texture::proc(name, file:string, width, height: f32) {
    using rl
    str := strings.clone_to_cstring(file)
    defer delete(str)
    image := LoadImage(str)
    if image.data == nil {
        log.error("failed to load image: %s", file)
        return
    }
    defer UnloadImage(image)
    if name in textures {
        UnloadTexture(textures[name].texture)
    }
    texture:=LoadTextureFromImage(image)
    textures[name] = TextureData {
        texture=texture,
        width=width,
        height=height,
    }
    log.info("loaded image: %s", file)
}
