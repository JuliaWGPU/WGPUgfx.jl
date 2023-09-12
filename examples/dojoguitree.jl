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
using AbstractTrees

using Dojo: Shape, Node

mutable struct WorldNode{T<:Renderable} <: Renderable
	parent::Union{Nothing, T}
	object::Union{Nothing, T}
	childObjs::Union{Nothing, Vector{T}}
	body::Union{Nothing, Dojo.Node}
end

mutable struct DojoNode{T<:Dojo.Node} <: Dojo.Node{Float64}
	parent::Union{Nothing, T}
	object::Union{Nothing, T}
	childObjs::Union{Nothing, Vector{T}}
end

AbstractTrees.children(t::WorldNode) = t.childObjs
# AbstractTrees.nodevalue(t::TreeNode) = t.object.id

function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, node::WorldNode)
	summary(io, node)
	print(io, "\n")
	renderObj = (node.object != nothing) ? (node.object.renderObj |> typeof) : nothing
	rType = node.object.rType
	body = node.body
	println(io, " rObj : $(renderObj)")
	println(io, " rType : $(rType)")
	println(io, " body : $(summary(body)), $(body.id), $(body.name)")
end

AbstractTrees.printnode(io::IO, node::WorldNode) = Base.show(io, MIME{Symbol("text/plain")}(), node)

AbstractTrees.children(t::DojoNode) = t.childObjs
# AbstractTrees.nodevalue(t::TreeNode) = t.object.id

function Base.show(io::IO, mime::MIME{Symbol("text/plain")}, node::DojoNode)
	summary(io, node)
	parentId = node.parent == nothing ? "NA" : node.parent.object.id
	objectId = node.object == nothing ? "NA" : node.object.id
	name = node.object == nothing ? "NA" : "$(node.object.name)"
	println(io, " parent : $(parentId)")
	println(io, " object : $(name)")
	println(io, " id : $(objectId)")
end

AbstractTrees.printnode(io::IO, node::WorldNode) = Base.show(io, MIME{Symbol("text/plain")}(), node)
AbstractTrees.printnode(io::IO, node::DojoNode) = Base.show(io, MIME{Symbol("text/plain")}(), node)

function setObject!(tNode::WorldNode, obj::Renderable)
	setfield!(tNode, :object, obj)
end

function setObject!(tNode::DojoNode, obj::Dojo.Node)
	setfield!(tNode, :object, obj)
end

function addChild!(tNode::WorldNode, obj::Union{WorldNode, Renderable})
	if (tNode.childObjs == nothing)
		tNode.childObjs = []
	end
	if obj in tNode.childObjs
		return
	end
	if typeof(obj) <: WorldNode
		push!(tNode.childObjs, obj)
	elseif typeof(obj) <: Renderable
		push!(tNode.childObjs, WorldNode(tNode, obj, Renderable[]))
	end
end

function addChild!(tNode::DojoNode, obj::Union{DojoNode, Dojo.Node})
	if (tNode.childObjs == nothing)
		tNode.childObjs = []
	end
	if obj.id in [node.object.id for node in tNode.childObjs]
		return
	end
	if typeof(obj) == DojoNode
		push!(tNode.childObjs, obj)
	elseif typeof(obj) <: Dojo.Node
		push!(tNode.childObjs, DojoNode(tNode, obj, Dojo.Node[]))
	end
end

function removeChild!(tNode::WorldNode, obj::Renderable)
	for (idx, node) in enumerate(tNode.childObjs)
		if obj == node
			popat!(tNode.childObjs, idx)
		end
	end
end

function removeChild!(tNode::DojoNode, obj::Dojo.Node)
	for (idx, node) in enumerate(tNode.childObjs)
		if obj == node
			popat!(tNode.childObjs, idx)
		end
	end
end

	# if tNode.parent != nothing
		# if tNode.parent.object.id == idx
			# return tNode.parent
		# end
	#elseif

function findTNode(tNode::DojoNode, idx::Int64; recursion=1)
	if tNode.parent == nothing && length(tNode.childObjs) == 0
		return tNode
	elseif tNode.object.id == idx
		return tNode
	end
	for node in tNode.childObjs
		return findTNode(node, idx; recursion=recursion+1)
	end
	tNode.parent != nothing && findTNode(tNode.parent, idx; recursion=recursion+1)
	@error "Should not have fall through here"
end

function setTransform!(tNode::WorldNode, t)
	tNode.object.uniformData = t
	if tNode.childObjs == nothing
		return
	end
	for node in tNode.childObjs
		node.object.uniformData = t
	end
end


function buildTree(mechanism::Mechanism)
	rootNode = DojoNode(nothing, nothing, Dojo.Node[])
	tNode = rootNode
	for (id, joint) in enumerate(mechanism.joints)
		tNode = findTNode(tNode, joint.parent_id)
		pbody = get_body(mechanism, joint.parent_id)
		cbody = get_body(mechanism, joint.child_id)
		tNode.object == nothing && setObject!(tNode, pbody)
		addChild!(tNode, cbody)
	end
	return rootNode
end

function materialize!(node::DojoNode)
	wn = WorldNode(nothing, nothing, Renderable[], nothing)
	setfield!(wn, :body, getfield(node, :object))
	shape = getfield(node, :object).shape
	wo = nothing
	if typeof(shape) <: Dojo.EmptyShape
		mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.6, 0.5, 0.5, 1.0])
		wo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
	elseif typeof(shape) <: Dojo.Mesh
		mesh = WGPUgfx.defaultWGPUMesh(shape.path)
		wo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
	end
	
	setObject!(wn, wo)
	
	for cnode in node.childObjs
		cn = materialize!(cnode)
		addChild!(wn, cn)	
		setfield!(cn, :parent, wn)
	end
	
	return wn
end

function buildRobot(mechanism::Mechanism)
	tree = buildTree(mechanism)
	materialize!(tree)
end

mechanism = get_mechanism(:cartpole3D)
robot = buildRobot(mechanism)

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
addObject!(scene, robot)

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

# initialize!(mechanism, :cartpole3D; body_position=[0.0, 0.0, 0.00])

attachEventSystem(scene)

for (id, body) in enumerate(bodies)
	shape = body.shape
	if typeof(shape) <: Dojo.EmptyShape
		mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.6, 0.4, 0.5, 1.0])
		wo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		TreeNode(nothing, wo, Renderable[])
		addObject!(scene, wo)
	elseif typeof(shape) <: Dojo.Mesh
		mesh = WGPUgfx.defaultWGPUMesh(shape.path)
		wo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		addObject!(scene, wo)
	end
end


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
		if typeof(shape) <: Dojo.EmptyShape
			state = body.state
			trans = WGPUgfx.translate(state.x1 + Dojo.vector_rotate(shape.position_offset, state.q1))
			scale = WGPUgfx.scaleTransform(ones(3).*0.001)
			rot = WGPUgfx.rotateTransform(state.q1*shape.orientation_offset)
			mesh.uniformData = swapMat*(trans∘rot∘scale)(mesh.uniformData)
		elseif typeof(shape) <: Dojo.Shape
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
		if typeof(shape) <: Dojo.EmptyShape
			state = body.state
			trans = WGPUgfx.translate(shape.position_offset)
			scale = WGPUgfx.scaleTransform(ones(3).*0.001)
			rot = WGPUgfx.rotateTransform(shape.orientation_offset)
			mesh.uniformData = swapMat*(trans∘rot∘scale)(mesh.uniformData)
		elseif typeof(shape) <: Dojo.Shape
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
	camera.eye = [1.0, 1.0, 4.0]
	initialize!(mechanism, :cartpole3D; body_position=[0.0, 0.0, 0.0])
	initTransform!(scene, mechanism)
	try
		while !WindowShouldClose(canvas.windowRef[])
			stepController!(mechanism)
			stepTransform!(scene, mechanism)
			runApp(scene)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(canvas)
	end
end

main()


# function buildRobot(mechanism::Mechanism)
	# rootNode = TreeNode(nothing, nothing, Renderable[])
	# tNode = copy(rootNode)
	# for (id, joint) in enumerate(joints)
		# pbody = get_body(mechanism, joint.parent_id)
		# cbody = get_body(mechanism, joint.child_id)
		# pshape = pbody.shape
		# 
		# if typeof(pshape) <: Dojo.EmptyShape
			# mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.6, 0.4, 0.5, 1.0])
			# pwo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		# elseif typeof(pshape) <: Dojo.Mesh
			# mesh = WGPUgfx.defaultWGPUMesh(pshape.path)
			# pwo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		# end
# 
		# setObject!(tNode, pwo)
		# 
		# cshape = cbody.shape
		# if typeof(cshape) <: Dojo.EmptyShape
			# mesh = defaultWGPUMesh(joinpath(pkgdir(WGPUgfx), "assets", "sphere.obj"); color=[0.6, 0.4, 0.5, 1.0])
			# cwo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		# elseif typeof(cshape) <: Dojo.Mesh
			# mesh = WGPUgfx.defaultWGPUMesh(cshape.path)
			# cwo = WorldObject{WGPUMesh}(mesh, RenderType(VISIBLE | SURFACE | BBOX | AXIS), nothing, nothing, nothing, nothing)
		# end
		# 
		# addChild!(tNode, cwo)
	# end
# 
	# # rootNode = nothing
	# # for node in tNodes
		# # if node.parent == nothing
			# # rootNode = node
		# # end
	# # end
	# # if rootNode == nothing
		# # @error "Something is not right in root finding"
	# # end
	# return rootNode
# end
