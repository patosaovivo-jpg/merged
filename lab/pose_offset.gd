class_name PoseOffset
extends RefCounted

var skeleton: Skeleton3D
var _offsets: Dictionary = {}
var decay_time := 0.10
var _elapsed := 0.0
var active := false


func capture(sk: Skeleton3D, anim: Animation, seek_to: float, bones: Array) -> void:
    skeleton = sk
    _offsets.clear()
    for name in bones:
        var bi := sk.find_bone(name)
        if bi < 0:
            continue
        var current_q: Quaternion = sk.get_bone_pose_rotation(bi)
        var anim_q: Quaternion = ComboSeekCache._capture_pose(anim, seek_to).get(name, Quaternion.IDENTITY)
        _offsets[name] = current_q * (anim_q as Quaternion).inverse()
    _elapsed = 0.0
    active = true


func apply(delta: float) -> void:
    if not active:
        return
    _elapsed += delta
    var t := clampf(_elapsed / maxf(decay_time, 0.001), 0.0, 1.0)
    for name in _offsets:
        var bi := skeleton.find_bone(name)
        if bi < 0:
            continue
        var tree_q: Quaternion = skeleton.get_bone_pose_rotation(bi)
        var blended := (_offsets[name] as Quaternion).slerp(Quaternion.IDENTITY, t) * tree_q
        skeleton.set_bone_pose_rotation(bi, blended)
    if t >= 1.0:
        active = false