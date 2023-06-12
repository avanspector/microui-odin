package main

import "core:slice"
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

// Buffers
vertices : [BUFFER * 4]Vertex
indices  : [BUFFER * 6]u32
buf_idx  : i32

// Bind group
vao,
// Shader handles
prog: u32

vbo_buf, ebo_buf: Handle(Buffer)
tex_buf: Handle(Texture)
shader: Handle(Shader)

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
    using gl
    if buf_idx == 0 do return
    defer buf_idx = 0

    UseProgram(prog)

    projection := la.matrix_ortho3d(0, f32(vp_width), f32(vp_height), 0, -1, 1, false)
    Uniform1i(GetUniformLocation(prog, "atlas_texture"), 0)
    UniformMatrix4fv(GetUniformLocation(prog, "projection"), 1, FALSE, cast([^]f32)&projection)

    verts := vertices[:buf_idx * 4]
    indxs := indices[:buf_idx * 6]
    modify_buffer(vbo_buf, slice.to_bytes(verts))
    modify_buffer(ebo_buf, slice.to_bytes(indxs))

    // 1. Bind texture
    BindTexture(TEXTURE_2D, texture_ids[tex_buf])

    // 2. Bind VAO
    BindVertexArray(vao)

    // 3. Draw
    //gl.DrawElementsInstancedBaseVertex(gl.TRIANGLES, buf_idx * 6, gl.UNSIGNED_INT, nil, 1, 0)
    DrawElementsBaseVertex(TRIANGLES, buf_idx * 6, UNSIGNED_INT, nil, 0)
}

init_mu_backend :: proc(ctx: ^mu.Context) {
    using gl

    Enable(BLEND)
    //BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA)
    //BlendFuncSeparate(SRC_ALPHA, ONE_MINUS_SRC_ALPHA, ONE, ONE_MINUS_SRC_ALPHA)
    BlendFuncSeparate(SRC_ALPHA, ONE_MINUS_SRC_ALPHA, ONE, ONE)

    Disable(CULL_FACE)
    Disable(DEPTH_TEST)
    DepthMask(FALSE)

    mu.init(ctx)
    ctx.text_width  = mu.default_atlas_text_width
    ctx.text_height = mu.default_atlas_text_height

    GenVertexArrays(1, &vao)
    BindVertexArray(vao)
    defer BindVertexArray(0)

    vbo_buf = create_buffer({
        data = slice.to_bytes(vertices[:]),
        byte_width = size_of(Vertex),
        attributes = {
            { offset = 0,  format = .RG32_FLOAT },
            { offset = 8,  format = .RGBA32_FLOAT },
            { offset = 24, format = .RG32_FLOAT },
        },
        usage = .VERTEX,
        memory_model = .GPU_CPU,
    })

    ebo_buf = create_buffer({
        data = slice.to_bytes(indices[:]),
        byte_width = size_of(u32),
        attributes = {},
        usage = .INDEX,
        memory_model = .GPU_CPU,
    })

    pixels := make([][4]byte, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    defer delete(pixels)
    
    for alpha, i in mu.default_atlas_alpha {
        pixels[i] = { 255, 255, 255, alpha }
    }

    tex_buf = create_texture({
        data = slice.to_bytes(pixels),
        dimensions = { mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT },
        format = .RGBA8_UNORM,
    })

    shader, prog = create_shader({
        vs_source = vertex_shader, 
        ps_source = fragment_shader,
    })
}

mu_test_window :: proc(ctx: ^mu.Context) {
    mu.begin(ctx)
    defer mu.end(ctx)

    panel_width: i32 = 270
    wind := mu.get_container(ctx, "My Window")
    wind.rect = { vp_width - panel_width, 0, panel_width, vp_height }

    if mu.window(ctx, "My Window", {}, { .NO_CLOSE, .NO_RESIZE, .NO_TITLE }) {
        mu.layout_height(ctx, 50)

        if mu.layout_column(ctx) {
            if .SUBMIT in mu.button(ctx, "Open", mu.Icon('F')) {}
            if .SUBMIT in mu.button(ctx, "Save", mu.Icon('H')) {}
        }

        if mu.layout_column(ctx) {
            if .SUBMIT in mu.button(ctx, "Open", mu.Icon('F')) {}
            if .SUBMIT in mu.button(ctx, "Save", mu.Icon('H')) {}
        }

        if mu.layout_column(ctx) {
            if .SUBMIT in mu.button(ctx, "Open", mu.Icon('F')) {}
            if .SUBMIT in mu.button(ctx, "Save", mu.Icon('H')) {}
        }
        
        mu.layout_set_next(ctx, { 0, vp_height - 60, 0, 0 }, true)
        if mu.layout_column(ctx) {
            mu.layout_height(ctx, 20)
            if .SUBMIT in mu.button(ctx, "Open", mu.Icon('F')) {}
            if .SUBMIT in mu.button(ctx, "Save", mu.Icon('H')) {}
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
    if (frag_color.a == 0.0) discard;
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
