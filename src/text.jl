export defaultTextBox, TextBox

using WGPUCore
using FreeTypeAbstraction
using Images
using AbstractTrees

# load a font

# render a character
function getCharTexture(chr::Char)
	ftface = FTFont(joinpath(@__DIR__, "..", "assets", "JuliaMono", "JuliaMono-Light.ttf"))
	img, metric = renderface(ftface, chr, 150)
	img = imrotate(RGB{N0f8}.(img./255f0) .|> RGBA, pi, axes(img))
	return (img |> channelview |> collect, metric)
end

@cenum(
	Justification,
	RIGHT = 1,
	LEFT = 2,
	CENTER = 4
)

@cenum(
	TextRenderMode,
	DEBUG,
	REALTIME
)

mutable struct TextBox <: RenderableUI
	text::String
	x::Int
	y::Int
	width::Int
	height::Int
	textColor::Vector{Float32} # TODO static versions
	backgroundColor::Vector{Float32} # TODO static versions
	box::Quad
	textQuads::Vector{Quad}
	justification::Justification
	mode::TextRenderMode
end

isTextureDefined(tb::TextBox) = isTextureDefined(tb.box)
isNormalDefined(tb::TextBox) = isNormalDefined(tb.box)


Base.setproperty!(tb::TextBox, f::Symbol, v) = begin
	(f in fieldnames(tb |> typeof)) ?
		setfield!(tb, f, v) :
		setfield!(tb.box, f, v)
end

Base.getproperty(tb::TextBox, f::Symbol) = begin
	(f in fieldnames(tb |> typeof)) ?
		getfield(tb, f) :
		getfield(tb.box, f)
end

AbstractTrees.children(tb::TextBox) = tb.textQuads

function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, tb::TextBox)
	summary(io, tb)
	print(io, "\n")
	println(io, " text : $(tb.text)")
end

function compileShaders!(gpuDevice, scene::Scene, tb::TextBox; binding=3)
	compileShaders!(gpuDevice, scene, tb.box; binding=binding)
	for quad in tb.textQuads
		compileShaders!(gpuDevice, scene, quad; binding=binding )
		# quad.cshaders[scene.cameraId] = tb.box.cshaders[scene.cameraId]
	end
end

function defaultTextBox(text::String; x=0, y=0, width=100, height=100, backgroundColor=[0.2, 0.4, 0.8, 1.0], color=[1.0, 1.0, 1.0, 1.0], backGroundImage="")
	mode = DEBUG # TODO debug only right now
	# Debug is simple.
	# We might need different allocators for text rendering
	# For web and for native applications ...
	box = defaultQuad()
	quads = Quad[]
	for chr in text
		(texData, metric) = getCharTexture(chr)
		if size(texData) == (4, 0, 0)
			texData = nothing
		end
		# offset = size(texData, 2)
		quad = defaultQuad(;scale=[0.05f0, 0.05f0, 0.05f0, 1.0f0], color=[0.4, 0.4, 0.2, 0.6].|>Float32, imgData=texData);
		# quad.uniformData = translate([x + offset, y, 1.0]).linear
		push!(quads, quad)
	end
	
	TextBox(
		text, 
		x, y, 
		width, 
		height, 
		color .|> Float32, 
		backgroundColor .|> Float32, 
		box,
		quads, 
		LEFT, 
		mode,
	)
end

function prepareObject(gpuDevice, tb::TextBox; binding=0)
	prepareObject(gpuDevice, tb.box)
	for quad in tb.textQuads
		prepareObject(gpuDevice, quad)
	end
end

function preparePipeline(gpuDevice, renderer, tb::TextBox, camera; binding=0)
	preparePipeline(gpuDevice, renderer, tb.box, camera; binding=binding)
	for quad in tb.textQuads
		preparePipeline(gpuDevice, renderer, quad, camera; binding=binding)
	end
end

function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, tb::TextBox, camId::Int)
	offset = 0.0
	tb.box.uniformData = translate([tb.x, tb.y, 1.0]).linear
	render(renderPass, renderPassOptions, tb.box,camId)
	for (idx, chr) in enumerate(tb.text)
		quad = tb.textQuads[idx]
		offset += ((quad.textureData !== nothing) ? size(quad.textureData, 1)/40 : 0.1)
		quad.uniformData = translate([tb.x - 0.5 + offset, tb.y + 0.5, 1.0]).linear 
		render(renderPass, renderPassOptions, quad, camId)
	end
end

