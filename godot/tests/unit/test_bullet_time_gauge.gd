extends TestCase
## The budget of slow motion while aiming.

const FRAME: float = 1.0 / 60.0


func test_a_full_gauge_buys_three_seconds() -> void:
	var gauge: BulletTimeGauge = BulletTimeGauge.new()
	var slow_frames: int = 0
	for _i: int in 600:
		if gauge.spend(true, FRAME):
			slow_frames += 1
	check(absi(slow_frames - int(BulletTimeGauge.FULL_SECONDS * 60.0)) <= 1, "%d slow frames" % slow_frames)
	check_near(gauge.energy, 0.0)


func test_an_empty_gauge_does_not_flicker_back_on_during_the_same_hold() -> void:
	var gauge: BulletTimeGauge = BulletTimeGauge.new()
	for _i: int in 400:
		gauge.spend(true, FRAME)
	check(not gauge.spend(true, FRAME), "still holding: time runs at full speed")
	check_near(gauge.energy, 0.0, 1e-9, "and nothing refills while aiming")


func test_it_refills_when_not_aiming_and_can_be_used_part_full() -> void:
	var gauge: BulletTimeGauge = BulletTimeGauge.new()
	for _i: int in 400:
		gauge.spend(true, FRAME)
	for _i: int in 60:
		check(not gauge.spend(false, FRAME))
	check_near(gauge.energy, 1.0 / BulletTimeGauge.REFILL_SECONDS, 0.01, "a second of rest")
	check(gauge.spend(true, FRAME), "a part-full gauge works again after letting go")
	for _i: int in 600:
		gauge.spend(false, FRAME)
	check_near(gauge.energy, 1.0, 1e-9, "never more than full")


func test_refill_restores_everything() -> void:
	var gauge: BulletTimeGauge = BulletTimeGauge.new()
	for _i: int in 400:
		gauge.spend(true, FRAME)
	gauge.refill()
	check_near(gauge.energy, 1.0)
	check(gauge.spend(true, FRAME))
