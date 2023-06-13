package main

import "core:runtime"
import "vendor:glfw"
import gl "vendor:opengl"
import mu "vendor:microui"

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
	gl.Viewport(0, 0, width, height)
	vp_width, vp_height = width, height
}

main :: proc() {
	if glfw.Init() == 0 do return
	defer glfw.Terminate()

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window := glfw.CreateWindow(1024, 768, "microui demo", nil, nil)
	if window == nil do return
	defer glfw.DestroyWindow(window)
	
	glfw.MakeContextCurrent(window)
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)

	glfw.SetFramebufferSizeCallback(window, framebuffer_resize_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, mouse_move_callback)
	glfw.SetScrollCallback(window, mouse_scroll_callback)
	glfw.SwapInterval(1)

	init_mu_backend(&ctx)

	for !glfw.WindowShouldClose(window) {
		defer { glfw.SwapBuffers(window); glfw.PollEvents() }

		gl.ClearColor(0.8, 0.1, 0.3, 1.0);
		gl.Clear(gl.COLOR_BUFFER_BIT);

		mu_test_window(&ctx)

		mu_draw_events(&ctx)

	}   
}
