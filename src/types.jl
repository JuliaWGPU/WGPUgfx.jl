using GeometryBasics: Vec3, Vec4, Mat4
export CameraUniform, LightingUniform, toByteArray

# Camera uniform structure for use in shaders
struct CameraUniform
    eye::Vec3{Float32}
    aspectRatio::Float32
    lookAt::Vec3{Float32}
    fov::Float32
    viewMatrix::Mat4{Float32}
    projMatrix::Mat4{Float32}
end

# Lighting uniform structure for use in shaders
struct LightingUniform
    position::Vec4{Float32}
    specularColor::Vec4{Float32}
    ambientIntensity::Float32
    diffuseIntensity::Float32
    specularIntensity::Float32
    specularShininess::Float32
end

# Function to create an empty CameraUniform
function emptyCameraUniform()
    eye = Vec3{Float32}(0.0f0, 0.0f0, 3.0f0)
    aspectRatio = 1.0f0
    lookAt = Vec3{Float32}(0.0f0, 0.0f0, 0.0f0)
    fov = Float32(π/4)
    viewMatrix = Mat4{Float32}(1.0f0)
    projMatrix = Mat4{Float32}(1.0f0)
    return CameraUniform(eye, aspectRatio, lookAt, fov, viewMatrix, projMatrix)
end

# Function to create an empty LightingUniform
function emptyLightingUniform()
    position = Vec4{Float32}(2.0f0, 2.0f0, 2.0f0, 1.0f0)
    specularColor = Vec4{Float32}(1.0f0, 1.0f0, 1.0f0, 1.0f0)
    ambientIntensity = 0.9f0
    diffuseIntensity = 0.5f0
    specularIntensity = 0.2f0
    specularShininess = 0.2f0
    return LightingUniform(position, specularColor, ambientIntensity, diffuseIntensity, specularIntensity, specularShininess)
end

# Convert uniform structs to byte arrays for buffer
function toByteArray(uniform::CameraUniform)
    return reinterpret(UInt8, [uniform]) |> collect
end

function toByteArray(uniform::LightingUniform)
    return reinterpret(UInt8, [uniform]) |> collect
end

# Generic toByteArray for Matrix types
function toByteArray(matrix::AbstractMatrix{T}) where T <: AbstractFloat
    return reinterpret(UInt8, [matrix[:]...]) |> collect
end
