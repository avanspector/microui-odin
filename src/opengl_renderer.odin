//+build i386, amd64
package main

import la "core:math/linalg/glsl"
import gl "vendor:opengl"

// Buffer procs

create_vbo :: proc(vert_data: []Vertex) -> (buf_id: u32) {
	using gl
	GenBuffers(1, &buf_id)
	BindBuffer(ARRAY_BUFFER, buf_id)
	defer BindBuffer(ARRAY_BUFFER, 0)

	BufferData(ARRAY_BUFFER, len(vert_data) * size_of(Vertex), raw_data(vert_data), DYNAMIC_DRAW)
	VertexAttribPointer(0, len(Vertex{}.pos), FLOAT, FALSE, size_of(Vertex), offset_of(Vertex, pos))
	VertexAttribPointer(1, len(Vertex{}.col), FLOAT, FALSE, size_of(Vertex), offset_of(Vertex, col))
	VertexAttribPointer(2, len(Vertex{}.tex), FLOAT, FALSE, size_of(Vertex), offset_of(Vertex, tex))
    EnableVertexAttribArray(0)
    EnableVertexAttribArray(1)
    EnableVertexAttribArray(2)
 
	return buf_id
}

modify_vbo :: proc(buf_id: u32, vert_data: []Vertex) {
	using gl
	BindBuffer(ARRAY_BUFFER, buf_id)
	defer BindBuffer(ARRAY_BUFFER, 0)

	BufferSubData(ARRAY_BUFFER, 0, len(vert_data) * size_of(Vertex), raw_data(vert_data))
}

create_ebo :: proc(indx_data: []u32) -> (buf_id: u32) {
	using gl
	GenBuffers(1, &buf_id)
	BindBuffer(ELEMENT_ARRAY_BUFFER, buf_id)
	// Never unbind EBO before VAO
	//defer BindBuffer(ELEMENT_ARRAY_BUFFER, 0)

	BufferData(ELEMENT_ARRAY_BUFFER, len(indx_data) * size_of(u32), raw_data(indx_data), DYNAMIC_DRAW)

	return buf_id
}

modify_ebo :: proc(buf_id: u32, indx_data: []u32) {
	using gl
	BindBuffer(ELEMENT_ARRAY_BUFFER, buf_id)
	// Never unbind EBO before VAO
	//defer BindBuffer(ELEMENT_ARRAY_BUFFER, 0)

	BufferSubData(ELEMENT_ARRAY_BUFFER, 0, len(indx_data) * size_of(u32), raw_data(indx_data))
}

destroy_buffer :: proc(buf_id: ^u32) {
    gl.DeleteBuffers(1, buf_id)
}

// Texture procs

create_rgba_texture :: proc(tex_data: []byte, width, height: i32) -> (tex_id: u32) {
	using gl
	GenTextures(1, &tex_id)
	BindTexture(TEXTURE_2D, tex_id)
	defer BindTexture(TEXTURE_2D, 0)
		
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_S, REPEAT)
    TexParameteri(TEXTURE_2D, TEXTURE_WRAP_T, REPEAT)
    TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR_MIPMAP_LINEAR)
    TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR)

	TexImage2D(TEXTURE_2D, 0, RGBA, width, height, 0, RGBA, UNSIGNED_BYTE, raw_data(tex_data))
	GenerateMipmap(TEXTURE_2D)
	
	return tex_id
}

destroy_texture :: proc(tex_id: ^u32) {
    gl.DeleteTextures(1, tex_id)
}

// Shader procs

create_vertex_shader :: proc(vs_data: ^cstring) -> (vs_id: u32) {
	using gl
	vs_id = CreateShader(VERTEX_SHADER)
	ShaderSource(vs_id, 1, vs_data, nil)
	CompileShader(vs_id)

	succ: i32
	GetShaderiv(vs_id, COMPILE_STATUS, &succ)
	if succ == 0 do panic("Vertex shader is not compiled")

	return vs_id
}

create_fragment_shader :: proc(fs_data: ^cstring) -> (fs_id: u32) {
	using gl
	fs_id = CreateShader(FRAGMENT_SHADER)
	ShaderSource(fs_id, 1, fs_data, nil)
	CompileShader(fs_id)

	succ: i32
	GetShaderiv(fs_id, COMPILE_STATUS, &succ)
	if succ == 0 do panic("Fragment shader is not compiled")

	return fs_id
}

create_shader_program :: proc(vs, fs: u32) -> (prog_id: u32) {
	using gl
	prog_id = CreateProgram()
	AttachShader(prog_id, vs)
	AttachShader(prog_id, fs)
	LinkProgram(prog_id)

	succ: i32
	GetProgramiv(prog_id, LINK_STATUS, &succ);
	if succ == 0 do panic("Shader program is not linked")

	return prog_id
}

delete_shader_program :: proc(prog_id: u32) {
	gl.DeleteProgram(prog_id)
}
