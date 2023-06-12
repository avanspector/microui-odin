//+build i386, amd64
package main

import gl "vendor:opengl"

gl_data_formats := [Data_Format]u32 { 
    .RG32_FLOAT   = gl.RG32F, 
    .RGB32_FLOAT  = gl.RGB32F,  
    .RGB32_UINT   = gl.RGB32UI, 
    .RGBA8_UNORM  = gl.RGBA, 
    .RGBA32_FLOAT = gl.RGBA32F, 
    .RGBA32_UINT  = gl.RGBA32UI, 
}

gl_memory_model := [Memory_Model]u32 {
    .GPU     = gl.STATIC_DRAW, 
    .GPU_CPU = gl.DYNAMIC_DRAW,
}

gl_buffer_usage := [Buffer_Usage]u32 {
    .VERTEX = gl.ARRAY_BUFFER, 
    .INDEX  = gl.ELEMENT_ARRAY_BUFFER,
    .UNIFORM = 0,   // TODO
}

texture_ids: map[Handle(Texture)]u32
buffer_ids:  map[Handle(Buffer)]u32

// Buffer procs

create_buffer :: proc(using buffer: Buffer) -> Handle(Buffer) {
    using gl
    id: u32
    GenBuffers(1, &id)
    BindBuffer(gl_buffer_usage[usage], id)
    defer BindBuffer(gl_buffer_usage[usage], 0)

    BufferData(gl_buffer_usage[usage], len(data), raw_data(data), gl_memory_model[memory_model])

    for attr, i in buffer.attributes {
        VertexAttribPointer(u32(i), data_format_sizes[attr.format] / size_of(f32), FLOAT, FALSE, byte_width, uintptr(attr.offset))
        EnableVertexAttribArray(u32(i))
    }

    append(&buffers, buffer)
    handle := Handle(Buffer){ len(buffers) - 1 }
    buffer_ids[handle] = id

    return handle
}

modify_buffer :: proc(buf: Handle(Buffer), data: []u8) {
    using gl
    using buffer := &buffers[buf.index]
    id := buffer_ids[buf]

    BindBuffer(gl_buffer_usage[usage], id)
    // Never unbind EBO before VAO in OpenGL
    defer if usage != .INDEX { 
        BindBuffer(gl_buffer_usage[usage], 0)
    }

    BufferSubData(gl_buffer_usage[usage], 0, len(data), raw_data(data))
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

    TexImage2D(TEXTURE_2D, 0, i32(gl_data_formats[format]), 
               dimensions.x, dimensions.y, 0, 
               gl_data_formats[format], data_type, raw_data(data))
    GenerateMipmap(TEXTURE_2D)

    append(&textures, texture)
    handle := Handle(Texture){ len(textures) - 1 }
    texture_ids[handle] = id

    return handle
}

// Shader procs

create_shader :: proc(shader: Shader) -> (Handle(Shader), u32) {
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

    return Handle(Shader){ 0 }, prog
}

