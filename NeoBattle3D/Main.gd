extends Node3D

const PLAYER_SCRIPT = preload("res://Player.gd")
const BOT_SCRIPT = preload("res://Bot.gd")
var player: CharacterBody3D
var zone: MeshInstance3D
var zone_radius := 90.0
var elapsed := 0.0
var status_label: Label
var alive_bots := 8

var lobby_root: Node3D
var lobby_layer: CanvasLayer
var waiting_layer: CanvasLayer
var waiting_active := false
var waiting_seconds := 20.0
var waiting_label: Label
var match_started := false
var match_finished := false

func _ready() -> void:
    randomize()
    _make_lobby()

func _open_waiting_area() -> void:
    if waiting_active:
        return
    waiting_active = true
    waiting_seconds = 20.0
    waiting_layer = CanvasLayer.new()
    add_child(waiting_layer)

    var shade := ColorRect.new()
    shade.color = Color(0.015, 0.035, 0.055, 0.88)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    waiting_layer.add_child(shade)

    var heading := Label.new()
    heading.text = "ساحة انتظار اللاعبين"
    heading.position = Vector2(390, 35)
    heading.size = Vector2(500, 55)
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.add_theme_font_size_override("font_size", 34)
    heading.add_theme_color_override("font_color", Color(0.98, 0.82, 0.38))
    waiting_layer.add_child(heading)

    var board := Panel.new()
    board.position = Vector2(300, 125)
    board.size = Vector2(680, 350)
    waiting_layer.add_child(board)

    var board_title := Label.new()
    board_title.text = "ترتيب الفريق والاستعداد"
    board_title.position = Vector2(25, 18)
    board_title.size = Vector2(630, 40)
    board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    board_title.add_theme_font_size_override("font_size", 25)
    board.add_child(board_title)

    var rows := [
        "01     أنت — قائد الفريق                         جاهز",
        "02     لاعب الفريق 2                              جاهز",
        "03     لاعب الفريق 3                              جاهز",
        "04     لاعب الفريق 4                              جاهز"
    ]
    for i in range(rows.size()):
        var row := Label.new()
        row.text = rows[i]
        row.position = Vector2(55, 85 + i * 55)
        row.size = Vector2(570, 38)
        row.add_theme_font_size_override("font_size", 20)
        row.add_theme_color_override("font_color", Color(0.9, 0.94, 1))
        board.add_child(row)

    waiting_label = Label.new()
    waiting_label.position = Vector2(350, 505)
    waiting_label.size = Vector2(580, 45)
    waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    waiting_label.add_theme_font_size_override("font_size", 23)
    waiting_label.add_theme_color_override("font_color", Color.WHITE)
    waiting_layer.add_child(waiting_label)

    var enter := Button.new()
    enter.text = "متابعة إلى المباراة"
    enter.position = Vector2(500, 585)
    enter.size = Vector2(280, 70)
    enter.add_theme_font_size_override("font_size", 24)
    waiting_layer.add_child(enter)
    enter.pressed.connect(_start_match)
    _refresh_waiting_label()

func _refresh_waiting_label() -> void:
    if is_instance_valid(waiting_label):
        if waiting_seconds > 0.0:
            waiting_label.text = "بدء المباراة بعد: %d ثانية" % int(ceil(waiting_seconds))
        else:
            waiting_label.text = "اكتمل تجهيز ساحة الانتظار — يمكنك الدخول الآن"

func _start_match() -> void:
    if match_started:
        return
    match_started = true
    elapsed = 0.0
    waiting_active = false
    if is_instance_valid(waiting_layer):
        waiting_layer.queue_free()
    if is_instance_valid(lobby_layer):
        lobby_layer.queue_free()
    if is_instance_valid(lobby_root):
        lobby_root.queue_free()
    _make_environment()
    _make_island()
    _make_player()
    _spawn_bots()
    _make_hud()
    _make_zone()

func _make_lobby() -> void:
    lobby_root = Node3D.new()
    lobby_root.name = "LobbyIsland"
    add_child(lobby_root)

    var world_env := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.68, 0.78, 0.88)
    environment.ambient_light_energy = 0.9
    world_env.environment = environment
    lobby_root.add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -25, 0)
    sun.light_energy = 1.25
    lobby_root.add_child(sun)

    var water := MeshInstance3D.new()
    var water_mesh := PlaneMesh.new()
    water_mesh.size = Vector2(180, 180)
    water.mesh = water_mesh
    var water_mat := StandardMaterial3D.new()
    water_mat.albedo_color = Color(0.035, 0.31, 0.48)
    water_mat.roughness = 0.25
    water.material_override = water_mat
    water.position.y = -1.3
    lobby_root.add_child(water)

    var platform := StaticBody3D.new()
    var deck := MeshInstance3D.new()
    var deck_mesh := BoxMesh.new()
    deck_mesh.size = Vector3(25, 0.8, 13)
    deck.mesh = deck_mesh
    var wood := StandardMaterial3D.new()
    wood.albedo_color = Color(0.38, 0.22, 0.12)
    deck.material_override = wood
    platform.add_child(deck)
    var deck_collision := CollisionShape3D.new()
    var deck_shape := BoxShape3D.new()
    deck_shape.size = deck_mesh.size
    deck_collision.shape = deck_shape
    platform.add_child(deck_collision)
    lobby_root.add_child(platform)

    for i in range(4):
        _make_lobby_avatar(Vector3(-7.5 + i * 5.0, 0.45, 0.0), i)
    for i in range(5):
        _make_palm_lobby(Vector3(-18 + i * 9, -0.2, -13 - (i % 2) * 5))

    var camera := Camera3D.new()
    camera.position = Vector3(0, 10, 27)
    camera.rotation_degrees = Vector3(-17, 0, 0)
    camera.current = true
    lobby_root.add_child(camera)

    lobby_layer = CanvasLayer.new()
    add_child(lobby_layer)

    var title := Label.new()
    title.text = "NEO BATTLE"
    title.position = Vector2(36, 22)
    title.add_theme_font_size_override("font_size", 38)
    title.add_theme_color_override("font_color", Color(0.95, 0.83, 0.38))
    lobby_layer.add_child(title)

    var currency := Label.new()
    currency.text = "◆  1200       ◈  350"
    currency.position = Vector2(920, 28)
    currency.add_theme_font_size_override("font_size", 22)
    currency.add_theme_color_override("font_color", Color.WHITE)
    lobby_layer.add_child(currency)

    var team := Label.new()
    team.text = "الفريق\n1  اللاعب الرئيسي\n2  صديق الفريق\n3  لاعب\n4  لاعب"
    team.position = Vector2(35, 430)
    team.add_theme_font_size_override("font_size", 19)
    team.add_theme_color_override("font_color", Color.WHITE)
    lobby_layer.add_child(team)

    var mode := Label.new()
    mode.text = "الوضع: Battle Royale  •  الخريطة: جزيرة النخيل"
    mode.position = Vector2(420, 565)
    mode.add_theme_font_size_override("font_size", 20)
    mode.add_theme_color_override("font_color", Color.WHITE)
    lobby_layer.add_child(mode)

    var start := Button.new()
    start.text = "دخول ساحة الانتظار"
    start.position = Vector2(1000, 610)
    start.size = Vector2(230, 76)
    start.add_theme_font_size_override("font_size", 22)
    lobby_layer.add_child(start)
    start.pressed.connect(_open_waiting_area)

    var hint := Label.new()
    hint.text = "ردهة تجريبية • Offline"
    hint.position = Vector2(36, 680)
    hint.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
    lobby_layer.add_child(hint)

func _make_lobby_avatar(pos: Vector3, index: int) -> void:
    var avatar := Node3D.new()
    avatar.position = pos
    lobby_root.add_child(avatar)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.62
    capsule.height = 2.0
    body.mesh = capsule
    var outfit := StandardMaterial3D.new()
    var colors := [Color(0.16,0.36,0.62), Color(0.55,0.24,0.18), Color(0.22,0.43,0.29), Color(0.42,0.32,0.58)]
    outfit.albedo_color = colors[index]
    body.material_override = outfit
    body.position.y = 1.0
    avatar.add_child(body)
    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.42
    head.mesh = head_mesh
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.72,0.55,0.42)
    head.material_override = skin
    head.position.y = 2.25
    avatar.add_child(head)
    var pet := MeshInstance3D.new()
    var pet_mesh := SphereMesh.new()
    pet_mesh.radius = 0.38
    pet.mesh = pet_mesh
    var pet_mat := StandardMaterial3D.new()
    pet_mat.albedo_color = Color(0.9, 0.72, 0.28)
    pet.material_override = pet_mat
    pet.position = Vector3(1.0, 0.38, 1.2)
    avatar.add_child(pet)

func _make_palm_lobby(pos: Vector3) -> void:
    var trunk := MeshInstance3D.new()
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.22
    trunk_mesh.bottom_radius = 0.32
    trunk_mesh.height = 6.5
    trunk.mesh = trunk_mesh
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color(0.34,0.22,0.12)
    trunk.material_override = trunk_mat
    trunk.position = pos + Vector3(0,3.25,0)
    lobby_root.add_child(trunk)
    for j in range(6):
        var leaf := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 0.3
        leaf_mesh.height = 4.2
        leaf.mesh = leaf_mesh
        var leaf_mat := StandardMaterial3D.new()
        leaf_mat.albedo_color = Color(0.12,0.38,0.18)
        leaf.material_override = leaf_mat
        leaf.position = pos + Vector3(cos(TAU * j / 6.0) * 1.5, 6.1, sin(TAU * j / 6.0) * 1.5)
        leaf.rotation.z = -0.9
        leaf.rotation.y = TAU * j / 6.0
        lobby_root.add_child(leaf)

func _process(delta: float) -> void:
    if waiting_active:
        waiting_seconds = maxf(0.0, waiting_seconds - delta)
        _refresh_waiting_label()
    if not match_started or match_finished:
        return
    elapsed += delta
    zone_radius = maxf(18.0, 90.0 - elapsed * 0.32)
    if is_instance_valid(zone):
        zone.scale = Vector3(zone_radius / 90.0, 1.0, zone_radius / 90.0)
    if is_instance_valid(player):
        var distance := Vector2(player.global_position.x, player.global_position.z).length()
        if distance > zone_radius:
            player.take_damage(4.0 * delta)
        alive_bots = get_tree().get_nodes_in_group("bots").size()
        if is_instance_valid(status_label):
            status_label.text = "NEO BATTLE  |  Bots: %d  |  HP: %d  |  Zone: %dm" % [alive_bots, int(player.health), int(zone_radius)]
        if player.health <= 0.0:
            _finish_match(false)
        elif alive_bots == 0:
            _finish_match(true)

func _finish_match(victory: bool) -> void:
    if match_finished:
        return
    match_finished = true
    var layer := CanvasLayer.new()
    add_child(layer)
    var shade := ColorRect.new()
    shade.color = Color(0.01, 0.025, 0.04, 0.9)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(shade)
    var title := Label.new()
    title.text = "فوز! أحسنت" if victory else "انتهت المباراة"
    title.position = Vector2(390, 220)
    title.size = Vector2(500, 90)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.38) if victory else Color.WHITE)
    layer.add_child(title)
    var details := Label.new()
    details.text = "تم إقصاء جميع المنافسين" if victory else "حاول مرة أخرى"
    details.position = Vector2(390, 315)
    details.size = Vector2(500, 50)
    details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    details.add_theme_font_size_override("font_size", 24)
    details.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(details)
    var restart := Button.new()
    restart.text = "العودة إلى اللوبي"
    restart.position = Vector2(500, 420)
    restart.size = Vector2(280, 70)
    restart.add_theme_font_size_override("font_size", 23)
    layer.add_child(restart)
    restart.pressed.connect(func(): get_tree().reload_current_scene())

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
    _make_road(Vector3(0, 0.04, 0), Vector2(190, 7), 0.0)
    _make_road(Vector3(0, 0.04, 0), Vector2(7, 190), 0.0)
    _make_road(Vector3(-38, 0.04, -34), Vector2(78, 5), -0.55)
    _make_road(Vector3(38, 0.04, 34), Vector2(78, 5), -0.55)
    _make_beach_edges()
    _make_street_lights()
    _make_district(Vector3(0, 0, -58), 5, 0, "PEAK")
    _make_district(Vector3(-62, 0, -32), 4, 1, "MILL")
    _make_district(Vector3(62, 0, 32), 5, 2, "FACTORY")
    _make_district(Vector3(-62, 0, 58), 3, 3, "GRAVEYARD")
    _make_district(Vector3(58, 0, -62), 4, 0, "OBSERVATORY")
    _make_district(Vector3(-58, 0, 0), 3, 1, "RIVERSIDE")
    _make_district(Vector3(0, 0, 62), 4, 2, "VILLAGE")
    _make_district(Vector3(62, 0, 0), 3, 3, "SHIPYARD")
    _make_peak_hill(Vector3(0, 0, -76))
    _make_shipyard_docks(Vector3(76, 0, 0))
    _make_village_details(Vector3(0, 0, 62))
    _make_villa_compound(Vector3(48, 0, -42))
    for i in range(68):
        var p := Vector2(randf_range(-100, 100), randf_range(-100, 100))
        if p.length() > 24.0 and absf(p.x) > 6.0 and absf(p.y) > 6.0:
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

func _make_road(pos: Vector3, dimensions: Vector2, angle: float) -> void:
    var road := MeshInstance3D.new()
    var road_mesh := BoxMesh.new()
    road_mesh.size = Vector3(dimensions.x, 0.08, dimensions.y)
    road.mesh = road_mesh
    var road_mat := StandardMaterial3D.new()
    road_mat.albedo_color = Color(0.17, 0.19, 0.18)
    road.material_override = road_mat
    road.position = pos
    road.rotation.y = angle
    add_child(road)

func _make_district(center: Vector3, count: int, style: int, district_name: String) -> void:
    var offsets := [Vector2(-12, -10), Vector2(0, -12), Vector2(12, -9), Vector2(-10, 4), Vector2(3, 5), Vector2(13, 7)]
    for i in range(count):
        var offset: Vector2 = offsets[i % offsets.size()]
        _make_building(center + Vector3(offset.x, 0, offset.y), style + i)
    var sign := Label3D.new()
    sign.text = district_name
    sign.position = center + Vector3(0, 9, -17)
    sign.font_size = 38
    sign.outline_size = 7
    sign.modulate = Color(1.0, 0.88, 0.58)
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(sign)
    if style == 2:
        _make_factory_stack(center + Vector3(17, 0, -4))
    elif style == 3:
        _make_graveyard_props(center)
    elif style == 0:
        _make_observatory_dish(center + Vector3(-17, 0, 8))


func _make_beach_edges() -> void:
    var sand_mat := StandardMaterial3D.new()
    sand_mat.albedo_color = Color(0.72, 0.63, 0.42)
    sand_mat.roughness = 1.0
    var strips := [
        [Vector3(0, 0.025, -105), Vector3(205, 0.12, 9)],
        [Vector3(0, 0.025, 105), Vector3(205, 0.12, 9)],
        [Vector3(-105, 0.025, 0), Vector3(9, 0.12, 205)],
        [Vector3(105, 0.025, 0), Vector3(9, 0.12, 205)]
    ]
    for item in strips:
        var beach := MeshInstance3D.new()
        var beach_mesh := BoxMesh.new()
        beach_mesh.size = item[1]
        beach.mesh = beach_mesh
        beach.material_override = sand_mat
        beach.position = item[0]
        add_child(beach)

func _make_street_lights() -> void:
    var pole_mat := StandardMaterial3D.new()
    pole_mat.albedo_color = Color(0.22, 0.24, 0.23)
    var lamp_mat := StandardMaterial3D.new()
    lamp_mat.albedo_color = Color(1.0, 0.82, 0.48)
    lamp_mat.emission_enabled = true
    lamp_mat.emission = Color(0.75, 0.48, 0.18)
    for i in range(-4, 5):
        for side in [-1.0, 1.0]:
            var pole := MeshInstance3D.new()
            var pole_mesh := CylinderMesh.new()
            pole_mesh.top_radius = 0.10
            pole_mesh.bottom_radius = 0.16
            pole_mesh.height = 5.0
            pole.mesh = pole_mesh
            pole.material_override = pole_mat
            pole.position = Vector3(float(i) * 21.0 + side * 5.0, 2.5, -4.5 if side < 0.0 else 4.5)
            add_child(pole)
            var lamp := MeshInstance3D.new()
            var lamp_mesh := SphereMesh.new()
            lamp_mesh.radius = 0.32
            lamp.mesh = lamp_mesh
            lamp.material_override = lamp_mat
            lamp.position = pole.position + Vector3(0, 2.5, 0)
            add_child(lamp)

func _make_factory_stack(pos: Vector3) -> void:
    var stack := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.65
    mesh.bottom_radius = 0.85
    mesh.height = 10.0
    stack.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.35, 0.36, 0.34)
    stack.material_override = mat
    stack.position = pos + Vector3(0, 5, 0)
    add_child(stack)
    var band := MeshInstance3D.new()
    var band_mesh := CylinderMesh.new()
    band_mesh.top_radius = 0.88
    band_mesh.bottom_radius = 0.88
    band_mesh.height = 0.35
    band.mesh = band_mesh
    var band_mat := StandardMaterial3D.new()
    band_mat.albedo_color = Color(0.72, 0.24, 0.12)
    band.material_override = band_mat
    band.position = pos + Vector3(0, 7, 0)
    add_child(band)

func _make_graveyard_props(center: Vector3) -> void:
    var stone_mat := StandardMaterial3D.new()
    stone_mat.albedo_color = Color(0.48, 0.49, 0.45)
    for i in range(7):
        var stone := MeshInstance3D.new()
        var stone_mesh := BoxMesh.new()
        stone_mesh.size = Vector3(0.8, 1.3 + float(i % 3) * 0.25, 0.35)
        stone.mesh = stone_mesh
        stone.material_override = stone_mat
        stone.position = center + Vector3(-9.0 + float(i) * 3.0, stone_mesh.size.y * 0.5, 14.0 + float(i % 2) * 2.0)
        add_child(stone)

func _make_observatory_dish(pos: Vector3) -> void:
    var base := MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.45
    base_mesh.bottom_radius = 0.65
    base_mesh.height = 5.0
    base.mesh = base_mesh
    var base_mat := StandardMaterial3D.new()
    base_mat.albedo_color = Color(0.38, 0.42, 0.44)
    base.material_override = base_mat
    base.position = pos + Vector3(0, 2.5, 0)
    add_child(base)
    var dish := MeshInstance3D.new()
    var dish_mesh := SphereMesh.new()
    dish_mesh.radius = 2.5
    dish_mesh.height = 0.65
    dish.mesh = dish_mesh
    dish.material_override = base_mat
    dish.position = pos + Vector3(0, 5.1, 0)
    dish.rotation_degrees.x = -25
    add_child(dish)


func _make_peak_hill(center: Vector3) -> void:
    var hill := MeshInstance3D.new()
    var hill_mesh := SphereMesh.new()
    hill_mesh.radius = 17.0
    hill_mesh.height = 13.0
    hill.mesh = hill_mesh
    hill.scale = Vector3(1.35, 0.55, 1.0)
    var hill_mat := StandardMaterial3D.new()
    hill_mat.albedo_color = Color(0.25, 0.37, 0.22)
    hill_mat.roughness = 1.0
    hill.material_override = hill_mat
    hill.position = center + Vector3(0, 2.4, 0)
    add_child(hill)
    var lookout := MeshInstance3D.new()
    var lookout_mesh := BoxMesh.new()
    lookout_mesh.size = Vector3(5.5, 0.6, 5.5)
    lookout.mesh = lookout_mesh
    var deck_mat := StandardMaterial3D.new()
    deck_mat.albedo_color = Color(0.38, 0.29, 0.2)
    lookout.material_override = deck_mat
    lookout.position = center + Vector3(0, 7.2, 0)
    add_child(lookout)

func _make_shipyard_docks(center: Vector3) -> void:
    var wood_mat := StandardMaterial3D.new()
    wood_mat.albedo_color = Color(0.34, 0.23, 0.15)
    for i in range(3):
        var dock := MeshInstance3D.new()
        var dock_mesh := BoxMesh.new()
        dock_mesh.size = Vector3(4.0, 0.55, 19.0)
        dock.mesh = dock_mesh
        dock.material_override = wood_mat
        dock.position = center + Vector3(-7.0 + float(i) * 7.0, 0.15, 18.0)
        add_child(dock)
        for j in range(4):
            var post := MeshInstance3D.new()
            var post_mesh := BoxMesh.new()
            post_mesh.size = Vector3(0.45, 1.7, 0.45)
            post.mesh = post_mesh
            post.material_override = wood_mat
            post.position = dock.position + Vector3(-1.4, -0.55, -7.0 + float(j) * 4.5)
            add_child(post)
    var crane_mat := StandardMaterial3D.new()
    crane_mat.albedo_color = Color(0.78, 0.55, 0.18)
    var crane := MeshInstance3D.new()
    var crane_mesh := BoxMesh.new()
    crane_mesh.size = Vector3(0.7, 9.0, 0.7)
    crane.mesh = crane_mesh
    crane.material_override = crane_mat
    crane.position = center + Vector3(15, 4.5, 3)
    add_child(crane)
    var arm := MeshInstance3D.new()
    var arm_mesh := BoxMesh.new()
    arm_mesh.size = Vector3(10, 0.55, 0.65)
    arm.mesh = arm_mesh
    arm.material_override = crane_mat
    arm.position = center + Vector3(10, 8.7, 3)
    add_child(arm)

func _make_village_details(center: Vector3) -> void:
    var fence_mat := StandardMaterial3D.new()
    fence_mat.albedo_color = Color(0.42, 0.29, 0.17)
    for i in range(8):
        var post := MeshInstance3D.new()
        var post_mesh := BoxMesh.new()
        post_mesh.size = Vector3(0.22, 1.1, 0.22)
        post.mesh = post_mesh
        post.material_override = fence_mat
        post.position = center + Vector3(-16.0 + float(i) * 4.5, 0.55, 15.0)
        add_child(post)
    for side in [-1.0, 1.0]:
        var rail := MeshInstance3D.new()
        var rail_mesh := BoxMesh.new()
        rail_mesh.size = Vector3(31, 0.18, 0.18)
        rail.mesh = rail_mesh
        rail.material_override = fence_mat
        rail.position = center + Vector3(0, 0.85, 15.0 + side * 0.35)
        add_child(rail)
