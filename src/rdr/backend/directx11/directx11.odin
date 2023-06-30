package base_backend_directx11

import "core:sys/windows"
import "vendor:directx/dxgi"
import dx "vendor:directx/d3d11"

import "../../base"

SUCCEEDED :: windows.SUCCEEDED

Handle  :: base.Handle
Buffer  :: base.Buffer
Texture :: base.Texture
Shader  :: base.Shader
Bind_Group :: base.Bind_Group
Command_Buffer :: base.Command_Buffer 

/*@(private)
dx_data_formats := [base.Data_Format]u32 { 
	.RG32_FLOAT   = gl.RG32F, 
	.RGB32_FLOAT  = gl.RGB32F,  
	.RGB32_UINT   = gl.RGB32UI, 
	.RGBA8_UNORM  = gl.RGBA, 
	.RGBA32_FLOAT = gl.RGBA32F, 
	.RGBA32_UINT  = gl.RGBA32UI, 
}

@(private)
dx_memory_model := [base.Memory_Model]u32 {
	.GPU     = gl.STATIC_DRAW, 
	.GPU_CPU = gl.DYNAMIC_DRAW, // HINT: Maybe try STREAM_DRAW?
}*/

@(private)
dx_buffer_usage := [base.Buffer_Usage]dx.BIND_FLAG {
	.VERTEX  = .VERTEX_BUFFER, 
	.INDEX   = .INDEX_BUFFER,
	.UNIFORM = .CONSTANT_BUFFER,
}

@(private)
texture_ids: map[Handle(Texture)]u32
@(private)
buffer_ids:  map[Handle(Buffer)]u32
@(private)
shader_ids:  map[Handle(Shader)]u32
@(private)
vao_ids: map[Handle(Shader)]u32

@(private)
dx_ctx: struct {
	device: ^dx.IDevice,
	device_context: ^dx.IDeviceContext,

	dxgi_device: ^dxgi.IDevice1,
	dxgi_adapter: ^dxgi.IAdapter,
	dxgi_factory: ^dxgi.IFactory2,

	swap_chain: ^dxgi.ISwapChain1,
	framebuffer: ^dx.ITexture2D,
}

set_viewport_view :: proc "contextless" (x, y, w, h: i32) {
	
}

set_scissor_view :: proc "contextless" (x, y, w, h: i32) {
	
}

clear_background :: proc "contextless" (r, g, b, a: f32) {
	
}

init_rdr :: proc(hwnd: rawptr) {
	using dx_ctx
	hwnd := dxgi.HWND(hwnd)

	feature_levels := [?]dx.FEATURE_LEVEL{ ._11_0, ._11_1 }
	
	res := dx.CreateDevice(nil, .HARDWARE, nil, {.BGRA_SUPPORT}, 
	                       raw_data(&feature_levels), len(feature_levels), 
	                       dx.SDK_VERSION, &device, nil, &device_context)
	assert(SUCCEEDED(res))

	res = device->QueryInterface(dxgi.IDevice1_UUID, auto_cast &dxgi_device)
	assert(SUCCEEDED(res))

	res = dxgi_device->GetAdapter(&dxgi_adapter)
	assert(SUCCEEDED(res))

	res = dxgi_adapter->GetParent(dxgi.IFactory2_UUID, auto_cast &dxgi_factory)
	assert(SUCCEEDED(res))

	swap_chain_desc := dxgi.SWAP_CHAIN_DESC1 {
		Format = .B8G8R8A8_UNORM_SRGB,
		SampleDesc = { Count = 1, Quality = 0 },
		BufferUsage = { .RENDER_TARGET_OUTPUT },
		BufferCount = 2,
		Scaling = .STRETCH,
		SwapEffect = .FLIP_DISCARD,
	}
	res = dxgi_factory->CreateSwapChainForHwnd(device, hwnd, &swap_chain_desc, nil, nil, &swap_chain)
	assert(SUCCEEDED(res))

	res = swap_chain->GetBuffer(0, dx.ITexture2D_UUID, auto_cast &framebuffer)
	assert(SUCCEEDED(res))

	framebuffer_view: ^dx.IRenderTargetView
	res = device->CreateRenderTargetView(framebuffer, nil, auto_cast &framebuffer_view)
	assert(SUCCEEDED(res))

	depth_buffer_desc: dx.TEXTURE2D_DESC
	framebuffer->GetDesc(&depth_buffer_desc)

	depth_buffer_desc.Format = .D24_UNORM_S8_UINT
	depth_buffer_desc.BindFlags = { .DEPTH_STENCIL }

	depth_buffer: ^dx.ITexture2D
	res = device->CreateTexture2D(&depth_buffer_desc, nil, auto_cast &depth_buffer)
	assert(SUCCEEDED(res))

	depth_buffer_view: ^dx.IDepthStencilView
	res = device->CreateDepthStencilView(depth_buffer, nil, auto_cast &depth_buffer_view)
	assert(SUCCEEDED(res))
}

// Buffer procs

create_buffer :: proc(buffer: Buffer) -> Handle(Buffer) {


	
	handle := base.add_resource(buffer)
	//buffer_ids[handle] = id
	return handle
}

// Texture procs

create_texture :: proc(texture: Texture) -> Handle(Texture) {
	

	handle := base.add_resource(texture)
	//texture_ids[handle] = id
	return handle
}

// Shader procs

create_shader :: proc(shader: Shader) -> Handle(Shader) {
	




	depth_stencil_desc := dx.DEPTH_STENCIL_DESC {

	}
	depth_stencil_state: ^dx.IDepthStencilState
	res := dx_ctx.device->CreateDepthStencilState(&depth_stencil_desc, &depth_stencil_state) 
	assert(SUCCEEDED(res))

	raster_desc := dx.RASTERIZER_DESC {

	}
	raster_state: ^dx.IRasterizerState
	res = dx_ctx.device->CreateRasterizerState(&raster_desc, &raster_state)
	assert(SUCCEEDED(res))

	handle := base.add_resource(shader)
	//shader_ids[handle] = prog
	//vao_ids[handle] = vao
	return handle
}

// Bind Group procs

create_bind_group :: proc(bind_group: Bind_Group) -> Handle(Bind_Group) {
	handle := base.add_resource(bind_group)
	return handle
}

@(private)
bind_group_to_shader :: proc(bind_group: Bind_Group, prog: u32) {
/*	
	for ubo, i in bind_group.uniforms {
		buffer := base.get_resource(ubo)
		if buffer == nil do panic("UBO is nil")

		
	}
/*	
	for tex, i in bind_group.textures {
		//tex_name := base.get_resource(tex).name
		
	}*/*/
}

// Command Buffer procs

draw_from_command_buffer :: proc(cmd: Command_Buffer) {
/*
	@static cache: struct {
		using command_buffer: Command_Buffer,
	}

	if shader, ok := cmd.shader.?; ok {
		if cmd.shader != cache.shader { 
			
		}
	}

	if bind_group, ok := cmd.bind_group.?; ok { 
		if cmd.bind_group != cache.bind_group {
			cache.bind_group = cmd.bind_group
			bg := base.get_resource(bind_group)
			//bind_group_to_shader(bg^, cache.prog)
		}
	}

	if vertex_buffer, ok := cmd.vertex_buffer.?; ok {
		if cmd.vertex_buffer != cache.vertex_buffer {
			cache.vertex_buffer = cmd.vertex_buffer
			
		}
		
	}

	if uniform_buffer, ok := cmd.uniform_buffer.?; ok {
		if cmd.uniform_buffer != cache.uniform_buffer {
			cache.uniform_buffer = cmd.uniform_buffer
			
		}
		
	}

	if index_buffer, ok := cmd.index_buffer.?; ok {
		if cmd.index_buffer != cache.index_buffer {
			cache.index_buffer = cmd.index_buffer
		}
	}*/
		
}
