class_name LabProjectileSpawner
extends Node3D
## Instancia projéteis a partir da mão, mas com a direção de voo estabilizada no
## ray da câmera (centro da tela). Assim o projétil sempre segue a mira, mesmo
## com a mão/animação se movendo.

const PROJECTILE_CFG := {
    "pistol": {
        "kind": 0, "speed": 45.0, "gravity": 0.0,
        "damage": 1, "trail": Color(1.0, 0.95, 0.5), "impact": Color(1.0, 0.7, 0.2),
        "burst": 1, "spread_deg": 1.0, "recoil": 0.35,
    },
    "rifle": {
        "kind": 0, "speed": 65.0, "gravity": 0.0,
        "damage": 2, "trail": Color(0.8, 1.0, 0.5), "impact": Color(0.6, 1.0, 0.3),
        "burst": 1, "spread_deg": 0.4, "recoil": 0.25,
    },
    "bow": {
        "kind": 1, "speed": 28.0, "gravity": 0.55,
        "damage": 2, "trail": Color(0.7, 0.55, 0.3), "impact": Color(0.9, 0.6, 0.2),
        "burst": 1, "spread_deg": 1.5, "recoil": 0.5,
    },
    "magic": {
        "kind": 2, "speed": 18.0, "gravity": 0.0,
        "damage": 3, "trail": Color(0.4, 0.6, 1.0), "impact": Color(0.5, 0.3, 1.0),
        "burst": 3, "spread_deg": 6.0, "recoil": 0.8,
    },
}

var aim: LabAimSystem
var camera: Camera3D
var skeleton: Skeleton3D
var weapon_id := ""


func spawn(aim_sys: LabAimSystem, sk: Skeleton3D, w_id: String, p_camera: Camera3D = null) -> void:
    aim = aim_sys
    skeleton = sk
    weapon_id = w_id
    camera = p_camera
    if camera == null and aim_sys != null:
        camera = aim_sys.camera
    var cfg: Dictionary = PROJECTILE_CFG.get(w_id, {})
    if cfg.is_empty():
        return
    var origin := _muzzle_position()
    var burst: int = cfg.get("burst", 1)
    for i in burst:
        _fire_one(origin, cfg, i)
    if aim:
        aim.add_recoil(cfg.get("recoil", 0.3))


func _muzzle_position() -> Vector3:
    if skeleton == null:
        return global_position
    var hand_i := skeleton.find_bone("mixamorig_RightHand")
    if hand_i < 0:
        return global_position
    return skeleton.global_transform * skeleton.get_bone_global_pose(hand_i).origin


func _fire_one(origin: Vector3, cfg: Dictionary, idx: int) -> void:
    # Direção de voo = ray da câmera pelo centro da tela (ou alvo travado).
    var base_dir := Vector3.FORWARD
    if aim and aim.lock_active and aim.lock_target != null and is_instance_valid(aim.lock_target):
        var to_target := aim.aim_point - origin
        if to_target.length() > 0.01:
            base_dir = to_target.normalized()
    elif camera != null:
        var center := camera.get_viewport().get_visible_rect().get_center()
        base_dir = camera.project_ray_normal(center).normalized()
    elif aim:
        var to_point := aim.aim_point - origin
        if to_point.length() > 0.01:
            base_dir = to_point.normalized()
    if base_dir.length() < 0.01:
        base_dir = Vector3.FORWARD

    var spread := deg_to_rad(float(cfg.get("spread_deg", 2.0)))
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var yaw := rng.randf_range(-spread, spread)
    var pitch := rng.randf_range(-spread, spread)
    var dir := (Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)) * base_dir
    dir = dir.normalized()

    var proj := LabProjectile.new()
    get_tree().root.add_child(proj)
    proj.global_position = origin + dir * 0.25
    proj.init(dir, cfg.get("speed", 30.0), cfg.get("kind", 0),
        cfg.get("gravity", 0.0), cfg.get("damage", 1),
        cfg.get("trail", Color.WHITE), cfg.get("impact", Color.ORANGE))
