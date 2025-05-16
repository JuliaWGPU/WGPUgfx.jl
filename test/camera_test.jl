using Test
using WGPUgfx
using GeometryBasics: Vec3, Vec4, Mat4

@testset "CameraUniform Tests" begin    
    # Test creating and manipulating camera uniform
    camera = defaultCamera(
        id=1,
        eye=[1.0, 2.0, 3.0] .|> Float32,
        lookAt=[0.0, 0.0, 0.0] .|> Float32,
        up=[0.0, 1.0, 0.0] .|> Float32,
        fov=(60/180)*pi |> Float32
    )
    
    # Test computing uniform data
    uniform_data = computeUniformData(camera)
    @test uniform_data isa WGPUgfx.CameraUniform
    @test uniform_data.eye == Vec3{Float32}(1.0, 2.0, 3.0)
    @test uniform_data.lookAt == Vec3{Float32}(0.0, 0.0, 0.0)
    @test uniform_data.fov ≈ (60/180)*pi |> Float32
    
    # Test byte array conversion
    byte_data = toByteArray(uniform_data)
    @test byte_data isa Vector{UInt8}
    @test length(byte_data) == sizeof(WGPUgfx.CameraUniform)
    
    # Ensure we can convert back
    recovered = reinterpret(WGPUgfx.CameraUniform, byte_data)[1]
    @test recovered.eye == uniform_data.eye
    @test recovered.lookAt == uniform_data.lookAt
    @test recovered.fov ≈ uniform_data.fov
    @test recovered.viewMatrix == uniform_data.viewMatrix
    @test recovered.projMatrix == uniform_data.projMatrix
end

@testset "Camera System Tests" begin
    # Create a scene with default camera
    scene = Scene()
    @test length(scene.cameraSystem) == 1
    
    # Add a second camera
    camera2 = defaultCamera(
        id=2,
        eye=[3.0, 3.0, 3.0] .|> Float32,
        lookAt=[0.0, 0.0, 0.0] .|> Float32
    )
    addCamera!(scene, camera2)
    
    # Test camera system
    @test length(scene.cameraSystem) == 2
    @test scene.cameraSystem[1].id == 1
    @test scene.cameraSystem[2].id == 2
    @test scene.cameraSystem[2].eye == Vec3{Float32}(3.0, 3.0, 3.0)
    
    # Test getting active camera with camera property
    scene.cameraId = 2
    @test scene.camera.id == 2
    @test scene.camera.eye == Vec3{Float32}(3.0, 3.0, 3.0)
    
    # Switch back to camera 1
    scene.cameraId = 1
    @test scene.camera.id == 1
    
    # Test shader generation
    shader_code = getShaderCode(scene.camera)
    @test shader_code isa Expr
    @test occursin("CameraUniform", string(shader_code))
end