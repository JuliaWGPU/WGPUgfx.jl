

struct Sphere
	radius
	nDivs
	vertexData
	indexData
	textureData
end

function defaultUniformData(::Type{Cube}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function getUniformData(cube::Cube)
	return defaultUniformData(Cube)
end

function getUniformBuffer(gpuDevice, cube::Cube)
	uniformData = defaultUniformData(Cube)
	(uniformBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"uniformBuffer", 
		uniformData, 
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end

function defaultSphere()
	vertexData =  cat([
	    [-1, -1, 1, 1, 0, 0],
	    [1, -1, 1, 1, 1, 0],
	    [1, 1, 1, 1, 1, 1],
	    [-1, 1, 1, 1, 0, 1],
	    [-1, 1, -1, 1, 1, 0],
	    [1, 1, -1, 1, 0, 0],
	    [1, -1, -1, 1, 0, 1],
	    [-1, -1, -1, 1, 1, 1],
	    [1, -1, -1, 1, 0, 0],
	    [1, 1, -1, 1, 1, 0],
	    [1, 1, 1, 1, 1, 1],
	    [1, -1, 1, 1, 0, 1],
	    [-1, -1, 1, 1, 1, 0],
	    [-1, 1, 1, 1, 0, 0],
	    [-1, 1, -1, 1, 0, 1],
	    [-1, -1, -1, 1, 1, 1],
	    [1, 1, -1, 1, 1, 0],
	    [-1, 1, -1, 1, 0, 0],
	    [-1, 1, 1, 1, 0, 1],
	    [1, 1, 1, 1, 1, 1],
	    [1, -1, 1, 1, 0, 0],
	    [-1, -1, 1, 1, 1, 0],
	    [-1, -1, -1, 1, 1, 1],
	    [1, -1, -1, 1, 0, 1],
	]..., dims=2) .|> Float32

	indexData =   cat([
	        [0, 1, 2, 2, 3, 0], 
	        [4, 5, 6, 6, 7, 4],  
	        [8, 9, 10, 10, 11, 8], 
	        [12, 13, 14, 14, 15, 12], 
	        [16, 17, 18, 18, 19, 16], 
	        [20, 21, 22, 22, 23, 20], 
	    ]..., dims=2) .|> UInt32

	textureData = cat([
	        [50, 100, 150, 200],
	        [100, 150, 200, 50],
	        [150, 200, 50, 100],
	        [200, 50, 100, 150],
	    ]..., dims=2) .|> UInt8
	
	cube = Cube(vertexData, indexData, textureData)
	cube
end

function getVertexBuffer(gpuDevice, cube::Cube)
	(vertexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		cube.vertexData, 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getTextureView(gpuDevice, cube::Cube)
	textureDataResized = repeat(cube.textureData, inner=(64, 64))
	textureSize = (size(textureDataResized)..., 1)

	texture = WGPU.createTexture(
		gpuDevice,
		"texture", 
		textureSize, 
		1,
		1, 
		WGPUTextureDimension_2D,  
		WGPUTextureFormat_R8Unorm,  
		WGPU.getEnum(WGPU.WGPUTextureUsage, ["CopyDst", "TextureBinding"]),
	)

	textureView = WGPU.createView(texture)
	(textureView, textureDataResized)
end

function writeTexture(gpuDevice, cube::Cube)
	(textureView, textureDataResized) = getTextureView(gpuDevice, cube)
	textureSize = textureView.size
	dstLayout = [
		:dst => [
			:texture => textureView.texture |> Ref,
			:mipLevel => 0,
			:origin => ((0, 0, 0) .|> Float32)
		],
		:textureData => textureDataResized |> Ref,
		:layout => [
			:offset => 0,
			:bytesPerRow => textureSize[2], # TODO
			:rowsPerImage => textureSize[1] |> first
		],
		:textureSize => textureSize
	]
	WGPU.writeTexture(gpuDevice.queue; dstLayout...)
	return textureView
end

function getIndexBuffer(gpuDevice, cube::Cube)
	(indexBuffer, _) = WGPU.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		cube.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

function getVertexBufferLayout(cube::Cube)
	WGPU.GPUVertexBufferLayout => [
		:arrayStride => 6*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => 0
			],
			:attribute => [
				:format => "Float32x2",
				:offset => 4*4,
				:shaderLocation => 1
			]
		]
	]
end

function toMesh(::Type{Cube})
	
end

end
