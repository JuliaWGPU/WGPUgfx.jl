using WGPUNative
using WGPUCore
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations
using Images

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
                push!(indices, [(p, -1, n) for (p, n) in faceidxs])
            elseif contains(line, "/")
                faceidxs = []
                for i in s[2:end]
                    (p, u, n) = [Meta.parse(j) for j in split(i, "/")]
                    push!(faceidxs, (p, u, n))
                end
                push!(indices, [idx for idx in faceidxs])
            else 
                indexList = [(Meta.parse(i), -1, -1) for i in s[2:end]]
                push!(indices, indexList)
            end
        end
    end
    return MeshData(positions, uvs, normals, indices)
end

mutable struct WGPUMesh <: MeshSurface
	gpuDevice
	topology
	vertexData
	colorData
	indexData
	normalData
	uvData
	uniformData
	uniformBuffer
	indexBuffer
	vertexBuffer
	textureData
	texture
	textureView
	sampler
	pipelineLayouts
	renderPipelines
	cshaders
end

function defaultWGPUMesh(path::String; scale::Union{Vector{Float32}, Float32} = 1.0f0, color::Vector{Float64}=[0.5, 0.6, 0.7, 1.0], image::String="", topology="TriangleList")
	meshdata = readObj(path) # TODO hardcoding Obj format
	vIndices = reduce(hcat, map((x)->broadcast(first, x), meshdata.indices)) .|> UInt32
	nIndices = reduce(hcat, map((x)->getindex.(x, 3), meshdata.indices))
	uIndices = reduce(hcat, map((x)->getindex.(x, 2), meshdata.indices))
	vertexData = reduce(hcat, meshdata.positions[vIndices[:]]) .|> Float32

	if typeof(scale) == Float32
		scale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end
	# TODO blender conversion 
	# swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;
	
	vertexData = scale*swapMat*vertexData
	uvData = nothing
	textureData = nothing
	texture = nothing
	textureView = nothing
	
	if image != ""
		uvData = reduce(hcat, meshdata.uvs[uIndices[:]]) .|> Float32
		textureData = begin
			img = load(image)
			img = imresize(img, (256, 256)) # TODO hardcoded size
			img = RGBA.(img)
			imgview = channelview(img) |> collect 
		end
	end
	
	indexData = 0:length(vIndices)-1 |> collect .|> UInt32
	unitColor = cat([
		color
	]..., dims=2) .|> Float32
	
	colorData = repeat(unitColor, inner=(1, length(vIndices)))
	
	normalData = scale*swapMat*reduce(hcat, meshdata.normals[nIndices[:]]) .|> Float32
	
	mesh = WGPUMesh(
		nothing, 
		topology,
		vertexData,
		colorData, 
		indexData, 
		normalData, 
		uvData, 
		nothing, 
		nothing,
		nothing,
		nothing,
		textureData,
		nothing, 
		nothing,
		nothing,
		Dict(),
		Dict(),
		Dict()
	)
	mesh
end
