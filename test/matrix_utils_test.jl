using Test
using WGPUgfx
using LinearAlgebra
using StaticArrays
using Rotations
using Quaternions

@testset "Matrix Utilities Tests" begin
    # Test isValidMatrix
    @test isValidMatrix(Matrix{Float32}(I, 4, 4)) == true
    @test isValidMatrix(ones(Float32, 4, 4)) == true
    @test isValidMatrix(ones(Float32, 3, 3)) == false
    @test isValidMatrix([1, 2, 3, 4]) == false
    @test isValidMatrix(nothing) == false

    # Test with invalid values
    invalid_matrix = Matrix{Float32}(I, 4, 4)
    invalid_matrix[2, 3] = NaN
    @test isValidMatrix(invalid_matrix) == false

    # Test ensureSMatrix
    identity_matrix = Matrix{Float32}(I, 4, 4)
    @test ensureSMatrix(identity_matrix) isa SMatrix{4, 4, Float32}
    @test ensureSMatrix(SMatrix{4, 4, Float32}(identity_matrix)) isa SMatrix{4, 4, Float32}
    @test_throws ErrorException ensureSMatrix(ones(Float32, 3, 3))
    
    # Test convertToMatrix
    # From SMatrix
    sm = @SMatrix [1.0f0 0.0f0 0.0f0 0.0f0; 0.0f0 1.0f0 0.0f0 0.0f0; 0.0f0 0.0f0 1.0f0 0.0f0; 0.0f0 0.0f0 0.0f0 1.0f0]
    @test convertToMatrix(sm) isa SMatrix{4, 4, Float32}
    @test convertToMatrix(sm) == sm
    
    # From regular matrix
    reg_mat = [1.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0; 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 1.0]
    @test convertToMatrix(reg_mat) isa SMatrix{4, 4, Float32}
    
    # From 3x3 matrix
    mat3 = [1.0 0.0 0.0; 0.0 1.0 0.0; 0.0 0.0 1.0]
    converted = convertToMatrix(mat3)
    @test converted isa SMatrix{4, 4, Float32}
    @test converted[1:3, 1:3] == mat3
    @test converted[4, 4] == 1.0f0
    
    # From RotMatrix
    rot = RotMatrix{3, Float64}(RotX(0.5))
    converted = convertToMatrix(rot)
    @test converted isa SMatrix{4, 4, Float32}
    @test converted[1:3, 1:3] ≈ rot
    @test converted[4, 4] == 1.0f0
    
    # From Quaternion
    quat = Quaternion(0.707, 0.0, 0.707, 0.0) # 90 degree rotation around Y
    converted = convertToMatrix(quat)
    @test converted isa SMatrix{4, 4, Float32}
    @test converted[4, 4] == 1.0f0
    
    # Test handling errors
    @test_throws ErrorException convertToMatrix(ones(2, 2))
end