//+build i386, amd64
package main

import "core:fmt"
import gl "vendor:opengl"

@(private="file")
gl_data_formats := [Data_Format]u32 { 
	.RG32_FLOAT   = gl.RG32F, 
	.RGB32_FLOAT  = gl.RGB32F,  
	.RGB32_UINT   = gl.RGB32UI, 
	.RGBA8_UNORM  = gl.RGBA, 
	.RGBA32_FLOAT = gl.RGBA32F, 
	.RGBA32_UINT  = gl.RGBA32UI, 
}
@(private="file")
gl_memory_model := [Memory_Model]u32 {
	.GPU     = gl.STATIC_DRAW, 
	.GPU_CPU = gl.DYNAMIC_DRAW,
}
@(private="file")
gl_buffer_usage := [Buffer_Usage]u32 {
	.VERTEX  = gl.ARRAY_BUFFER, 
	.INDEX   = gl.ELEMENT_ARRAY_BUFFER,
	.UNIFORM = gl.UNIFORM_BUFFER,
}
//@(private="file")
texture_ids: map[Handle(Texture)]u32
//@(private="file")
buffer_ids:  map[Handle(Buffer)]u32
//@(private="file")
shader_ids:  map[Handle(Shader)]u32
//@(private="file")
bind_group_ids: map[Handle(Bind_Group)]u32

// Buffer procs

create_buffer :: proc(using buffer: Buffer) -> Handle(Buffer) {
	using gl
	id: u32
	GenBuffers(1, &id)
	BindBuffer(gl_buffer_usage[usage], id)
	defer BindBuffer(gl_buffer_usage[usage], 0)

	BufferData(gl_buffer_usage[usage], 
			len(initial_data) if len(initial_data) > 0 else int(byte_width), 
			raw_data(initial_data), gl_memory_model[memory_model])

	if usage == .UNIFORM {
		BindBufferRange(gl_buffer_usage[usage], 0, id, 0, int(byte_width))
	}

	append(&buffers_pool, buffer)
	handle := Handle(Buffer){ len(buffers_pool) - 1 }
	buffer_ids[handle] = id
	return handle
}

modify_buffer :: proc(buf: Handle(Buffer), new_data: []u8) {
	assert(buf.index >= 0 && buf.index < len(buffers_pool))
	using gl
	using buffer := &buffers_pool[buf.index]

	id := buffer_ids[buf]
	BindBuffer(gl_buffer_usage[usage], id)
	// Never unbind EBO before VAO in OpenGL
	defer if usage != .INDEX { 
		BindBuffer(gl_buffer_usage[usage], 0)
	}

	BufferSubData(gl_buffer_usage[usage], 0, len(new_data), raw_data(new_data))
}

// Texture procs

create_texture :: proc(using texture: Texture) -> Handle(Texture) {
	using gl
	id: u32
	GenTextures(1, &id)
	BindTexture(TEXTURE_2D, id)
	defer BindTexture(TEXTURE_2D, 0)
	
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_S, REPEAT)
	TexParameteri(TEXTURE_2D, TEXTURE_WRAP_T, REPEAT)
	TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR_MIPMAP_LINEAR)
	TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR)

	data_type: u32
	#partial switch format {
	case .RGBA8_UNORM:                data_type = UNSIGNED_BYTE
	case .RGB32_FLOAT, .RGBA32_FLOAT: data_type = FLOAT
	case .RGB32_UINT,  .RGBA32_UINT:  data_type = UNSIGNED_INT
	}

	TexImage2D(TEXTURE_2D, 0, i32(gl_data_formats[format]), dimensions.x, dimensions.y, 
				0, gl_data_formats[format], data_type, raw_data(initial_data))
	GenerateMipmap(TEXTURE_2D)

	append(&textures_pool, texture)
	handle := Handle(Texture){ len(textures_pool) - 1 }
	texture_ids[handle] = id

	return handle
}

// Shader procs

create_shader :: proc(shader: Shader) -> Handle(Shader) {
	using gl
	using shader := shader

	vs := CreateShader(VERTEX_SHADER)
	ShaderSource(vs, 1, &vs_source, nil)
	CompileShader(vs)
	{
		succ: i32
		GetShaderiv(vs, COMPILE_STATUS, &succ)
		if succ == 0 do panic("Vertex shader is not compiled")
	}

	ps := CreateShader(FRAGMENT_SHADER)
	ShaderSource(ps, 1, &ps_source, nil)
	CompileShader(ps)
	{
		succ: i32
		GetShaderiv(ps, COMPILE_STATUS, &succ)
		if succ == 0 do panic("Fragment shader is not compiled")
	}

	prog := CreateProgram()
	AttachShader(prog, vs)
	AttachShader(prog, ps)
	LinkProgram(prog)
	{
		succ: i32
		GetProgramiv(prog, LINK_STATUS, &succ);
		if succ == 0 do panic("Shader program is not linked")
	}

	append(&shaders_pool, shader)
	handle := Handle(Shader){ len(shaders_pool) - 1 }
	shader_ids[handle] = prog

	return handle
}

bind_uniforms :: proc(shd: Handle(Shader), name: cstring) {
	assert(shd.index >= 0 && shd.index < len(shaders_pool))
	using gl

	id := shader_ids[shd]
	uniform_block_index := GetUniformBlockIndex(id, name)
	UniformBlockBinding(id, uniform_block_index, 0)
}

set_shader :: proc(shader: Handle(Shader)) {
	gl.UseProgram(shader_ids[shader])
}

// Bind Group procs

create_bind_group :: proc(using bind_group: Bind_Group) -> Handle(Bind_Group) {
	using gl
	id: u32
	GenVertexArrays(1, &id)
	BindVertexArray(id)
	defer BindVertexArray(0)

	for buf, n in vertex_buffers {
		id := buffer_ids[buf]
		buffer := &buffers_pool[buf.index]
		BindBuffer(gl_buffer_usage[buffer.usage], id)

		for attr, i in attributes[n] {
			// HACK: hardcoded size_of(f32)
			VertexAttribPointer(u32(i), data_format_sizes[attr.format] / size_of(f32), 
						FLOAT, FALSE, buffer.byte_width, uintptr(attr.offset))
			EnableVertexAttribArray(u32(i))
		}
	}

	append(&bind_groups_pool, bind_group)
	handle := Handle(Bind_Group){ len(bind_groups_pool) - 1 }
	bind_group_ids[handle] = id

	return handle
}

set_bind_group :: proc(bg: Handle(Bind_Group)) {
	assert(bg.index >= 0 && bg.index < len(bind_groups_pool))
	using gl

	BindVertexArray(bind_group_ids[bg])
	
}
