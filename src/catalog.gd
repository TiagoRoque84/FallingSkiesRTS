extends RefCounted

var units: Dictionary
var buildings: Dictionary
var factions: Array
var maps: Array
var ai: Dictionary
const COLORS = ["78c9ac", "e96e65", "bb94e8", "e7c963", "60b2e0", "e79bce", "e3a166", "88af65", "b8c5d3"]

func _init():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	units = data.units
	buildings = data.buildings
	factions = data.factions
	maps = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json")).maps
	ai = JSON.parse_string(FileAccess.get_file_as_string("res://data/ai.json"))

func definition(kind: String, faction: int) -> Dictionary:
	var base: Dictionary = (units.get(kind, buildings.get(kind, {}))).duplicate(true)
	var f: Dictionary = factions[clampi(faction, 0, 2)]
	base["name"] = f.names.get(kind, base.get("name", kind))
	if units.has(kind):
		base["hp"] = base.hp * f.hp
		base["speed"] = base.speed * f.speed
		base["cost"] = roundi(base.cost * f.cost)
		base["damage"] = base.damage * f.damage
		if faction == 1 and kind == "tank": base["range"] += 35
		if faction == 2 and kind == "scout": base["speed"] += 25
		if faction == 0 and kind == "medic": base["heal"] = 16
	return base

func color_for(index: int) -> Color:
	return Color(COLORS[posmod(index, COLORS.size())])
