package main

import "core:fmt"
import "core:slice"
import la  "core:math/linalg"
import glm "core:math/linalg/glsl"
import mu  "vendor:microui"

import "rdr"

Vertex :: struct {
	pos: glm.vec2,
	col: glm.vec4,
	tex: glm.vec2,
}

Uniforms_Matrices :: struct {
	projection: glm.mat4,
}

BUFFER :: 128 * 128

// Buffers
vertices : [BUFFER * 4]Vertex
indices  : [BUFFER * 6]u32
buf_idx  : u32

// Handles
microui_atlas: rdr.Handle(rdr.Bind_Group)
microui_vbo, micrui_ebo, microui_uniform: rdr.Handle(rdr.Buffer)
microui_atlas_tex: rdr.Handle(rdr.Texture)
microui_shader: rdr.Handle(rdr.Shader)

vp_width, vp_height: i32 = 1024, 768

ctx: mu.Context

create_mu_resources :: proc() {
	using rdr

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	defer delete(pixels)
	
	for alpha, i in mu.default_atlas_alpha {
		pixels[i] = { 255, 255, 255, alpha }
	}

	microui_atlas_tex = create_texture({
		name = "atlas_texture",
		initial_data = slice.to_bytes(pixels),
		dimensions = { mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT },
		format = .RGBA8_UNORM,
	})

	microui_vbo = create_buffer({
		initial_data = slice.to_bytes(vertices[:]),
		byte_width = size_of(Vertex),
		usage = .VERTEX,
		memory_model = .GPU_CPU,
	})

	micrui_ebo = create_buffer({
		initial_data = slice.to_bytes(indices[:]),
		byte_width = size_of(u32),
		usage = .INDEX,
		memory_model = .GPU_CPU, 
	})

	microui_uniform = create_buffer({
		name = "view_matrices",
		initial_data = nil,
		byte_width = size_of(Uniforms_Matrices),
		usage = .UNIFORM,
		memory_model = .GPU_CPU,
	})

	microui_atlas = create_bind_group({
		name = "Microui Atlas",
		uniforms = { microui_uniform },
		textures = { microui_atlas_tex },
	})

	microui_shader = create_shader({
		vs_source = vertex_shader, 
		ps_source = fragment_shader,
		vertex_buffers = { microui_vbo },
		vertex_buffers_layout = {
			{ byte_width = size_of(Vertex), attributes = {
				{ offset = 0,  format = .RG32_FLOAT },
				{ offset = 8,  format = .RGBA32_FLOAT },
				{ offset = 24, format = .RG32_FLOAT },
			}},
		},
		render_state = {
			blend_mode = .EXCLUDE_ALPHA,
			depth_test = .NONE,
			cull_mode  = .NONE,
		},
	})
}

init_mu_backend :: proc(ctx: ^mu.Context) {
	mu.init(ctx)
	ctx.text_width  = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height
}

mu_render :: proc() {
	if buf_idx == 0 do return
	defer buf_idx = 0

	uniforms := Uniforms_Matrices {
		projection = la.matrix_ortho3d(0, f32(vp_width), f32(vp_height), 0, -1, 1, false)
	}
	verts := vertices[:buf_idx * 4]
	indxs := indices[:buf_idx * 6]

	rdr.draw_from_command_buffer({
		shader = microui_shader,
		bind_group = microui_atlas,
		vertex_buffer = microui_vbo,
		index_buffer = micrui_ebo,
		uniform_buffer = microui_uniform,
		vertex_data = slice.to_bytes(verts),
		index_data = slice.to_bytes(indxs),
		uniform_data = slice.bytes_from_ptr(&uniforms, size_of(uniforms)),
	})
}


push_quad_impl :: proc(dst, src: mu.Rect, color: mu.Color) {
	if buf_idx == BUFFER do buf_idx = 0

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

mu_register_events :: proc(ctx: ^mu.Context) {
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
}

clip_rect_impl :: proc(rect: mu.Rect) {
	rdr.set_scissor_view(rect.x, rect.y, rect.w, rect.h)
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

	if mu.window(ctx, "Another LOL", { 40, 40, 300, 450 }) {
		if .ACTIVE in mu.header(ctx, "Window Info") {
			win := mu.get_current_container(ctx)
			mu.layout_row(ctx, {54, -1}, 0)
			mu.label(ctx, "Position:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.x, win.rect.y))
			mu.label(ctx, "Size:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.w, win.rect.h))
		}

		mu.layout_height(ctx, 50)

		if mu.layout_column(ctx) {
			if .SUBMIT in mu.button(ctx, "Open", mu.Icon('F')) {}
			if .SUBMIT in mu.button(ctx, "Save", mu.Icon('H')) {}
		}
	}
}


@(private="file")
vertex_shader: cstring = 
`#version 330 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 col;
layout (location = 2) in vec2 tex;

out vec4 vertex_color;
out vec2 tex_coords;

layout (std140) uniform view_matrices {
	mat4 projection;
};

void main() {
	gl_Position  = projection * vec4(pos, 0.0, 1.0);
	vertex_color = col;
	tex_coords   = tex; 
}`
@(private="file")
fragment_shader: cstring = 
`#version 330 core
in vec4 vertex_color;
in vec2 tex_coords;

out vec4 frag_color;

uniform sampler2D atlas_texture;

void main() {
	frag_color = texture(atlas_texture, tex_coords) * vertex_color;
	if (frag_color.a < 0.1) discard;
}`
