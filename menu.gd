extends Node


const STEAM_APP_ID = 2744870 # Playtest App ID
const GODOT_VERSIONS = {
	"4.2": "4.2.1",
	"4.1": "4.1.3",
	"4.0": "4.0.4",
	"3.5": "3.5.3",
	"3.4": "3.4.5",
	"3.3": "3.3.4",
	"3.2": "3.2.3",
	"3.1": "3.1.2",
	"3.0": "3.0.6",
	"2.1": "2.1.6",
	"2.0": "2.0.4.1",
	"1.1": "1.1"
}
var initialize_steam = {}
var steam_id = 0
var games = []
var page_number = 1
var get_games = 0
var getting_games = 0
var show_games = 0
var delete_unused_images = 0
var workshop_item_id = 0
var update_handle = 0
var update_progress = {}
@onready var workshop_button = $Buttons/Workshop
@onready var upload_window = $Buttons/Upload/Window
@onready var select_folder_file_dialog = $Buttons/Upload/Window/SelectFolder/FileDialog
@onready var folder_path_textedit = $Buttons/Upload/Window/FolderPath
@onready var select_image_file_dialog = $Buttons/Upload/Window/SelectImage/FileDialog
@onready var image_path_textedit = $Buttons/Upload/Window/ImagePath
@onready var item_type_button = $Buttons/Upload/Window/ItemType
@onready var update_or_new_button = $Buttons/Upload/Window/UpdateOrNew
@onready var item_id_textedit = $Buttons/Upload/Window/ItemID
@onready var upload_button = $Buttons/Upload/Window/Upload
@onready var update_progress_label = $Buttons/Upload/Window/UpdateProgress
@onready var upload_timer = $Buttons/Upload/Window/Timer
@onready var help_button = $Buttons/Help
@onready var about_window = $Buttons/About/Window
@onready var licenses_tab = $Buttons/About/Window/Tabs/Licenses
@onready var godotengine_tab = $Buttons/About/Window/Tabs/Licenses/GodotEngine


func _ready():
	if Steam.restartAppIfNecessary(STEAM_APP_ID):
		get_tree().quit()
	else:
		initialize_steam = Steam.steamInitEx()
		if initialize_steam["status"] != 0:
			OS.alert(initialize_steam["verbal"], "Error - Gamebox")
			get_tree().quit()
		else:
			steam_id = Steam.getSteamID()
			DirAccess.make_dir_absolute("user://workshop_cache_" + str(steam_id))
			Steam.connect("ugc_query_completed", _on_ugc_query_completed)
			Steam.connect("item_installed", _on_item_installed)
			Steam.connect("item_created", _on_item_created)
			Steam.connect("item_updated", _on_item_updated)
			$Versions.set_text($Versions.get_text() + str(Engine.get_version_info()["major"]) + "." + str(Engine.get_version_info()["minor"]) + "." + str(Engine.get_version_info()["patch"]))
			folder_path_textedit.hide()
			image_path_textedit.hide()
			licenses_tab.set_tab_title(1, "Godot Engine")
			godotengine_tab.set_tab_title(2, "Third-party licenses")
			_add_tests()
			delete_unused_images = 1
			get_games = 1
			getting_games = 1


func _process(_delta):
	Steam.run_callbacks()
	if get_games == 1 and getting_games > 0:
		get_games = 0
		getting_games -= 1
		games = []
		_get_games()
	if show_games == 1:
		_show_games()
		page_number = 1
		show_games = 0
		get_games = 1
	if upload_window.is_visible():
		if update_or_new_button.get_selected() == 0:
			if not item_id_textedit.get_text():
				upload_button.set_disabled(true)
			if item_id_textedit.get_text() and (folder_path_textedit.get_text() or image_path_textedit.get_text()):
				upload_button.set_disabled(false)
		if update_or_new_button.get_selected() == 1:
			if not folder_path_textedit.get_text() or not image_path_textedit.get_text():
				upload_button.set_disabled(true)
			if folder_path_textedit.get_text() and image_path_textedit.get_text():
				upload_button.set_disabled(false)
			if item_type_button.get_selected() == 1:
				upload_button.set_disabled(true)


func _get_games():
	var query_handle = Steam.createQueryUserUGCRequest(Steam.getSteamID(), Steam.USER_UGC_LIST_SUBSCRIBED, Steam.UGC_MATCHINGUGCTYPE_ITEMS, Steam.USERUGCLISTSORTORDER_TITLEASC, STEAM_APP_ID, STEAM_APP_ID, page_number)
	Steam.addRequiredTag(query_handle, "Games")
	Steam.sendQueryUGCRequest(query_handle)


func _on_ugc_query_completed(query_handle, result, results_returned, _total_matching, _cached):
	if result == 1:
		var workshop_cache_folder = DirAccess.open("user://workshop_cache_" + str(steam_id))
		for i in range(results_returned):
			if Steam.getItemState(Steam.getQueryUGCResult(query_handle, i)["file_id"]) in [8, 9]:
				Steam.downloadItem(Steam.getQueryUGCResult(query_handle, i)["file_id"], true)
			games.append(Steam.getQueryUGCResult(query_handle, i))
			if workshop_cache_folder:
				workshop_cache_folder.list_dir_begin()
				var file_name = workshop_cache_folder.get_next()
				while not file_name.ends_with(str(Steam.getQueryUGCResult(query_handle, i)["handle_preview_file"]) + ".png"):
					if file_name == "":
						var http_request = HTTPRequest.new()
						add_child(http_request)
						http_request.connect("request_completed", _on_request_completed)
						http_request.set_download_file("user://workshop_cache_" + str(steam_id) + "/" + str(Steam.getQueryUGCResult(query_handle, i)["file_id"]) + "_" + str(Steam.getQueryUGCResult(query_handle, i)["handle_preview_file"]) + ".png")
						http_request.request(Steam.getQueryUGCPreviewURL(query_handle, i))
						break
					file_name = workshop_cache_folder.get_next()
				workshop_cache_folder.list_dir_end()
			else:
				OS.alert("Couldn't access the workshop_cache folder.", "Error - Gamebox")
	Steam.releaseQueryUGCRequest(query_handle)
	if result == 1:
		if results_returned == 50:
			page_number += 1
			_get_games()
		elif results_returned < 50:
			show_games = 1


func _on_request_completed(_result, _response_code, _headers, _body):
	if getting_games < 2:
		getting_games += 1


func _on_item_installed(app_id, file_id):
	if app_id == STEAM_APP_ID and getting_games < 2 and FileAccess.file_exists(Steam.getItemInstallInfo(file_id)["folder"].path_join("gamebox_game.json")):
		getting_games += 1


func _add_tests():
	var image_test = Image.load_from_file(OS.get_executable_path().get_base_dir().path_join("test2d.png"))
	var icon_texture_test = ImageTexture.create_from_image(image_test)
	$Games.add_item("Test 2D [Godot 4.1]", icon_texture_test)
	image_test = Image.load_from_file(OS.get_executable_path().get_base_dir().path_join("test3d.png"))
	icon_texture_test = ImageTexture.create_from_image(image_test)
	$Games.add_item("Test 3D [Godot 4.1]", icon_texture_test)


func _show_games():
	$Games.clear()
	_add_tests()
	for game in games:
		var image = Image.load_from_file("user://workshop_cache_" + str(steam_id) + "/" + str(game["file_id"]) + "_" + str(game["handle_preview_file"]) + ".png")
		var icon_texture = ImageTexture.create_from_image(image)
		$Games.add_item(game["title"], icon_texture)
		$Games.set_item_metadata($Games.get_item_count() - 1, game["file_id"])
	if delete_unused_images == 1:
		var size = games.size()
		var workshop_cache_folder = DirAccess.open("user://workshop_cache_" + str(steam_id))
		workshop_cache_folder.list_dir_begin()
		var file_name = workshop_cache_folder.get_next()
		while file_name != "":
			var i = 0
			var id_handle = file_name.get_basename().split("_")
			for game in games:
				i += 1
				if file_name.get_extension() == "png" and id_handle.size() == 2 and id_handle[0] == str(game["file_id"]) and id_handle[1] == str(game["handle_preview_file"]):
					break
				elif i == size:
					workshop_cache_folder.remove(file_name)
			file_name = workshop_cache_folder.get_next()
		delete_unused_images = 0


func _on_games_item_activated(index):
	if index in [0, 1]:
		var test = "2d"
		if index == 1:
			test = "3d"
		var ext = ".x86_64"
		if OS.get_name() == "Windows":
			ext = ".exe"
		if OS.create_process(OS.get_executable_path().get_base_dir().path_join("godot/4.1test/godot-" + GODOT_VERSIONS["4.1"] + ext), ["--main-pack", OS.get_executable_path().get_base_dir().path_join("test" + test + ".pck")]) == -1:
			OS.alert("This game's process creation of Godot failed.", "Error - Gamebox")
	else:
		var game_path = Steam.getItemInstallInfo($Games.get_item_metadata(index))["folder"]
		var json = FileAccess.get_file_as_string(game_path.path_join("gamebox_game.json"))
		var gamebox_game = JSON.parse_string(json)
		if gamebox_game is Dictionary and "godot" in gamebox_game and "pack" in gamebox_game["godot"] and gamebox_game["godot"]["pack"] is String and FileAccess.file_exists(game_path.path_join(gamebox_game["godot"]["pack"])):
			var pck = FileAccess.open(game_path.path_join(gamebox_game["godot"]["pack"]), FileAccess.READ)
			var magic = pck.get_32()
			pck.get_32()
			var major = str(pck.get_32())
			var minor = str(pck.get_32())
			var godot_version = major + "." + minor
			var file_extension = ""
			#var lib_path = ""
			if magic == 0x43504447 and godot_version in GODOT_VERSIONS:
				match OS.get_name():
					"Linux":
						file_extension = ".x86_64"
						if major in ["3", "2", "1"]:
							file_extension = ".64"
						#lib_path = OS.get_environment("LD_LIBRARY_PATH")
						#OS.set_environment("LD_LIBRARY_PATH", lib_path + ":" + game_path.path_join(gamebox_game["godot"]["pack"]).get_base_dir())
					"Windows":
						file_extension = ".exe"
						#lib_path = OS.get_environment("PATH")
						#OS.set_environment("PATH", lib_path + ";" + game_path.path_join(gamebox_game["godot"]["pack"]).get_base_dir())
				if OS.create_process(OS.get_executable_path().get_base_dir().path_join("godot/") + godot_version + "/godot-" + GODOT_VERSIONS[godot_version] + file_extension, ["--path", game_path.path_join(gamebox_game["godot"]["pack"].get_base_dir()), "--main-pack", game_path.path_join(gamebox_game["godot"]["pack"])]) == -1:
					OS.alert("This game's process creation of Godot failed.", "Error - Gamebox")
#				match OS.get_name():
#					"Linux":
#						OS.set_environment("LD_LIBRARY_PATH", lib_path)
#					"Windows":
#						OS.set_environment("PATH", lib_path)
			else:
				OS.alert("This game's .pck file can't be loaded.", "Error - Gamebox")
		elif gamebox_game is Dictionary and "executable" in gamebox_game and ("linux-x64" in gamebox_game["executable"] or "windows-x64" in gamebox_game["executable"]) and gamebox_game["executable"].values().all(func(value): return value is String) and gamebox_game["executable"].keys().filter(func(key): return gamebox_game["executable"][key] != "").all(func(key): return FileAccess.file_exists(game_path.path_join(gamebox_game["executable"][key]))):
			var os_name = ""
			match OS.get_name():
				"Linux":
					os_name = "linux-x64"
				"Windows":
					os_name = "windows-x64"
			if os_name in gamebox_game["executable"] and gamebox_game["executable"][os_name] and OS.create_process(game_path.path_join(gamebox_game["executable"][os_name]), []) == -1:
				OS.alert("This game's process creation failed.", "Error - Gamebox")
			elif not os_name in gamebox_game["executable"] or not gamebox_game["executable"][os_name]:
				OS.alert("This game does not include a " + OS.get_name() + " executable.", "Error - Gamebox")
		else:
			OS.alert("This game's gamebox_game.json file is not properly configured.", "Error - Gamebox")


func _on_workshop_pressed():
	Steam.activateGameOverlayToWebPage("https://steamcommunity.com/app/" + str(STEAM_APP_ID) + "/workshop/")


func _on_upload_pressed():
	upload_window.show()


func _on_select_folder_pressed():
	select_folder_file_dialog.show()


func _on_select_folder_file_dialog_dir_selected(dir):
	folder_path_textedit.set_text(dir)
	folder_path_textedit.show()


func _on_select_image_pressed():
	select_image_file_dialog.show()


func _on_select_image_file_dialog_file_selected(path):
	image_path_textedit.set_text(path)
	image_path_textedit.show()


func _on_update_or_new_item_selected(index):
	var item_text = update_or_new_button.get_item_text(index)
	if item_text == "Update item":
		item_id_textedit.show()
	elif item_text == "New item":
		item_id_textedit.set_text("")
		item_id_textedit.hide()


func _on_upload_to_workshop_pressed():
	upload_button.hide()
	var item_text = update_or_new_button.get_item_text(update_or_new_button.get_selected())
	if item_text == "Update item":
		update_progress_label.set_text("Attempting upload...")
		_upload_to_workshop(int(item_id_textedit.get_text()))
	elif item_text == "New item":
		update_progress_label.set_text("Creating new item...")
		Steam.createItem(STEAM_APP_ID, Steam.WORKSHOP_FILE_TYPE_COMMUNITY)


func _upload_to_workshop(file_id):
	workshop_item_id = file_id
	update_handle = Steam.startItemUpdate(STEAM_APP_ID, file_id)
	var folder_name = folder_path_textedit.get_text().split("/")[-1]
	if update_or_new_button.get_item_text(update_or_new_button.get_selected()) == "New item":
		Steam.setItemTitle(update_handle, folder_name)
		Steam.setItemVisibility(update_handle, Steam.REMOTE_STORAGE_PUBLISHED_VISIBILITY_PRIVATE)
	Steam.setItemContent(update_handle, folder_path_textedit.get_text())
	Steam.setItemPreview(update_handle, image_path_textedit.get_text())
	if item_type_button.get_selected() != 1:
		Steam.setItemTags(update_handle, [item_type_button.get_item_text(item_type_button.get_selected())])
	Steam.submitItemUpdate(update_handle, "")
	update_progress = Steam.getItemUpdateProgress(update_handle)
	if update_progress["status"] > 0:
		update_progress_label.set_text("Uploading...")
		upload_timer.start()


func _on_item_updated(result, accept_tos):
	upload_timer.stop()
	if result == 1:
		update_progress_label.set_text("Upload successful.")
		Steam.activateGameOverlayToWebPage("https://steamcommunity.com/sharedfiles/filedetails/?id=" + str(workshop_item_id))
	else:
		update_progress_label.set_text("Upload failed. Error code: " + str(result))
	if accept_tos:
		_open_tos()


func _on_item_created(result, file_id, accept_tos):
	if result == 1:
		_upload_to_workshop(file_id)
	else:
		update_progress_label.set_text("New item creation failed. Error code: " + str(result))
	if accept_tos:
		_open_tos()


func _open_tos():
	update_progress_label.set_text("Error: You must accept the Steam Subscriber Agreement. Opening it now.")
	Steam.activateGameOverlayToWebPage("http://steamcommunity.com/sharedfiles/workshoplegalagreement")


func _on_upload_timer_timeout():
	update_progress = Steam.getItemUpdateProgress(update_handle)
	if update_progress["total"] != 0:
		var percent = 100 * update_progress["processed"] / update_progress["total"]
		if update_progress["status"] == 2:
			update_progress_label.set_text("Uploading... (preparing) " + str(percent) + "%")
		elif update_progress["status"] == 3:
			update_progress_label.set_text("Uploading... " + str(percent) + "%")
	if update_progress["status"] == 4:
		update_progress_label.set_text("Uploading... (image)")


func _on_upload_window_close_requested():
	if update_progress_label.get_text().begins_with("Uploading..."):
		OS.alert("Uploading... Please wait.\n\nYou can cancel the upload by quitting Gamebox.", "Alert - Gamebox")
	else:
		folder_path_textedit.set_text("")
		folder_path_textedit.hide()
		image_path_textedit.set_text("")
		image_path_textedit.hide()
		item_type_button.select(1)
		update_or_new_button.select(0)
		workshop_item_id = 0
		update_handle = 0
		item_id_textedit.set_text("")
		item_id_textedit.show()
		upload_button.show()
		upload_button.set_disabled(true)
		update_progress_label.set_text("")
		upload_window.hide()


func _on_help_pressed():
	Steam.activateGameOverlayToWebPage("https://steamcommunity.com/sharedfiles/filedetails/?id=3148684231")


func _on_about_pressed():
	about_window.show()


func _on_open_changelog_pressed():
	Steam.activateGameOverlayToWebPage("https://steamcommunity.com/sharedfiles/filedetails/?id=3148694992")


func _on_about_window_close_requested():
	about_window.hide()


func _on_quit_pressed():
	get_tree().quit()
