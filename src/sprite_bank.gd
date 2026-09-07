extends RefCounted

var building_sheets: Array=[]
var building_icons: Array=[]
var units: Texture2D
var utility: Texture2D
var terrain: Texture2D
var environment: Texture2D
const BUILDING_ORDER=["hq","power","refinery","barracks","factory","lab","hospital","turret","super"]

func _init():
	for name in ["resistance","espheni","berserker"]:
		var sheet=load("res://assets/sprites/"+name+"_buildings.png")
		building_sheets.append(sheet)
		var icons={}
		for i in 9:
			var atlas=AtlasTexture.new(); atlas.atlas=sheet; atlas.region=region(sheet,i,3,3); icons[BUILDING_ORDER[i]]=atlas
		building_icons.append(icons)
	units=load("res://assets/sprites/units_directions.png")
	utility=load("res://assets/sprites/utility_directions.png")
	terrain=load("res://assets/sprites/terrain_materials.png")
	if ResourceLoader.exists("res://assets/sprites/environment.png"): environment=load("res://assets/sprites/environment.png")

func region(texture: Texture2D,index: int,cols: int,rows: int) -> Rect2:
	var size=Vector2(texture.get_size())/Vector2(cols,rows)
	return Rect2(Vector2(index%cols,index/cols)*size,size)

func building_region(faction: int,kind: String) -> Rect2:
	return region(building_sheets[faction],BUILDING_ORDER.find(kind),3,3)

func unit_region(faction: int,e: Dictionary) -> Rect2:
	var row=faction
	if not e.d.get("biological",false): row=faction+3
	var direction=posmod(roundi(e.angle/(TAU/8)),8)
	return region(units,row*8+direction,8,6)

func icon(faction: int,kind: String) -> Texture2D:
	if BUILDING_ORDER.has(kind): return building_icons[faction][kind]
	return null
