extends RefCounted
func board() -> Dictionary:
	var data := {"v":1,"grid":[80,45,16],"tiles":[],"objects":[[1,40.0,153.0],[2,120.0,152.0,0,0.2,0.15],[3,168.0,152.0,0,"A"],[4,232.0,152.0,1,"A"]]}
	for x in 80: data.tiles.append([x,10])
	return data
