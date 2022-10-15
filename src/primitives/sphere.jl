# 
# struct Sphere
	# radius
	# nDivs
	# vertexData
	# indexData
	# colorData
# end
# 
# function defaultUniformData(::Type{Sphere})
	# uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	# return uniformData
# end
# 
# function getUniformData(sphere::Sphere)
	# return defaultUniformData(Sphere)
# end
# 
# function getUniformBuffer(gpuDevice, sphere::Sphere)
	# uniformData = defaultUniformData(Sphere)
	# (uniformBuffer, _) = WGPUCore.createBufferWithData(
		# gpuDevice,
		# "uniformBuffer",
		# uniformData,
		# ["Uniform", "CopyDst"]
	# )
	# uniformBuffer
# end
# 
# 
# function generateSphere(radius, nDivs)
	# vec = [0, 0, 1, 0]
	# for θz in 0:pi/nDivs:pi
		# rot = RotX(θ)
		# 
		# θ = 2*pi/nDivs
	# end
# end
# 
# function defaultSphere()
	# vertexData =  cat([
	    # [-1, -1, 1, 1, 0, 0],
	    # [1, -1, 1, 1, 1, 0],
	    # [1, 1, 1, 1, 1, 1],
	    # [-1, 1, 1, 1, 0, 1],
	    # [-1, 1, -1, 1, 1, 0],
	    # [1, 1, -1, 1, 0, 0],
	    # [1, -1, -1, 1, 0, 1],
	    # [-1, -1, -1, 1, 1, 1],
	    # [1, -1, -1, 1, 0, 0],
	    # [1, 1, -1, 1, 1, 0],
	    # [1, 1, 1, 1, 1, 1],
	    # [1, -1, 1, 1, 0, 1],
	    # [-1, -1, 1, 1, 1, 0],
	    # [-1, 1, 1, 1, 0, 0],
	    # [-1, 1, -1, 1, 0, 1],
	    # [-1, -1, -1, 1, 1, 1],
	    # [1, 1, -1, 1, 1, 0],
	    # [-1, 1, -1, 1, 0, 0],
	    # [-1, 1, 1, 1, 0, 1],
	    # [1, 1, 1, 1, 1, 1],
	    # [1, -1, 1, 1, 0, 0],
	    # [-1, -1, 1, 1, 1, 0],
	    # [-1, -1, -1, 1, 1, 1],
	    # [1, -1, -1, 1, 0, 1],
	# ]..., dims=2) .|> Float32
# 
	# indexData =   cat([
	        # [0, 1, 2, 2, 3, 0],
	        # [4, 5, 6, 6, 7, 4],
	        # [8, 9, 10, 10, 11, 8],
	        # [12, 13, 14, 14, 15, 12],
	        # [16, 17, 18, 18, 19, 16],
	        # [20, 21, 22, 22, 23, 20],
	    # ]..., dims=2) .|> UInt32
# 
	# textureData = cat([
	        # [50, 100, 150, 200],
	        # [100, 150, 200, 50],
	        # [150, 200, 50, 100],
	        # [200, 50, 100, 150],
	    # ]..., dims=2) .|> UInt8
	# 
	# sphere = Sphere(vertexData, indexData, textureData)
	# sphere
# end
# 
# function getVertexBuffer(gpuDevice, sphere::Sphere)
	# (vertexBuffer, _) = WGPUCore.createBufferWithData(
		# gpuDevice,
		# "vertexBuffer",
		# sphere.vertexData,
		# ["Vertex", "CopySrc"]
	# )
	# vertexBuffer
# end
# 
# 
# function getTextureView(gpuDevice, sphere::Sphere)
	# textureDataResized = repeat(sphere.textureData, inner=(64, 64))
	# textureSize = (size(textureDataResized)..., 1)
# 
	# texture = WGPUCore.createTexture(
		# gpuDevice,
		# "texture",
		# textureSize,
		# 1,
		# 1,
		# WGPUCoreTextureDimension_2D,
		# WGPUTextureFormat_R8Unorm,
		# WGPUCore.getEnum(WGPUCore.WGPUTextureUsage, ["CopyDst", "TextureBinding"]),
	# )
# 
	# textureView = WGPUCore.createView(texture)
	# (textureView, textureDataResized)
# end
# 
# function writeTexture(gpuDevice, sphere::Sphere)
	# (textureView, textureDataResized) = getTextureView(gpuDevice, sphere)
	# textureSize = textureView.size
	# dstLayout = [
		# :dst => [
			# :texture => textureView.texture |> Ref,
			# :mipLevel => 0,
			# :origin => ((0, 0, 0) .|> Float32)
		# ],
		# :textureData => textureDataResized |> Ref,
		# :layout => [
			# :offset => 0,
			# :bytesPerRow => textureSize[2], # TODO
			# :rowsPerImage => textureSize[1] |> first
		# ],
		# :textureSize => textureSize
	# ]
	# WGPUCore.writeTexture(gpuDevice.queue; dstLayout...)
	# return textureView
# end
# 
# function getIndexBuffer(gpuDevice, sphere::Sphere)
	# (indexBuffer, _) = WGPUCore.createBufferWithData(
		# gpuDevice,
		# "indexBuffer",
		# sphere.indexData |> flatten,
		# "Index"
	# )
	# indexBuffer
# end
# 
# function getVertexBufferLayout(sphere::Sphere)
	# WGPUCore.GPUVertexBufferLayout => [
		# :arrayStride => 6*4,
		# :stepMode => "Vertex",
		# :attributes => [
			# :attribute => [
				# :format => "Float32x4",
				# :offset => 0,
				# :shaderLocation => 0
			# ],
			# :attribute => [
				# :format => "Float32x2",
				# :offset => 4*4,
				# :shaderLocation => 1
			# ]
		# ]
	# ]
# end
# 
# function toMesh(::Type{Sphere})
	# 
# end
# 
# end
