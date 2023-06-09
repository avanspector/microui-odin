package main

import "core:fmt"
import "core:slice"
import glm "core:math/linalg/glsl"

import "rdr"
import "rdr/base"

Matrices_Uniforms :: struct {
	projection: glm.mat4,
	view: glm.mat4,
	model: glm.mat4,
}

cubes, cube_uniform: rdr.Handle(rdr.Buffer)
red, green, blue, yellow: rdr.Handle(rdr.Shader)
cube: rdr.Handle(rdr.Bind_Group)

create_cube_resources :: proc() {
	using rdr

	cubes = create_buffer({
		initial_data = slice.to_bytes(cubeVertices[:]),
		byte_stride = size_of([3]f32),
		usage = .VERTEX,
		memory_model = .GPU,
	})

	cube_uniform = create_buffer({
		name = "Matrices",
		byte_stride = size_of(Matrices_Uniforms),
		usage = .UNIFORM,
		memory_model = .GPU_CPU,
	})

	red = create_shader({
		vs_source = vs_source,
		ps_source = ps_red,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_stride = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		},
	})

	green = create_shader({
		vs_source = vs_source,
		ps_source = ps_green,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_stride = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		},
	})

	blue = create_shader({
		vs_source = vs_source,
		ps_source = ps_blue,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_stride = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		},
	})

	yellow = create_shader({
		vs_source = vs_source,
		ps_source = ps_yellow,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_stride = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		},
	})

	fmt.println(base.bind_groups_pool[:1])

	cube = create_bind_group({
		uniforms = { cube_uniform },
	})

	fmt.println("END OF CREATE", base.bind_groups_pool[:1])
}

render_cubes :: proc() {
	using rdr

	fmt.println("START OF RENDER", base.bind_groups_pool[:1])
	
	uniforms := Matrices_Uniforms {
		projection = glm.mat4Perspective(0.79, f32(vp_width)/f32(vp_height), 1., 100.),
		view = glm.mat4LookAt({ 0., 0., 3. }, { 0., 0., 3. }+{ 0., 0., -1. }, { 0., 1., 0. }),
	}

	uniforms.model = glm.mat4Translate({ -0.75, 0.75, 0. })
	draw_from_command_buffer({
		shader = red,
		bind_group = cube,
		vertex_buffer = cubes,
		uniform_buffer = cube_uniform,
		vertex_data = slice.to_bytes(cubeVertices[:]),
		uniform_data = slice.bytes_from_ptr(&uniforms, size_of(uniforms)),
	})

	uniforms.model = glm.mat4Translate({ 0.75, 0.75, 0. })
	draw_from_command_buffer({
		shader = green,
		bind_group = cube,
		vertex_buffer = cubes,
		uniform_buffer = cube_uniform,
		vertex_data = slice.to_bytes(cubeVertices[:]),
		uniform_data = slice.bytes_from_ptr(&uniforms, size_of(uniforms)),
	})

	uniforms.model = glm.mat4Translate({ -0.75, -0.75, 0. })
	draw_from_command_buffer({
		shader = blue,
		bind_group = cube,
		vertex_buffer = cubes,
		uniform_buffer = cube_uniform,
		vertex_data = slice.to_bytes(cubeVertices[:]),
		uniform_data = slice.bytes_from_ptr(&uniforms, size_of(uniforms)),
	})

	uniforms.model = glm.mat4Translate({ 0.75, -0.75, 0. })
	draw_from_command_buffer({
		shader = yellow,
		bind_group = cube,
		vertex_buffer = cubes,
		uniform_buffer = cube_uniform,
		vertex_data = slice.to_bytes(cubeVertices[:]),
		uniform_data = slice.bytes_from_ptr(&uniforms, size_of(uniforms)),
	})

	fmt.println("END OF RENDER", base.bind_groups_pool[:1])
}

cubeVertices := [?]f32 {
	// positions         
	-0.5, -0.5, -0.5, 
	 0.5, -0.5, -0.5,  
	 0.5,  0.5, -0.5,  
	 0.5,  0.5, -0.5,  
	-0.5,  0.5, -0.5, 
	-0.5, -0.5, -0.5, 

	-0.5, -0.5,  0.5, 
	 0.5, -0.5,  0.5,  
	 0.5,  0.5,  0.5,  
	 0.5,  0.5,  0.5,  
	-0.5,  0.5,  0.5, 
	-0.5, -0.5,  0.5, 

	-0.5,  0.5,  0.5, 
	-0.5,  0.5, -0.5, 
	-0.5, -0.5, -0.5, 
	-0.5, -0.5, -0.5, 
	-0.5, -0.5,  0.5, 
	-0.5,  0.5,  0.5, 

	 0.5,  0.5,  0.5,  
	 0.5,  0.5, -0.5,  
	 0.5, -0.5, -0.5,  
	 0.5, -0.5, -0.5,  
	 0.5, -0.5,  0.5,  
	 0.5,  0.5,  0.5,  

	-0.5, -0.5, -0.5, 
	 0.5, -0.5, -0.5,  
	 0.5, -0.5,  0.5,  
	 0.5, -0.5,  0.5,  
	-0.5, -0.5,  0.5, 
	-0.5, -0.5, -0.5, 

	-0.5,  0.5, -0.5, 
	 0.5,  0.5, -0.5,  
	 0.5,  0.5,  0.5,  
	 0.5,  0.5,  0.5,  
	-0.5,  0.5,  0.5, 
	-0.5,  0.5, -0.5, 
}

vs_source: cstring = 
`#version 330 core
layout (location = 0) in vec3 aPos;

layout (std140) uniform Matrices
{
    mat4 projection;
    mat4 view;
    uniform mat4 model;
};

void main()
{
    gl_Position = projection * view * model * vec4(aPos, 1.0);
}`

ps_red: cstring = 
`#version 330 core
out vec4 FragColor;

void main()
{
    FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}`

ps_green: cstring = 
`#version 330 core
out vec4 FragColor;

void main()
{
    FragColor = vec4(0.0, 1.0, 0.0, 1.0);
}`

ps_blue: cstring = 
`#version 330 core
out vec4 FragColor;

void main()
{
    FragColor = vec4(0.0, 0.0, 1.0, 1.0);
}`

ps_yellow: cstring = 
`#version 330 core
out vec4 FragColor;

void main()
{
    FragColor = vec4(1.0, 1.0, 0.0, 1.0);
}`
