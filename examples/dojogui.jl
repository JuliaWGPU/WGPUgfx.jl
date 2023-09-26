using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUgfx
using WGPUCore
using FileIO
using LightXML
using Dojo
using Dojo: input_impulse!, clear_external_force!, update_state!
using DojoEnvironments
using DataStructures
using ControlSystemsBase

function get_joint_dims(mechanism::Mechanism)
	jointNames = mechanism.joints .|> (x) -> getproperty(x, :name)
	dims = jointNames .|> (x) -> input_dimension(get_joint(mechanism, x))
	jointDims = OrderedDict{Symbol, Int}(zip(jointNames, dims))
	return jointDims
end

function get_input_dims(mechanism::Mechanism, x::Symbol)
	return get_joint_dims(mechanism)[x]
end

function get_input_dims(mechanism::Mechanism)
	return get_joint_dims(mechanism) |> values
end

function get_input_idx(mechanism::Mechanism, x::Symbol)
	jointDims = get_joint_dims(mechanism)
	idx = 0
	for (k, v) in jointDims
		idx += v
		if k == x
			return idx
		end
	end
	@error "Could not find the symbol"
end

function get_state_idxs(mechanism)
	for joint in mechanism.joints
	end	
end


WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)
canvas = WGPUCore.defaultCanvas(WGPUCore.WGPUCanvas)
gpuDevice = WGPUCore.getDefaultDevice()

camera = defaultCamera()
light = defaultLighting()
grid = defaultGrid()
axis = defaultAxis()

scene = Scene(
	gpuDevice,
	canvas,
	camera,
	light,
	[],
	repeat([nothing], 4)...
)

addObject!(scene, grid)
addObject!(scene, axis)

mechanism = get_mechanism(:cartpole3D)

bodies = mechanism.bodies
origin = mechanism.origin

# ### Controller
stateIdxs = [[4:6..., 10:16...]]
x0 = zeros(16)
u0 = zeros(8)

A, B = get_minimal_gradients!(mechanism, x0, u0)
# Q = [1.0, 1.0, 1.0, 0.2, 0.2, 0.8, 0.002, 0.002, 0.002, 0.002] |> diagm
Q = [0.00001, 0.00001, 0.00001, 0.099, 0.099, 0.099, 0.0001, 0.0001, 0.00004, 0.00004] |> diagm

x_goal = get_minimal_state(mechanism)[stateIdxs...]

actuators = [:left_wheel, :right_wheel]

R = I(length(actuators))
idxs = [get_input_idx(mechanism, actuator) for actuator in actuators]

function controller!(mechanism, k)
	x = get_minimal_state(mechanism)[stateIdxs...]
	K = lqr(Discrete,A[stateIdxs..., stateIdxs...],B[stateIdxs..., [idxs...]],Q,R)
    u = K * (x - x_goal)
    @show u
    leftWheel = get_joint(mechanism, :left_wheel)
    rightWheel = get_joint(mechanism, :right_wheel)
    set_input!(leftWheel, [u[1]])
    set_input!(rightWheel, [u[2]])
end

initialize!(mechanism, :rhea; body_position=[0.0, 0.0, 0.0])

attachEventSystem(scene)

for (id, body) in enumerate(bodies)
	shape = body.shape
	if typeof(shape) <: Dojo.Mesh
		mesh = WGPUgfx.defaultWGPUMesh(shape.path)
		wo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		addObject!(scene, wo)
	end
end


swapMat = [1 0 0 0; 0 0 1 0; 0 -1 0 0; 0 0 0 1] .|> Float32
# swapMat = [1 0 0 0; 0 1 0 0; 0 0 1 0; 0 0 0 1] .|> Float32


function initTransform!(scene, mechanism)
	bodies = mechanism.bodies
	origin = mechanism.origin
	gid = 0
	for (id, mesh) in enumerate(scene.objects)
		if typeof(mesh) <: WorldObject
			gid += 1
			body = bodies[gid]
			shape = body.shape
		else
			continue
		end
		if typeof(shape) <: Dojo.Shape
			state = body.state
			trans = WGPUgfx.translate(state.x1 + Dojo.vector_rotate(shape.position_offset, state.q1))
			scale = WGPUgfx.scaleTransform(shape.scale)
			rot = WGPUgfx.rotateTransform(state.q1*shape.orientation_offset)
			mesh.uniformData = swapMat*(trans∘rot∘scale)(mesh.uniformData)
		end
	end
end


function stepTransform!(scene, mechanism)
	bodies = mechanism.bodies
	origin = mechanism.origin
	gid = 0
	for (id, mesh) in enumerate(scene.objects)
		if typeof(mesh) <: WorldObject
			gid += 1
			body = bodies[gid]
			shape = body.shape
		else
			continue
		end
		if typeof(shape) <: Dojo.Shape
			state = body.state
			trans = WGPUgfx.translate(shape.position_offset)
			scale = WGPUgfx.scaleTransform(shape.scale)
			rot = WGPUgfx.rotateTransform(shape.orientation_offset)
			mesh.uniformData = swapMat*(trans∘rot∘scale)(mesh.uniformData)
		end
	end
end

function stepController!(mechanism)
	try
		controller!(mechanism, 0)
		for joint in mechanism.joints
			input_impulse!(joint, mechanism)
		end
		status = mehrotra!(mechanism, opts=SolverOptions(verbose=false))
		for body in mechanism.bodies
			clear_external_force!(body) 
		end
		if status == :failed
			return false
		else
			for body in mechanism.bodies
				update_state!(body, mechanism.timestep)
			end
		end
	catch e
		@info e
	end
end

main = () -> begin
	initTransform!(scene, mechanism)
	initialize!(mechanism, :rhea; body_position=[0.0, 0.0, 0.00])
	try
		while !WindowShouldClose(canvas.windowRef[])
			stepController!(mechanism)
			# stepTransform!(scene, mechanism)
			runApp(scene)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(canvas)
	end
end

main()
