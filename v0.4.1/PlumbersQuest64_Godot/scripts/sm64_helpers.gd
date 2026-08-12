class_name SM64Helpers
extends RefCounted
## Helpers that talk to libsm64-godot without depending on typed handler nodes.

## Load a large flat floor so Mario can always be created.
## Call after LibSM64Global.init().
static func load_flat_floor(half_size: float = 50.0, y: float = 0.0) -> void:
	var arr := LibSM64SurfaceArray.new()
	var a := Vector3(-half_size, y, -half_size)
	var b := Vector3( half_size, y, -half_size)
	var c := Vector3( half_size, y,  half_size)
	var d := Vector3(-half_size, y,  half_size)
	arr.add_triangle(a, b, c)
	arr.add_triangle(a, c, d)
	LibSM64.static_surfaces_load(arr)

## Load all MeshInstance3D nodes in group into static surfaces.
static func load_group_as_static_surfaces(group_name: StringName = &"libsm64_static_surfaces") -> int:
	var arr := LibSM64SurfaceArray.new()
	var count := 0
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		load_flat_floor()
		return 2
	for node in tree.get_nodes_in_group(group_name):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var faces: PackedVector3Array = mi.mesh.get_faces()
		if faces.is_empty():
			continue
		for i in range(0, faces.size(), 3):
			var v1 := mi.global_transform * faces[i]
			var v2 := mi.global_transform * faces[i + 1]
			var v3 := mi.global_transform * faces[i + 2]
			arr.add_triangle(v1, v2, v3)
			count += 1
	if count > 0:
		LibSM64.static_surfaces_load(arr)
	else:
		load_flat_floor()
		count = 2
	return count
