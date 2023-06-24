package base_backend_opengl33core

import "../../../rdr/base"
import gl "vendor:opengl"

Handle  :: base.Handle
Buffer  :: base.Buffer
Texture :: base.Texture
Shader  :: base.Shader
Bind_Group :: base.Bind_Group
Command_Buffer :: base.Command_Buffer 

@(private)
gl_data_formats := [base.Data_Format]u32 { 
	.RG32_FLOAT   = gl.RG32F, 
	.RGB32_FLOAT  = gl.RGB32F,  
	.RGB32_UINT   = gl.RGB32UI, 
	.RGBA8_UNORM  = gl.RGBA, 
	.RGBA32_FLOAT = gl.RGBA32F, 
	.RGBA32_UINT  = gl.RGBA32UI, 
}

@(private)
gl_memory_model := [base.Memory_Model]u32 {
	.GPU     = gl.STATIC_DRAW, 
	.GPU_CPU = gl.DYNAMIC_DRAW, // HINT: Maybe try STREAM_DRAW?
}

@(private)
gl_buffer_usage := [base.Buffer_Usage]u32 {
	.VERTEX  = gl.ARRAY_BUFFER, 
	.INDEX   = gl.ELEMENT_ARRAY_BUFFER,
	.UNIFORM = gl.UNIFORM_BUFFER,
}

@(private)
texture_ids: map[Handle(Texture)]u32
@(private)
buffer_ids:  map[Handle(Buffer)]u32
@(private)
shader_ids:  map[Handle(Shader)]u32
@(private)
vao_ids: map[Handle(Shader)]u32

set_viewport_view :: proc "contextless" (x, y, w, h: i32) {
	gl.Viewport(x, y, w, h)
}

set_scissor_view :: proc "contextless" (x, y, w, h: i32) {
	gl.Scissor(x, y, w, h)
}

clear_background :: proc "contextless" (r, g, b, a: f32) {
	gl.ClearColor(r, g, b, a)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

init_rdr :: proc() {
	gl.Enable(gl.SCISSOR_TEST)
}

// Buffer procs

create_buffer :: proc(buffer: Buffer) -> Handle(Buffer) {
	using gl
	buf_usage := gl_buffer_usage[buffer.usage]

	id: u32
	GenBuffers(1, &id)
	BindBuffer(buf_usage, id)
	defer BindBuffer(buf_usage, 0)
	{
		using buffer

		BufferData(buf_usage, 
			len(initial_data) if len(initial_data) > 0 else int(byte_width), 
			raw_data(initial_data), gl_memory_model[memory_model])

		if usage == .UNIFORM {
			BindBufferRange(buf_usage, 0, id, 0, int(byte_width))
		}
	}
	handle := base.add_resource(buffer)
	buffer_ids[handle] = id
	return handle
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
	switch texture.format {
	case .RGBA8_UNORM:                             data_type = UNSIGNED_BYTE
	case .RG32_FLOAT, .RGB32_FLOAT, .RGBA32_FLOAT: data_type = FLOAT
	case .RGB32_UINT,  .RGBA32_UINT:               data_type = UNSIGNED_INT
	}
	
	data_format := gl_data_formats[texture.format]
	TexImage2D(TEXTURE_2D, 0, i32(data_format), 
			texture.dimensions.x, texture.dimensions.y, 0,
			data_format, data_type, raw_data(texture.initial_data))
	GenerateMipmap(TEXTURE_2D)

	handle := base.add_resource(texture)
	texture_ids[handle] = id
	return handle
}

// Shader procs

create_shader :: proc(shader: Shader) -> Handle(Shader) {
	using gl
	shader := shader

	// Shader compilation
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

	// VAO and vertex buffers layout
	vao: u32
	GenVertexArrays(1, &vao)
	BindVertexArray(vao)
	defer BindVertexArray(0)

	attr_idx: u32
	for buf in shader.vertex_buffers {
		id := buffer_ids[buf]
		BindBuffer(gl_buffer_usage[.VERTEX], id)
		defer BindBuffer(gl_buffer_usage[.VERTEX], 0)

		for buf_layout in shader.vertex_buffers_layout {
			for attr in buf_layout.attributes {
				data_type: u32; type_size: i32
				switch attr.format {
				case .RGBA8_UNORM:                
					data_type = UNSIGNED_BYTE
					type_size = size_of(u8)
				case .RGB32_UINT, .RGBA32_UINT:  
					data_type = UNSIGNED_INT
					type_size = size_of(u32)
				case .RG32_FLOAT, .RGB32_FLOAT, .RGBA32_FLOAT: 
					data_type = FLOAT
					type_size = size_of(f32)
				}
				VertexAttribPointer(attr_idx, base.data_sizes[attr.format]/type_size, 
						data_type, FALSE, buf_layout.byte_width, uintptr(attr.offset))
				EnableVertexAttribArray(attr_idx)
				attr_idx += 1
			}
		}
	}

	// Render modes and states
	switch shader.render_state.blend_mode {
		case .NONE: Disable(BLEND)
		case .EXCLUDE_ALPHA: 
			Enable(BLEND) 
			BlendFuncSeparate(SRC_ALPHA, ONE_MINUS_SRC_ALPHA, ONE, ONE)
	}
	#partial switch shader.render_state.depth_test {
		case .NONE: Disable(DEPTH_TEST); DepthMask(FALSE)
		case .LESS: Enable(DEPTH_TEST); DepthFunc(LESS)
	}
	#partial switch shader.render_state.cull_mode {
		case .NONE: Disable(CULL_FACE)
	}

	handle := base.add_resource(shader)
	shader_ids[handle] = prog
	vao_ids[handle] = vao
	return handle
}

// Bind Group procs

create_bind_group :: proc(bind_group: Bind_Group) -> Handle(Bind_Group) {
	handle := base.add_resource(bind_group)
	return handle
}

@(private)
bind_group_to_shader :: proc(bind_group: Bind_Group, prog: u32) {
	using gl
	
	for ubo, i in bind_group.uniforms {
		buffer := base.get_resource(ubo)
		if buffer == nil do panic("UBO is nil")

		uniform_block_index := GetUniformBlockIndex(prog, buffer.name)
		UniformBlockBinding(prog, uniform_block_index, u32(i))
	}
	
	for tex, i in bind_group.textures {
		tex_name := base.get_resource(tex).name
		ActiveTexture(TEXTURE0 + u32(i))
		BindTexture(TEXTURE_2D, texture_ids[tex])
		Uniform1i(GetUniformLocation(prog, tex_name), i32(i))
	}
}

// Command Buffer procs

draw_from_command_buffer :: proc(cmd: Command_Buffer) {
	using gl

	@static cache: struct {
		using command_buffer: Command_Buffer,
		vao, vbo, ebo, ubo, prog: u32,
	}

	if shader, ok := cmd.shader.?; ok {
		if cmd.shader != cache.shader { 
			cache.prog = shader_ids[shader]
			cache.vao = vao_ids[shader]
			UseProgram(cache.prog)
			BindVertexArray(cache.vao)
		}
	}

	if bind_group, ok := cmd.bind_group.?; ok { 
		if cmd.bind_group != cache.bind_group {
			cache.bind_group = cmd.bind_group
			bg := base.get_resource(bind_group)
			bind_group_to_shader(bg^, cache.prog)
		}
	}

	if vertex_buffer, ok := cmd.vertex_buffer.?; ok {
		if cmd.vertex_buffer != cache.vertex_buffer {
			cache.vertex_buffer = cmd.vertex_buffer
			cache.vbo = buffer_ids[vertex_buffer]
		}
		BindBuffer(gl_buffer_usage[.VERTEX], cache.vbo)
		defer BindBuffer(gl_buffer_usage[.VERTEX], 0)

		BufferSubData(gl_buffer_usage[.VERTEX], 0, 
				len(cmd.vertex_data), raw_data(cmd.vertex_data))
	}

	if uniform_buffer, ok := cmd.uniform_buffer.?; ok {
		if cmd.uniform_buffer != cache.uniform_buffer {
			cache.uniform_buffer = cmd.uniform_buffer
			cache.ubo = buffer_ids[uniform_buffer]
		}
		BindBuffer(gl_buffer_usage[.UNIFORM], cache.ubo)
		defer BindBuffer(gl_buffer_usage[.UNIFORM], 0)

		BufferSubData(gl_buffer_usage[.UNIFORM], 0, 
				len(cmd.uniform_data), raw_data(cmd.uniform_data))
	}

	if index_buffer, ok := cmd.index_buffer.?; ok {
		if cmd.index_buffer != cache.index_buffer {
			cache.index_buffer = cmd.index_buffer
			cache.ebo = buffer_ids[index_buffer]
		}
		BindBuffer(gl_buffer_usage[.INDEX], cache.ebo)
		defer BindBuffer(gl_buffer_usage[.INDEX], 0)

		BufferSubData(gl_buffer_usage[.INDEX], 0, 
				len(cmd.index_data), raw_data(cmd.index_data))

		DrawElementsBaseVertex(TRIANGLES, i32(len(cmd.vertex_data)), UNSIGNED_INT, nil, 0)
	} else {
		DrawArrays(TRIANGLES, 0, i32(len(cmd.vertex_data)))
	}
}
