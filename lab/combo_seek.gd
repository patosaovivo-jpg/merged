class_name ComboSeekCache
extends RefCounted

const BONES := [
    "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
    "mixamorig_RightArm", "mixamorig_RightForeArm",
    "mixamorig_LeftArm",  "mixamorig_LeftForeArm",
]
const STEP := 1.0 / 30.0

var _cache: Dictionary = {}   # "keyA|keyB" -> float


func build(db: LabAnimDB, chain: Array) -> void:
    _cache.clear()
    for i in chain.size() - 1:
        var ka: String = chain[i]
        var kb: String = chain[i + 1]
        if not db.anims.has(ka) or not db.anims.has(kb):
            continue
        var pose_end := _capture_pose(db.anims[ka], db.anims[ka].length)
        _cache[ka + "|" + kb] = _best_seek(db.anims[kb], pose_end)


func get_seek(key_a: String, key_b: String) -> float:
    return _cache.get(key_a + "|" + key_b, 0.0)


static func _capture_pose(anim: Animation, t: float) -> Dictionary:
    var out := {}
    for bone in BONES:
        for track in anim.get_track_count():
            if anim.track_get_type(track) != Animation.TYPE_ROTATION_3D:
                continue
            if not String(anim.track_get_path(track)).ends_with(bone):
                continue
            out[bone] = anim.rotation_track_interpolate(track, t)
            break
    return out


static func _pose_dist(a: Dictionary, b: Dictionary) -> float:
    var d := 0.0
    for bone in a:
        if b.has(bone):
            d += (a[bone] as Quaternion).angle_to(b[bone])
    return d


static func _best_seek(anim: Animation, target: Dictionary) -> float:
    var best_t := 0.0
    var best_d := INF
    var t := 0.0
    while t <= anim.length:
        var pose := _capture_pose(anim, t)
        var d := _pose_dist(target, pose)
        if d < best_d:
            best_d = d
            best_t = t
        t += STEP
    return best_t