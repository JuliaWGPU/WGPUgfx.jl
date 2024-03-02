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
sz::Tuple{Int, Int} = size(cviewImg)
midPoint = sz./2 .|> ceil .|> Int

radius = minimum(sz)/2
filteredIdxs = filter(x->(x%3)==0, 1:size(circle.vertexData, 2))
vertices = radius*(circle.vertexData[:, filteredIdxs][1:2, :]) .+ [midPoint...]

gui = imshow_gui(sz, (1, 1))
canvas = gui["canvas"]

function pixDist(x)
	sqrt(first(x)^2 + last(x)^2)
end

mask = map(x -> pixDist(x.I .- midPoint) < radius, CartesianIndices((1 : sz[1], 1 : sz[2])))

function imgDiffError(img1, img2)
	(mask.*img1 .- mask.*img2).^2 |> sum
end

function addLine!(img, v1, v2, tf)
	sz = size(img)
	m = (v2[2] - v1[2])/(v2[1] - v1[1])
	if v1[1] > v2[1]
	 	(v1, v2) = (v2, v1)
	end
	y = v1[2] |> round
	e = 0.0
	st = ceil(v1[1]) |> Int
	ed = ceil(v2[1]) |> Int
	for x in st:ed
		y += (m + e)
		e = y - round(y)
		y = round(y)	
		if (1 <= x <= sz[1]) && (1 <= y <= sz[2])
			@inbounds img[Int(x), Int(y)] += ((img[Int(x), Int(y)] <= 0.0f0) ? 0.0f0 : tf*-0.05f0)
		end
	end
end

function addPoint!(img, v1)
	(x, y) = ceil.(v1)
	for lx in -2:2
		for ly in -2:2
			if (1 <= lx + x <= sz[1]) && (1 <= ly + y <= sz[2])
				@inbounds img[Int(x + lx), Int(y + ly)] = 0.0f0
			end
		end
	end
end

sparsity = 40

rs = zeros(Int64, size(vertices, 2), sparsity)
topIdxs = zeros(Int64, size(vertices, 2))

sgn = [-1.0f0, 1.0f0]
temp = ones(Float32, sz...)
minValue = Inf
for i in 1:10
	for idx in 1:size(vertices, 2)
		topIdx = 0
		sIdx = 0
		vertex = vertices[:, idx]
		for oIdx in 1:size(vertices, 2)
			tf = (oIdx in rs[idx, :]) ? rand(sgn) : 1.0f0
			oVertex = vertices[:, oIdx]
		 	addLine!(temp, vertex, oVertex, tf)
			value = imgDiffError(grayImg, outputImg .+ temp)
			if value < minValue
				minValue = value
				if tf > 0
					topIdx = oIdx
					rs[idx, (sIdx % sparsity) + 1] = topIdx
					sIdx += 1
				else
					rs[idx, (sIdx % sparsity) + 1] = 0
				end
			end
			addLine!(temp, vertex, oVertex, -tf)
		end
		for tpIdx in rs[idx, :]
			if tpIdx != 0
				oVertex = vertices[:, tpIdx]
				addLine!(outputImg, vertex, oVertex, 1.0f0)
			end
		end
	end
end

function drawResult()
	outputImg = ones(sz...)
	for idx in 1:size(rs, 1)
		vertex = vertices[:, idx]
		for tpIdx in rs[idx, :]
			if tpIdx != 0
				oVertex = vertices[:, tpIdx]
				addLine!(outputImg, vertex, oVertex, 0.01f0)
			end
		end
	end
	return outputImg
end

# outputImgBlurs = gaussian_pyramid(outputImg, 4, 1.0, 2.0)
# finalOutput = sum(outputImgBlurs)/5
# imshow!(canvas, finalOutput)

# outputImg = (outputImg .- minimum(outputImg))/(maximum(outputImg) .- minimum(outputImg))

imshow!(canvas, outputImg)
