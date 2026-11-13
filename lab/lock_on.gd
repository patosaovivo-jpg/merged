class_name LabLockOn
extends Node3D
## Lock-on estilo Dark Souls: seleciona o inimigo mais próximo no centro da tela,
## mantém a câmera orbitando ao redor do jogador olhando para o alvo e exibe
## um indicador 3D procedural sobre a cabeça do alvo.

signal target_changed(new_target: Node3D)
signal lost_target

var target: Node3D = null
var active := false

var max_range := 20.0
var max_angle := 35.0   # graus
var cam_speed := 6.0
var indicator_color := Color(1.0, 1.0, 1.0)

var _indicator: MeshInstance3D = null
var _marker: MeshInstance3D = null
var _spin_speed := 2.0
var _mouse_yaw_offset := 0.0
var _mouse_pitch_offset := 0.0


func toggle(camera: Camera3D, player_pos: Vector3) -> void:
    if active and target != null and is_instance_valid(target):
        _deactivate()
        return
    # busca o mais próximo dentro do cone de visão
    var best: Node3D = null
    var best_dist := max_range
    var cam_forward := -camera.global_transform.basis.z
    for n in get_tree().get_nodes_in_group("dummies"):
        if not (n is Node3D):
            continue
        var node := n as Node3D
        if not is_instance_valid(node):
            continue
        var to_node := node.global_position - player_pos
        var dist := to_node.length()
        if dist > max_range or dist < 0.01:
            continue
        var dir := to_node.normalized()
        var angle := rad_to_deg(cam_forward.angle_to(dir))
        if angle > max_angle:
            continue
        if dist < best_dist:
            best_dist = dist
            best = node
    if best != null:
        _activate(best)
    else:
        _deactivate()


func _activate(new_target: Node3D) -> void:
    if new_target == null or not is_instance_valid(new_target):
        _deactivate()
        return
    target = new_target
    active = true
    _mouse_yaw_offset = 0.0
    _mouse_pitch_offset = 0.0
    _create_indicator()
    target_changed.emit(target)


func _deactivate() -> void:
    _remove_indicator()
    target = null
    active = false
    target_changed.emit(null)
    lost_target.emit()


func update(delta: float, camera_pivot: Node3D, spring_arm: SpringArm3D, player_pos: Vector3) -> void:
    if not active:
        _remove_indicator()
        return
    if target == null or not is_instance_valid(target):
        _deactivate()
        return
    var dist := target.global_position.distance_to(player_pos)
    if dist > max_range * 1.5 or dist < 0.1:
        _deactivate()
        return
    # atualiza indicador
    if _indicator and is_instance_valid(_indicator):
        _indicator.global_position = target.global_position + Vector3(0, 1.8, 0)
    # câmera orbita suavemente para o alvo, com offset do mouse que decai
    var to_target := target.global_position - (player_pos + Vector3(0, 1.5, 0))
    if to_target.length() < 0.01:
        _deactivate()
        return
    var desired_yaw := atan2(-to_target.x, -to_target.z) + _mouse_yaw_offset
    var desired_pitch := clampf(-atan2(to_target.y, Vector2(to_target.x, to_target.z).length()), -0.6, 0.4) + _mouse_pitch_offset
    camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, desired_yaw, 1.0 - exp(-cam_speed * delta))
    camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, desired_pitch, 1.0 - exp(-cam_speed * delta))
    _mouse_yaw_offset = lerpf(_mouse_yaw_offset, 0.0, delta * 4.0)
    _mouse_pitch_offset = lerpf(_mouse_pitch_offset, 0.0, delta * 4.0)


func add_mouse_input(dx: float, dy: float, sens: float) -> void:
    if not active:
        return
    _mouse_yaw_offset -= dx * sens * 0.5
    _mouse_pitch_offset -= dy * sens * 0.5
    _mouse_yaw_offset = clampf(_mouse_yaw_offset, -0.6, 0.6)
    _mouse_pitch_offset = clampf(_mouse_pitch_offset, -0.4, 0.4)


func get_direction_to_target(player_pos: Vector3) -> Vector3:
    if target == null or not is_instance_valid(target):
        return Vector3.ZERO
    var to := target.global_position - player_pos
    to.y = 0.0
    if to.length() < 0.01:
        return Vector3.ZERO
    return to.normalized()


func _create_indicator() -> void:
    _remove_indicator()
    if target == null or not is_instance_valid(target):
        return
    _indicator = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.15
    torus.outer_radius = 0.22
    torus.rings = 12
    torus.ring_segments = 8
    _indicator.mesh = torus
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = indicator_color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _indicator.material_override = mat
    _indicator.scale = Vector3(1.2, 1.2, 1.2)
    get_tree().root.add_child(_indicator)
    _indicator.global_position = target.global_position + Vector3(0, 1.8, 0)
    # pequena marca branca sobre o alvo
    _marker = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.08
    sphere.height = 0.16
    _marker.mesh = sphere
    var mmat := StandardMaterial3D.new()
    mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mmat.albedo_color = Color(1, 1, 1, 1)
    _marker.material_override = mmat
    get_tree().root.add_child(_marker)
    _marker.global_position = target.global_position + Vector3(0, 1.8, 0)


func _remove_indicator() -> void:
    if _indicator and is_instance_valid(_indicator):
        _indicator.queue_free()
    _indicator = null
    if _marker and is_instance_valid(_marker):
        _marker.queue_free()
    _marker = null


func set_indicator_color(c: Color) -> void:
    indicator_color = c
    if _indicator and is_instance_valid(_indicator):
        var mat := _indicator.material_override as StandardMaterial3D
        if mat:
            mat.albedo_color = c


func _process(delta: float) -> void:
    if _indicator and is_instance_valid(_indicator) and target and is_instance_valid(target):
        _indicator.global_position = target.global_position + Vector3(0, 1.8, 0)
        _indicator.rotation.y += _spin_speed * delta
        # pulso leve
        var pulse := 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.1
        _indicator.scale = Vector3(pulse, pulse, pulse)
    if _marker and is_instance_valid(_marker) and target and is_instance_valid(target):
        _marker.global_position = target.global_position + Vector3(0, 1.8, 0)