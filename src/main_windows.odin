//+build windows

package main

import "core:fmt"
import "core:runtime"
import "vendor:glfw"
import gl "vendor:opengl"
import mu "vendor:microui"

import "rdr"
import "rdr/base"

main :: proc() {
when rdr.RDR_GL == "gl33core" {
	window := init_glfw_opengl(3, 3)
	
	if window == nil do panic("Didn't init window.")
	
	rdr.init_rdr()

} else when rdr.RDR_GL == "directx11" {
	window, hwnd := init_glfw_directx()
	
	if window == nil || hwnd == nil do panic("Didn't init window.")
	
	rdr.init_rdr(hwnd)
}
	defer { glfw.DestroyWindow(window); glfw.Terminate() }

	create_cube_resources()
	fmt.println("AFTER CREATE", base.bind_groups_pool[:1])
	//create_mu_resources()

	//init_mu_backend(&ctx)


	for !glfw.WindowShouldClose(window) {
		defer { glfw.SwapBuffers(window); glfw.PollEvents() }

		rdr.clear_background(0.1, 0.1, 0.1, 1.0)

		
		//mu_test_window(&ctx)
		//mu_register_events(&ctx)

		fmt.println("BEFORE RENDER", base.bind_groups_pool[:1])
		render_cubes()
		//mu_render()
	}   
}

init_glfw_opengl :: proc(major, minor: i32) -> (window: glfw.WindowHandle) {
	if glfw.Init() == 0 do return
	
	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, major)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, minor)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window = glfw.CreateWindow(1024, 768, "microui demo", nil, nil)
	if window == nil do return

	glfw.MakeContextCurrent(window)

	gl.load_up_to(3, 3, glfw.gl_set_proc_address) 
	glfw.SwapInterval(1)

	glfw.SetFramebufferSizeCallback(window, framebuffer_resize_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, mouse_move_callback)
	glfw.SetScrollCallback(window, mouse_scroll_callback)

	return window
}

init_glfw_directx :: proc() -> (window: glfw.WindowHandle, hwnd: rawptr) {
	if glfw.Init() == 0 do return
	
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	window = glfw.CreateWindow(1024, 768, "microui demo", nil, nil)
	if window == nil do return

	hwnd = glfw.GetWin32Window(window)
	glfw.MakeContextCurrent(window)

	glfw.SetFramebufferSizeCallback(window, framebuffer_resize_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, mouse_move_callback)
	glfw.SetScrollCallback(window, mouse_scroll_callback)

	return window, hwnd
}

mouse_scroll_callback :: proc "c" (window: glfw.WindowHandle, xoff, yoff: f64) {
	context = runtime.default_context()
	mu.input_scroll(&ctx, cast(i32)xoff, cast(i32)yoff * -5)
}

mouse_move_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()
	mu.input_mouse_move(&ctx, cast(i32)xpos, cast(i32)ypos)
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()
	xpos, ypos := glfw.GetCursorPos(window)
	mu_button: mu.Mouse

	switch button {
	case glfw.MOUSE_BUTTON_LEFT:   mu_button = .LEFT
	case glfw.MOUSE_BUTTON_RIGHT:  mu_button = .RIGHT
	case glfw.MOUSE_BUTTON_MIDDLE: mu_button = .MIDDLE
	}
	switch action {
	case glfw.PRESS:   mu.input_mouse_down(&ctx, cast(i32)xpos, cast(i32)ypos, mu_button)
	case glfw.RELEASE: mu.input_mouse_up(&ctx, cast(i32)xpos, cast(i32)ypos, mu_button)
	}
}

framebuffer_resize_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	rdr.set_viewport_view(0, 0, width, height)
	rdr.set_scissor_view(0, 0, width, height)
	vp_width, vp_height = width, height
}
