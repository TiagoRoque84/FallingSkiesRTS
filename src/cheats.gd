extends RefCounted

var allowed = false
var used = false
var flags = {"resources": false, "invincible": false, "superweapon": false, "reveal": false}
const NAMES = {"resources": "Recursos infinitos", "invincible": "Invencibilidade", "superweapon": "Superarma instantânea", "reveal": "Revelar todo o mapa"}

func reset(permission: bool):
	allowed = permission
	used = false
	for key in flags: flags[key] = false

func toggle(key: String) -> bool:
	if not allowed or not flags.has(key): return false
	flags[key] = not flags[key]
	used = used or flags[key]
	return true

func active(key: String, owner: int = 0) -> bool:
	return owner == 0 and allowed and flags.get(key, false)
