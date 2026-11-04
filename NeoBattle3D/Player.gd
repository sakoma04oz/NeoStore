extends CharacterBody3D

const SPEED := 7.0
const JUMP_VELOCITY := 5.5
var gravity := 18.0
var camera_pivot: Node3D
var camera: Camera3D
var touch_look := Vector2.ZERO
var last_touch := -1

func _ready() -> void:
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.48
    capsule.height = 1.9
    var body_mesh := MeshInstance3D.new()
    body_mesh.mesh = capsule
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.25, 0.72, 0.85)
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
    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.5
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 3.2, 7.5)
    camera.rotation_degrees.x = -15
    camera.current = true
    camera_pivot.add_child(camera)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var forward := -camera_pivot.global_basis.z
    var right := camera_pivot.global_basis.x
    var direction := (right * input_dir.x + forward * input_dir.y).normalized()
    if direction:
        velocity.x = direction.x * SPEED
        velocity.z = direction.z * SPEED
        rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED * delta * 3)
        velocity.z = move_toward(velocity.z, 0, SPEED * delta * 3)
    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x > get_viewport().size.x * 0.42:
            last_touch = event.index
        elif not event.pressed and event.index == last_touch:
            last_touch = -1
    elif event is InputEventScreenDrag and event.index == last_touch:
        camera_pivot.rotate_y(-event.relative.x * 0.005)
