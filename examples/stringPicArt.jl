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

circle = defaultUICircle(;nSectors=64, radius=1.0, color=[0.7, 0.8, 0.9, 1.0])

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

mainApp()

using Images
using ImageView

img = load(joinpath(ENV["HOMEPATH"], "Downloads", "OIP.jpg"))
grayImg = Gray.(img)

outputImg = ones(grayImg |> size)

dd = imshow(grayImg)
cviewImg = channelview(grayImg) |> float
sz = size(cviewImg)

midPoint = sz./2 .|> ceil .|> Int

radius = (sz .- midPoint).^2 |> sum |> sqrt |> ceil |> Int
filteredIdxs = filter(x->(x%3)==0, 1:size(circle.vertexData, 2))
vertices = radius*(circle.vertexData[:, filteredIdxs][1:2, :]) .+ [midPoint...]

sparsity = 4

rs = zeros(Int, size(vertices, 2), sparsity)

using CEnum

@cenum(
	BORDERHIT,
	LEFTHIT = 1,
	RIGHTHIT = 2,
	TOPHIT = 3,
	BOTTOMHIT = 4,
)

gui = imshow_gui(sz, (1, 1))

canvas = gui["canvas"]

for idx in 1:size(vertices, 2)
	vertex = vertices[:, idx]
	maxValue = 0
	topIdx = 1
	for oIdx in 1:size(vertices, 2)
		oVertex = vertices[:, oIdx]
		θ = atan((oVertex[2] - vertex[2]), (oVertex[1] - vertex[1]))
		s = Set{BORDERHIT}()
		hitPoints = Vector{Float32}[]
		leftY = vertex[2] + (oVertex[2] - vertex[2])/(oVertex[1] - vertex[1])*(0 - vertex[1]) |> Float32
		rightY = vertex[2] + (oVertex[2] - vertex[2])/(oVertex[1] - vertex[1])*(sz[1] - vertex[1])  |> Float32
		bottomX = vertex[1] + (oVertex[1] - vertex[1])/(oVertex[2] - vertex[2])*(0 - vertex[2]) |> Float32
		topX = vertex[1] + (oVertex[1] - vertex[1])/(oVertex[2] - vertex[2])*(sz[2] - vertex[2]) |> Float32
		if 0 <= leftY <= sz[2]
			push!(s, LEFTHIT)
			push!(hitPoints, [0.0f0, leftY])
		end
		if 0 <= rightY <= sz[2]
			push!(s, RIGHTHIT)
			push!(hitPoints, [sz[1], rightY])
		end
		if 0 <= bottomX <= sz[1]
			push!(s, BOTTOMHIT)
			push!(hitPoints, [bottomX, 0.0f0])
		end
		if 0 <= topX <= sz[1]
			push!(s, TOPHIT)
			push!(hitPoints, [topX, sz[2]])
		end
		if length(hitPoints) > 0
			pointIdxs = (1, 2)
			if hitPoints[2][1] < hitPoints[1][1]
				pointIdxs = (2, 1)
			end
			firstPoint = hitPoints[pointIdxs[1]]
			secondPoint = hitPoints[pointIdxs[2]]
			for x in ceil(firstPoint[1]) : floor(secondPoint[1])
				y = ceil(firstPoint[2] + tan(θ)*x)
				if x <= 0 || x > 768 || y <= 0 || y > 768
					continue
				end
				outputImg[Int(x), Int(y)] = 0.0
				imshow!(canvas, outputImg)
			end
		end
		sleep(0.1)
	end
end

outputImgBlurs = gaussian_pyramid(outputImg, 4, 1.0, 2.0)

finalOutput = sum(outputImgBlurs)/5

imshow(finalOutput)

function imgDiffError(img1, img2)
	(img1 .- img2).^2 |> sum
end


if abspath(PROGRAM_FILE) == @__FILE__
	mainApp()
else
	mainApp()
end

