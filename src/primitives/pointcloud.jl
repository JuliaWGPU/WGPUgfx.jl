using WGPUNative
using WGPUCore
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations
using Images

export defaultWGPUPointCloud, WGPUPointCloud, lookAtRightHanded, perspectiveMatrix, orthographicMatrix,
	windowingTransform, translateWGPUPointCloud, openglToWGSL, translate, scaleTransform,
	getUniformBuffer, getUniformData

export WGPUPointCloud

struct PointCloudData
	positions
	uvs
	normals
	indices
end

mutable struct WGPUPointCloud <: Renderable
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


# function readPlyFile(path)
# 	plyData = PlyIO.load_ply(path);
# 	vertexElement = plyData["vertex"]
# 	sh = cat(map((x) -> getindex(vertexElement, x), ["f_dc_0", "f_dc_1", "f_dc_2"])..., dims=2)
# 	scale = cat(map((x) -> getindex(vertexElement, x), ["scale_0", "scale_1", "scale_2"])..., dims=2)
# 	normals = cat(map((x) -> getindex(vertexElement, x), ["nx", "ny", "nz"])..., dims=2)
# 	points = cat(map((x) -> getindex(vertexElement, x), ["x", "y", "z"])..., dims=2)
# 	quaternions = cat(map((x) -> getindex(vertexElement, x), ["rot_0", "rot_1", "rot_2", "rot_3"])..., dims=2)
# 	features = cat(map((x) -> getindex(vertexElement, x), ["f_rest_$i" for i in 0:44])..., dims=2)
# 	opacity = vertexElement["opacity"]
# 	splatData = GSplatData(points, scale, sh, quaternions, opacity, features) 
# 	return splatData
# end


function defaultWGPUPointCloud(path::String; scale::Union{Vector{Float32}, Float32} = 1.0f0, color::Vector{Float64}=[0.5, 0.6, 0.7, 1.0], image::String="", topology="PointList")
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
	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	# swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;
	
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
	
	mesh = WGPUPointCloud(
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
