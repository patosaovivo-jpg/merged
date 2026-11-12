class_name PoseOffset
extends RefCounted

## Aplica um offset de pose que decai ao longo de decay_time segundos.

var skeleton: Skeleton3D
var bones: Array = []
var offsets: Dictionary = {}
var decay_time := 0.10
var elapsed := 0.0
var active := false


func capture(sk: Skeleton3D, anim: Animation, seek_to: float, bone_names: Array) -> void:
	skeleton = sk
	bones = bone_names
	offsets.clear()
	for name in bone_names:
		var bi := sk.find_bone(name)
		if bi < 0:
			continue
		var current_q: Quaternion = sk.get_bone_pose_rotation(bi)
		var anim_q: Quaternion = _sample_rotation(anim, name, seek_to)
		offsets[name] = current_q * anim_q.inverse()
	elapsed = 0.0
	active = true


func apply(delta: float) -> void:
	if not active or skeleton == null:
		return
	elapsed += delta
	var t := clampf(elapsed / maxf(decay_time, 0.001), 0.0, 1.0)
	for name in offsets:
		var bi := skeleton.find_bone(name)
		if bi < 0:
			continue
		var tree_q: Quaternion = skeleton.get_bone_pose_rotation(bi)
		var blended: Quaternion = offsets[name].slerp(Quaternion.IDENTITY, t) * tree_q
		skeleton.set_bone_pose_rotation(bi, blended)
	if t >= 1.0:
		active = false


static func _sample_rotation(anim: Animation, bone_name: String, t: float) -> Quaternion:
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		if not String(anim.track_get_path(track)).ends_with(bone_name):
			continue
		return anim.rotation_track_interpolate(track, t)
	return Quaternion.IDENTITY