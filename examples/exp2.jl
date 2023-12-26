using WGPUgfx
using GLFW
using GLFW: WindowShouldClose, PollEvents
using WGPUCore
using WGPUNative
using Images
using ImageView

circle = defaultUICircle(;nSectors=300, radius=1.0, color=[0.7, 0.8, 0.9, 1.0])

img = load(joinpath(ENV["HOMEPATH"], "Downloads", "spanda.png"))
grayImg = Gray.(img)
grayImg = imresize(grayImg, (500, 500))

outputImg = ones(Float32, grayImg |> size)
cviewImg = channelview(grayImg) |> float
sz = size(cviewImg)


midPoint = sz./2 .|> ceil .|> Int

radius = minimum(sz)/2
filteredIdxs = filter(x->(x%3)==0, 1:size(circle.vertexData, 2))
vertices = radius*(circle.vertexData[:, filteredIdxs][1:2, :]) .+ [midPoint...]

function pixDist(x)
	sqrt(first(x)^2 + last(x)^2)
end

mask = map(x -> pixDist(x.I .- midPoint) < radius, CartesianIndices((1 : sz[1], 1 : sz[2])))
	
gui = imshow_gui(sz, (1, 1))

canvas = gui["canvas"]


function imgDiffError(img1, img2)
	(mask.*img1 .- mask.*img2).^2 |> sum
end


function addLine!(img, v1, v2, tf)
	m = (v2[2] - v1[2])/(v2[1] - v1[1])
	points = [v1, v2]
	pointIdxs = [1, 2]
	if points[1][1] > points[2][1]
	 	pointIdxs = [2, 1]
	end
	(firstPoint, secondPoint) = points[pointIdxs]
	y = firstPoint[2] |> round
	y = firstPoint[2] |> round
	e = 0
	for x in ceil.(firstPoint[1]:secondPoint[1])
		y += (m + e)
		e = y - round(y)
		y = round(y)	
		if (1 <= x <= sz[1]) && (1 <= y <= sz[2])
			img[Int(x), Int(y)] += ((img[Int(x), Int(y)] <= 0.0f0) ? 0.0f0 : (tf)*0.1f0)
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

minValue = Inf
temp = ones(Float32, sz...)

while true
	idx = rand(1:size(vertices, 2))
	oIdx = rand(1:size(vertices, 2))
	tf = rand([-1.0f0, +1.0f0])
	vertex = vertices[:, idx]
	oVertex = vertices[:, oIdx]
 	addLine!(temp, vertex, oVertex, tf)
	value = imgDiffError(grayImg, outputImg .+ temp)
	if value < minValue
		minValue = value
		addLine!(outputImg, vertex, oVertex, tf)
	end
	addLine!(temp, vertex, oVertex, -tf)
end

# outputImgBlurs = gaussian_pyramid(outputImg, 4, 1.0, 2.0)
# finalOutput = sum(outputImgBlurs)/5
# imshow!(canvas, finalOutput)

outputImg = (outputImg .- minimum(outputImg))/(maximum(outputImg) .- minimum(outputImg))

imshow!(canvas, outputImg)
