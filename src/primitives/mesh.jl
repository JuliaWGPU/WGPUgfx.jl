using WGPU_jll

using WGPU
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations

export defaultWGPUMesh, WGPUMesh, lookAtRightHanded, perspectiveMatrix, orthographicMatrix, 
	windowingTransform, translateWGPUMesh, openglToWGSL, translate, scaleTransform,
	getUniformBuffer, getUniformData


export WGPUMesh

struct MeshData
	positions
	uvs
	normals
	indices
end

struct Index
	position
	uv
	normal
end

# TODO not used yet
function readMesh(path::String)
	extension = split(path, ".") |> last |> Symbol
	readMesh(path::String, Val(extension))
end

function readObj(path::String)
	(positions, normals, uvs, indices) = ([], [], [], [])
    f = open(path)
    while(!eof(f))
        line = readline(f)
        s = split(line, " ")
        if s[1] == "v"
            vec = [Meta.parse(i) for i in s[2:end]]
            push!(positions, [vec..., 1.0])
        elseif s[1] == "vt"
            vec = [Meta.parse(i) for i in s[2:end]]
            push!(uvs, vec)
        elseif s[1] == "vn"
            vec = [Meta.parse(i) for i in s[2:end]]
            push!(normals, [vec..., 0])
        elseif s[1] == "f"
            if contains(line, "//")
                faceidxs = []
                for i in s[2:end]
                    (p, n) = [Meta.parse(j) for j in split(i, "//")]
                    push!(faceidxs, (p, n))
                end
                push!(indices, [Index(p, -1, n) for (p, n) in faceidxs])
            elseif contains(line, "/")
                faceidxs = []
                for i in s[2:end]
                    (p, u, n) = [Meta.parse(j) for j in split(i, "/")]
                    push!(faceidxs, (p, u, n))
                end
                push!(indices, [idx for idx in faceidxs])
            else 
                indexList = [Index(Meta.parse(i), -1, -1) for i in s[2:end]]
                push!(indices, indexList)
            end
        end
    end
    return MeshData(positions, uvs, normals, indices)
end

mutable struct WGPUMesh
	gpuDevice
	topology::WGPUPrimitiveTopology
	vertexData
	colorData
	indexData
	normalData
	uvData
	uniformData
	uniformBuffer
end

function prepareObject(gpuDevice, mesh::WGPUMesh)
	uniformData = computeUniformData(mesh)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice,
		"Mesh Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(mesh, :uniformData, uniformData)
	setfield!(mesh, :uniformBuffer, uniformBuffer)
	setfield!(mesh, :gpuDevice, gpuDevice)
	return mesh
end


function defaultUniformData(::Type{WGPUMesh}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

# TODO for now mesh is static
# definitely needs change based on position, rotation etc ...
function computeUniformData(mesh::WGPUMesh)
	return defaultUniformData(WGPUMesh)
end


function defaultWGPUMesh(path::String; topology=WGPUPrimitiveTopology_TriangleList)
	meshdata = readObj(path) # TODO hardcoding Obj format
	vIndices = cat(map((x)->first.(x), meshdata.indices)..., dims=2) .|> UInt32
	nIndices = cat(map((x)->getindex.(x, 3), meshdata.indices)..., dims=2)
	vertexData = cat(meshdata.positions[vIndices[:]]..., dims=2) .|> Float32
	indexData = vIndices
	unitColor = cat([
		[0.3, 0.6, 0.5, 1]
	]..., dims=2) .|> Float32
	
	colorData = repeat(unitColor, inner=(1, length(vIndices)))

	normalData = cat(meshdata.normals[nIndices[:]]..., dims=2) .|> Float32
	
	mesh = WGPUMesh(
		nothing, 
		topology,
		vertexData,
		colorData, 
		indexData, 
		normalData, 
		nothing, 
		nothing, 
		nothing
	)
	mesh
end


Base.setproperty!(mesh::WGPUMesh, f::Symbol, v) = begin
	setfield!(mesh, f, v)
	setfield!(mesh, :uniformData, f==:uniformData ? v : computeUniformData(mesh))
	updateUniformBuffer(mesh)
end


Base.getproperty(mesh::WGPUMesh, f::Symbol) = begin
	getfield(mesh, f)
end


function getUniformData(mesh::WGPUMesh)
	return mesh.uniformData
end


function updateUniformBuffer(mesh::WGPUMesh)
	data = SMatrix{4, 4}(mesh.uniformData[:])
	@info :UniformBuffer data
	WGPU.writeBuffer(
		mesh.gpuDevice[].queue, 
		getfield(mesh, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(mesh::WGPUMesh)
	data = WGPU.readBuffer(
		mesh.gpuDevice,
		getfield(mesh, :uniformBuffer),
		0,
		getfield(mesh, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	@info "Received Buffer" datareinterpret
end


function getUniformBuffer(mesh::WGPUMesh)
	getfield(mesh, :uniformBuffer)
end


function getShaderCode(::Type{WGPUMesh})
	shaderSource = quote
		struct WGPUMeshUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 0 mesh::@user WGPUMeshUniform
 	end
 	
	return shaderSource
end


# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, mesh::WGPUMesh)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat([mesh.vertexData, mesh.colorData, mesh.normalData]...), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, mesh::WGPUMesh)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		mesh.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(::Type{WGPUMesh})
	WGPU.GPUVertexBufferLayout => [
		:arrayStride => 12*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => 0
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 4*4,
				:shaderLocation => 1
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 8*4,
				:shaderLocation => 2
			]
		]
	]
end


function getBindingLayouts(::Type{WGPUMesh})
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => 4,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(::Type{WGPUMesh}, uniformBuffer)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => 4,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
	]
end

