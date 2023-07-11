using WGPUNative
using WGPUCore

export defaultPlane, Plane

mutable struct Plane
	width
	height
	wSegments
	hSegments
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


function prepareObject(gpuDevice, plane::Plane)
	uniformData = computeUniformData(plane)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Plane Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(plane, :uniformData, uniformData)
	setfield!(plane, :uniformBuffer, uniformBuffer)
	setfield!(plane, :gpuDevice, gpuDevice)
	setfield!(plane, :indexBuffer, getIndexBuffer(gpuDevice, plane))
	setfield!(plane, :vertexBuffer, getVertexBuffer(gpuDevice, plane))
	return plane
end


function preparePipeline(gpuDevice, scene, plane::Plane; isVision=false, binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(plane, :vertexBuffer)
	uniformBuffer = getfield(plane, :uniformBuffer)
	indexBuffer = getfield(plane, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(scene.camera; binding = 0), 
		getBindingLayouts(scene.light; binding = (isVision ? 2 : 1)), 
		getBindingLayouts(plane; binding=binding)
	)
	append!(
		bindings, 
		getBindings(scene.camera, cameraUniform; binding=0), 
		getBindings(scene.light, lightUniform; binding=(isVision ? 2 : 1)), 
		getBindings(plane, uniformBuffer; binding=binding)
	)
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindingLayouts, bindings)
	plane.pipelineLayout = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		plane,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" PLANE RENDER PIPELINE "
	)
	plane.renderPipeline = renderPipeline
end


function defaultUniformData(::Type{Plane}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end


function computeUniformData(plane::Plane)
	return defaultUniformData(Plane)
end


function getUniformBuffer(gpuDevice, plane::Plane)
	uniformData = defaultUniformData(Plane)
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"uniformBuffer", 
		uniformData, 
		["Uniform", "CopyDst"]
	)
	uniformBuffer
end



function defaultPlane(width=1, height=1, wSegments=2, hSegments=2, color=[0.6, 0.2, 0.5, 1.0])

	vertexData = cat([
		[-1, -1, 0, 1],
		[1, -1, 0, 1],
		[1, 1, 0, 1],
		[1, 1, 0, 1],
		[-1, 1, 0, 1],
		[-1, -1, 0, 1],
	]..., dims=2) .|> Float32

	unitColor = cat([
		[0.6, 0.4, 0.5, 1],
		[0.5, 0.6, 0.3, 1],
		[0.4, 0.5, 0.6, 1],
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, 2))

	indexData = cat([
		[0, 1, 2, 3, 4, 5],
	]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
		[0, 0, 1, 0],
	]..., dims=2) .|> Float32

	normalData = repeat(faceNormal, inner=(1, 3))

	
	Plane(
		width, 
		height, 
		wSegments, 
		hSegments, 
		nothing, #gpuDevice, 
		vertexData,
		colorData,
		indexData,
		normalData,
		nothing, #uvData,
		nothing, #uniformData,
		nothing, #uniformBuffer,
		nothing, #indexBuffer,
		nothing, #vertexBuffer,
		nothing, #textureData,
		nothing, #texture,
		nothing, #textureView,
		nothing, #sampler,
		nothing, #pipelineLayout,
		nothing, #renderPipeline
	)
end


Base.setproperty!(plane::Plane, f::Symbol, v) = begin
	setfield!(plane, f, v)
	setfield!(plane, :uniformData, f==:uniformData ? v : computeUniformData(plane))
	updateUniformBuffer(plane)
end

Base.getproperty(plane::Plane, f::Symbol) = begin
	if f != :uniformBuffer
		return getfield(plane, f)
	else
		return readUniformBuffer(plane)
	end
end

function getUniformData(plane::Plane)
	return plane.uniformData
end


function updateUniformBuffer(plane::Plane)
	data = SMatrix{4, 4}(plane.uniformData[:])
	@info :UniformBuffer data
	WGPUCore.writeBuffer(
		plane.gpuDevice.queue, 
		getfield(plane, :uniformBuffer),
		data,
	)
end

function readUniformBuffer(plane::Plane)
	data = WGPUCore.readBuffer(
		plane.gpuDevice,
		getfield(plane, :uniformBuffer),
		0,
		getfield(plane, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	@info "Received Buffer" datareinterpret
end

function getUniformBuffer(plane::Plane)
	getfield(plane, :uniformBuffer)
end


function getShaderCode(plane::Plane; isVision::Bool, islight=false, binding=0)
	name = Symbol(:plane, binding)
	isTexture = plane.textureData != nothing
	shaderSource = quote
		struct WGPUPlaneUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user WGPUPlaneUniform
		
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


function getVertexBuffer(gpuDevice, plane::Plane)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(
			[
				plane.vertexData, 
				plane.colorData, 
				plane.normalData,
				plane.uvData
			][plane.textureData != nothing ? (1:end) : (1:end-1)]...
		), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, plane::Plane)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		plane.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(plane::Plane; offset = 0)
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
		][plane.textureData != nothing ? (1:end) : (1:end-1)]
	]
end


function getBindingLayouts(plane::Plane; binding=0)
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
	][plane.textureData != nothing ? (1:end) : (1:1)]
	return bindingLayouts
end


function getBindings(plane::Plane, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
		WGPUCore.GPUTextureView => [
			:binding => binding + 1,
			:textureView => plane.textureView
		],
		WGPUCore.GPUSampler => [
			:binding => binding + 2,
			:sampler => plane.sampler
		]
	][plane.textureData != nothing ? (1:end) : (1:1)]
end

function getRenderPipelineOptions(scene, plane::Plane)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(plane)
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

function render(renderPass, renderPassOptions, plane::Plane)
	WGPUCore.setPipeline(renderPass, plane.renderPipeline)
	WGPUCore.setIndexBuffer(renderPass, plane.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, plane.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, plane.pipelineLayout.bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(plane.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end


function toMesh(::Type{Plane})
	
end


