class_name ComboSeekCache
extends RefCounted

## Pré-calcula o seek ideal para encadear combos.
## Para cada par (key_A, key_B), encontra o tempo em key_B cuja pose
## (ossos de braço/torso) é mais parecida com a pose final de key_A.

const BONES := [
	"mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
	"mixamorig_LeftArm", "mixamorig_LeftForeArm",
	"mixamorig_RightArm", "mixamorig_RightForeArm",
]

var _cache: Dictionary = {}


func build(p_db, p_chain: Array) -> void:
	_cache.clear()
	if p_db == null or p_chain == null or p_chain.size() < 2:
		return
	for i in range(p_chain.size() - 1):
		var ka := String(p_chain[i])
		var kb := String(p_chain[i + 1])
		if not p_db.has(ka) or not p_db.has(kb):
			continue
		var anim_a: Animation = p_db.anims[ka]
		var anim_b: Animation = p_db.anims[kb]
		var final_pose := _capture_pose(anim_a, anim_a.length)
		var best_t := 0.0
		var best_d := INF
		var t := 0.0
		while t <= anim_b.length + 1e-9:
			var pose_b := _capture_pose(anim_b, t)
			var d := pose_dist(final_pose, pose_b)
			if d < best_d:
				best_d = d
				best_t = t
			t += 1.0 / 30.0
		_cache[ka + "|" + kb] = best_t


func get_seek(key_a: String, key_b: String) -> float:
	var k := key_a + "|" + key_b
	if _cache.has(k):
		return float(_cache[k])
	return 0.0


static func pose_dist(qa: Dictionary, qb: Dictionary) -> float:
	var d := 0.0
	for bone in qa:
		if qb.has(bone):
			d += qa[bone].angle_to(qb[bone])
	return d


func _capture_pose(anim: Animation, time: float) -> Dictionary:
	var out := {}
	for bone in BONES:
		out[bone] = _sample_rotation(anim, bone, time)
	return out


static func _sample_rotation(anim: Animation, bone_name: String, t: float) -> Quaternion:
	for track in anim.get_track_count():
		if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		if not String(anim.track_get_path(track)).ends_with(bone_name):
			continue
		return anim.rotation_track_interpolate(track, t)
	return Quaternion.IDENTITY