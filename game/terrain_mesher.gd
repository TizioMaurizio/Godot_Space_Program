class_name TerrainMesher
extends RefCounted

static func globe(planet: PlanetDefinition, resolution: int = 48, scale: float = 0.001) -> ArrayMesh:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
	for axis in faces:
		var u: Vector3 = axis.cross(Vector3.UP).normalized()
		if u.length_squared() < 0.1: u = axis.cross(Vector3.BACK).normalized()
		var v: Vector3 = axis.cross(u)
		for y in range(resolution):
			for x in range(resolution):
				for corner in [Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x+1,y),Vector2i(x,y),Vector2i(x,y+1),Vector2i(x+1,y+1)]:
					var n := DVector.from_vec(axis+u*(2.0*corner.x/resolution-1)+v*(2.0*corner.y/resolution-1)).unit()
					var h: float = SurfaceQuery.height_fixed(planet,n)
					surface.set_normal(n.vec()); surface.set_uv(Vector2(n.x,n.y)); surface.set_uv2(Vector2(h,n.z))
					surface.add_vertex(n.scaled((planet.radius+h)*scale).vec())
	if planet.terrain != null and planet.terrain.style == "lunar": surface.generate_normals()
	return surface.commit()

static func tile(planet: PlanetDefinition, focus: DVec3, east: DVec3, north: DVec3, origin: Vector2, size: float, water: bool = false) -> Dictionary:
	var resolution: int = 16
	var center := focus.scaled(planet.radius).plus(east.scaled(origin.x+size*0.5)).plus(north.scaled(origin.y+size*0.5)).unit()
	var anchor := center.scaled(planet.radius+(planet.ocean.sea_level if water and planet.ocean != null else SurfaceQuery.height_fixed(planet,center)))
	var positions: Array[Vector3] = []; var directions: Array[DVec3] = []; var heights: Array[float] = []
	for y in range(resolution+1):
		for x in range(resolution+1):
			var n := focus.scaled(planet.radius).plus(east.scaled(origin.x+size*x/resolution)).plus(north.scaled(origin.y+size*y/resolution)).unit()
			var h: float = planet.ocean.sea_level if water and planet.ocean != null else SurfaceQuery.height_fixed(planet,n)
			positions.append(n.scaled(planet.radius+h).minus(anchor).vec()); directions.append(n); heights.append(SurfaceQuery.height_fixed(planet,n) if water else h)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(resolution):
		for x in range(resolution):
			for corner in [Vector2i(x,y),Vector2i(x+1,y+1),Vector2i(x+1,y),Vector2i(x,y),Vector2i(x,y+1),Vector2i(x+1,y+1)]:
				var index: int = corner.y*(resolution+1)+corner.x
				var dx: Vector3 = positions[corner.y*(resolution+1)+mini(corner.x+1,resolution)]-positions[corner.y*(resolution+1)+maxi(corner.x-1,0)]
				var dz: Vector3 = positions[mini(corner.y+1,resolution)*(resolution+1)+corner.x]-positions[maxi(corner.y-1,0)*(resolution+1)+corner.x]
				var n: DVec3 = directions[index]
				surface.set_normal(n.vec() if water else dx.cross(dz).normalized())
				surface.set_uv(Vector2(n.x,n.y)); surface.set_uv2(Vector2(heights[index],n.z)); surface.add_vertex(positions[index])
	# Downward edge skirts cover LOD T-junctions; they are never collision authority.
	if not water:
		for edge in range(4):
			for i in range(resolution):
				var a: int; var b: int
				match edge:
					0: a=i; b=i+1
					1: a=resolution*(resolution+1)+i; b=a+1
					2: a=i*(resolution+1); b=(i+1)*(resolution+1)
					3: a=i*(resolution+1)+resolution; b=(i+1)*(resolution+1)+resolution
				var drop: float = clampf(size/16,2,200)
				for item in [[a,false],[b,true],[b,false],[a,false],[a,true],[b,true]]:
					var index: int = item[0]; var n: DVec3 = directions[index]
					surface.set_normal(n.vec()); surface.set_uv(Vector2(n.x,n.y)); surface.set_uv2(Vector2(heights[index],n.z))
					surface.add_vertex(positions[index]-n.vec()*drop if item[1] else positions[index])
	return {"mesh":surface.commit(),"anchor":anchor}
