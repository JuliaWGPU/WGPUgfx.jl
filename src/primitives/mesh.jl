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

struct Index
	position
	uv
	normal
end

# TODO not used yet
# TODO think about conversion from blender export
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
	indexBuffer
	vertexBuffer
	textureData
	texture
	textureView
	sampler
	bindGroup
	renderPipeline
end

function prepareObject(gpuDevice, mesh::WGPUMesh)
	uniformData = computeUniformData(mesh)
	if mesh.textureData != nothing
		textureSize = (size(mesh.textureData)[2:3]..., 1)
		texture = WGPUCore.createTexture(
			gpuDevice,
			"Mesh Texture",
			textureSize,
			1,
			1,
			WGPUCore.WGPUTextureDimension_2D,
			WGPUCore.WGPUTextureFormat_RGBA8UnormSrgb,
			WGPUCore.getEnum(
				WGPUCore.WGPUTextureUsage, 
				[
					"CopyDst",
					"TextureBinding"
				]
			)
		)
		textureView = WGPUCore.createView(texture)
		sampler = WGPUCore.createSampler(gpuDevice)
		setfield!(mesh, :texture, texture)
		setfield!(mesh, :textureView, textureView)
		setfield!(mesh, :sampler, sampler)
		dstLayout = [
			:dst => [
				:texture => texture |> Ref,
				:mipLevel => 0,
				:origin => ((0, 0, 0) .|> Float32)
			],
			:textureData => mesh.textureData |> Ref,
			:layout => [
				:offset => 0,
				:bytesPerRow => 256*4, # TODO should be multiple of 256
				:rowsPerImage => 256
			],
			:textureSize => textureSize
		]
		try
			WGPUCore.writeTexture(gpuDevice.queue; dstLayout...)
		catch(e)
			@error "Writing texture in MeshLoader failed !!!"
			rethrow(e)
		end

	end
	(uniformBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice,
		"Mesh Buffer",
		uniformData,
		["Uniform", "CopyDst", "CopySrc"]
	)
	setfield!(mesh, :uniformData, uniformData)
	setfield!(mesh, :uniformBuffer, uniformBuffer)
	setfield!(mesh, :gpuDevice, gpuDevice)
	setfield!(mesh, :indexBuffer, getIndexBuffer(gpuDevice, mesh))
	setfield!(mesh, :vertexBuffer, getVertexBuffer(gpuDevice, mesh))
	return mesh
end



function preparePipeline(gpuDevice, scene, mesh::WGPUMesh; isVision=false, binding=2)
	bindingLayouts = []
	bindings = []
	cameraUniform = getfield(scene.camera, :uniformBuffer)
	lightUniform = getfield(scene.light, :uniformBuffer)
	vertexBuffer = getfield(mesh, :vertexBuffer)
	uniformBuffer = getfield(mesh, :uniformBuffer)
	indexBuffer = getfield(mesh, :indexBuffer)
	append!(
		bindingLayouts, 
		getBindingLayouts(scene.camera; binding = 0), 
		getBindingLayouts(scene.light; binding = isVision ? 2 : 1), 
		getBindingLayouts(mesh; binding=binding)
	)
	append!(
		bindings, 
		getBindings(scene.camera, cameraUniform; binding = 0), 
		getBindings(scene.light, lightUniform; binding = isVision ? 2 : 1), 
		getBindings(mesh, uniformBuffer; binding=binding)
	)
	(bindGroupLayouts, bindGroup) = WGPUCore.makeBindGroupAndLayout(gpuDevice, bindingLayouts, bindings)
	mesh.bindGroup = bindGroup
	pipelineLayout = WGPUCore.createPipelineLayout(gpuDevice, "PipeLineLayout", bindGroupLayouts)
	renderPipelineOptions = getRenderPipelineOptions(
		scene,
		mesh,
	)
	renderPipeline = WGPUCore.createRenderPipeline(
		gpuDevice, 
		pipelineLayout, 
		renderPipelineOptions; 
		label=" MESH RENDER PIPELINE "
	)
	mesh.renderPipeline = renderPipeline
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


function defaultWGPUMesh(path::String; image::String="", topology=WGPUPrimitiveTopology_TriangleList)
	meshdata = readObj(path) # TODO hardcoding Obj format
	vIndices = reduce(hcat, map((x)->broadcast(first, x), meshdata.indices)) .|> UInt32
	nIndices = reduce(hcat, map((x)->getindex.(x, 3), meshdata.indices))
	uIndices = reduce(hcat, map((x)->getindex.(x, 2), meshdata.indices))
	vertexData = reduce(hcat, meshdata.positions[vIndices[:]]) .|> Float32

	uvData = nothing
	textureData = nothing
	texture = nothing
	textureView = nothing
	
	if image != ""
		uvData = reduce(hcat, meshdata.uvs[uIndices[:]]) .|> Float32
		textureData = begin
			img = load(image)
			img = imresize(img, (256, 256)) # TODO hardcoded size
			img = RGBA.(img) |> adjoint
			imgview = channelview(img) |> collect 
		end
	end
	
	indexData = 0:length(vIndices)-1 |> collect .|> UInt32
	unitColor = cat([
		[0.5, 0.6, 0.7, 1]
	]..., dims=2) .|> Float32
	
	colorData = repeat(unitColor, inner=(1, length(vIndices)))
	
	normalData = reduce(hcat, meshdata.normals[nIndices[:]]) .|> Float32
	
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
	WGPUCore.writeBuffer(
		mesh.gpuDevice[].queue, 
		getfield(mesh, :uniformBuffer),
		data,
	)
end


function readUniformBuffer(mesh::WGPUMesh)
	data = WGPUCore.readBuffer(
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


function getShaderCode(mesh::WGPUMesh; isVision=false, islight=false, binding=0)
	name = Symbol(:mesh, binding)
	isTexture = mesh.textureData != nothing
	shaderSource = quote
		struct WGPUMeshUniform
			transform::Mat4{Float32}
		end
		
		@var Uniform 0 $binding $name::@user WGPUMeshUniform
		
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
function getVertexBuffer(gpuDevice, mesh::WGPUMesh)
	(vertexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"vertexBuffer", 
		vcat(
			[
				mesh.vertexData, 
				mesh.colorData, 
				mesh.normalData, 
				mesh.uvData
			][mesh.textureData != nothing ? (1:end) : (1:end-1)]...
		), 
		["Vertex", "CopySrc"]
	)
	vertexBuffer
end


function getIndexBuffer(gpuDevice, mesh::WGPUMesh)
	(indexBuffer, _) = WGPUCore.createBufferWithData(
		gpuDevice, 
		"indexBuffer", 
		mesh.indexData |> flatten, 
		"Index"
	)
	indexBuffer
end


function getVertexBufferLayout(mesh::WGPUMesh; offset=0)
	WGPUCore.GPUVertexBufferLayout => [
		:arrayStride => mesh.textureData != nothing ? 14*4 : 12*4,
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
		][mesh.textureData != nothing ? (1:end) : (1:end-1)]
	]
end


function getBindingLayouts(mesh::WGPUMesh; binding=4)
	bindingLayouts = [
		WGPUCore.WGPUBufferEntry => [
			:binding => binding,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
		WGPUCore.WGPUTextureEntry => [ # TODO hardcoded
			:binding => binding + 1,
			:visibility=> "Fragment",
			:sampleType => "Float",
			:viewDimension => "2D",
			:multisampled => false
		],
		WGPUCore.WGPUSamplerEntry => [ # TODO hardcoded
			:binding => binding + 2,
			:visibility => "Fragment",
			:type => "Filtering"
		]
	][mesh.textureData != nothing ? (1:end) : (1:1)]
	return bindingLayouts
end


function getBindings(mesh::WGPUMesh, uniformBuffer; binding=4)
	bindings = [
		WGPUCore.GPUBuffer => [
			:binding => binding,
			:buffer => uniformBuffer,
			:offset => 0,
			:size => uniformBuffer.size
		],
		WGPUCore.GPUTextureView => [
			:binding => binding + 1, 
			:textureView => mesh.textureView
		],
		WGPUCore.GPUSampler => [
			:binding => binding + 2,
			:sampler => mesh.sampler
		]
	][mesh.textureData != nothing ? (1:end) : (1:1)]
end

function getRenderPipelineOptions(scene, mesh::WGPUMesh)
	renderpipelineOptions = [
		WGPUCore.GPUVertexState => [
			:_module => scene.cshader.internal[],						# SET THIS (AUTOMATICALLY)
			:entryPoint => "vs_main",							# SET THIS (FIXED FOR NOW)
			:buffers => [
					getVertexBufferLayout(mesh)
				]
		],
		WGPUCore.GPUPrimitiveState => [
			:topology => "TriangleList",
			:frontFace => "CCW",
			:cullMode => "Front",
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

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, mesh::WGPUMesh)
	WGPUCore.setPipeline(renderPass, mesh.renderPipeline)
	WGPUCore.setIndexBuffer(renderPass, mesh.indexBuffer, "Uint32")
	WGPUCore.setVertexBuffer(renderPass, 0, mesh.vertexBuffer)
	WGPUCore.setBindGroup(renderPass, 0, mesh.bindGroup, UInt32[], 0, 99)
	WGPUCore.drawIndexed(renderPass, Int32(mesh.indexBuffer.size/sizeof(UInt32)); instanceCount = 1, firstIndex=0, baseVertex= 0, firstInstance=0)
end
