package rdr

import "base"

RDR_GL :: #config(RDR_GL, "gl33core")

when RDR_GL == "gl33core" {
	import backend "backend/gl33core"
} else when RDR_GL == "directx11" {
	import backend "backend/directx11"
} else {
	#panic("[COMPILE ERROR] Unknown GL backend.")
}

Slot    :: base.Slot
Handle  :: base.Handle
Buffer  :: base.Buffer
Texture :: base.Texture
Shader  :: base.Shader
Bind_Group :: base.Bind_Group
Command_Buffer :: base.Command_Buffer 

init_rdr :: backend.init_rdr
set_viewport_view :: backend.set_viewport_view
set_scissor_view  :: backend.set_scissor_view 
clear_background  :: backend.clear_background 

// Buffer procs

create_buffer :: backend.create_buffer

// Texture procs

create_texture :: backend.create_texture

// Shader procs

create_shader :: backend.create_shader

// Bind Group procs

create_bind_group :: backend.create_bind_group

// Command Buffer procs

draw_from_command_buffer :: backend.draw_from_command_buffer
