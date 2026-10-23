class_name RailAudit
extends RefCounted

static func inspect(root: Node) -> Dictionary:
	var report={"passed":true,"overflow":[],"overlap":[],"buttons":0,"groups":{}}
	_walk(root,Rect2(-100000,-100000,200000,200000),report)
	for key in report.groups:
		var entries=report.groups[key]
		for i in entries.size():
			for j in range(i+1,entries.size()):
				if entries[i].rect.intersects(entries[j].rect): report.overlap.append([entries[i].text,entries[j].text])
	report.erase("groups"); report.passed=report.overflow.is_empty() and report.overlap.is_empty()
	return report

static func _walk(node: Node, clipping: Rect2, report: Dictionary):
	if node is Control:
		if not node.is_visible_in_tree(): return
		var rect=node.get_global_rect()
		if node is BaseButton:
			var visible_part=rect.intersection(clipping)
			if visible_part.has_area():
				report.buttons+=1
				if not Rect2(-0.5,-0.5,1921,1081).encloses(visible_part): report.overflow.append({"path":str(node.get_path()),"rect":str(visible_part)})
			if node.has_meta("avoid_overlap"):
				var key=node.get_meta("avoid_overlap")
				if not report.groups.has(key): report.groups[key]=[]
				report.groups[key].append({"text":node.text,"rect":rect})
		if node.clip_contents or node is ScrollContainer: clipping=clipping.intersection(rect)
	for child in node.get_children(): _walk(child,clipping,report)
