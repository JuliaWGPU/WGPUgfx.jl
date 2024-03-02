export defaultGlyph, Glyph
using FreeType

using GeometryBasics: Vec2

rootType(::Type{Ref{T}}) where T = T

Base.fieldnames(::Type{FT_Face}) = Base.fieldnames(FT_FaceRec)
Base.fieldnames(::Type{FT_GlyphSlot}) = Base.fieldnames(FT_GlyphSlotRec)

Base.getproperty(fo::FT_Face, sym::Symbol) = 
	Base.getproperty(fo |> unsafe_load, sym)

Base.getproperty(fo::FT_GlyphSlot, sym::Symbol) =
	Base.getproperty(fo |> unsafe_load, sym)

charCode = 'd'


struct FontPoint
    x::Float32
    y::Float32
end

for op in [:+, :-, :/, :*]
    quote 
        Base.$op(p1::FontPoint, p2::FontPoint) = FontPoint(Base.$op(p1.x, p2.x), Base.$op(p1.y, p2.y))
        Base.$op(p1::FontPoint, x::Number) = FontPoint(Base.$op(p1.x, x), Base.$op(p1.y, x))
        Base.$op(x::Number, p1::FontPoint) = FontPoint(Base.$op(p1.x, x), Base.$op(p1.y, x))
    end |> eval
end


# Base.show(io::IO, ::MIME"text/plain", p::Point) = println("Point [$(p.x), $(p.y)]")

Base.convert(::Type{FontPoint}, p::FT_Vector) = FontPoint(p.x, p.y)

global curves = FontPoint[]

function moveTo(vector::Ptr{FT_Vector}, userData::Ptr{Cvoid})
    global curves
    v = convert(FontPoint, unsafe_load(vector))
    push!(curves, v)
    println("Move To : $v")
    return 0
end

function lineTo(vector::Ptr{FT_Vector}, userData::Ptr{Cvoid})
    global curves
    idx = length(curves)
    v = convert(FontPoint, unsafe_load(vector))
    previousPoint = curves[idx]
    midPoint = (v + previousPoint)/2
    if length(curves) == 1
        push!(curves, [midPoint, v]...)
    else
        push!(curves, [previousPoint, midPoint, v]...)
    end
    println("Line To : $v")
    return 0
end

function conicTo(vector::Ptr{FT_Vector}, control::Ptr{FT_Vector}, userData::Ptr{Cvoid})
    v = convert(FontPoint, unsafe_load(vector))
    idx = div(length(curves), 3)
    previousPoint = curves[idx + 1]
    ctrl = convert(FontPoint, unsafe_load(control))
    push!(curves, [previousPoint, ctrl, v]...)
    println("Conic To : $v")
    println("Ctrl To : $ctrl")
    return 0
end

function cubicTo(vector::Ptr{FT_Vector}, control1::Ptr{FT_Vector}, control2::Ptr{FT_Vector}, ::Ptr{Cvoid})
    v = unsafe_load(vector)
    ctrl1 = unsafe_load(control1)
    ctrl2 = unsafe_load(control2)
    println("Cubic To : [$(v.x) , $(v.y)]")
    println("Ctrl1 : [$(ctrl1.x) , $(ctrl1.y)]")
    println("Ctrl2 : [$(ctrl2.x) , $(ctrl2.y)]")
    return 0
end

moveToFunc = @cfunction(moveTo, Int, (Ptr{FT_Vector}, Ptr{Cvoid}))
lineToFunc = @cfunction(lineTo, Int, (Ptr{FT_Vector}, Ptr{Cvoid}))
conicToFunc = @cfunction(conicTo, Int, (Ptr{FT_Vector}, Ptr{FT_Vector}, Ptr{Cvoid}))
cubicToFunc = @cfunction(cubicTo, Int, (Ptr{FT_Vector}, Ptr{FT_Vector}, Ptr{FT_Vector}, Ptr{Cvoid}))

outlineFuncs = FT_Outline_Funcs(
    moveToFunc,
    lineToFunc,
    conicToFunc,
    cubicToFunc,
    0 |> Int32,
    0 |> Int32
)

struct CurvePoints
	p1::Vec2{Float32}
	p2::Vec2{Float32}
	p3::Vec2{Float32}
end

struct GlyphData
	glyphRec::FT_GlyphSlotRec
	width::Float32
	height::Float32
	bearingX::Float32
	bearingY::Float32
	advance::Float32
	curvePoints::Vector{FontPoint}
	nContours::Int32
end

function getCurvePoints(outline, firstIdx, lastIdx)
	
end

moveToFunc = Ref{FT_Outline_MoveTo_Func}()
lineToFunc = Ref{FT_Outline_LineTo_Func}()
conicToFunc = Ref{FT_Outline_ConicTo_Func}()
cubicToFunc = Ref{FT_Outline_CubicTo_Func}()

global funcsRef = CStruct(FT_Outline_Funcs)

funcsRef.move_to = moveToFunc[]
funcsRef.line_to = lineToFunc[]
funcsRef.conic_to = conicToFunc[]
funcsRef.cubic_to = cubicToFunc[]
funcsRef.delta = (0 |> Int32)
funcsRef.shift = (0 |> Int32)

function createGlyph(charCode)
	global curves
    ftLib = Ref{FT_Library}(C_NULL)
	
    FT_Init_FreeType(ftLib)
	
    @assert ftLib[] != C_NULL
    
    function loadFace(filename::String, ftlib=ftLib[])
        face = Ref{FT_Face}()
        err = FT_New_Face(ftlib, filename, 0, face)
        @assert err == 0 "Could not load face at $filename with index 0 : Errored $err"
        return face[]
    end
    
    face = loadFace(joinpath(@__DIR__, "..", "..",  "assets", "JuliaMono", "JuliaMono-Light.ttf"))
	
    FT_Set_Pixel_Sizes(face, 1.0, 1.0)
	
    loadFlags = FT_LOAD_NO_BITMAP | FT_KERNING_DEFAULT
    glyphIdx = FT_Get_Char_Index(face, charCode)
    FT_Load_Glyph(face, glyphIdx, loadFlags)
	glyph = face.glyph |> unsafe_load
	nContours = glyph.outline.n_contours
	contours = unsafe_wrap(Array, glyph.outline.contours, nContours)
	# curvePoints = unsafe_wrap(Array, glyph.outline.points, glyph.outline.n_points)

	status = FT_Outline_Decompose(
		glyph.outline |> Ref, 
		outlineFuncs |> Ref, 
		C_NULL
	)

	@assert status == 0 "FreeType Decompose failed!!!"
	
	for contourIdx in 1:nContours
		# getCurvePoints(outline, start, contours[contourIdx])
	end

	glyph = GlyphData(
		glyph,
		glyph.metrics.width,
		glyph.metrics.height,
		glyph.metrics.horiBearingX,
		glyph.metrics.horiBearingY,
		glyph.metrics.horiAdvance,
		curves,
		nContours
	)
end


# function getShaderCode(glyphData::GlyphData)
# 	src = quote
# 		struct CurvePoints
# 			p1::Vec2{Float32}
# 		end

# 		@var StorageRead 0 0 curve::Array{CurvePoints}
# 	end
# end


mutable struct Glyph <: RenderableUI
	gpuDevice
    topology
    vertexData
    colorData
    indexData
    uvData
    uniformData
    uniformBuffer
    indexBuffer
    vertexBuffer
    textureData
    texture
    textureView
    sampler
    pipelineLayouts
    renderPipelines
    cshaders
end


function defaultGlyph(charCode::Char; color=[0.2, 0.9, 0.0, 1.0], scale::Union{Vector{Float32}, Float32} = 1.0f0)

	if typeof(scale) == Float32
		scale = [scale.*ones(Float32, 3)..., 1.0f0] |> diagm
	else
		scale = scale |> diagm
	end

	swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32;
	# swapMat = [1 0 0 0; 0 0 -1 0; 0 1 0 0; 0 0 0 1] .|> Float32;

	glyphData = createGlyph(charCode)

	vertices = cat([[v.x/64, v.y/64, 1.0f0, 1.0f0] for v in glyphData.curvePoints]..., dims=2)

	vertexData = scale*swapMat*vertices

	unitColor = cat([
		color,
	]..., dims=2) .|> Float32

	colorData = repeat(unitColor, inner=(1, size(vertices, 2)))

	indexData = cat([
		(1:length(vertices)) |> collect,
	]..., dims=2) .|> UInt32
	
	box = Glyph(
		nothing, 		# gpuDevice
		"PointList",
		vertexData, 
		colorData, 
		indexData, 
		nothing,
		nothing, 		# uniformData
		nothing, 		# uniformBuffer
		nothing, 		# indexBuffer
		nothing,	 	# vertexBuffer
		nothing,		# textureData
		nothing,	# texture
		nothing,	# textureView
		nothing,	# sampler
		Dict(),		# pipelineLayout
		Dict(),		# renderPipeline
		Dict(),		# cshader
	)
	box
end



