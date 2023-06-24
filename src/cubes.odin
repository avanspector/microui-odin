package main

import "core:fmt"
import "core:slice"
import la "core:math/linalg"
import glm "core:math/linalg/glsl"

Matrices_Uniforms :: struct {
	projection: glm.mat4,
	view: glm.mat4,
	model: glm.mat4,
}

cubes, cube_uniform: Handle(Buffer)
red, green, blue, yellow: Handle(Shader)
cube: Handle(Bind_Group)

create_cube_resources :: proc() {
	cubes = create_buffer({
		initial_data = slice.to_bytes(cubeVertices[:]),
		byte_width = size_of([3]f32),
		usage = .VERTEX,
		memory_model = .GPU,
	})

	cube_uniform = create_buffer({
		name = "Matrices",
		byte_width = size_of(Matrices_Uniforms),
		usage = .UNIFORM,
		memory_model = .GPU_CPU,
	})

	red = create_shader({
		vs_source = vs_source,
		ps_source = ps_red,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_width = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		}
	})

	green = create_shader({
		vs_source = vs_source,
		ps_source = ps_green,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_width = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		}
	})

	blue = create_shader({
		vs_source = vs_source,
		ps_source = ps_blue,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_width = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		}
	})

	fmt.println("\nshaders pool before add\n\n", len(shaders_pool), shaders_pool)

	yellow = create_shader({
		vs_source = vs_source,
		ps_source = ps_yellow,
		vertex_buffers = { cubes },
		vertex_buffers_layout = {
			{ byte_width = size_of([3]f32), attributes = {
				{ offset = 0, format = .RGB32_FLOAT },
			}},
		},
		render_state = {
			depth_test = .LESS,
		}
	})

	fmt.println("\nshaders pool after add\n\n", len(shaders_pool), shaders_pool)
	
	cube = create_bind_group({
		uniforms = { cube_uniform },
	})

	fmt.println("\nshaders pool before leaving first proc\n\n", len(shaders_pool), shaders_pool)
}

render_cubes :: proc() {
	uniforms := Matrices_Uniforms {
		projection = glm.mat4Perspective(0.79, f32(vp_width)/f32(vp_height), 1., 100.),
		view = glm.mat4LookAt({ 0., 0., 3. }, { 0., 0., 3. }+{ 0., 0., -1. }, { 0., 1., 0. })
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
