extends SceneTree

func _initialize():
	DirAccess.make_dir_recursive_absolute("res://LICENSES")
	FileAccess.open("res://LICENSES/GODOT.txt",FileAccess.WRITE).store_string(Engine.get_license_text())
	var parts=Engine.get_copyright_info()
	var licenses=Engine.get_license_info()
	var text="GODOT ENGINE — THIRD-PARTY NOTICES\n\n"+JSON.stringify(parts,"\t")+"\n\n"
	for name in licenses: text+="\n===== "+name+" =====\n"+licenses[name]+"\n"
	FileAccess.open("res://LICENSES/THIRD_PARTY.txt",FileAccess.WRITE).store_string(text)
	print("Licenças extraídas do motor utilizado.")
	quit()
