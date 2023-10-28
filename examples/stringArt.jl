using WGPUgfx
using GLFW
using GLFW: WindowShouldClose, PollEvents
using WGPUCore
using WGPUNative

WGPUCore.SetLogLevel(WGPULogLevel_Off)

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

if abspath(PROGRAM_FILE) == @__FILE__
	mainApp()
else
	mainApp()
end
