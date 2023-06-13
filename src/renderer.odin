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

textures_pool: [dynamic]Texture

Texture :: struct {
	initial_data : []u8,
	dimensions   : [2]i32,
	format       : Data_Format,
}

// Buffers

buffers_pool: [dynamic]Buffer

Memory_Model :: enum {
	GPU, 
	GPU_CPU,
}

Buffer_Usage :: enum {
	VERTEX, 
	INDEX, 
	UNIFORM,
}

Buffer :: struct {
	initial_data : []u8,
	byte_width   : i32,
	usage        : Buffer_Usage,
	memory_model : Memory_Model,
}

// Shaders

shaders_pool: [dynamic]Shader

Shader :: struct {
	vs_source, ps_source: cstring,
}

// Bind Groups

bind_groups_pool: [dynamic]Bind_Group

Buffer_Attribute :: struct {
	offset: i32,
	format: Data_Format,
}

Bind_Group :: struct {
	name       : string,
	textures   : []Handle(Texture),
	vertex_buffers : []Handle(Buffer),
	attributes : [][]Buffer_Attribute,
}