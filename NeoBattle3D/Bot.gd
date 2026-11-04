extends CharacterBody3D

var target: CharacterBody3D
var health := 100.0
var speed := 3.2
var gravity := 18.0
var attack_timer := 0.0
var wander_time := 0.0
var wander_dir := Vector3.ZERO

func _ready() -> void:
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 1.75
    body.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.78, 0.34, 0.22)
    body.material_override = mat
    body.position.y = 0.88
    add_child(body)
    var shape := CollisionShape3D.new()
    var collision := CapsuleShape3D.new()
    collision.radius = 0.42
    collision.height = 1.75
    shape.shape = collision
    shape.position.y = 0.88
    add_child(shape)

func _physics_process(delta: float) -> void:
    if not is_instance_valid(target):
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
    var to_target := target.global_position - global_position
    to_target.y = 0
    if to_target.length() > 5.0:
        var direction := to_target.normalized()
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
        rotation.y = atan2(-direction.x, -direction.z)
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * delta * 3.0)
        velocity.z = move_toward(velocity.z, 0.0, speed * delta * 3.0)
        attack_timer -= delta
        if attack_timer <= 0.0:
            target.take_damage(5.0)
            attack_timer = 1.4
    move_and_slide()

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        queue_free()
