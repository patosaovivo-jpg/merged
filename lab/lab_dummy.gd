class_name LabDummy
extends StaticBody3D
## Boneco de treino: pisca e balança quando acertado.

var _mat := StandardMaterial3D.new()
var _body: Node3D
var hits := 0

func _ready() -> void:
	add_to_group("dummies")
	_mat.albedo_color = Color(0.85, 0.7, 0.4)
	_body = Node3D.new()
	add_child(_body)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.38
	cm.height = 1.5
	torso.mesh = cm
	torso.position.y = 0.8
	torso.material_override = _mat
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	head.mesh = sm
	head.position.y = 1.78
	head.material_override = _mat
	_body.add_child(head)
	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.2, 0.1)
	post.mesh = bm
	post.position.y = 0.1
	_body.add_child(post)

func hit(_idx: int) -> void:
	hits += 1
	_mat.albedo_color = Color(1, 0.25, 0.2)
	var tw := create_tween()
	tw.tween_property(_body, "rotation:x", 0.25, 0.06)
	tw.tween_property(_body, "rotation:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC)
	tw.parallel().tween_property(_mat, "albedo_color", Color(0.85, 0.7, 0.4), 0.3)
