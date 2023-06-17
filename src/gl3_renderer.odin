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
	.GPU_CPU = gl.DYNAMIC_DRAW, // HINT: Maybe try STREAM_DRAW?
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

create_buffer :: proc(buffer: Buffer) -> Handle(Buffer) {
	using gl
	buffer_usage := gl_buffer_usage[buffer.usage]

	id: u32
	GenBuffers(1, &id)
	BindBuffer(buffer_usage, id)
	defer BindBuffer(buffer_usage, 0)
	{
		using buffer

		BufferData(buffer_usage, 
			len(initial_data) if len(initial_data) > 0 else int(byte_width), 
			raw_data(initial_data), gl_memory_model[memory_model])

		if usage == .UNIFORM {
			BindBufferRange(buffer_usage, 0, id, 0, int(byte_width))
		}
	}
	handle := add_resource(buffer)
	buffer_ids[handle] = id
	return handle
}

modify_buffer :: proc(buf: Handle(Buffer), new_data: []u8) {
	using gl
	
	buffer := get_resource(buf)
	if buffer == nil do return
	buffer_usage := gl_buffer_usage[buffer.usage]

	id := buffer_ids[buf]
	BindBuffer(buffer_usage, id)
	defer if buffer.usage != .INDEX { // HINT: Never unbind EBO before VAO in OpenGL.
		BindBuffer(buffer_usage, 0)
	}

	BufferSubData(buffer_usage, 0, len(new_data), raw_data(new_data))
}

// Texture procs

create_texture :: proc(texture: Texture) -> Handle(Texture) {
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
	#partial switch texture.format {
	case .RGBA8_UNORM:                data_type = UNSIGNED_BYTE
	case .RGB32_FLOAT, .RGBA32_FLOAT: data_type = FLOAT
	case .RGB32_UINT,  .RGBA32_UINT:  data_type = UNSIGNED_INT
	}
	
	data_format := gl_data_formats[texture.format]
	TexImage2D(TEXTURE_2D, 0, i32(data_format), 
			texture.dimensions.x, texture.dimensions.y, 0,
			data_format, data_type, raw_data(texture.initial_data))
	GenerateMipmap(TEXTURE_2D)

	handle := add_resource(texture)
	texture_ids[handle] = id
	return handle
}

// Shader procs

create_shader :: proc(shader: Shader) -> Handle(Shader) {
	using gl
	shader := shader

	vs := CreateShader(VERTEX_SHADER)
	ShaderSource(vs, 1, &shader.vs_source, nil)
	CompileShader(vs)
	{
		succ: i32
		GetShaderiv(vs, COMPILE_STATUS, &succ)
		if succ == 0 do panic("Vertex shader is not compiled")
	}

	ps := CreateShader(FRAGMENT_SHADER)
	ShaderSource(ps, 1, &shader.ps_source, nil)
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

	handle := add_resource(shader)
	shader_ids[handle] = prog
	return handle
}

// Bind Group procs

create_bind_group :: proc(bind_group: Bind_Group) -> Handle(Bind_Group) {
	assert(len(bind_group.attributes) == len(bind_group.vbos))
	using gl

	id: u32
	GenVertexArrays(1, &id)
	BindVertexArray(id)
	defer BindVertexArray(0)

	BindBuffer(gl_buffer_usage[.INDEX], buffer_ids[ebo])

	for buf, n in bind_group.vbos {
		id := buffer_ids[buf]
		buffer := get_resource(buf)
		BindBuffer(gl_buffer_usage[.VERTEX], id)
		defer BindBuffer(gl_buffer_usage[.VERTEX], 0)

		for attr, i in bind_group.attributes[n] {
			// HACK: hardcoded size_of(f32)
			VertexAttribPointer(u32(i), data_format_sizes[attr.format] / size_of(f32), 
						FLOAT, FALSE, buffer.byte_width, uintptr(attr.offset))
			EnableVertexAttribArray(u32(i))
		}
	}

	prog := shader_ids[bind_group.shader]
	for ubo, i in bind_group.uniforms {
		buffer := get_resource(ubo)
		BindBuffer(gl_buffer_usage[.UNIFORM], id)
		defer BindBuffer(gl_buffer_usage[.UNIFORM], 0)

		uniform_block_index := GetUniformBlockIndex(prog, buffer.name)
		UniformBlockBinding(prog, uniform_block_index, u32(i))
	}
	UseProgram(prog)
	for tex, i in bind_group.textures {
		tex_name := get_resource(tex).name
		ActiveTexture(TEXTURE0 + u32(i))
		BindTexture(TEXTURE_2D, texture_ids[tex])
		Uniform1i(GetUniformLocation(prog, tex_name), i32(i))
		fmt.println(tex, tex_name, i)
	}

	handle := add_resource(bind_group)
	bind_group_ids[handle] = id
	return handle
}

set_bind_group :: proc(bg: Handle(Bind_Group)) {
	using gl

	bind_group := get_resource(bg)

	UseProgram(shader_ids[bind_group.shader])
	BindVertexArray(bind_group_ids[bg])

	//for tex, i in bind_group.textures {
	//	ActiveTexture(TEXTURE0 + u32(i))
	//	BindTexture(TEXTURE_2D, texture_ids[tex])
	//}
}
