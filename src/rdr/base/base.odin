package rdr_base

Data_Format :: enum {
	RG32_FLOAT,  
	RGB32_FLOAT,  
	RGB32_UINT,
	RGBA8_UNORM, 
	RGBA32_FLOAT, 
	RGBA32_UINT,
}

data_sizes := [Data_Format]i32 {
	.RGBA8_UNORM  = 4,
	.RG32_FLOAT   = 8,
	.RGB32_FLOAT  = 12,  
	.RGB32_UINT   = 12,
	.RGBA32_FLOAT = 16, 
	.RGBA32_UINT  = 16,
}

// === Textures ===

Texture :: struct {
	name         : cstring,
	initial_data : []u8 `fmt:"-"`,
	dimensions   : [2]i32,
	format       : Data_Format,
}

// === Buffers ===

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
	name         : cstring,
	initial_data : []u8 `fmt:"-"`,
	byte_stride  : i32,
	usage        : Buffer_Usage,
	memory_model : Memory_Model,
}

// === Shaders ===

Vertex_Layout :: struct {
	offset: i32,
	format: Data_Format,
}

Shader :: struct {
	vs_source: cstring `fmt:"-"`, 
	ps_source: cstring `fmt:"-"`,
	vertex_buffers: []Handle(Buffer),
	vertex_buffers_layout: []struct {
		byte_stride: i32,
		attributes: []Vertex_Layout,
	} `fmt:"-"`,
	render_state: struct {
		blend_mode: Blend_Mode,
		depth_test: Depth_Test,
		cull_mode:  Cull_Mode,
	} `fmt:"-"`,
}

// === Bind Groups ===

Blend_Mode :: enum {
	NONE,
	EXCLUDE_ALPHA,
}

Depth_Test :: enum {
	NONE,
	LESS,
	GREATER_OR_EQUAL,
	LESS_OR_EQUAL,
}

Cull_Mode :: enum {
	NONE,
	FRONT,
	BACK,
}

Bind_Group :: struct {
	name     : string,
	uniforms : []Handle(Buffer),
	textures : []Handle(Texture),
}

// === Command Buffers ===

Command_Buffer :: struct {
	shader          : Maybe(Handle(Shader)),
	bind_group      : Maybe(Handle(Bind_Group)),
	vertex_buffer   : Maybe(Handle(Buffer)),
	index_buffer    : Maybe(Handle(Buffer)),
	uniform_buffer  : Maybe(Handle(Buffer)),
	vertex_data     : []u8,
	index_data      : []u8,
	uniform_data    : []u8,
}

// === Resource Pools ===

Handle :: struct($T: typeid) {
	index: i32,
	gen: i32,
}

Slot :: struct($T: typeid) {
	resource: Maybe(T), 
	gen: i32, 
}

buffers_pool     : [20]Slot(Buffer)
textures_pool    : [20]Slot(Texture)
shaders_pool     : [20]Slot(Shader)
bind_groups_pool : [20]Slot(Bind_Group)

// FIXME: Change to something smart with unions or polymorphism.

get_resource_buffer :: proc(using res: Handle(Buffer)) -> ^Buffer {
	assert(index >= 0 && index < i32(len(buffers_pool)))
	return &buffers_pool[index].resource.? if gen == buffers_pool[index].gen else nil
} 
get_resource_texture :: proc(using res: Handle(Texture)) -> ^Texture {
	assert(index >= 0 && index < i32(len(textures_pool)))
	return &textures_pool[index].resource.? if gen == textures_pool[index].gen else nil
} 
get_resource_shader :: proc(using res: Handle(Shader)) -> ^Shader {
	assert(index >= 0 && index < i32(len(shaders_pool)))
	return &shaders_pool[index].resource.? if gen == shaders_pool[index].gen else nil
} 
get_resource_bind_group :: proc(using res: Handle(Bind_Group)) -> ^Bind_Group {
	assert(index >= 0 && index < i32(len(bind_groups_pool)))
	return &bind_groups_pool[index].resource.? if gen == bind_groups_pool[index].gen else nil
} 
get_resource :: proc {
	get_resource_buffer,
	get_resource_texture,
	get_resource_shader,
	get_resource_bind_group,
}

add_resource_buffer :: proc(res: Buffer) -> Handle(Buffer) {
	for slot, i in &buffers_pool {
		if _, ok := slot.resource.?; !ok {
			slot.resource = res
			return { i32(i), slot.gen }
		}
	}
	//append(&buffers_pool, Slot(Buffer){ resource = res, gen = 0 })
	return { i32(len(buffers_pool)-1), 0 }
}
add_resource_texture :: proc(res: Texture) -> Handle(Texture) {
	for slot, i in &textures_pool {
		if _, ok := slot.resource.?; !ok {
			slot.resource = res
			return { i32(i), slot.gen }
		}
	}
	//append(&textures_pool, Slot(Texture){ resource = res, gen = 0 })
	return { i32(len(textures_pool)-1), 0 }
}
add_resource_shader :: proc(res: Shader) -> Handle(Shader) {
	for slot, i in &shaders_pool {
		if _, ok := slot.resource.?; !ok {
			slot.resource = res
			return { i32(i), slot.gen }
		}
	}
	//append(&shaders_pool, Slot(Shader){ resource = res, gen = 0 })
	return { i32(len(shaders_pool)-1), 0 }
}
add_resource_bind_group :: proc(res: Bind_Group) -> Handle(Bind_Group) {
	for slot, i in &bind_groups_pool {
		if _, ok := slot.resource.?; !ok {
			slot.resource = res
			return { i32(i), slot.gen }
		}
	}
	//append(&bind_groups_pool, Slot(Bind_Group){ resource = res, gen = 0 })
	return { i32(len(bind_groups_pool)-1), 0 }
}
add_resource :: proc {
	add_resource_buffer,
	add_resource_texture,
	add_resource_shader,
	add_resource_bind_group,
}

remove_resource_buffer :: proc(using handle: Handle(Buffer)) {
	assert(index >= 0 && index < i32(len(buffers_pool)))
	if gen == buffers_pool[index].gen do buffers_pool[index] = { nil, gen + 1 }
}
remove_resource_texture :: proc(using handle: Handle(Texture)) {
	assert(index >= 0 && index < i32(len(textures_pool)))
	if gen == textures_pool[index].gen do textures_pool[index] = { nil, gen + 1 }
}
remove_resource_shader :: proc(using handle: Handle(Shader)) {
	assert(index >= 0 && index < i32(len(shaders_pool)))
	if gen == shaders_pool[index].gen do shaders_pool[index] = { nil, gen + 1 }
}
remove_resource_bind_group :: proc(using handle: Handle(Bind_Group)) {
	assert(index >= 0 && index < i32(len(bind_groups_pool)))
	if gen == bind_groups_pool[index].gen do bind_groups_pool[index] = { nil, gen + 1 }
}
remove_resource :: proc {
	remove_resource_buffer,
	remove_resource_texture,
	remove_resource_shader,
	remove_resource_bind_group,
}
