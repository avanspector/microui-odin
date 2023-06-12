package main

Handle :: struct($T: typeid) {
    index: int,
}

Data_Format :: enum {
    RG32_FLOAT,  
    RGB32_FLOAT,  
    RGB32_UINT,
    RGBA8_UNORM, 
    RGBA32_FLOAT, 
    RGBA32_UINT,
}

data_format_sizes := [Data_Format]i32 {
    .RGBA8_UNORM  = 4,
    .RG32_FLOAT   = 8,
    .RGB32_FLOAT  = 12,  
    .RGB32_UINT   = 12,
    .RGBA32_FLOAT = 16, 
    .RGBA32_UINT  = 16,
}

// Textures

textures: [dynamic]Texture

Texture :: struct {
    data       : []u8,
    dimensions : [2]i32,
    format     : Data_Format,
}

// Buffers

buffers: [dynamic]Buffer

Memory_Model :: enum {
    GPU, 
    GPU_CPU,
}

Buffer_Usage :: enum {
    VERTEX, 
    INDEX, 
    UNIFORM,
}

Buffer_Attribute :: struct {
    offset: i32,
    format: Data_Format,
}

Buffer :: struct {
    data         : []u8,
    byte_width   : i32,
    attributes   : []Buffer_Attribute,
    usage        : Buffer_Usage,
    memory_model : Memory_Model,
}

// Shaders

Shader :: struct {
    vs_source, ps_source: cstring,
}


