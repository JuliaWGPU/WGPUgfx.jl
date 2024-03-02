using FreeType
using WGPUCore: CStruct, cStruct, ptr, concrete
using WGPUgfx

rootType(::Type{Ref{T}}) where T = T

Base.fieldnames(::Type{FT_Face}) = Base.fieldnames(FT_FaceRec)
Base.fieldnames(::Type{FT_GlyphSlot}) = Base.fieldnames(FT_GlyphSlotRec)

Base.getproperty(fo::FT_Face, sym::Symbol) = 
	Base.getproperty(fo |> unsafe_load, sym)

Base.getproperty(fo::FT_GlyphSlot, sym::Symbol) =
	Base.getproperty(fo |> unsafe_load, sym)

charCode = 'h'

ftLib = Ref{FT_Library}(C_NULL)
	
FT_Init_FreeType(ftLib)

@assert ftLib[] != C_NULL

function loadFace(filename::String, ftlib=ftLib[])
    face = Ref{FT_Face}()
    err = FT_New_Face(ftlib, filename, 0, face)
    @assert err == 0 "Could not load face at $filename with index 0 : Errored $err"
    return face[]
end

face = loadFace(joinpath(pkgdir(WGPUgfx),   "assets", "JuliaMono", "JuliaMono-Light.ttf"))

FT_Set_Pixel_Sizes(face, 1.0, 1.0)

loadFlags = FT_LOAD_NO_BITMAP | FT_KERNING_DEFAULT
glyphIdx = FT_Get_Char_Index(face, charCode)
FT_Load_Glyph(face, glyphIdx, loadFlags)
glyph = face.glyph |> unsafe_load
nContours = glyph.outline.n_contours
contours = unsafe_wrap(Array, glyph.outline.contours, nContours)
curvePoints = unsafe_wrap(Array, glyph.outline.points, glyph.outline.n_points)


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
    v = convert(FontPoint, unsafe_load(vector))
    ctrl1 = convert(FontPoint, unsafe_load(control1))
    ctrl2 = convert(FontPoint, unsafe_load(control2))
    println("CubicTo : [$(v.x) , $(v.y)]")
    println("Ctrl1 : [$(ctrl1.x) , $(ctrl1.y)]")
    println("Ctrl2 : [$(ctrl2.x) , $(ctrl2.y)]")
    return 0
end

moveToFunc = @cfunction(moveTo, Int, (Ptr{FT_Vector}, Ptr{Cvoid}))
lineToFunc = @cfunction(lineTo, Int, (Ptr{FT_Vector}, Ptr{Cvoid}))
conicToFunc = @cfunction(conicTo, Int, (Ptr{FT_Vector}, Ptr{FT_Vector}, Ptr{Cvoid}))
cubicToFunc = @cfunction(cubicTo, Int, (Ptr{FT_Vector}, Ptr{FT_Vector}, Ptr{FT_Vector}, Ptr{Cvoid}))

funcsRef = FT_Outline_Funcs(
    moveToFunc,
    lineToFunc,
    conicToFunc,
    cubicToFunc,
    0 |> Int32,
    0 |> Int32
)

FT_Outline_Decompose(
    glyph.outline |> Ref, 
    funcsRef |> Ref, 
    C_NULL, 
)

