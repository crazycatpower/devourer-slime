extends "res://tools/capture/world5_manual.gd"

func _ready() -> void:
	OUT="res://build/recordings/world5"
	stage=50
	var best_count: int=-1
	for mode: int in 100:
		var sim: Recorder=fresh()
		if FileAccess.file_exists(OUT+"/boss_best.json"):
			var rr: ReplayInput=ReplayInput.new()
			rr.sim=sim
			rr.frames=JSON.parse_string(FileAccess.get_file_as_string(OUT+"/boss_best.json"))
			for i: int in rr.frames.size(): sim.step(rr.sample(Vector2.ZERO))
			best_count=maxi(best_count,sim.boss.filled_count())
		for warm: int in floori(float(mode)/3)%6*12:
			var warm_in: SimInput=SimInput.new()
			warm_in.left=mode%3==0
			warm_in.right=mode%3==2
			warm_in.jump=mode%2==0
			warm_in.jump_pressed=warm==0 and warm_in.jump
			sim.step(warm_in)
		var previous_jump: bool=false
		var jump_ticks: int=0
		var maximum: int=0
		for tick: int in 18000:
			var b: BossState=sim.boss
			var p: PlayerState=sim.player
			var center: Vector2=Vector2(p.center_x(),p.center_y())
			var bc: Vector2=Vector2(b.center_x(),b.center_y())
			var side: float=-1.0 if center.x<bc.x else 1.0
			var distance: float=160.0+float(mode%7)*30
			var tx: float=bc.x+side*distance
			var aim: Vector2=bc
			var inp: SimInput=SimInput.new()
			var nearest: float=INF
			var ammo: Vector2=Vector2.ZERO
			if not p.has_block and not b.is_filled():
				for r: int in sim.level.rows:
					for c: int in range(maxi(1,floori(p.x/40)-10),mini(sim.level.cols-1,floori(p.x/40)+11)):
						if not Tile.is_eatable(sim.level.get_cell(r,c)): continue
						var point: Vector2=Vector2(c*40+20,r*40+20)
						var cost: float=center.distance_to(point)
						if cost<nearest:
							nearest=cost
							ammo=point
				if nearest<INF:
					aim=ammo
					tx=ammo.x+(35 if center.x>ammo.x else -35)
					inp.eat=true
			if p.has_block:
				var best_aim: float=INF
				for r: int in 3:
					for c: int in 3:
						if b.cell(r,c)!=0 or not b.has_occupied_neighbor(r,c): continue
						var point: Vector2=Vector2(b.x+c*40+20,b.y+r*40+20)
						var cost: float=center.distance_to(point)+float(r)*(10 if mode<20 else -10)
						for step_i: int in range(1,20):
							var test_point: Vector2=center.lerp(point,float(step_i)/20)
							var cr: int=floori((test_point.y-b.y)/40)
							var cc: int=floori((test_point.x-b.x)/40)
							if cr>=0 and cr<3 and cc>=0 and cc<3 and b.cell(cr,cc)!=0: cost+=500
						if cost<best_aim:
							best_aim=cost
							aim=point
				if best_aim>450:
					tx=bc.x+(160 if aim.x>=bc.x else -160)
					if p.grounded: jump_ticks=40
				var flight: float=center.distance_to(aim)/12
				aim.x+=b.vx*flight*(float(mode%4)/3)
				aim.y-=flight*flight*0.12
				inp.shoot_released=tick%8==0 and not p.waiting_for_shoot_release and best_aim<450
			if absf(center.x-bc.x)<150 and not b.is_filled() and b.y+b.h>p.y-60:
				tx=bc.x+side*280
			if b.is_filled() or b.eating_progress>0:
				aim=bc
				tx=bc.x+side*110
				inp.eat=true
			if b.dead:
				for r: int in sim.level.rows:
					for c: int in sim.level.cols:
						if sim.level.get_cell(r,c)==Tile.GOAL:
							tx=c*40+3
			for fb: SimFallingBlock in sim.falling_blocks:
				if fb.lethal and absf(center.x-fb.x)<45 and fb.y<center.y and fb.delay<20:
					tx=center.x+(80 if center.x>fb.x else -80)
			inp.right=p.x<tx-6
			inp.left=p.x>tx+6
			var ahead: float=p.x+p.w+3 if inp.right else p.x-3
			var blocked: bool=Tile.is_solid(sim.level.get_cell(floori((p.y+p.h-2)/40),floori(ahead/40)))
			if blocked and p.grounded: jump_ticks=40
			jump_ticks=maxi(0,jump_ticks-1)
			inp.jump=(jump_ticks>0) or (mode%2==1 and tick%90<35) or (b.dead and tick%70<35)
			inp.jump_pressed=inp.jump and not previous_jump
			previous_jump=inp.jump
			inp.mouse_x=aim.x-sim.camera.x
			inp.mouse_y=aim.y-sim.camera.y
			sim.step(inp)
			maximum=maxi(maximum,b.filled_count())
			if maximum>best_count:
				best_count=maximum
				print("BOSS BEST ",best_count," mode=",mode," tick=",tick," player=",Vector2(p.x,p.y))
				FileAccess.open(OUT+"/boss_best.json",FileAccess.WRITE).store_string(JSON.stringify(sim.frames))
			if p.dead or p.won: break
		print("BOSS mode=",mode," max=",maximum," frames=",sim.frames.size()," dead=",sim.player.dead," pos=",Vector2(sim.player.x,sim.player.y)," boss=",Vector2(sim.boss.x,sim.boss.y)," state=",sim.boss.state)
		if save_win(sim):
			get_tree().quit()
			return
	get_tree().quit(1)
