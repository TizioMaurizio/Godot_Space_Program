class_name LegacyVehicleConverter
extends RefCounted
## The shipped .tres is retained as a regression fixture. New designs use CraftDesign.
## Reject modified legacy inputs explicitly instead of silently ignoring their data.
static func convert(config: VehicleDefinition) -> CraftDesign:
	var design := CraftCodec.load_craft("res://data/craft/orbital_test_vehicle.json")
	if config.stages.size() != 2 or absf(config.wet_mass()-float(CraftAnalysis.analyze(design).mass)) > 1e-6:
		push_error("Legacy vehicle differs from the migrated OTV; define it as a CraftDesign.")
		return null
	var pairs := [["tank.forge","engine.forge"],["tank.lumen","engine.lumen"]]
	for i in range(2):
		var old: StageDefinition = config.stages[i]
		var tank: Dictionary = PartCatalog.get_part(pairs[i][0]).modules.tank
		var engine: Dictionary = PartCatalog.get_part(pairs[i][1]).modules.engine
		if absf(old.fuel_mass-float(tank.fuel)) > 1e-6 or absf(old.oxidizer_mass-float(tank.oxidizer)) > 1e-6 or old.engine.vacuum_thrust != engine.thrust or old.engine.sea_level_isp != engine.isp_sl or old.engine.vacuum_isp != engine.isp_vac:
			push_error("Legacy propulsion differs from the migrated OTV; update the part catalog/design.")
			return null
	return design
