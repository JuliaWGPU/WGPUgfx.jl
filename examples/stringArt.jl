using WGPUgfx
using GLFW
using GLFW: WindowShouldClose, PollEvents
using WGPUCore
using WGPUNative

WGPUCore.SetLogLevel(WGPULogLevel_Debug)

scene = Scene()
renderer = getRenderer(scene)
canvas = scene.canvas
gpuDevice = scene.gpuDevice

circle = defaultUICircle(;nSectors=80, radius=0.9, color=[0.7, 0.8, 0.9, 1.0])

addObject!(renderer, circle, scene.camera);

for column in filter(x->(x%3)!=1, 1:size(circle.vertexData, 2))
	objs = addObject!(
		renderer, 
		defaultUICircle(;nSectors=20, radius=0.015, color=[0.2, 0.2, 0.2, 0.5]),
		scene.camera
	);
	miniCircle = objs[end]
	miniCircle.uniformData = translate((
		circle.vertexData[:, column][1:2]...,
		0.0f0,
		1.0f0
	)).linear
end

function runApp(renderer)
	init(renderer)
	render(renderer)
	getImage()
	deinit(renderer)
end

function addLine(vData)
	idxs = zeros(Int, 2)
	totalIdxs = filter(x->(x%3)!=1, 1:size(vData, 2))
	while idxs[1] == 0 && idxs[2] == 0 && (idxs[1] == idxs[2])
		idxs = rand(totalIdxs, 2)
	end
	line = defaultLine2D(; 
		startPoint=vData[:, idxs[1]][1:3],
		endPoint=vData[:, idxs[2]][1:3],
		color=[0.3, 0.3, 0.3, 1.0]
	)
	addObject!(renderer, line, scene.camera);
end

function mainApp()
	try
		count = 1
		while !WindowShouldClose(canvas.windowRef[])
			runApp(renderer)
			addLine(circle.vertexData)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(canvas)
	end
end

function getImage()
	ctxtSize = WGPUCore.determineSize(renderer.presentContext) .|> Int
	bufferDims = WGPUCore.BufferDimensions(ctxtSize...)
	bufferSize = bufferDims.padded_bytes_per_row * bufferDims.height
	outputBuffer = WGPUCore.createBuffer(
		"OUTPUT BUFFER",
		gpuDevice,
		bufferSize,
		["CopyDst", "CopySrc"],
		false
	)
	WGPUCore.copyTextureToBuffer(
		renderer.cmdEncoder,
		[
			:texture => renderer.currentTextureView,
			:mipLevel => 0,
			:origin => [
				:x => 0,
				:y => 0,
				:z => 0,
			] |> Dict
		] |> Dict,
		[
			:buffer => outputBuffer,
			:layout => [
				:offset => 0,
				:bytesPerRow => bufferDims.padded_bytes_per_row,
				:rowsPerImage => WGPU_COPY_STRIDE_UNDEFINED,
			] |> Dict,
		] |> Dict,
		[
			:width => bufferDims.width,
			:height => bufferDims.height,
			:depthOrArrayLayers => 1,
		] |> Dict
	)
	data = WGPUCore.readBuffer(gpuDevice, outputBuffer, 0, bufferSize |> Int)
	return data
end

if abspath(PROGRAM_FILE) == @__FILE__
	mainApp()
else
	mainApp()
end


using Images
using ImageView

img = load(joinpath(ENV["HOMEPATH"], "Downloads", "OIP.jpg"))
grayImg = Gray.(img)

imshow(grayImg)
cviewImg = channelview(grayImg) |> float
sz = size(cviewImg)

midPoint = sz./2 .|> ceil .|> Int

radius = (sz .- midPoint).^2 |> sum |> sqrt |> ceil |> Int
filteredIdxs = filter(x->(x%3)==0, 1:size(circle.vertexData, 2))
vertices = radius*circle.vertexData[:, filteredIdxs][1:2, :] .+ radius

sparsity = 4

rs = zeros(Int, size(vertices, 2), sparsity)

function overlapScore()

end

for idx in 1:size(vertices, 2)
	vertex = vertices[:, idx]
	maxValue = 0
	topIdx = 1
	for yIdx in 1:size(vertices, 2)
		yVertex = vertices[:, yIdx]
		
end

