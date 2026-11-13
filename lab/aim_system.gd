class_name LabAimSystem
extends Node3D
## Mira: crosshair 2D desenhado no centro exato da tela, ray de mira e ponto 3D
## onde o projétil deve convergir.

signal aim_point_changed(point: Vector3)

## Crosshair desenhado à mão (sem texturas/PNGs), sempre centralizado no próprio
## Control. O Control usa anchors PRESET_CENTER com offsets explícitos, então o
## desenho nunca sai do centro da viewport, mesmo redimensionando a janela.
class Crosshair extends Control:
    var col := Color(1, 1, 1, 0.75)
    var spread := 0.0

    func _draw() -> void:
        var c := size * 0.5
        var gap := 5.0 + spread
        var ln := 8.0
        var th := 2.0
        draw_line(Vector2(c.x, c.y - gap - ln), Vector2(c.x, c.y - gap), col, th, true)
        draw_line(Vector2(c.x, c.y + gap), Vector2(c.x, c.y + gap + ln), col, th, true)
        draw_line(Vector2(c.x - gap - ln, c.y), Vector2(c.x - gap, c.y), col, th, true)
        draw_line(Vector2(c.x + gap, c.y), Vector2(c.x + gap + ln, c.y), col, th, true)

var camera: Camera3D
var skeleton: Skeleton3D
var active := false
var aim_point := Vector3.ZERO
var max_range := 60.0
var lock_target: Node3D = null
var lock_active := false

var _player_rid: RID
var _cl: CanvasLayer
var _ch: Crosshair
var _spread := 0.0
var _hit_target := false

const IK_BONE_UPPER := "mixamorig_RightArm"
const IK_BONE_FORE := "mixamorig_RightForeArm"
var _ik_weight := 0.0


func setup(cam: Camera3D, sk: Skeleton3D, player_body: PhysicsBody3D = null) -> void:
    camera = cam
    skeleton = sk
    _player_rid = player_body.get_rid() if player_body != null else RID()
    _build_crosshair()


func set_active(on: bool) -> void:
    active = on
    if _cl:
        _cl.visible = on
    _ik_weight = 0.0


func _process(delta: float) -> void:
    if not active or camera == null:
        return
    _update_aim_ray()
    _update_crosshair(delta)
    if skeleton:
        _update_ik(delta)


func set_lock_target(t: Node3D, on: bool) -> void:
    lock_target = t
    lock_active = on


func _update_aim_ray() -> void:
    if lock_active and lock_target != null and is_instance_valid(lock_target):
        aim_point = lock_target.global_position + Vector3(0, 0.9, 0)
        _hit_target = true
        aim_point_changed.emit(aim_point)
        return
    var vp := get_viewport()
    var center := vp.get_visible_rect().get_center()
    var ray_from := camera.project_ray_origin(center)
    var ray_dir := camera.project_ray_normal(center)
    var space := get_world_3d().direct_space_state
    var params := PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * max_range)
    if _player_rid.is_valid():
        params.exclude = [_player_rid]
    var result := space.intersect_ray(params)
    _hit_target = false
    if result:
        aim_point = result.position
        if result.collider and result.collider.is_in_group("dummies"):
            _hit_target = true
    else:
        aim_point = ray_from + ray_dir * max_range
    aim_point_changed.emit(aim_point)


func _build_crosshair() -> void:
    if _cl != null and is_instance_valid(_cl):
        return
    _cl = CanvasLayer.new()
    _cl.layer = 20
    _cl.transform = Transform2D.IDENTITY
    _cl.offset = Vector2.ZERO
    add_child(_cl)
    _ch = Crosshair.new()
    _ch.name = "Crosshair"
    _ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ch.focus_mode = Control.FOCUS_NONE
    _ch.set_anchors_preset(Control.PRESET_CENTER)
    _ch.offset_left = -24.0
    _ch.offset_top = -24.0
    _ch.offset_right = 24.0
    _ch.offset_bottom = 24.0
    _cl.add_child(_ch)
    _cl.visible = false


func _update_crosshair(delta: float) -> void:
    if _ch == null:
        return
    _spread = lerpf(_spread, 0.0, delta * 8.0)
    _ch.col = Color(1, 0.3, 0.3, 0.9) if _hit_target else Color(1, 1, 1, 0.75)
    _ch.spread = _spread * 14.0
    _ch.queue_redraw()


func add_recoil(amount := 1.0) -> void:
    _spread = clampf(_spread + amount, 0.0, 1.0)


func _update_ik(delta: float) -> void:
    _ik_weight = lerpf(_ik_weight, 1.0 if active else 0.0, delta * 10.0)
    if _ik_weight < 0.01 or skeleton == null:
        return
    var upper_i := skeleton.find_bone(IK_BONE_UPPER)
    var fore_i := skeleton.find_bone(IK_BONE_FORE)
    if upper_i < 0 or fore_i < 0:
        return
    var skel_xf := skeleton.global_transform
    var aim_local := skel_xf.affine_inverse() * aim_point
    var shoulder_local := skeleton.get_bone_global_pose(upper_i).origin
    var aim_dir := (aim_local - shoulder_local).normalized()
    if aim_dir == Vector3.ZERO:
        return
    var current_q := skeleton.get_bone_pose_rotation(upper_i)
    var rest_q := skeleton.get_bone_rest(upper_i).basis.get_rotation_quaternion()
    var target_q := current_q.slerp(rest_q, _ik_weight * 0.4)
    skeleton.set_bone_pose_rotation(upper_i, target_q)
