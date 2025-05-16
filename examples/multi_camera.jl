using WGPUgfx
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations
using GLFW

function run_multi_camera_example()
    # Create scene with default size
    scene = Scene((800, 600))
    
    # Create a second camera
    camera1 = scene.camera  # First camera is already created with the scene
    camera2 = defaultCamera(
        id=2,
        eye=[5.0, 3.0, 5.0] .|> Float32,
        lookAt=[0.0, 0.0, 0.0] .|> Float32,
        up=[0.0, 1.0, 0.0] .|> Float32
    )
    
    # Create a third camera for top-down view
    camera3 = defaultCamera(
        id=3,
        eye=[0.0, 8.0, 0.0] .|> Float32,
        lookAt=[0.0, 0.0, 0.0] .|> Float32,
        up=[0.0, 0.0, 1.0] .|> Float32
    )
    
    # Add cameras to the scene
    addCamera!(scene, camera2)
    addCamera!(scene, camera3)
    
    # Create objects
    cube = defaultMesh()
    cube_world = WorldObject(
        cube,
        RenderType(VISIBLE | SURFACE | WIREFRAME),
        nothing,
        nothing,
        defaultAxis(len=1.0),
        nothing
    )
    
    # Main coordinate axis
    axis = defaultAxis(len=3.0)
    
    # Floor grid
    grid = defaultGrid(scale=0.5f0, len=10.0, segments=10)
    
    # Add UI element - text or quad display
    quad = defaultQuad(color=[0.2, 0.4, 0.8, 0.7])
    
    # Add objects to the scene
    renderer = getRenderer(scene)
    addObject!(renderer, cube_world)
    addObject!(renderer, axis)
    addObject!(renderer, grid)
    addObject!(renderer, quad)
    
    # Prepare for rendering
    WGPUCore.printDeviceInfo(scene.gpuDevice)
    
    # Create viewport configurations
    window_width, window_height = scene.canvas.size
    viewports = Dict(
        1 => (0, 0, window_width÷2, window_height÷2),              # Top-left - camera 1
        2 => (window_width÷2, 0, window_width÷2, window_height÷2), # Top-right - camera 2
        3 => (0, window_height÷2, window_width, window_height÷2)   # Bottom - camera 3 (wide)
    )
    
    # Initialize animation parameters
    frameCount = 0
    angle = 0.0
    
    # Main application loop
    function render_frame(renderer)
        # Update animation parameters
        frameCount += 1
        angle += 0.01
        
        # Orbit camera 1 around the scene
        rotMatrix = RotMatrix{3}(RotY(angle))
        camera1.eye = rotMatrix * [4.0, 2.0, 0.0]
        
        # Rotate camera 2 in the opposite direction
        camera2.eye = rotMatrix * [-5.0, 3.0, 0.0]
        
        # Rotate the cube
        rotation = SMatrix{4,4,Float32}(RotMatrix{3}(RotY(angle/2)))
        cube_world.uniformData = rotation
        
        # Move the UI quad
        theta = frameCount * 0.05
        quad.uniformData = translate([
            0.8 * sin(theta), 
            0.8 * cos(theta), 
            0.0
        ]).linear
        
        # Begin frame
        init(renderer)
        
        # Render with multiple cameras
        render(renderer, viewports)
        
        # End frame
        deinit(renderer)
        
        return nothing
    end
    
    # Set up event system for user interaction
    attachEventSystem(renderer)
    
    # Show information about the scene
    println("Scene information:")
    println("- Objects: $(length(scene.objects))")
    println("- Cameras: $(length(scene.cameraSystem))")
    println("- Window size: $(scene.canvas.size)")
    println("- Viewport configuration:")
    for (cam_id, viewport) in viewports
        println("  - Camera $cam_id: $viewport")
    end
    
    # Run the main loop
    println("Starting rendering loop... Press ESC to exit")
    runApp(scene.canvas) do
        # Check for ESC key to exit
        if GLFW.GetKey(scene.canvas.windowRef[], GLFW.KEY_ESCAPE) == GLFW.PRESS
            GLFW.SetWindowShouldClose(scene.canvas.windowRef[], true)
        end
        
        # Render a frame
        render_frame(renderer)
    end
    
    println("Multi-camera example completed successfully")
end

# Run the example when this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_multi_camera_example()
end
