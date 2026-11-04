extends CharacterBody3D

const SPEED := 7.0
const JUMP_VELOCITY := 5.5
var gravity := 18.0
var health := 200.0
var camera_pivot: Node3D
var camera: Camera3D
var last_touch := -1
var fire_cooldown := 0.0
var gliding := true
var glider_root: Node3D

func _ready() -> void:
    _make_character()
    _make_glider()
    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.5
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 3.2, 7.5)
    camera.rotation_degrees.x = -15
    camera.current = true
    camera_pivot.add_child(camera)

func _make_character() -> void:
    var body_mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.48
    capsule.height = 1.9
    body_mesh.mesh = capsule
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.82, 0.72, 0.56)
    body_mesh.material_override = material
    body_mesh.position.y = 0.95
    add_child(body_mesh)
    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.48
    shape.height = 1.9
    col.shape = shape
    col.position.y = 0.95
    add_child(col)

func _make_glider() -> void:
    glider_root = Node3D.new()
    glider_root.position.y = 3.0
    add_child(glider_root)
    var wing_mat := StandardMaterial3D.new()
    wing_mat.albedo_color = Color(0.72, 0.08, 0.12)
    wing_mat.roughness = 0.8
    for side in [-1.0, 1.0]:
        var wing := MeshInstance3D.new()
        var wing_mesh := BoxMesh.new()
        wing_mesh.size = Vector3(4.2, 0.12, 1.0)
        wing.mesh = wing_mesh
        wing.material_override = wing_mat
        wing.position = Vector3(side * 2.15, 0.45, 0.0)
        wing.rotation.z = side * -0.08
        glider_root.add_child(wing)
    var center := MeshInstance3D.new()
    var center_mesh := BoxMesh.new()
    center_mesh.size = Vector3(1.4, 0.16, 1.2)
    center.mesh = center_mesh
    center.material_override = wing_mat
    center.position.y = 0.42
    glider_root.add_child(center)

func _physics_process(delta: float) -> void:
    fire_cooldown = maxf(0.0, fire_cooldown - delta)
    if not is_on_floor():
        velocity.y -= (gravity * (0.22 if gliding else 1.0)) * delta
    elif gliding:
        gliding = false
        if is_instance_valid(glider_root):
            glider_root.queue_free()
    if Input.is_action_just_pressed("jump"):
        jump_now()
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var forward := -camera_pivot.global_basis.z
    var right := camera_pivot.global_basis.x
    var direction := (right * input_dir.x + forward * input_dir.y).normalized()
    var move_speed := 9.0 if gliding else SPEED
    if direction.length() > 0.01:
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 5.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 1.2)
        velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 1.2)
    move_and_slide()

func jump_now() -> void:
    if is_on_floor():
        velocity.y = JUMP_VELOCITY

func take_damage(amount: float) -> void:
    health = maxf(0.0, health - amount)

func shoot() -> void:
    if fire_cooldown > 0.0:
        return
    fire_cooldown = 0.22
    var from := camera.global_position
    var to := from + (-camera.global_basis.z * 100.0)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [self]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var target = hit.collider
        if target.is_in_group("bots") and target.has_method("take_damage"):
            target.take_damage(34.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x > get_viewport().size.x * 0.42:
            last_touch = event.index
        elif not event.pressed and event.index == last_touch:
            last_touch = -1
    elif event is InputEventScreenDrag and event.index == last_touch:
        camera_pivot.rotate_y(-event.relative.x * 0.005)
