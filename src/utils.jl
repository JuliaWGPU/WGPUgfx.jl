# Utility functions for WGPUgfx

using LinearAlgebra
using StaticArrays
using Rotations
using Quaternions


export convertToMatrix, ensureSMatrix, isValidMatrix, convertMatrixToSMatrix

"""
    isValidMatrix(matrix)

Check if an object is a valid matrix for use in transformations.
"""
function isValidMatrix(matrix)
    # Basic shape checking
    if !(matrix isa AbstractMatrix)
        return false
    end

    # Check dimensions
    if size(matrix) != (4, 4)
        return false
    end

    # Check if values are valid numbers
    for val in matrix
        if !isfinite(val)
            return false
        end
    end

    return true
end

"""
    ensureSMatrix(matrix)

Convert a matrix to SMatrix{4,4,Float32} or throw an error if not possible.
"""
function ensureSMatrix(matrix)
    if matrix isa SMatrix{4,4,Float32}
        return matrix
    elseif isValidMatrix(matrix)
        return SMatrix{4,4,Float32}(matrix)
    else
        error("Cannot convert to SMatrix{4,4,Float32}: $(typeof(matrix))")
    end
end

"""
    convertToMatrix(data)

Convert various data types to a 4x4 Float32 matrix.
"""
function convertToMatrix(matrix::SMatrix{4,4})
    return SMatrix{4,4,Float32}(matrix)
end

function convertToMatrix(matrix::AbstractMatrix)
    if size(matrix) == (4, 4)
        return SMatrix{4,4,Float32}(matrix)
    elseif size(matrix) == (3, 3)
        # Convert 3x3 to 4x4 homogeneous matrix
        result = Matrix{Float32}(I, 4, 4)
        result[1:3, 1:3] .= matrix
        return SMatrix{4,4,Float32}(result)
    else
        error("Matrix size $(size(matrix)) cannot be converted to 4x4 matrix")
    end
end

function convertToMatrix(rotMatrix::RotMatrix{3})
    result = Matrix{Float32}(I, 4, 4)
    result[1:3, 1:3] .= rotMatrix
    return SMatrix{4,4,Float32}(result)
end

function convertToMatrix(quat::Quaternion)
    result = Matrix{Float32}(I, 4, 4)
    result[1:3, 1:3] .= RotMatrix(quat)
    return SMatrix{4,4,Float32}(result)
end

"""
    convertMatrixToSMatrix(M)

Converts a Matrix to SMatrix{4,4,Float32}.
"""
function convertMatrixToSMatrix(M)
    if M isa SMatrix{4,4}
        return convert(SMatrix{4,4,Float32}, M)
    else
        return SMatrix{4,4,Float32}(M)
    end
end
