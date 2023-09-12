struct System <: Renderable end

struct CameraSystem <: System
	primary
	secondary
end

struct LightSystem <: System
	primary
	secondary
end


# 
