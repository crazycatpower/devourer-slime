class_name BackdropProps
extends RefCounted
## Shared inert equipment, always seated on its own foundation.

static func draw(p: Painter, x: float, base: float, kind: int, colors: PackedColorArray) -> void:
	var dark: Color = colors[0].darkened(0.2)
	var body: Color = colors[1]
	var edge: Color = colors[2]
	# Every device meets a slab. Sizes are deliberately below the main machine.
	p.fill_rect(x - 4.0, base - 5.0, 70.0, 5.0, edge)
	match kind:
		0: # Sloped operator desk, supported screen and keyboard.
			p.fill_rect(x + 8.0, base - 57.0, 46.0, 52.0, body)
			p.fill_rect(x, base - 65.0, 62.0, 8.0, edge)
			p.fill_rect(x + 27.0, base - 78.0, 8.0, 13.0, body)
			p.fill_rect(x + 7.0, base - 108.0, 48.0, 30.0, body)
			p.fill_rect(x + 12.0, base - 103.0, 38.0, 20.0, dark)
			p.fill_rect(x + 17.0, base - 96.0, 17.0, 2.0, colors[3])
			p.fill_rect(x + 12.0, base - 62.0, 30.0, 2.0, dark)
		1: # Pump motor on brackets with inlet and outlet plumbing.
			p.fill_rect(x + 8.0, base - 21.0, 10.0, 16.0, body)
			p.fill_rect(x + 42.0, base - 21.0, 10.0, 16.0, body)
			p.fill_rect(x + 3.0, base - 52.0, 54.0, 31.0, body)
			for fin: int in 4:
				p.fill_rect(x + 12.0 + fin * 9.0, base - 48.0, 3.0, 23.0, edge)
			p.fill_rect(x + 54.0, base - 41.0, 17.0, 7.0, edge)
			p.fill_rect(x + 66.0, base - 41.0, 5.0, 36.0, edge)
		2: # Sample shelf with shelf-supported bottles, not floating pickups.
			for dx: float in [0.0, 58.0]:
				p.fill_rect(x + dx, base - 117.0, 4.0, 112.0, edge)
			for shelf: int in 3:
				var y: float = base - 12.0 - shelf * 34.0
				p.fill_rect(x, y, 62.0, 4.0, body)
				for bottle: int in 3:
					p.fill_rect(x + 10.0 + bottle * 16.0, y - 17.0, 9.0, 17.0, body)
					p.fill_rect(x + 12.0 + bottle * 16.0, y - 20.0, 5.0, 3.0, edge)
		3: # Sealed reagent or waste barrel with bands and recessed label.
			p.fill_rect(x + 7.0, base - 76.0, 48.0, 71.0, body)
			for y: float in [base - 76.0, base - 55.0, base - 16.0]:
				p.fill_rect(x + 5.0, y, 52.0, 4.0, edge)
			p.fill_rect(x + 20.0, base - 45.0, 23.0, 18.0, dark)
			p.fill_rect(x + 40.0, base - 79.0, 8.0, 3.0, edge)
		4: # Hopper/filter module seated on a four-square support frame.
			p.fill_rect(x + 3.0, base - 123.0, 56.0, 48.0, body)
			p.fill_rect(x, base - 127.0, 62.0, 4.0, edge)
			p.fill_rect(x + 12.0, base - 75.0, 38.0, 12.0, body)
			p.fill_rect(x + 24.0, base - 63.0, 14.0, 34.0, body)
			for dx: float in [5.0, 53.0]:
				p.fill_rect(x + dx, base - 75.0, 5.0, 70.0, edge)
		5: # Material spools supported on a grounded rack and axle.
			p.fill_rect(x + 2.0, base - 43.0, 5.0, 38.0, body)
			p.fill_rect(x + 55.0, base - 43.0, 5.0, 38.0, body)
			p.fill_rect(x, base - 42.0, 62.0, 4.0, edge)
			for spool: int in 2:
				var sx: float = x + 10.0 + spool * 26.0
				p.fill_rect(sx, base - 66.0, 7.0, 43.0, edge)
				p.fill_rect(sx + 16.0, base - 66.0, 6.0, 43.0, edge)
				p.fill_rect(sx + 7.0, base - 61.0, 9.0, 33.0, body)
		6: # Bank of three insulated power cells bolted to a base.
			for cell: int in 3:
				var cx: float = x + cell * 22.0
				var h: float = 88.0 - cell * 12.0
				p.fill_rect(cx, base - h, 18.0, h - 5.0, body)
				p.fill_rect(cx + 3.0, base - h - 7.0, 12.0, 7.0, edge)
				p.fill_rect(cx + 3.0, base - h + 8.0, 2.0, h - 23.0, edge)
			p.fill_rect(x + 9.0, base - 20.0, 45.0, 4.0, edge)
		7: # Service locker with recessed doors, hinge and ventilation.
			p.fill_rect(x, base - 146.0, 62.0, 141.0, body)
			p.fill_rect(x + 5.0, base - 139.0, 52.0, 127.0, dark)
			p.fill_rect(x + 30.0, base - 139.0, 2.0, 127.0, body)
			for vent: int in 3:
				p.fill_rect(x + 11.0, base - 130.0 + vent * 6.0, 13.0, 2.0, edge)
				p.fill_rect(x + 38.0, base - 130.0 + vent * 6.0, 13.0, 2.0, edge)
			p.fill_rect(x + 24.0, base - 78.0, 3.0, 11.0, edge)
			p.fill_rect(x + 36.0, base - 78.0, 3.0, 11.0, edge)
	p.fill_rect(x - 2.0, base - 2.0, 66.0, 2.0, dark)


