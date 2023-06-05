package main

import    "vendor:glfw"
import gl "vendor:opengl"
import la "core:math/linalg"

resize_callback :: proc "c" (window: glfw.WindowHandle, width, height: i32) {
	gl.Viewport(0, 0, width, height)
	projection = la.matrix_ortho3d(0, f32(width), f32(height), 0, -1, 1, false)
}

main :: proc() {
	if glfw.Init() == 0 do return
	defer glfw.Terminate()

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    window := glfw.CreateWindow(1024, 768, "microui demo", nil, nil) //or_return
    if window == nil do return
    defer glfw.DestroyWindow(window)
    glfw.MakeContextCurrent(window)

    gl.load_up_to(3, 3, glfw.gl_set_proc_address)
    glfw.SetFramebufferSizeCallback(window, resize_callback)

    init_mu_backend(&ctx)

	for !glfw.WindowShouldClose(window) {
		defer { glfw.SwapBuffers(window); glfw.PollEvents()	}

		gl.ClearColor(0.2, 0.3, 0.3, 1.0);
		gl.Clear(gl.COLOR_BUFFER_BIT);

		mu_test_window(&ctx)

		mu_draw_events(&ctx)

	}	
}

