class_name CommunityBrowser
extends VBoxContainer

var session: Node
var service: LevelPublisher
var replay_level: Dictionary={}
var sort_order := "hot"
var search_text := ""
var cursors: Array[String]=[""]
var page := 0
var next_cursor := ""
var generation := 0
var rows: VBoxContainer
var status: Label
var previous_button: Button
var next_button: Button
var page_label: Label
var search: LineEdit
var search_timer: Timer
var records: Array=[]
var expanded := ""
var sort_buttons: Array[Button]=[]
var details_by_id: Dictionary={}
var headings: HBoxContainer
var column_widths: Dictionary={}
const NAME_COLOR := Color("9edfff")
const AUTHOR_COLOR := Color("ffd28e")
const INFO_COLOR := Color("dbc4ff")
const LIKES_COLOR := Color("a5edb3")

# A clipping container whose minimum height follows the animation instead of
# its child's full height, so neighboring rows slide down with the details.
class Reveal extends Container:
	var opened := false
	var height := 0.0:
		set(value):
			height=value
			update_minimum_size()
	var animation: Tween
	var row_style: StyleBox
	func _init() -> void:
		clip_contents=true
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _ready() -> void:
		call_deferred("watch_content")
	func watch_content() -> void:
		get_child(0).minimum_size_changed.connect(func():
			if opened: set_open(true))
	func _get_minimum_size() -> Vector2: return Vector2(0,height)
	func _notification(what: int) -> void:
		if what==NOTIFICATION_SORT_CHILDREN and get_child_count()>0:
			var child := get_child(0) as Control
			fit_child_in_rect(child,Rect2(Vector2.ZERO,Vector2(size.x,child.get_combined_minimum_size().y)))
	func set_open(open: bool, animate := true) -> void:
		opened=open
		if is_instance_valid(animation): animation.kill()
		show()
		var target: float=get_child(0).get_combined_minimum_size().y if open else 0.0
		if not animate:
			height=target
			row_style.content_margin_top=8 if open else 0
			row_style.content_margin_bottom=8 if open else 0
			visible=open
			return
		animation=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		animation.tween_property(self,"height",target,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		animation.parallel().tween_property(row_style,"content_margin_top",8.0 if open else 0.0,0.22)
		animation.parallel().tween_property(row_style,"content_margin_bottom",8.0 if open else 0.0,0.22)
		if not open: animation.tween_callback(hide)

static func menu_button(text: String, callback: Callable) -> Button:
	var button := LevelEditorUI.button(text,callback)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return button

func _ready() -> void:
	custom_minimum_size.x=minf(720 if replay_level.is_empty() else 840,get_viewport_rect().size.x-56)
	add_theme_constant_override("separation",0)
	if not replay_level.is_empty():
		add_child(menu_button("Back to levels",func(): session.show_menu()))
	else:
		var sorts := GridContainer.new()
		sorts.columns=6 if custom_minimum_size.x>=600 else 3
		sorts.add_theme_constant_override("h_separation",0)
		sorts.add_theme_constant_override("v_separation",0)
		add_child(sorts)
		var labels := ["Hot","No Completions","Top Today","Top Week","Top Month","Top Year"]
		var values := ["hot","uncompleted","today","week","month","year"]
		for i in labels.size():
			var order: String=values[i]
			var button := menu_button(labels[i],func():
				sort_order=order
				refresh(true))
			button.toggle_mode=true
			button.set_meta("sort",order)
			sorts.add_child(button)
			sort_buttons.append(button)
		search=LineEdit.new()
		search.placeholder_text="Search by puzzle name or author"
		search.max_length=100
		search.text=search_text
		add_child(search)
		search_timer=Timer.new()
		search_timer.wait_time=0.25
		search_timer.one_shot=true
		add_child(search_timer)
		search_timer.timeout.connect(func(): refresh(true))
		search.text_changed.connect(func(value: String):
			search_text=value
			generation+=1
			search_timer.start())
	status=Label.new()
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var list_padding := MarginContainer.new()
	list_padding.name="ListPadding"
	list_padding.add_theme_constant_override("margin_top",8)
	list_padding.add_theme_constant_override("margin_bottom",8)
	add_child(list_padding)
	var list_content := VBoxContainer.new()
	list_content.add_theme_constant_override("separation",0)
	list_padding.add_child(list_content)
	var heading_padding := MarginContainer.new()
	heading_padding.add_theme_constant_override("margin_left",8)
	heading_padding.add_theme_constant_override("margin_right",8)
	heading_padding.add_theme_constant_override("margin_top",8)
	heading_padding.add_theme_constant_override("margin_bottom",8)
	list_content.add_child(heading_padding)
	headings=HBoxContainer.new()
	headings.add_theme_constant_override("separation",8)
	heading_padding.add_child(headings)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y=clampf(get_viewport_rect().size.y-320,100,300)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	list_content.add_child(scroll)
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.resized.connect(func(): heading_padding.add_theme_constant_override("margin_right",8+roundi(scrollbar.size.x)))
	rows=VBoxContainer.new()
	rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",0)
	scroll.add_child(rows)
	var paging := HBoxContainer.new()
	paging.add_theme_constant_override("separation",0)
	paging.alignment=BoxContainer.ALIGNMENT_CENTER
	add_child(paging)
	var page_padding := MarginContainer.new()
	page_padding.add_theme_constant_override("margin_left",8)
	page_padding.add_theme_constant_override("margin_right",8)
	paging.add_child(page_padding)
	page_label=Label.new()
	page_padding.add_child(page_label)
	previous_button=menu_button("Previous",func():
		page=maxi(0,page-1)
		refresh())
	paging.add_child(previous_button)
	next_button=menu_button("Next",func():
		cursors.resize(page+1)
		cursors.append(next_cursor)
		page+=1
		refresh())
	paging.add_child(next_button)
	paging.add_child(menu_button("Refresh",func(): refresh(true)))
	rebuild_headings()
	refresh()

func refresh(reset := false) -> void:
	if reset:
		page=0
		cursors=[""]
	for button in sort_buttons: button.button_pressed=button.get_meta("sort")==sort_order
	session.browser_state={"sort":sort_order,"search":search_text}
	generation+=1
	var request_generation := generation
	status.text="Loading..."
	status.show()
	previous_button.disabled=true
	next_button.disabled=true
	clear_rows()
	var result: Dictionary
	if replay_level.is_empty(): result=await service.list_levels(sort_order,search_text,cursors[page])
	else: result=await service.list_replays(str(replay_level.id),cursors[page])
	if not is_inside_tree() or generation!=request_generation: return
	page_label.text="Page %d"%(page+1)
	previous_button.disabled=page==0
	if result.has("error"):
		status.text=str(result.error)
		return
	records=result.get("levels" if replay_level.is_empty() else "replays",[])
	next_cursor=str(result.get("cursor",""))
	next_button.disabled=next_cursor.is_empty()
	status.text="No levels found." if records.is_empty() and replay_level.is_empty() else "No replays yet." if records.is_empty() else ""
	status.visible=not status.text.is_empty()
	rebuild_rows()

func clear_rows() -> void:
	details_by_id.clear()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

func rebuild_rows() -> void:
	clear_rows()
	rebuild_headings()
	for record in records:
		if not record is Dictionary: continue
		var item: Dictionary=record
		var panel := PanelContainer.new()
		var row_style := StyleBoxEmpty.new()
		row_style.set_content_margin_all(0)
		panel.add_theme_stylebox_override("panel",row_style)
		rows.add_child(panel)
		var contents := VBoxContainer.new()
		contents.add_theme_constant_override("separation",0)
		panel.add_child(contents)
		var header := menu_button("",func():
			if not replay_level.is_empty(): launch_replay(item)
			else: toggle_details(str(item.id)))
		header.custom_minimum_size.y=ceilf(get_theme_font("font","Button").get_height(get_theme_font_size("font_size","Button")))+16
		contents.add_child(header)
		var line := HBoxContainer.new()
		line.mouse_filter=Control.MOUSE_FILTER_IGNORE
		header.add_child(line)
		line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		line.offset_left=8
		line.offset_top=8
		line.offset_right=-8
		line.offset_bottom=-8
		line.add_theme_constant_override("separation",8)
		if replay_level.is_empty():
			add_field(line,str(item.get("name","Puzzle")),NAME_COLOR,1.2)
			add_field(line,str(item.get("author","Anonymous")),AUTHOR_COLOR,0.8)
			add_field(line,str(maxi(0,int(item.get("plays",0)))),INFO_COLOR,0,column_widths.plays).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			add_field(line,str(maxi(0,int(item.get("likes",0)))),LIKES_COLOR,0,column_widths.likes).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		else:
			add_field(line,str(item.get("author","Anonymous")),AUTHOR_COLOR,0,140)
			add_field(line,str(item.get("comment","")),INFO_COLOR,1,column_widths.comment)
			add_field(line,format_time(float(item.get("time",0))),LIKES_COLOR,0,column_widths.time).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		if replay_level.is_empty():
			var reveal := Reveal.new()
			reveal.row_style=row_style
			reveal.name="Details"
			contents.add_child(reveal)
			details_by_id[str(item.id)]=reveal
			var box := PanelContainer.new()
			box.name="Box"
			var style := get_theme_stylebox("panel","PanelContainer").duplicate() as StyleBoxFlat
			style.set_content_margin_all(0)
			box.add_theme_stylebox_override("panel",style)
			reveal.add_child(box)
			var info := VBoxContainer.new()
			info.name="Contents"
			info.add_theme_constant_override("separation",0)
			box.add_child(info)
			var description_padding := MarginContainer.new()
			for side in ["left","top","right","bottom"]: description_padding.add_theme_constant_override("margin_"+side,8)
			info.add_child(description_padding)
			var description := Label.new()
			description.text=str(item.get("description",""))
			description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			description.add_theme_color_override("font_color",Color("dbc4ff"))
			description_padding.add_child(description)
			var actions := HBoxContainer.new()
			actions.name="Actions"
			actions.add_theme_constant_override("separation",0)
			info.add_child(actions)
			actions.add_child(menu_button("Play",func(): launch_level(item,false)))
			actions.add_child(menu_button("Replays",func(): session.show_menu(item)))
			if service.owned_ids.has(str(item.id)):
				actions.add_child(menu_button("Edit",func(): confirm_edit(item)))
				actions.add_child(menu_button("Delete",func(): confirm_delete(item,info)))
			reveal.call_deferred("set_open",expanded==str(item.id),false)

func toggle_details(id: String) -> void:
	expanded="" if expanded==id else id
	for key in details_by_id:
		if details_by_id[key].opened!=(key==expanded): details_by_id[key].set_open(key==expanded)

func rebuild_headings() -> void:
	for child in headings.get_children():
		headings.remove_child(child)
		child.queue_free()
	var font := get_theme_font("font","Label")
	var font_size := get_theme_font_size("font_size","Label")
	column_widths={"plays":font.get_string_size("Plays",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,"likes":font.get_string_size("Likes",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,"time":font.get_string_size("00:00.00",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x,"comment":font.get_string_size("W".repeat(ReplayTrack.MAX_COMMENT_LENGTH),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x}
	for item in records:
		if not item is Dictionary: continue
		for key in ["plays","likes"]:
			column_widths[key]=maxf(column_widths[key],font.get_string_size(str(maxi(0,int(item.get(key,0)))),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
		column_widths.time=maxf(column_widths.time,font.get_string_size(format_time(float(item.get("time",0))),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
		var comment := str(item.get("comment",""))
		if comment.length()<=ReplayTrack.MAX_COMMENT_LENGTH:
			column_widths.comment=maxf(column_widths.comment,font.get_string_size(comment,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
	if replay_level.is_empty():
		add_field(headings,"Name",NAME_COLOR,1.2)
		add_field(headings,"Author",AUTHOR_COLOR,0.8)
		add_field(headings,"Plays",INFO_COLOR,0,column_widths.plays).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		add_field(headings,"Likes",LIKES_COLOR,0,column_widths.likes).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	else:
		add_field(headings,"Author",AUTHOR_COLOR,0,140)
		add_field(headings,"Comment",INFO_COLOR,1,column_widths.comment)
		add_field(headings,"Time",LIKES_COLOR,0,column_widths.time).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func add_field(line: HBoxContainer, text: String, color: Color, stretch: float, width := 0.0) -> Label:
	var label := Label.new()
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.text=text
	label.tooltip_text=text
	label.add_theme_color_override("font_color",color)
	label.custom_minimum_size.x=ceilf(width)
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	if stretch>0:
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio=stretch
		label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	line.add_child(label)
	return label

func confirm_edit(item: Dictionary) -> void:
	var warning := LevelEditorUI.modal(session,session.current_color(),"Warning!\n\nEditing your level will reset likes and remove all replays.",{})
	LevelEditorUI.compact_buttons(warning)
	warning.actions.add_theme_constant_override("separation",0)
	var dismiss := func():
		session.remove_child(warning)
		warning.queue_free()
	warning.cancel_action=dismiss
	warning.actions.add_child(menu_button("Back",dismiss))
	warning.actions.add_child(menu_button("Continue",func():
		dismiss.call()
		launch_level(item,true)))

func launch_level(item: Dictionary, editing: bool) -> void:
	status.text="Loading puzzle..."
	status.show()
	var result := await service.get_level(str(item.id))
	if not is_inside_tree(): return
	if result.has("error"):
		status.text=str(result.error)
		return
	if LevelEditorCodec.decode(str(result.get("levelString",""))).is_empty():
		status.text="This puzzle code is invalid."
		return
	result.name=item.get("name","Puzzle")
	session.enter_community(result,"",editing)

func launch_replay(item: Dictionary) -> void:
	status.text="Loading replay..."
	status.show()
	var result := await service.get_replay(str(item.id))
	if not is_inside_tree(): return
	if result.has("error"):
		status.text=str(result.error)
		return
	var track := ReplayTrack.decode(str(result.get("replayString","")))
	if track.is_empty():
		status.text="This replay is invalid or uses an unsupported version."
		return
	var entry := replay_level.duplicate(true)
	entry.levelString=track.l
	session.enter_community(entry,str(result.replayString))

func confirm_delete(item: Dictionary, contents: VBoxContainer) -> void:
	var confirmation := HBoxContainer.new()
	confirmation.add_theme_constant_override("separation",0)
	contents.add_child(confirmation)
	var label := Label.new()
	label.text="Delete this puzzle and its replays?"
	confirmation.add_child(label)
	var confirm := menu_button("Delete",func():
		confirmation.hide()
		status.text="Deleting..."
		status.show()
		var result := await service.delete_level(str(item.id))
		if not is_inside_tree(): return
		if result.has("error"): status.text=str(result.error)
		else: refresh(true))
	confirmation.add_child(confirm)
	confirmation.add_child(menu_button("Cancel",func(): confirmation.queue_free()))

static func format_time(seconds: float) -> String:
	return "%d:%05.2f"%[int(seconds)/60,fmod(seconds,60.0)]
