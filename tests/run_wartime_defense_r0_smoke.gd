# Compatibility entry point. Current defense behavior is the spatial R1 flow.
extends "res://tests/run_wartime_spatial_r1_smoke.gd"

func use_defense() -> bool:
	return true
