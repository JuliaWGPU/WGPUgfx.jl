using WGPUNative
using WGPUCore

export defaultCube, Cube

mutable struct Cube
	gpuDevice
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
	pipelineLayout
	renderPipeline
end

function prepareObject(gpuDevice, cube::Cube)
	uniformData = computeUniformData(cube)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Cube Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(cube, :uniformData, uniformData)
	setfield!(cube, :uniformBuffer, uniformBuffer)
	setfield!(cube, :gpuDevice, gpuDevice)
	setfield!(cube, :indexBuffer, getIndexBuffer(gpuDevice, cube))
	setfield!(cube, :vertexBuffer, getVertexBuffer(gpuDevice, cube))
	return cube
end

function preparePipeline(gpuDevice, scene, cube::Cube; isVision=false, binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(cube, :vertexBuffer)
	uniformBuffer = getfield(cube, :uniformBuffer)
	indexBuffer = getfield(cube, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(scene.camera; binding = 0), 
		getBindingLayouts(scene.light; binding = (isVision ? 2 : 1)), 
		getBindingLayouts(cube; binding=binding)
	)
	append!(
		bindings, 
		getBindings(scene.camera, cameraUniform; binding=0), 
		getBindings(scene.light, lightUniform; binding=(isVision ? 2 : 1)), 
		getBindings(cube, uniformBuffer; binding=binding)
	)
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindingLayouts, bindings)
	cube.pipelineLayout = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		cube,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" CUBE RENDER PIPELINE "
	)
	cube.renderPipeline = renderPipeline
end

function defaultUniformData(::Type{Cube}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

# TODO for now cube is static
# definitely needs change based on position, rotation etc ...
function computeUniformData(cube::Cube)
	return defaultUniformData(Cube)
end


function defaultCube()
	vertexData = cat([
	    [-1, -1, 1, 1],
	    [1, -1, 1, 1],
	    [1, 1, 1, 1],
	    [-1, 1, 1, 1],
	    [-1, 1, -1, 1],
	    [1, 1, -1, 1],
	    [1, -1, -1, 1],
	    [-1, -1, -1, 1],
	    [1, -1, -1, 1],
	    [1, 1, -1, 1],
	    [1, 1, 1, 1],
	    [1, -1, 1, 1],
	    [-1, -1, 1, 1],
	    [-1, 1, 1, 1],
	    [-1, 1, -1, 1],
	    [-1, -1, -1, 1],
	    [1, 1, -1, 1],
	    [-1, 1, -1, 1],
	    [-1, 1, 1, 1],
	    [1, 1, 1, 1],
	    [1, -1, 1, 1],
	    [-1, -1, 1, 1],
	    [-1, -1, -1, 1],
	    [1, -1, -1, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.6, 0.4, 0.5, 1],
		[0.5, 0.6, 0.3, 1],
		[0.4, 0.5, 0.6, 1],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 8))

	indexData =   cat([
	        [0, 1, 2, 2, 3, 0], 
	        [4, 5, 6, 6, 7, 4],  
	        [8, 9, 10, 10, 11, 8], 
	        [12, 13, 14, 14, 15, 12], 
	        [16, 17, 18, 18, 19, 16], 
	        [20, 21, 22, 22, 23, 20], 
	    ]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
		[0, 0, -1, 0],
		[1, 0, 0, 0],
		[-1, 0, 0, 0],
		[0, 1, 0, 0],
		[0, -1, 0, 0]
	]..., dims=2) .|> Float32
	
	normalData = repeat(faceNormal, inner=(1, 4))

	cube = Cube(
		nothing, 		# gpuDevice
		vertexData, 
		colorData, 
		indexData, 
		normalData, 
		nothing, 		# TODO fill later
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		nothing,	 	# textureData
		nothing,	 	# texture
		nothing,	 	# textureView
		nothing,	 	# sampler
		nothing,		# pipelineLayout
		nothing			# renderPipeline
	)
	cube
end


Base.setproperty!(cube::Cube, f::Symbol, v) = begin
	setfield!(cube, f, v)
	setfield!(cube, :uniformData, f==:uniformData ? v : computeUniformData(cube))
	updateUniformBuffer(cube)
end


Base.getproperty(cube::Cube, f::Symbol) = begin
	if f != :uniformBuffer
		return getfield(cube, f)
	else
		return readUniformBuffer(cube)
	end
end


function getUniformData(cube::Cube)
	return cube.uniformData
end


function updateUniformBuffer(cube::Cube)
	data = SMatrix{4, 4}(cube.uniformData[:])
	@info :UniformBuffer data
	WGPUCore.writeBuffer(
		cube.gpuDevice.queue, 
		getfield(cube, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(cube::Cube)
	data = WGPUCore.readBuffer(
		cube.gpuDevice,
		getfield(cube, :uniformBuffer),
		0,
		getfield(cube, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	@info "Received Buffer" datareinterpret
end


function getUniformBuffer(cube::Cube)
	getfield(cube, :uniformBuffer)
end

function getShaderCode(cube::Cube; isVision::Bool, islight=false, binding=0)
	name = Symbol(:cube, binding)
	isTexture = cube.textureData != nothing
	shaderSource = quote
		struct WGPUCubeUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user WGPUCubeUniform
		
		if $isTexture
			@var Generic 0 $(binding + 1)  tex::Texture2D{Float32}
			@var Generic 0 $(binding + 2)  smplr::Sampler
		end

		@vertex function vs_main(vertexIn::@user VertexInput)::@user VertexOutput
			@var out::@user VertexOutput
			if $isVision
				@var pos::Vec4{Float32} = $(name).transform*vertexIn.pos
				out.vPosLeft = lefteye.transform*pos
				out.vPosRight = righteye.transform*pos
				out.pos = vertexIn.pos
			else
				out.pos = $(name).transform*vertexIn.pos
				out.pos = camera.transform*out.pos
			end
			out.vColor = vertexIn.vColor
			if $isTexture
				out.vTexCoords = vertexIn.vTexCoords
			end
			if $islight
				if $isVision
					@var normal::Vec4{Float32} = $(name).transform*vertexIn.vNormal
					out.vNormalLeft = lefteye.transform*normal
					out.vNormalRight = righteye.transform*normal
				else
					out.vNormal = $(name).transform*vertexIn.vNormal
					out.vNormal = camera.transform*out.vNormal
				end
			end
			return out
		end

		@fragment function fs_main(fragmentIn::@user VertexOutput)::@location 0 Vec4{Float32}
			if $isTexture
				@var color::Vec4{Float32} = textureSample(tex, smplr, fragmentIn.vTexCoords)
			else
				@var color::Vec4{Float32} = fragmentIn.vColor
			end
			if $islight
				if $isVision
					@let NLeft::Vec3{Float32} = normalize(fragmentIn.vNormalLeft.xyz)
					@let LLeft::Vec3{Float32} = normalize(lighting.position.xyz - fragmentIn.vPosLeft.xyz)
					@let VLeft::Vec3{Float32} = normalize(lefteye.eye.xyz - fragmentIn.vPosLeft.xyz)
					@let HLeft::Vec3{Float32} = normalize(LLeft + VLeft)
					@let NRight::Vec3{Float32} = normalize(fragmentIn.vNormalRight.xyz)
					@let LRight::Vec3{Float32} = normalize(lighting.position.xyz - fragmentIn.vPosRight.xyz)
					@let VRight::Vec3{Float32} = normalize(righteye.eye.xyz - fragmentIn.vPosRight.xyz)
					@let HRight::Vec3{Float32} = normalize(LRight + VRight)
					@let diffuseLeft::Float32 = lighting.diffuseIntensity*max(dot(NLeft, LLeft), 0.0)
					@let specularLeft::Float32 = lighting.specularIntensity*pow(max(dot(NLeft, HLeft), 0.0), lighting.specularShininess)
					@let ambientLeft::Float32 = lighting.ambientIntensity
					@let diffuseRight::Float32 = lighting.diffuseIntensity*max(dot(NRight, LRight), 0.0)
					@let specularRight::Float32 = lighting.specularIntensity*pow(max(dot(NRight, HRight), 0.0), lighting.specularShininess)
					@let ambientRight::Float32 = lighting.ambientIntensity
					@let colorLeft::Vec4{Float32} = color*(ambientLeft + diffuseLeft) + lighting.specularColor*specularLeft
					@let colorRight::Vec4{Float32} = color*(ambientRight + diffuseRight) + lighting.specularColor*specularRight
					return colorLeft + colorRight
				else
					@let N::Vec3{Float32} = normalize(fragmentIn.vNormal.xyz)
					@let L::Vec3{Float32} = normalize(lighting.position.xyz - fragmentIn.pos.xyz)
					@let V::Vec3{Float32} = normalize(camera.eye.xyz - fragmentIn.pos.xyz)
					@let H::Vec3{Float32} = normalize(L + V)
					@let diffuse::Float32 = lighting.diffuseIntensity*max(dot(N, L), 0.0)
					@let specular::Float32 = lighting.specularIntensity*pow(max(dot(N, H), 0.0), lighting.specularShininess)
					@let ambient::Float32 = lighting.ambientIntensity
					return color*(ambient + diffuse) + lighting.specularColor*specular
				end
			else
				return color
			end
		end

 	end
 	
	return shaderSource
end

# TODO check it its called multiple times
function getVertexBuffer(gpuDevice, cube::Cube)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(
			[
				cube.vertexData, 
				cube.colorData, 
				cube.normalData,
				cube.uvData
			][cube.textureData != nothing ? (1:end) : (1:end-1)]...
		), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, cube::Cube)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		cube.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

# TODO remove kwargs offset
function getVertexBufferLayout(cube::Cube; offset = 0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => 12*4,
		:stepMode => "Vertex",
		:attributes => [
			:attribute => [
				:format => "Float32x4",
				:offset => 0,
				:shaderLocation => offset + 0
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 4*4,
				:shaderLocation => offset + 1
			],
			:attribute => [
				:format => "Float32x4",
				:offset => 8*4,
				:shaderLocation => offset + 2
			],
			:attribute => [
				:format => "Float32x2",
				:offset => 12*4,
				:shaderLocation => offset + 3
			]
		][cube.textureData != nothing ? (1:end) : (1:end-1)]
	]
end


function getBindingLayouts(cube::Cube; binding=0)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
		WGPUCore.WGPUTextureEntry => [
			:binding => binding + 1,
			:visibility => "Fragment",
			:sampleType => "Float",
			:viewDimension => "2D",
			:multisampled => false
		],
		WGPUCore.WGPUSamplerEntry => [
			:binding => binding + 2,
			:visibility => "Fragment",
			:type => "Filtering"
		]
	][cube.textureData != nothing ? (1:end) : (1:1)]
	return bindingLayouts
end


function getBindings(cube::Cube, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
		WGPUCore.GPUTextureView => [
			:binding => binding + 1,
			:textureView => cube.textureView
		],
		WGPUCore.GPUSampler => [
			:binding => binding + 2,
			:sampler => cube.sampler
		]
	][cube.textureData != nothing ? (1:end) : (1:1)]
end

function getRenderPipelineOptions(scene, cube::Cube)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(cube)
				]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => "TriangleList",
			:frontFace => "CCW",
			:cullMode => "Back",
			:stripIndexFormat => "Undefined"
		],
		WGPUCore.GPUDepthStencilState => [
			:depthWriteEnabled => true,
			:depthCompare => WGPUCompareFunction_LessEqual,
			:format => WGPUTextureFormat_Depth24Plus
		],
		WGPUCore.GPUMultiSampleState => [
			:count => 1,
			:mask => typemax(UInt32),
			:alphaToCoverageEnabled=>false,
		],
		WGPUCore.GPUFragmentState => [
			:_module => scene.cshader.internal[],						# SET THIS
			:entryPoint => "fs_main",							# SET THIS (FIXED FOR NOW)
			:targets => [
				WGPUCore.GPUColorTargetState =>	[
					:format => scene.renderTextureFormat,				# SET THIS
					:color => [
						:srcFactor => "One",
						:dstFactor => "Zero",
						:operation => "Add"
					],
					:alpha => [
						:srcFactor => "One",
						:dstFactor => "Zero",
						:operation => "Add",
					]
				],
			]
		]
	]
	renderpipelineOptions
end

function render(renderPass, renderPassOptions, cube::Cube)
	WGPUCore.setPipeline(renderPass, cube.renderPipeline)
	WGPUCore.setIndexBuffer(renderPass, cube.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, cube.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, cube.pipelineLayout.bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(cube.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end


function toMesh(cube::Cube)
	
end
