using WGPUNative
using WGPUCore

export Triangle3D, defaultTriangle3D

mutable struct Triangle3D
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

function prepareObject(gpuDevice, tri::Triangle3D)
	uniformData = computeUniformData(tri)
	# TODO
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Triangle Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(tri, :uniformData, uniformData)
	setfield!(tri, :uniformBuffer, uniformBuffer)
	setfield!(tri, :gpuDevice, gpuDevice)
	setfield!(tri, :indexBuffer, getIndexBuffer(gpuDevice, tri))
	setfield!(tri, :vertexBuffer, getVertexBuffer(gpuDevice, tri))
	return tri
end


function preparePipeline(gpuDevice, scene, tri::Triangle3D; isVision=false, binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(tri, :vertexBuffer)
	uniformBuffer = getfield(tri, :uniformBuffer)
	indexBuffer = getfield(tri, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(scene.camera; binding = 0), 
		getBindingLayouts(scene.light; binding = (isVision ? 2 : 1)), 
		getBindingLayouts(tri; binding=binding)
	)
	append!(
		bindings, 
		getBindings(scene.camera, cameraUniform; binding=0), 
		getBindings(scene.light, lightUniform; binding=(isVision ? 2 : 1)), 
		getBindings(tri, uniformBuffer; binding=binding)
	)
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindingLayouts, bindings)
	tri.pipelineLayout = pipelineLayout
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		tri,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" TRIANGLE RENDER PIPELINE "
	)
	tri.renderPipeline = renderPipeline
end


function defaultUniformData(::Type{Triangle3D})
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end

function computeUniformData(tri::Triangle3D)
	return defaultUniformData(Triangle3D)
end


function defaultTriangle3D()
	vertexData =  cat([
	    [-1.0, -1.0, 0.0, 1],
   	    [1.0, -1.0, 0.0, 1],	    
   	    [0.0, 1.0, 0.0, 1],
	]..., dims=2) .|> Float32

	indexData = cat([[0, 1, 2]]..., dims=2) .|> UInt32

	faceNormal = cat([
		[0, 0, 1, 0],
	]..., dims=2) .|> Float32

	normalData = repeat(faceNormal, inner=(1, 3))
	
	# colorData = repeat(cat([[0.5, 0.3, 0.3, 1]]..., dims=2), 1, 3) .|> Float32

	colorData = [
		1.0f0 0.0f0 0.0f0 1.0f0; 
		0.0f0 1.0f0 0.0f0 1.0f0; 
		0.0f0 0.0f0 1.0f0 1.0f0; 
	] |> adjoint
	
	triangle = Triangle3D(
		nothing,
		vertexData, 
		colorData, 
		indexData, 
		normalData, 
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
		nothing,
	)
	triangle
end

Base.setproperty!(tri::Triangle3D, f::Symbol, v) = begin
	setfield!(tri, f, v)
	setfield!(tri, :uniformData, f==:uniformData ? v : computeUniformData(tri))
	updateUniformBuffer(tri)
end


Base.getproperty(tri::Triangle3D, f::Symbol) = begin
	if f != :uniformBuffer
		return getfield(tri, f)
	else
		return readUniformBuffer(tri)
	end
end


function getUniformData(tri::Triangle3D)
	return tri.uniformData
end


function updateUniformBuffer(tri::Triangle3D)
	data = SMatrix{4, 4}(tri.uniformData[:])
	@info :UniformBuffer data
	WGPUCore.writeBuffer(
		tri.gpuDevice.queue, 
		getfield(tri, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(tri::Triangle3D)
	data = WGPUCore.readBuffer(
		tri.gpuDevice,
		getfield(tri, :uniformBuffer),
		0,
		getfield(tri, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	@info "Received Buffer" datareinterpret
end

function getUniformBuffer(tri::Triangle3D)
	getfield(tri, :uniformBuffer)
end


function getShaderCode(tri::Triangle3D; isVision::Bool, islight=false, binding=0)
	name = Symbol(:tri, binding)
	isTexture = tri.textureData != nothing
	shaderSource = quote
		struct WGPUTriangle3DUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user WGPUTriangle3DUniform
		
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


function getVertexBuffer(gpuDevice, tri::Triangle3D)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(
			[
				tri.vertexData, 
				tri.colorData, 
				tri.normalData,
				tri.uvData
			][tri.textureData != nothing ? (1:end) : (1:end-1)]...
		), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end

function getIndexBuffer(gpuDevice, tri::Triangle3D)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		tri.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end

function getVertexBufferLayout(tri::Triangle3D; offset = 0)
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
		][tri.textureData != nothing ? (1:end) : (1:end-1)]
	]
end

function getBindingLayouts(tri::Triangle3D; binding=0)
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
	][tri.textureData != nothing ? (1:end) : (1:1)]
	return bindingLayouts
end

function getBindings(tri::Triangle3D, uniformBuffer; binding=0)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
		WGPUCore.GPUTextureView => [
			:binding => binding + 1,
			:textureView => tri.textureView
		],
		WGPUCore.GPUSampler => [
			:binding => binding + 2,
			:sampler => tri.sampler
		]
	][tri.textureData != nothing ? (1:end) : (1:1)]
end

function getRenderPipelineOptions(scene, tri::Triangle3D)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(tri)
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

function render(renderPass, renderPassOptions, tri::Triangle3D)
	WGPUCore.setPipeline(renderPass, tri.renderPipeline)
	WGPUCore.setIndexBuffer(renderPass, tri.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, tri.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, tri.pipelineLayout.bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(tri.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end

function toMesh(::Type{Triangle3D})
	
end
