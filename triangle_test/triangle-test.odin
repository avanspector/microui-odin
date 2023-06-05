package main

import la "core:math/linalg/glsl"
import gl "vendor:opengl"
import mu "vendor:microui"

Vertex :: struct {
	pos: la.vec2,
	col: la.vec4,
	tex: la.vec2,
}

// Buffers
vertices := [?]Vertex {
	{ pos = {  0.5,  0.5 }, col = { 1.0, 0.0, 0.0, 1.0 }, tex = { 1.0, 1.0 } },
	{ 		{  0.5, -0.5 }, 	  { 0.0, 1.0, 0.0, 1.0 }, 		{ 1.0, 0.0 } },
	{ 		{ -0.5, -0.5 }, 	  { 0.0, 0.0, 1.0, 1.0 }, 		{ 0.0, 0.0 } },
	{ 		{ -0.5,  0.5 }, 	  { 1.0, 1.0, 0.0, 1.0 }, 		{ 0.0, 1.0 } },
}
indices := [?]u32 {
	0, 1, 3,
	1, 2, 3,
}

// Buffer handles
vao, vbo, ebo,
// Shader handles
vs, fs, prog,
// Texture handles
tex: u32


init_triangle_test :: proc() {
	using gl
	GenVertexArrays(1, &vao)
    BindVertexArray(vao)
    defer BindVertexArray(0)

    vbo = create_vbo(vertices[:])
    ebo = create_ebo(indices[:])
    tex = create_rgba_texture(mu.default_atlas_alpha[:], mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT)

    vs   = create_vertex_shader(&vertex_shader)
    fs   = create_fragment_shader(&fragment_shader)
    prog = create_shader_program(vs, fs)
}

draw_triangle_test :: proc() {
	using gl

	UseProgram(prog)
	
	BindTexture(TEXTURE_2D, tex)

	BindVertexArray(vao)

	DrawElements(TRIANGLES, 6, UNSIGNED_INT, nil)
}


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
