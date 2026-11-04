extends Node3D

const PLAYER_SCRIPT = preload("res://Player.gd")
const BOT_SCRIPT = preload("res://Bot.gd")
var player: CharacterBody3D
var zone: MeshInstance3D
var zone_radius := 90.0
var elapsed := 0.0
var status_label: Label
var alive_bots := 8

func _ready() -> void:
    randomize()
    _make_environment()
    _make_island()
    _make_player()
    _spawn_bots()
    _make_hud()
    _make_zone()

func _process(delta: float) -> void:
    elapsed += delta
    zone_radius = maxf(18.0, 90.0 - elapsed * 0.32)
    if is_instance_valid(zone):
        zone.scale = Vector3(zone_radius / 90.0, 1.0, zone_radius / 90.0)
    if is_instance_valid(player):
        var distance := Vector2(player.global_position.x, player.global_position.z).length()
        if distance > zone_radius:
            player.take_damage(4.0 * delta)
        alive_bots = get_tree().get_nodes_in_group("bots").size()
        status_label.text = "NEO BATTLE  |  Bots: %d  |  HP: %d  |  Zone: %dm" % [alive_bots, int(player.health), int(zone_radius)]

func _make_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_SKY
    e.sky = Sky.new()
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.65, 0.72, 0.82)
    e.ambient_light_energy = 0.8
    env.environment = e
    add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.2
    add_child(sun)

func _make_island() -> void:
    var ground := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(220, 220)
    mesh.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.22, 0.42, 0.27)
    mat.roughness = 1.0
    mesh.material_override = mat
    ground.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(220, 1, 220)
    collision.shape = shape
    collision.position.y = -0.5
    ground.add_child(collision)
    add_child(ground)
    var sea := MeshInstance3D.new()
    var sea_mesh := PlaneMesh.new()
    sea_mesh.size = Vector2(520, 520)
    sea.mesh = sea_mesh
    var sea_mat := StandardMaterial3D.new()
    sea_mat.albedo_color = Color(0.08, 0.38, 0.55)
    sea_mat.roughness = 0.28
    sea.material_override = sea_mat
    sea.position.y = -1.1
    add_child(sea)
    for i in range(16):
        var p := Vector2(randf_range(-68, 68), randf_range(-68, 68))
        if p.length() < 18.0:
            p += Vector2(28, 25)
        _make_building(Vector3(p.x, 0, p.y), i)
    _make_villa_compound(Vector3(48, 0, -42))
    for i in range(34):
        var p := Vector2(randf_range(-92, 92), randf_range(-92, 92))
        if p.length() > 22.0:
            _make_palm(Vector3(p.x, 0, p.y))

func _make_building(pos: Vector3, index: int) -> void:
    var w := randf_range(7.0, 11.0)
    var h := randf_range(4.0, 8.0)
    var d := randf_range(7.0, 10.0)
    var body := StaticBody3D.new()
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(w, h, d)
    mesh.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = [Color(0.68,0.58,0.43), Color(0.35,0.52,0.58), Color(0.58,0.57,0.48), Color(0.48,0.43,0.37)][index % 4]
    mesh.material_override = mat
    mesh.position.y = h * 0.5
    body.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    collision.shape = shape
    collision.position.y = h * 0.5
    body.add_child(collision)
    var roof := MeshInstance3D.new()
    var roof_mesh := BoxMesh.new()
    roof_mesh.size = Vector3(w + 0.5, 0.35, d + 0.5)
    roof.mesh = roof_mesh
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = Color(0.48, 0.25, 0.16)
    roof.material_override = roof_mat
    roof.position.y = h + 0.18
    body.add_child(roof)
    body.position = pos
    add_child(body)

func _make_palm(pos: Vector3) -> void:
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.18
    trunk_mesh.bottom_radius = 0.32
    trunk_mesh.height = 5.5
    trunk.mesh = trunk_mesh
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color(0.38, 0.25, 0.13)
    trunk.material_override = trunk_mat
    trunk.position = pos + Vector3(0, 2.75, 0)
    trunk.rotation.z = 0.08
    add_child(trunk)
    for j in range(6):
        var leaf := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 0.35
        leaf_mesh.height = 3.8
        leaf.mesh = leaf_mesh
        var leaf_mat := StandardMaterial3D.new()
        leaf_mat.albedo_color = Color(0.16, 0.39 + randf() * 0.12, 0.19)
        leaf.material_override = leaf_mat
        leaf.position = pos + Vector3(cos(TAU * j / 6.0) * 1.35, 5.25, sin(TAU * j / 6.0) * 1.35)
        leaf.rotation.z = -0.9
        leaf.rotation.y = TAU * j / 6.0
        add_child(leaf)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 28, 0)
    add_child(player)

func _spawn_bots() -> void:
    for i in range(8):
        var bot := CharacterBody3D.new()
        bot.set_script(BOT_SCRIPT)
        bot.add_to_group("bots")
        bot.target = player
        var angle := TAU * float(i) / 8.0
        bot.position = Vector3(cos(angle) * randf_range(24, 48), 2, sin(angle) * randf_range(24, 48))
        add_child(bot)

func _make_zone() -> void:
    zone = MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 90
    cylinder.bottom_radius = 90
    cylinder.height = 0.12
    zone.mesh = cylinder
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.15, 0.65, 1.0, 0.17)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    zone.material_override = m
    zone.position.y = 0.08
    add_child(zone)

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    status_label = Label.new()
    status_label.position = Vector2(18, 16)
    status_label.add_theme_font_size_override("font_size", 19)
    status_label.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(status_label)
    var help := Label.new()
    help.text = "WASD / الأسهم للحركة • Space للقفز • زر FIRE للإطلاق"
    help.position = Vector2(18, 48)
    help.add_theme_font_size_override("font_size", 15)
    help.add_theme_color_override("font_color", Color(0.92,0.95,1))
    layer.add_child(help)
    var fire := Button.new()
    fire.text = "FIRE"
    fire.position = Vector2(1080, 590)
    fire.size = Vector2(150, 90)
    fire.add_theme_font_size_override("font_size", 24)
    layer.add_child(fire)
    fire.pressed.connect(func(): player.shoot())
    var jump := Button.new()
    jump.text = "JUMP"
    jump.position = Vector2(920, 610)
    jump.size = Vector2(130, 70)
    layer.add_child(jump)
    jump.pressed.connect(func(): player.jump_now())


func _make_villa_compound(pos: Vector3) -> void:
    var wall_mat := StandardMaterial3D.new()
    wall_mat.albedo_color = Color(0.78, 0.68, 0.52)
    var wall_specs := [
        [Vector3(0, 1.4, -13), Vector3(28, 2.8, 0.8)],
        [Vector3(0, 1.4, 13), Vector3(28, 2.8, 0.8)],
        [Vector3(-14, 1.4, 0), Vector3(0.8, 2.8, 26)],
        [Vector3(14, 1.4, -5), Vector3(0.8, 2.8, 16)]
    ]
    for spec in wall_specs:
        var wall := MeshInstance3D.new()
        var wall_mesh := BoxMesh.new()
        wall_mesh.size = spec[1]
        wall.mesh = wall_mesh
        wall.material_override = wall_mat
        wall.position = pos + spec[0]
        add_child(wall)
    var house := StaticBody3D.new()
    var house_mesh := MeshInstance3D.new()
    var house_box := BoxMesh.new()
    house_box.size = Vector3(15, 7, 11)
    house_mesh.mesh = house_box
    var house_mat := StandardMaterial3D.new()
    house_mat.albedo_color = Color(0.43, 0.48, 0.34)
    house_mesh.material_override = house_mat
    house_mesh.position = pos + Vector3(0, 3.5, -3)
    house.add_child(house_mesh)
    var house_col := CollisionShape3D.new()
    var house_shape := BoxShape3D.new()
    house_shape.size = house_box.size
    house_col.shape = house_shape
    house_col.position = Vector3(0, 3.5, -3)
    house.add_child(house_col)
    var roof := MeshInstance3D.new()
    var roof_box := BoxMesh.new()
    roof_box.size = Vector3(16, 0.5, 12)
    roof.mesh = roof_box
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = Color(0.62, 0.19, 0.12)
    roof.material_override = roof_mat
    roof.position = pos + Vector3(0, 7.25, -3)
    house.add_child(roof)
    add_child(house)
