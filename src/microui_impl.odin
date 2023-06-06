package main

import     "core:slice"
import glm "core:math/linalg/glsl"
import la  "core:math/linalg"
import gl  "vendor:opengl"
import mu  "vendor:microui"

Vertex :: struct {
    pos: glm.vec2,
    col: glm.vec4,
    tex: glm.vec2,
}

BUFFER :: 128 * 128

// Uniforms
modelview, projection: glm.mat4

// Buffers
vertices : [BUFFER * 4]Vertex
indices  : [BUFFER * 6]u32
buf_idx  : i32

// Buffer handles
vao, vbo, ebo,
// Shader handles
vs, fs, prog,
// Texture handles
tex: u32

vp_width, vp_height: i32 = 1024, 768

ctx: mu.Context

push_quad_impl :: proc(dst, src: mu.Rect, color: mu.Color) {
    if buf_idx == BUFFER do flush_impl()

    vert_idx  := buf_idx * 4
    index_idx := buf_idx * 6
    buf_idx   += 1

    x := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
    y := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
    w := f32(src.w) / mu.DEFAULT_ATLAS_WIDTH
    h := f32(src.h) / mu.DEFAULT_ATLAS_HEIGHT

    vertices[vert_idx + 0].tex = { x, y }
    vertices[vert_idx + 1].tex = { x + w, y }
    vertices[vert_idx + 2].tex = { x, y + h }
    vertices[vert_idx + 3].tex = { x + w, y + h }

    x, y, w, h = f32(dst.x), f32(dst.y), f32(dst.w), f32(dst.h)

    vertices[vert_idx + 0].pos.xy = { x, y }
    vertices[vert_idx + 1].pos.xy = { x + w, y }
    vertices[vert_idx + 2].pos.xy = { x, y + h }
    vertices[vert_idx + 3].pos.xy = { x + w, y + h }

    color4f := glm.vec4{ f32(color.r), f32(color.g), f32(color.b), f32(color.a) } / 255

    vertices[vert_idx + 0].col = color4f
    vertices[vert_idx + 1].col = color4f
    vertices[vert_idx + 2].col = color4f
    vertices[vert_idx + 3].col = color4f

    indices[index_idx + 0] = u32(vert_idx + 0)
    indices[index_idx + 1] = u32(vert_idx + 1)
    indices[index_idx + 2] = u32(vert_idx + 2)
    indices[index_idx + 3] = u32(vert_idx + 2)
    indices[index_idx + 4] = u32(vert_idx + 3)
    indices[index_idx + 5] = u32(vert_idx + 1)
}

draw_text_impl :: proc(text: string, pos: mu.Vec2, color: mu.Color) {
    dst := mu.Rect{ pos.x, pos.y, 0, 0 }
    for c in text {
        if c & 0xc0 == 0x80 do continue // not sure what this is, but it's in the sample
        chr := cast(int)min(c, 127)
        src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + chr]
        dst.w, dst.h = src.w, src.h
        push_quad_impl(dst, src, color)
        dst.x += dst.w
    }
}

draw_rect_impl :: proc(rect: mu.Rect, color: mu.Color) {
    push_quad_impl(rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], color)
}

draw_icon_impl :: proc(id: int, rect: mu.Rect, color: mu.Color) {
    src := mu.default_atlas[id]
    x := rect.x + (rect.w - src.w) / 2
    y := rect.y + (rect.h - src.h) / 2
    push_quad_impl({ x, y, src.w, src.h }, src, color)
}

flush_impl :: proc() {
    if buf_idx == 0 do return
    defer buf_idx = 0

    gl.UseProgram(prog)

    projection = la.matrix_ortho3d(0, f32(vp_width), f32(vp_height), 0, -1, 1, false)
    gl.Uniform1i(gl.GetUniformLocation(prog, "atlas_texture"), 0)
    gl.UniformMatrix4fv(gl.GetUniformLocation(prog, "projection"), 1, gl.FALSE, cast([^]f32)&projection)

    verts := vertices[:buf_idx * 4]
    indxs := indices[:buf_idx * 6]
    modify_vbo(vbo, verts)
    modify_ebo(ebo, indxs)

    // 1. Bind texture
    gl.ActiveTexture(gl.TEXTURE0);
    gl.BindTexture(gl.TEXTURE_2D, tex)

    // 2. Bind VAO
    gl.BindVertexArray(vao)

    // 3. Draw
    //gl.DrawElementsInstancedBaseVertex(gl.TRIANGLES, buf_idx * 6, gl.UNSIGNED_INT, nil, 1, 0)
    gl.DrawElementsBaseVertex(gl.TRIANGLES, buf_idx * 6, gl.UNSIGNED_INT, nil, 0)
}

init_mu_backend :: proc(ctx: ^mu.Context) {
    using gl

    Enable(BLEND)
    BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA)
    Enable(SCISSOR_TEST)
    Disable(CULL_FACE)
    Disable(DEPTH_TEST)

    mu.init(ctx)
    //ctx._style.colors[.WINDOW_BG].a = 255
    ctx.text_width, ctx.text_height = mu.default_atlas_text_width, mu.default_atlas_text_height

    GenVertexArrays(1, &vao)
    BindVertexArray(vao)
    defer BindVertexArray(0)

    vbo = create_vbo(vertices[:])
    ebo = create_ebo(indices[:])

    pixels := make([][4]byte, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    defer delete(pixels)
    
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = { 255, 255, 255, alpha }
    }

    tex = create_rgba_texture(slice.to_bytes(pixels), mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT)

    vs   = create_vertex_shader(&vertex_shader)
    fs   = create_fragment_shader(&fragment_shader)
    prog = create_shader_program(vs, fs)
}

mu_test_window :: proc(ctx: ^mu.Context) {
    mu.begin(ctx)
    defer mu.end(ctx)

    if mu.window(ctx, "My Window", { 10, 10, 290, 206 }) {
        mu.layout_row(ctx, []i32{ 60, -1 })

        mu.label(ctx, "First:");
        if .SUBMIT in mu.button(ctx, "Button1") {
        }

        mu.label(ctx, "Second:");
        if .SUBMIT in mu.button(ctx, "Button2") {
            mu.open_popup(ctx, "My Popup")
        }

        if mu.popup(ctx, "My Popup") {
            mu.label(ctx, "Hello world!")
        }

    }
}

mu_draw_events :: proc(ctx: ^mu.Context) {
    command: ^mu.Command
    for var in mu.next_command_iterator(ctx, &command) {
        switch cmd in var {
        case ^mu.Command_Text: draw_text_impl(cmd.str, cmd.pos, cmd.color)
        case ^mu.Command_Rect: draw_rect_impl(cmd.rect, cmd.color)
        case ^mu.Command_Icon: draw_icon_impl(int(cmd.id), cmd.rect, cmd.color)
        case ^mu.Command_Clip: clip_rect_impl(cmd.rect)
        case ^mu.Command_Jump: unreachable()
        }
    }

    flush_impl()
}

clip_rect_impl :: proc(rect: mu.Rect) {
    flush_impl()
    gl.Scissor(rect.x, vp_height - (rect.y + rect.h), rect.w, rect.h)
}


when ODIN_ARCH == .amd64 || ODIN_ARCH == .i386 {
    vertex_shader: cstring = 
`#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 col;
layout (location = 2) in vec2 tex;

out vec4 vertex_color;
out vec2 tex_coords;

uniform mat4 projection;

void main() {
    gl_Position  = projection * vec4(pos, 0.0, 1.0);
    vertex_color = col;
    tex_coords   = tex; 
}`
    fragment_shader: cstring = 
`#version 330 core
in vec4 vertex_color;
in vec2 tex_coords;

out vec4 frag_color;

uniform sampler2D atlas_texture;

void main() {
    frag_color = texture(atlas_texture, tex_coords) * vertex_color;
}`
} else when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64 {
    vertex_shader: cstring = 
`#version 300 es
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 col;
layout (location = 2) in vec2 tex;

out vec4 vertex_color;
out vec2 tex_coords;

uniform mat4 projection;

void main() {
    gl_Position  = projection * vec4(pos, 0.0, 1.0);
    vertex_color = col;
    tex_coords   = tex; 
}`
    fragment_shader: cstring = 
`#version 300 es
in vec4 vertex_color;
in vec2 tex_coords;

out vec4 frag_color;

uniform sampler2D atlas_texture;

void main() {
    frag_color = texture(atlas_texture, tex_coords) * vertex_color;
}`
}
