using WGPUgfx
using GLFW
using GLFW: WindowShouldClose, PollEvents
using WGPUCore
using WGPUNative
using Images
using ImageView

circle = defaultUICircle(;nSectors=10, radius=1.0, color=[0.7, 0.8, 0.9, 1.0])

img = load(joinpath(ENV["HOMEPATH"], "Downloads", "OIP.jpg"))
grayImg = Gray.(img)
grayImg = imresize(grayImg, (512, 512))

outputImg = ones(grayImg |> size)
cviewImg = channelview(grayImg) |> float
sz = size(cviewImg)

midPoint = sz./2 .|> ceil .|> Int

radius = minimum(sz)/2
filteredIdxs = filter(x->(x%3)==0, 1:size(circle.vertexData, 2))
vertices = radius*(circle.vertexData[:, filteredIdxs][1:2, :]) .+ [midPoint...]

gui = imshow_gui(sz, (1, 1))

canvas = gui["canvas"]

function imgDiffError(img1, img2)
	(img1 .- img2).^2 |> sum
end

topIdx = 0
oIdxs = Int[]

function addLine!(img, v1, v2)
	m = (v2[2] - v1[2])/(v2[1] - v1[1])
	points = [v1, v2]
	pointIdxs = [1, 2]
	if points[1][1] > points[2][1]
	 	pointIdxs = [2, 1]
	end
	(firstPoint, secondPoint) = points[pointIdxs]
	@info "firstPoint" firstPoint
	@info "secondPoint", secondPoint
	y = (firstPoint[2] + 0.5)|> round
	e = 0
	for x in floor.(firstPoint[1]:secondPoint[1])
		y += (m + e)
		e = y - round(y)
		y = round(y)
		try
			img[Int(x), Int(y)] = 0.0f0
			#addPoint!(img, [Int(x), Int(y)])
			# @info x, y
		catch e
			print(e)
		end
	end
end


function addPoint!(img, v1)
	(x, y) = ceil.(v1)
	for lx in -2:2
		for ly in -2:2
			if (1 <= lx + x <= sz[1]) && (1 <= ly + y <= sz[2])
				img[Int(x + lx), Int(y + ly)] = 0.0f0
			end
		end
	end
end


addPoint!(outputImg, vertices[:, 1])
addPoint!(outputImg, vertices[:, 2])
addLine!(outputImg, vertices[:, 1], vertices[:, 2])

imshow!(canvas, outputImg)
