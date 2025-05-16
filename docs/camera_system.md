# Camera System in WGPUgfx

The camera system in WGPUgfx provides a flexible way to handle multiple cameras in a 3D scene. This document explains how to use the camera system effectively.

## Overview

The camera system consists of the following components:

1. `Camera` - A structure representing a single camera with properties like position, orientation, and projection
2. `CameraSystem` - A container that holds multiple cameras
3. `CameraUniform` - A uniform structure passed to shaders that contains camera data

Each camera automatically generates its own shader code with proper structure definitions and bindings, allowing multiple cameras to be used simultaneously.

## Basic Usage

### Creating a Camera

```julia
# Default camera (automatically added to scene)
scene = Scene()
camera = scene.camera

# Create additional camera
camera2 = defaultCamera(
    id=2,                                # Unique ID for the camera
    eye=[3.0, 3.0, 3.0] .|> Float32,     # Camera position
    lookAt=[0.0, 0.0, 0.0] .|> Float32,  # Look-at point
    up=[0.0, 1.0, 0.0] .|> Float32,      # Up vector
    fov=(45/180)*pi |> Float32           # Field of view in radians
)

# Add to scene
addCamera!(scene, camera2)
```

### Switching Between Cameras

```julia
# Set active camera by ID
scene.cameraId = 2  # Switch to camera 2

# Access active camera
activeCamera = scene.camera
```

### Camera Properties

Important camera properties:

- `eye`: Position of the camera
- `lookAt`: Point the camera is looking at
- `up`: Up vector for the camera orientation
- `fov`: Field of view in radians
- `aspectRatio`: Width/height ratio of the viewport
- `nearPlane`: Near clipping plane distance
- `farPlane`: Far clipping plane distance
- `projectionType`: `PERSPECTIVE` or `ORTHO`

## Rendering with Multiple Cameras

### Split-Screen Rendering

```julia
# Create viewport configurations for split screen
viewports = Dict(
    1 => (0, 0, width÷2, height),      # Left half - camera 1
    2 => (width÷2, 0, width÷2, height)  # Right half - camera 2
)

# In render loop
function render_frame(renderer)
    init(renderer)
    render(renderer, viewports)  # Render with multiple viewports
    deinit(renderer)
end
```

### Picture-in-Picture

```julia
viewports = Dict(
    1 => (0, 0, width, height),           # Full screen - camera 1
    2 => (width-200, height-200, 200, 200) # Small overlay - camera 2
)
```

## Advanced Usage

### Camera Uniform Structure

The `CameraUniform` structure is defined in each shader and contains:

```julia
struct CameraUniform
    eye::Vec3{Float32}           # Camera position
    aspectRatio::Float32         # Width/height ratio
    lookAt::Vec3{Float32}        # Look-at position
    fov::Float32                 # Field of view in radians
    viewMatrix::Mat4{Float32}    # View transformation matrix
    projMatrix::Mat4{Float32}    # Projection matrix
end
```

When rendering with multiple cameras, each camera is bound to a different uniform binding slot, allowing shaders to access the appropriate camera data.

### Camera Transformations

```julia
# Update eye position
camera.eye = [x, y, z] .|> Float32

# Rotate camera around scene
angle = 0.01
rotMatrix = RotMatrix{3}(RotY(angle))
camera.eye = rotMatrix * [4.0, 2.0, 0.0]

# Change projection type
camera.projectionType = ORTHO  # or PERSPECTIVE
```

## Performance Considerations

- Each camera requires its own uniform buffer and shader pipeline
- For optimal performance, limit the number of active cameras
- Consider using frustum culling to skip rendering objects outside camera view

## Common Issues

- Ensure all vector inputs are Float32 (use `.|> Float32`)
- Set unique IDs for each camera
- Update `eye` and `lookAt` together to avoid strange orientations
- For UI elements, consider using a dedicated orthographic camera
- Make sure to use proper viewport dimensions when rendering with multiple cameras
- Remember that each camera requires its own shader compilation and pipeline setup

## Troubleshooting

### "Camera not available in shader"

This may happen if a camera's shader hasn't been compiled yet. The system will attempt to automatically recompile shaders when needed, but you can explicitly trigger compilation:

```julia
compileShaders!(scene.gpuDevice, scene, object)
```

### Performance Issues with Multiple Cameras

When using many cameras, consider:
- Limiting the number of active cameras
- Using smaller viewports for less important cameras 
- Reducing the complexity of objects rendered in secondary cameras