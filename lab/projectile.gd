class_name LabProjectile
extends Node3D
## Projétil genérico: voa em linha reta ou curva (arco), colide com o primeiro
## objeto no grupo "dummies" ou com StaticBody3D, chama FX e se destrói.

signal hit_something(position: Vector3, normal: Vector3, hit_node: Node)

enum Kind { BULLET, ARROW, MAGIC }

var kind: Kind = Kind.BULLET
var speed := 28.0
var gravity_scale := 0.0
var damage := 1
var lifetime := 4.0
var trail_color := Color(1.0, 0.85, 0.2)
var impact_color := Color(1.0, 0.5, 0.1)

var _vel := Vector3.ZERO
var _age := 0.0
var _mesh: MeshInstance3D
var _trail: GPUParticles3D
var _space: PhysicsDirectSpaceState3D
var _done := false
const GRAVITY := 9.8


func init(direction: Vector3, p_speed: float, p_kind: Kind,
        p_gravity: float, p_damage: int, p_trail: Color, p_impact: Color) -> void:
    kind = p_kind
    speed = p_speed
    gravity_scale = p_gravity
    damage = p_damage
    trail_color = p_trail
    impact_color = p_impact
    _vel = direction.normalized() * speed
    _build_mesh()
    _build_trail()


func _ready() -> void:
    _space = get_world_3d().direct_space_state


func _process(delta: float) -> void:
    if _done:
        return
    _age += delta
    if _age > lifetime:
        _destroy(global_position, Vector3.UP, null)
        return
    _vel.y -= GRAVITY * gravity_scale * delta
    var from := global_position
    var to := from + _vel * delta
    var params := PhysicsRayQueryParameters3D.create(from, to)
    params.exclude = [get_parent().get_rid() if get_parent() is PhysicsBody3D else RID()]
    var result := _space.intersect_ray(params)
    if result:
        _destroy(result.position, result.normal, result.collider)
        return
    global_position = to
    if _mesh:
        _mesh.look_at(to + _vel.normalized(), _safe_up(_vel))


func _destroy(pos: Vector3, normal: Vector3, collider: Node) -> void:
    if _done:
        return
    _done = true
    if collider and collider.has_method("hit"):
        collider.hit(damage)
    hit_something.emit(pos, normal, collider)
    _spawn_impact(pos, normal)
    if _trail:
        _trail.emitting = false
    await get_tree().create_timer(0.6).timeout
    queue_free()


func _build_mesh() -> void:
    _mesh = MeshInstance3D.new()
    add_child(_mesh)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    match kind:
        Kind.BULLET:
            var c := CapsuleMesh.new()
            c.radius = 0.012; c.height = 0.055
            c.radial_segments = 6; c.rings = 1
            _mesh.mesh = c
            mat.albedo_color = Color(0.9, 0.85, 0.5)
        Kind.ARROW:
            var c := CylinderMesh.new()
            c.top_radius = 0.0; c.bottom_radius = 0.008
            c.height = 0.55; c.radial_segments = 6
            _mesh.mesh = c
            mat.albedo_color = Color(0.6, 0.45, 0.2)
        Kind.MAGIC:
            var s := SphereMesh.new()
            s.radius = 0.07; s.height = 0.14
            s.radial_segments = 8; s.rings = 4
            _mesh.mesh = s
            mat.albedo_color = trail_color
            mat.emission_enabled = true
            mat.emission = trail_color
            mat.emission_energy_multiplier = 2.5
    _mesh.material_override = mat
    _mesh.rotation_degrees.x = 90.0


func _build_trail() -> void:
    _trail = GPUParticles3D.new()
    add_child(_trail)
    var pm := ParticleProcessMaterial.new()
    pm.direction = Vector3(0, 0, 1)
    pm.spread = 8.0
    pm.initial_velocity_min = 0.2
    pm.initial_velocity_max = 0.6
    pm.gravity = Vector3.ZERO
    pm.scale_min = 0.04
    pm.scale_max = 0.09
    pm.color = trail_color
    _trail.process_material = pm
    _trail.amount = 18
    _trail.lifetime = 0.18
    _trail.fixed_fps = 30
    _trail.emitting = true
    _trail.local_coords = false
    var tm := StandardMaterial3D.new()
    tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tm.albedo_color = trail_color
    tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _trail.draw_pass_1 = SphereMesh.new()


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
    var fx := GPUParticles3D.new()
    get_tree().root.add_child(fx)
    fx.global_position = pos
    var pm := ParticleProcessMaterial.new()
    pm.direction = normal if normal != Vector3.ZERO else Vector3.UP
    pm.spread = 60.0
    pm.initial_velocity_min = 1.5
    pm.initial_velocity_max = 4.5
    pm.gravity = Vector3(0, -6, 0)
    pm.scale_min = 0.05
    pm.scale_max = 0.14
    pm.color = impact_color
    var ramp := GradientTexture1D.new()
    ramp.gradient = _alpha_ramp()
    pm.color_ramp = ramp
    fx.process_material = pm
    fx.amount = 32 if kind == Kind.MAGIC else 18
    fx.lifetime = 0.45
    fx.one_shot = true
    fx.explosiveness = 0.9
    fx.fixed_fps = 30
    var tm := StandardMaterial3D.new()
    tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tm.albedo_color = impact_color
    tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fx.draw_pass_1 = SphereMesh.new()
    fx.emitting = true
    get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(fx): fx.queue_free())
    if kind != Kind.ARROW:
        var ring := MeshInstance3D.new()
        get_tree().root.add_child(ring)
        ring.global_position = pos + normal * 0.01
        ring.look_at(pos + normal, _safe_up(normal))
        var rm := TorusMesh.new()
        rm.inner_radius = 0.0; rm.outer_radius = 0.07
        rm.rings = 8; rm.ring_segments = 12
        ring.mesh = rm
        var rmat := StandardMaterial3D.new()
        rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        rmat.albedo_color = impact_color
        rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring.material_override = rmat
        var tw := ring.create_tween()
        tw.tween_property(ring, "scale", Vector3(4, 4, 4), 0.3)
        tw.parallel().tween_property(rmat, "albedo_color:a", 0.0, 0.3)
        tw.tween_callback(ring.queue_free)
    # Marca de impacto no chão/parede
    var decal := MeshInstance3D.new()
    get_tree().root.add_child(decal)
    decal.global_position = pos + normal * 0.01
    decal.look_at(pos + normal, _safe_up(normal))
    var q := QuadMesh.new()
    q.size = Vector2(0.25, 0.25)
    decal.mesh = q
    var dmat := StandardMaterial3D.new()
    dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dmat.albedo_color = Color(0.3, 0.3, 0.3, 0.7)
    dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    decal.material_override = dmat
    var dtw := decal.create_tween()
    dtw.tween_property(dmat, "albedo_color:a", 0.0, 8.0)
    dtw.tween_callback(decal.queue_free)
    # Flash de luz no impacto
    var light := OmniLight3D.new()
    get_tree().root.add_child(light)
    light.global_position = pos + normal * 0.05
    light.light_color = impact_color
    light.light_energy = 3.0
    light.omni_range = 1.5
    var ltw := light.create_tween()
    ltw.tween_property(light, "light_energy", 0.0, 0.15)
    ltw.tween_callback(light.queue_free)


static func _safe_up(n: Vector3) -> Vector3:
    var d := n.normalized()
    if d == Vector3.ZERO:
        return Vector3.UP
    return Vector3.RIGHT if absf(d.dot(Vector3.UP)) > 0.99 else Vector3.UP


static func _alpha_ramp() -> Gradient:
    var g := Gradient.new()
    g.set_color(0, Color(1, 1, 1, 1))
    g.set_color(1, Color(1, 1, 1, 0))
    return g