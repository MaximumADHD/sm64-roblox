--!strict

local TerrainType = {
	DEFAULT = 0,
	GRASS = 1,
	WATER = 2,
	STONE = 3,
	SPOOKY = 4,
	SNOW = 5,
	ICE = 6,
	SAND = 7,
	METAL = 8,
}

TerrainType.FROM_MATERIAL = {
	[Enum.Material.Mud] = TerrainType.GRASS,
	[Enum.Material.Grass] = TerrainType.GRASS,
	[Enum.Material.Ground] = TerrainType.GRASS,
	[Enum.Material.LeafyGrass] = TerrainType.GRASS,

	[Enum.Material.Ice] = TerrainType.ICE,
	[Enum.Material.Marble] = TerrainType.ICE,
	[Enum.Material.Glacier] = TerrainType.ICE,

	[Enum.Material.Wood] = TerrainType.SPOOKY,
	[Enum.Material.WoodPlanks] = TerrainType.SPOOKY,

	[Enum.Material.Foil] = TerrainType.METAL,
	[Enum.Material.Metal] = TerrainType.METAL,
	[Enum.Material.DiamondPlate] = TerrainType.METAL,
	[Enum.Material.CorrodedMetal] = TerrainType.METAL,

	[Enum.Material.Rock] = TerrainType.STONE,
	[Enum.Material.Salt] = TerrainType.STONE,
	[Enum.Material.Brick] = TerrainType.STONE,
	[Enum.Material.Slate] = TerrainType.STONE,
	[Enum.Material.Basalt] = TerrainType.STONE,
	[Enum.Material.Pebble] = TerrainType.STONE,
	[Enum.Material.Granite] = TerrainType.STONE,
	[Enum.Material.Sandstone] = TerrainType.STONE,
	[Enum.Material.Cobblestone] = TerrainType.STONE,
	[Enum.Material.CrackedLava] = TerrainType.STONE,

	[Enum.Material.Snow] = TerrainType.SNOW,
	[Enum.Material.Sand] = TerrainType.SAND,
	[Enum.Material.Water] = TerrainType.WATER,
	[Enum.Material.Fabric] = TerrainType.SNOW,
}

return TerrainType
