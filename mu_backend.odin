package main

import    "core:fmt"
import    "core:slice"
import la "core:math/linalg/glsl"
import gl "vendor:opengl"
import mu "vendor:microui"

Vertex :: struct {
	pos: la.vec2,
	col: la.vec4,
	tex: la.vec2,
}

BUFFER :: 128 * 128

// Uniforms
modelview, projection: la.mat4

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

ctx: mu.Context

push_quad :: proc(dst, src: mu.Rect, color: mu.Color) {
    if buf_idx == BUFFER do flush()
    
	vert_idx  := buf_idx * 4
	elem_idx  := buf_idx * 4
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

    color4f := la.vec4{ f32(color.r), f32(color.g), f32(color.b), f32(color.a) }
    vertices[vert_idx + 0].col = color4f
    vertices[vert_idx + 1].col = color4f
    vertices[vert_idx + 2].col = color4f
    vertices[vert_idx + 3].col = color4f

    indices[index_idx + 0] = u32(elem_idx + 0)
    indices[index_idx + 1] = u32(elem_idx + 1)
    indices[index_idx + 2] = u32(elem_idx + 2)
    indices[index_idx + 3] = u32(elem_idx + 2)
    indices[index_idx + 4] = u32(elem_idx + 3)
    indices[index_idx + 5] = u32(elem_idx + 1)
}

draw_text :: proc(text: string, pos: mu.Vec2, color: mu.Color) {
    dst := mu.Rect{ pos.x, pos.y, 0, 0 }
    for c in text {
        if c & 0xc0 == 0x80 do continue // not sure what this is, but it's in the sample
        chr := int(c) if c < 127 else 127
        src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + chr]
        dst.w, dst.h = src.w, src.h
        push_quad(dst, src, color)
        dst.x += dst.w
    }
}

draw_rect :: proc(rect: mu.Rect, color: mu.Color) {
    push_quad(rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], color)
}

draw_icon :: proc(id: int, rect: mu.Rect, color: mu.Color) {
    src := mu.default_atlas[id]
    x := rect.x + (rect.w - src.w) / 2
    y := rect.y + (rect.h - src.h) / 2
    push_quad({x, y, src.w, src.h}, src, color)
}

flush :: proc() {
    if buf_idx == 0 do return
    defer buf_idx = 0
    //projection = la.mat4(1)
    //gl.UniformMatrix4fv(gl.GetUniformLocation(vs, "projection"), 1, gl.FALSE, cast([^]f32)&projection)

    verts := vertices[:buf_idx * 4]
    indxs := indices[:buf_idx * 6]
    modify_vbo(vbo, verts)
    modify_ebo(ebo, indxs)

    // 1. Bind texture
    gl.BindTexture(gl.TEXTURE_2D, tex)

    // 2. Bind VAO
    gl.BindVertexArray(vao)

    // 3. Draw
    //gl.DrawElementsInstancedBaseVertex(gl.TRIANGLES, buf_idx * 6, gl.UNSIGNED_INT, nil, 1, 0)
    gl.DrawElementsBaseVertex(gl.TRIANGLES, buf_idx * 6, gl.UNSIGNED_INT, nil, 0)
    //gl.DrawElements(gl.TRIANGLES, buf_idx * 6, gl.UNSIGNED_INT, &indices)
}

init_mu_backend :: proc(ctx: ^mu.Context, loc := #caller_location) {
    using gl

    mu.init(ctx)
    ctx._style.colors[.WINDOW_BG].a = 124
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

    gl.debug_helper(loc, 0)
}


mu_test_window :: proc(ctx: ^mu.Context) {
    mu.begin(ctx)
    defer mu.end(ctx)

    if mu.window(ctx, "My Window", mu.Rect{ 10, 10, 140, 86 }) {
        mu.layout_row(ctx, []i32{ 60, -1 })

        mu.label(ctx, "First:");
        if .SUBMIT in mu.button(ctx, "Button1") {
            fmt.println("Button1 pressed");
        }

        mu.label(ctx, "Second:");
        if .SUBMIT in mu.button(ctx, "Button2") {
            mu.open_popup(ctx, "My Popup");
        }

        if mu.popup(ctx, "My Popup") {
            mu.label(ctx, "Hello world!");
        }

    }
}

mu_draw_events :: proc(ctx: ^mu.Context) {
    commands: ^mu.Command
    for var in mu.next_command_iterator(ctx, &commands) {
        switch cmd in var {
        case ^mu.Command_Text: draw_text(cmd.str, cmd.pos, cmd.color)
        case ^mu.Command_Rect: draw_rect(cmd.rect, cmd.color)
        case ^mu.Command_Icon: draw_icon(cast(int)cmd.id, cmd.rect, cmd.color)
        case ^mu.Command_Clip: flush()
        case ^mu.Command_Jump: unreachable()
        }

        flush()
    }
}


when ODIN_ARCH == .amd64 || ODIN_ARCH == .i386 {
	vertex_shader: cstring = 
`#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 col;
layout (location = 2) in vec2 tex;

out vec4 vertex_color;
out vec2 tex_coords;

void main() {
    gl_Position  = vec4(pos, 0.0, 1.0);
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
layout (location = 0) in vec3 position;
layout (location = 1) in vec4 color;
layout (location = 2) in vec2 tex;

out vec4 vertex_color;
out vec2 tex_coords;

uniform mat4 projection;

void main() {
    gl_Position  = projection * vec4(pos, 1.0);
    vertex_color = color;
    tex_coords   = tex; 
}`
    fragment_shader: cstring = 
`#version 300 es
in vec4 vertex_color;
in vec2 tex_coords;

out vec4 frag_color;

uniform sampler2D atlas;

void main() {
    frag_color = texture(atlas, tex_coords) * vertex_color;
}`
}
