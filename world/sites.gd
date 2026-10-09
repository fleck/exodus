class_name Sites
extends Object
## Fixed places in the first encampment. Gameplay stays on the flat
## so companions can walk; the dunes beyond are vista.

const CAMP := Vector3.ZERO
const TABERNACLE := Vector3(0, 0, -1.5)
const MARAH := Vector3(46, 0, 8)
const ROCK := Vector3(-24, 0, 28)
const HILL := Vector3(-2, 0, -58)
const VALLEY := Vector3(10, 0, -44)
const CALF := Vector3(14, 0, 10)
const RAID_SPAWN := Vector3(62, 0, -16)

const SPAWNS := {
	&"Moses": Vector3(-2.2, 0.25, 5.0),
	&"Aaron": Vector3(2.2, 0.25, 5.0),
	&"Joshua": Vector3(-3.4, 0.25, 7.4),
	&"Miriam": Vector3(3.4, 0.25, 7.4),
}
