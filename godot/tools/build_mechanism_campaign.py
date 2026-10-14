"""Build the explicitly commissioned World 6–10 stages and input routes.

The original campaign, designer exports and all boss rooms are left intact.
Every blueprint below has a named lesson and a route replayed by Godot tests.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SLOTS, ROUTES, LESSONS = {}, {}, {}
RIGHT, LEFT, UP, DOWN = 9, 14, 17, 18


class Room:
    def __init__(self, slot, name, hint, width=30, height=15):
        self.slot, self.width, self.height = slot, width, height
        self.a = [["@" if r in (0, height-1) or c in (0, width-1) else "."
                   for c in range(width)] for r in range(height)]
        self.wires, self.sensors, self.rails, self.route = set(), set(), {}, []
        self.gates = []
        self.expected_sensors = None
        self.put(13, 2, "P")
        self.put(13, width-3, "$")
        LESSONS[str(slot)] = {"name": name, "hint": hint}

    def put(self, r, c, tile):
        self.a[r][c] = tile

    def rect(self, r1, c1, r2, c2, tile):
        for r in range(r1, r2+1):
            for c in range(c1, c2+1):
                self.put(r, c, tile)

    def start(self, c, r):
        for line in self.a:
            for x, tile in enumerate(line):
                if tile == "P":
                    line[x] = "."
        self.put(r, c, "P")

    def goal(self, c, r):
        for line in self.a:
            for x, tile in enumerate(line):
                if tile == "$":
                    line[x] = "."
        self.put(r, c, "$")

    def wire(self, *points):
        for (x, y), (xx, yy) in zip(points, points[1:]):
            assert x == xx or y == yy
            self.wires.update((c, y) for c in range(min(x, xx), max(x, xx)+1))
            self.wires.update((xx, r) for r in range(min(y, yy), max(y, yy)+1))

    def rail(self, *points):
        cells = []
        for (x, y), (xx, yy) in zip(points, points[1:]):
            assert x == xx or y == yy
            dx, dy = (xx > x)-(xx < x), (yy > y)-(yy < y)
            while (x, y) != (xx, yy):
                cells.append((x, y))
                x, y = x+dx, y+dy
        cells.append(points[-1])
        for i, cell in enumerate(cells):
            nxt = cells[min(i+1, len(cells)-1)]
            dx, dy = nxt[0]-cell[0], nxt[1]-cell[1]
            self.rails[cell] = RIGHT if dx > 0 else LEFT if dx < 0 else UP if dy < 0 else DOWN
        return len(cells)

    def walk(self, c):
        self.route.append({"op": "walk", "x": c*40+3})

    def jump(self, c):
        self.route.append({"op": "jump", "x": c*40+3})

    def eat(self, c, r=13):
        self.route.append({"op": "eat", "c": c, "r": r})

    def shoot(self, c, r=13):
        self.route.append({"op": "shoot", "c": c, "r": r})

    def wait(self, ticks):
        self.route.append({"op": "wait", "ticks": ticks})

    def brake(self):
        self.route.append({"op": "brake"})

    def pocket(self, c, r=13):
        self.sensors.add((c, r))
        self.put(r, c+1, "@")

    def lift_gate(self, c):
        self.gates.append(c)
        # Low approach ceiling prevents jumping over the receiver.
        self.rect(1, c, 8, c, "@")
        self.rect(12, c-2, 12, c+2, "@")
        self.put(12, c, ".")
        self.put(13, c, "X")
        self.rail((c, 13), (c, 9))

    def glass_gate(self, c, tnt=False):
        self.gates.append(c)
        self.rect(1, c, 13, c, "X")
        if tnt:
            self.put(13, c, "T")

    def finish(self, goal_c=None):
        self.route.append({"op": "verify", "open_gates": self.gates, "covered": sorted(map(list, self.sensors if self.expected_sensors is None else self.expected_sensors)),
                           "spent_tnt": [[c, r] for r, row in enumerate(self.a) for c, tile in enumerate(row) if tile == "T"]})
        if goal_c is not None:
            self.walk(goal_c)
        doc = {"rows": ["".join(row) for row in self.a],
               "wires": sorted(map(list, self.wires)),
               "sensors": sorted(map(list, self.sensors)),
               "rails": [[x, y, t] for (x, y), t in sorted(self.rails.items())]}
        SLOTS[str(self.slot)] = doc
        ROUTES[str(self.slot)] = self.route


# World 6: a visible source, wires and receivers; later stages compose circuits.
for n, (name, hint) in enumerate([
    ("壓住才通電", "吞下泥土，吐進綠色感測器；玻璃門會被抬起"),
    ("遠方的接收端", "沿著連線找接收端；信號可以穿過鋼鐵地形"),
    ("一個開關兩扇門", "同一個感測器可以控制兩個接收端"),
    ("落砂開關", "吞下沙子下方的泥土，讓沙子落到感測器上"),
    ("上下繞線", "線路轉彎仍能傳遞信號；先觀察完整連線"),
    ("左右分路", "兩個感測器各控制一扇門，分別放入覆蓋方塊"),
    ("落砂雙開關", "先讓落砂啟動第一路，再吐出沙子覆蓋另一個感測器"),
    ("搬運與再覆蓋", "先把貨物運到站，再吞下貨物啟動另一條獨立電路"),
    ("電路總測試", "先運送貨物，再依序啟動兩條彼此分離的開門電路"),
], 1):
    l = Room(50+n, name, hint, 42 if n == 9 else 29+n)

    if n in (7, 8, 9):
        if n == 7:
            l.sensors.add((5, 13)); l.put(11, 5, "A"); l.put(12, 5, "#")
            l.lift_gate(12); l.wire((5, 13), (5, 14), (12, 14), (12, 13))
            l.walk(4); l.eat(5, 12); l.shoot(3, 5); l.wait(70)
            l.put(13, 17, "A"); l.pocket(18); l.lift_gate(24)
            l.wire((18, 13), (18, 14), (24, 14), (24, 13))
            l.walk(16); l.eat(17); l.shoot(18)
        else:
            l.pocket(5); l.put(13, 4, "#")
            l.put(13, 9, "#"); l.rail((9, 13), (15, 13))
            l.wire((5, 13), (5, 14), (9, 14), (9, 13))
            l.pocket(19); l.lift_gate(25)
            l.wire((19, 13), (19, 14), (25, 14), (25, 13))
            l.walk(3); l.eat(4); l.shoot(5); l.wait(100)
            l.walk(14); l.eat(15); l.walk(17); l.shoot(19)
            if n == 9:
                l.put(13, 28, "#"); l.pocket(29); l.lift_gate(36)
                l.wire((29, 13), (29, 14), (36, 14), (36, 13))
                l.walk(27); l.eat(28); l.shoot(29)
        l.wait(70); l.finish(l.width-3)
        continue
    source = 5
    l.pocket(source)
    if n == 4:
        l.put(11, 5, "A"); l.put(12, 5, "#")
        l.walk(4); l.eat(5, 12)
    else:
        l.put(13, 4, "#")
        l.walk(3); l.eat(4); l.shoot(5)
    gate = 12
    l.lift_gate(gate)
    if n in (2, 5):
        l.wire((5, 13), (5, 10), (9, 10), (9, 8), (gate, 8), (gate, 9))
    else:
        l.wire((5, 13), (5, 14), (gate, 14), (gate, 13))
    if n == 3:
        l.lift_gate(22)
        l.wire((12, 14), (22, 14), (22, 13))
    if n == 6:
        second = 18
        l.pocket(second)
        l.put(13, second-1, "#")
        l.lift_gate(second+6)
        l.wire((second, 13), (second, 14), (second+6, 14), (second+6, 13))
        l.walk(second-2); l.eat(second-1); l.shoot(second)
    l.wait(72)
    l.finish(l.width-3)


# World 7: floor control, projectile sliding and the ceiling variant.
ice_names = ["冰上起步", "提早煞車", "冰彈開路", "雪地斷橋", "天花板滑行", "滑動的砝碼", "冰階攀登", "高處接收端", "冰面與頂棚"]
ice_hints = ["冰面加速與煞車都比較慢，先在安全地面練習", "越過冰面障礙前先控制速度", "吞下冰塊再吐出，打碎擋路玻璃", "先在冰面加速，再跳過尖刺區", "射擊貼著天花板的冰，讓它滑到遠方感測器", "把泥土吐向冰面，讓它滑進感測器", "持有冰時普通地面也很滑，提早轉向", "沿頂棚移動的冰可以控制地面的門", "先處理頂棚開關，再使用冰彈打開最後一道玻璃"]
for n in range(1, 10):
    l = Room(60+n, ice_names[n-1], ice_hints[n-1], 29+n)
    if n in (5, 8, 9):
        l.start(2, 4)
        l.rect(5, 1, 13, 6, "@")
        l.put(4, 4, "#")
        end = 15 if n == 5 else 18
        l.rect(3, 7, 3, end, "@")
        l.put(4, 7, "I"); l.put(4, end+1, "@")
        l.sensors.add((end, 4))
        l.lift_gate(24)
        l.wire((end, 4), (24, 4), (24, 9))
        l.walk(3); l.eat(4, 4); l.shoot(7, 4); l.wait(130)
        if n == 9:
            l.put(13, 27, "I"); l.glass_gate(32)
            l.walk(26); l.eat(27); l.walk(29); l.shoot(32)
    elif n == 6:
        l.put(13, 4, "#")
        l.rect(14, 7, 14, 17, "I")
        l.pocket(17)
        l.lift_gate(25)
        l.wire((17, 13), (17, 14), (25, 14), (25, 13))
        l.walk(3); l.eat(4); l.walk(8); l.shoot(11, 14); l.wait(130)
    elif n in (3, 7):
        l.put(13, 4, "I")
        l.glass_gate(13)
        l.walk(3); l.eat(4); l.walk(9); l.shoot(13)
        if n == 7:
            l.rect(12, 19, 13, 21, "I")
            l.rect(10, 25, 13, l.width-2, "@")
            l.goal(l.width-3, 9)
            l.walk(17); l.jump(20); l.walk(20); l.jump(27)
    else:
        l.rect(14, 6, 14, 17+n, "I")
        if n == 2:
            l.put(13, 13, "@")
            l.walk(10); l.jump(16)
        if n == 4:
            l.rect(13, 15, 13, 17, "~")
            l.walk(13); l.jump(22)
    l.finish(l.width-3)


# World 8: settling sand, removing support, digging and signal weight.
sand_names = ["落砂成階", "砂橋", "挖開沙堆", "失去支撐", "砂粒感測", "尖刺會碎砂", "填補虛空", "貨運沙梯", "流砂總測試"]
sand_hints = ["等待沙子落地堆積，再利用沙階登上終點", "落砂會填入低處，等砂橋穩定再過去", "低通道不能跳過沙堆，從側面吞下阻擋的沙子", "吞下支撐泥土後先退開，讓沙子落下", "讓沙子覆蓋感測器，就能抬起玻璃門", "沙子碰到尖刺會消失，不會鋪成安全地面", "吞下沙子，吐向虛空核心填出通路", "軌道可以運送沙子；站在貨物上一起升高", "依序挖砂、啟動感測器，再填補虛空通道"]
for n in range(1, 10):
    l = Room(70+n, sand_names[n-1], sand_hints[n-1], 29+n, 19 if n == 2 else 15)
    if n == 1:
        l.rect(11, 14, 13, l.width-2, "@")
        l.rect(4, 10, 5, 10, "A")
        l.rect(4, 12, 6, 12, "A")
        l.goal(l.width-3, 10)
        l.wait(90); l.walk(8); l.jump(11); l.jump(16)
    elif n == 2:
        l.rect(14, 1, 17, l.width-2, "@")
        l.rect(13, 10, 17, 15, ".")
        l.rect(5, 10, 9, 15, "A")
        l.wait(100)
    elif n in (3, 4, 6, 9):
        l.rect(1, 10, 10, 10, "@")
        l.rect(11, 8, 11, 12, "@")
        l.put(12, 10, "A"); l.put(13, 10, "#" if n == 4 else "A")
        l.walk(9); l.eat(10); l.shoot(6, 5); l.wait(30)
        l.eat(10); l.shoot(6, 5)
        if n == 6:
            l.rect(13, 17, 13, 19, "~")
            l.rect(3, 18, 7, 18, "A")
            l.wait(60); l.walk(15); l.jump(23)
        if n == 9:
            l.put(11, 17, "A"); l.put(12, 17, "#")
            l.sensors.add((17, 13)); l.lift_gate(23)
            l.wire((17, 13), (17, 14), (23, 14), (23, 13))
            l.walk(16); l.eat(17, 12); l.shoot(15, 5); l.wait(80)
            l.put(13, 27, "A")
            l.rect(1, 32, 11, 33, "@")
            l.put(13, 32, "O"); l.put(13, 33, "O")
            l.walk(26); l.eat(27); l.walk(30); l.shoot(32); l.walk(31); l.eat(32); l.shoot(33)
    elif n == 5:
        l.put(11, 6, "A"); l.put(12, 6, "#")
        l.sensors.add((6, 13)); l.lift_gate(17)
        l.wire((6, 13), (6, 14), (17, 14), (17, 13))
        l.walk(5); l.eat(6, 12); l.shoot(3, 5); l.wait(80)
    elif n == 7:
        l.put(13, 5, "A")
        l.rect(1, 13, 11, 14, "@")
        l.put(13, 13, "O"); l.put(13, 14, "O")
        l.walk(4); l.eat(5); l.walk(11); l.shoot(13); l.walk(12); l.eat(13); l.shoot(14)
    elif n == 8:
        l.start(4, 12); l.put(13, 4, "A")
        l.put(13, 2, "#"); l.sensors.add((2, 13))
        l.wire((2, 13), (4, 13))
        l.rail((4, 13), (4, 8), (12, 8))
        l.rect(9, 13, 13, l.width-2, "@")
        l.goal(l.width-3, 8); l.wait(180)
    l.finish(l.width-3)


# World 9: riders traverse visibly different routes, including leftward travel.
rail_names = ["搭上升降台", "跨越刺床", "向上再向右", "折線運輸", "下降到出口", "逆向列車", "雙車廂", "砂貨運", "機關巡迴"]
rail_hints = ["站在方塊上等升降台上升，到站後走向終點", "待在運輸方塊上穿過刺床，下車前看清落腳處", "軌道轉彎時乘客也會一起轉向", "沿著箭頭搭乘，先橫移再升高", "下降運輸途中不要跳離方塊", "這次終點在左側，依箭頭向左搭乘", "前車廂先轉彎，站在前方車頂跟著列車運送", "沙子有軌道承接就由軌道控制，不會自行落下", "沿多次轉彎完成巡迴，最後下車到終點"]
paths = [
    [(4, 13), (4, 8)], [(4, 11), (15, 11)],
    [(4, 13), (4, 8), (14, 8)], [(4, 13), (9, 13), (9, 8), (16, 8)],
    [(4, 6), (10, 6), (10, 12), (17, 12)],
    [(22, 13), (13, 13), (13, 7), (5, 7)],
    [(4, 11), (15, 11), (15, 8), (21, 8)],
    [(4, 13), (4, 9), (10, 9), (10, 6), (19, 6)],
    [(4, 13), (10, 13), (10, 8), (17, 8), (17, 11), (24, 11), (24, 6), (31, 6)],
]
for n in range(1, 10):
    path = paths[n-1]
    l = Room(80+n, rail_names[n-1], rail_hints[n-1], 29+n)
    x, y = path[0]
    l.start(x, y-1); l.put(y, x, "A" if n == 8 else "#")
    source = x+2 if n == 6 else x-2
    l.put(y, source, "#"); l.sensors.add((source, y))
    l.wire((source, y), (x, y))
    steps = l.rail(*path)
    if n == 7:
        l.put(y, x+1, "#")
        l.start(x+1, y-1)
    end_x, end_y = path[-1]
    if n == 6:
        l.rect(end_y+1, 1, 13, end_x-1, "@")
        l.goal(2, end_y); goal = 2
    else:
        l.rect(end_y+1, end_x+1, 13, l.width-2, "@")
        l.goal(l.width-3, end_y); goal = l.width-3
    if n in (2, 7):
        l.rect(13, 6, 13, 13, "~")
    l.wait(steps*12+18)
    l.finish(goal)


# World 10: firing, throwing, remote signals and delayed chain reactions.
tnt_names = ["遠距點火", "吐出的炸彈", "延遲連鎖", "隔牆信號", "落砂引信", "兩次回投", "留出撤離距離", "冰上的爆破", "爆破總測試"]
tnt_hints = ["用泥土射中 TNT，再等待 0.4 秒引爆", "吞下 TNT，從安全距離吐向玻璃牆", "連鎖炸彈各有倒數，等第二次爆炸後再通過", "覆蓋感測器可以在遠方點燃 TNT", "移除砂粒支撐，讓感測器遠距引爆", "兩道玻璃牆各需要一顆 TNT，先看好下一個補給", "投擲前保持距離，爆炸時不要靠近紅色危險區", "帶著冰時很難煞車，先在安全位置完成瞄準", "先引爆連鎖牆，再取沙子填補最後的虛空通道"]
for n in range(1, 10):
    l = Room(90+n, tnt_names[n-1], tnt_hints[n-1], 29+n)
    if n in (2, 6, 7):
        l.put(13, 4, "T"); l.glass_gate(13)
        l.walk(3); l.eat(4); l.walk(9); l.shoot(13)
        if n == 6:
            l.put(13, 18, "T"); l.glass_gate(25)
            l.walk(17); l.eat(18); l.walk(21); l.shoot(25)
        if n == 7:
            l.rect(12, 19, 13, 21, "@")
            l.walk(17); l.jump(23)
    elif n in (4, 5):
        source = 5 if n == 4 else 7
        l.sensors.add((source, 13))
        if n == 4:
            l.pocket(source); l.put(13, 4, "#")
            l.walk(3); l.eat(4); l.shoot(5)
        else:
            l.put(11, 7, "A"); l.put(12, 7, "#")
            l.walk(6); l.eat(7, 12); l.shoot(3, 5)
        l.glass_gate(18, True)
        l.wire((source, 13), (source, 14), (18, 14), (18, 13))
        l.wait(80)
    else:
        l.put(13, 4, "I" if n == 8 else "#")
        gate = 14 if n in (3, 9) else 16
        l.glass_gate(gate, True)
        if n in (3, 9):
            l.glass_gate(gate+2, True)
        if n == 8:
            l.rect(14, 7, 14, 11, "I")
        l.walk(3); l.eat(4); l.walk(gate-4); l.shoot(gate); l.wait(80)
        if n == 9:
            l.put(13, 22, "A")
            l.rect(1, 29, 11, 30, "@")
            l.put(13, 29, "O"); l.put(13, 30, "O")
            l.walk(21); l.eat(22); l.walk(27); l.shoot(29); l.walk(28); l.eat(29); l.shoot(30)
    l.finish(l.width-3)

# Reworked stages: each asks for a different decision rather than another door.
# Keep first-contact lessons short; use later maps for spatial puzzles.

# Signals can reshape a staircase, open a floor, or reuse the same weight.
l = Room(52, "把階梯叫下來", "覆蓋開關讓高處泥土下降；跳上運來的踏腳，再登上右側高台", 28)
l.put(13, 4, "#"); l.pocket(5)
l.put(5, 12, "#"); l.rail((12, 5), (12, 12))
l.wire((5, 13), (5, 14), (12, 14), (12, 12))
l.rect(10, 16, 13, 26, "@"); l.goal(24, 9)
l.walk(3); l.eat(4); l.shoot(5); l.wait(110)
l.walk(10); l.jump(12); l.jump(17); l.finish(24)

l = Room(53, "一顆砝碼兩次用", "第一道門升起後不會落回；回收同一顆泥土，帶去啟動第二道門", 31)
l.put(13, 4, "#"); l.pocket(5); l.lift_gate(12)
l.wire((5, 13), (5, 14), (12, 14), (12, 13))
l.pocket(20); l.lift_gate(25)
l.wire((20, 13), (20, 14), (25, 14), (25, 13))
l.walk(3); l.eat(4); l.shoot(5); l.wait(70); l.walk(4); l.eat(5)
l.walk(18); l.shoot(20); l.wait(70)
l.expected_sensors = {(20, 13)}; l.finish(28)

l = Room(55, "開的是地板", "上層沒有出口；通電移走玻璃地板，沿豎井下到左下角", 25)
l.start(2, 5); l.goal(2, 13)
l.rect(6, 1, 6, 23, "@"); l.put(6, 13, "X")
l.put(5, 4, "#"); l.pocket(5, 5)
l.rail((13, 6), (13, 10))
l.wire((5, 5), (5, 4), (13, 4), (13, 6))
l.walk(3); l.eat(4, 5); l.shoot(5, 5); l.wait(70)
l.walk(13); l.wait(55); l.finish(2)

l = Room(56, "出口在身後", "先在右側找到砝碼，向左覆蓋開關，再回頭穿過原本關閉的門", 28)
l.start(20, 13); l.goal(2, 13)
l.put(13, 18, "#"); l.sensors.add((15, 13)); l.put(13, 14, "@")
l.lift_gate(8); l.wire((15, 13), (15, 14), (8, 14), (8, 13))
l.walk(19); l.eat(18); l.shoot(15); l.wait(80); l.finish(2)

# Ice traversal alternates braking, drops and jumps instead of copying a gate.
l = Room(62, "下坡前先煞車", "走下冰台前先停穩；落到中間平台，再跳到終點，別直接衝進刺床", 27, 19)
l.start(2, 5); l.goal(24, 12)
l.rect(6, 1, 6, 9, "I"); l.rect(7, 1, 18, 9, "@")
l.rect(10, 10, 10, 14, "I"); l.rect(11, 10, 18, 14, "@")
l.rect(16, 15, 16, 20, "~"); l.rect(13, 21, 18, 25, "@")
l.walk(8); l.wait(30); l.walk(13); l.wait(30); l.jump(22); l.finish(24)

l = Room(64, "兩段冰跳", "每次跳躍後先在安全冰台停下；兩段刺床不能一次衝完", 33)
l.rect(14, 3, 14, 29, "I")
l.rect(13, 10, 13, 12, "~"); l.rect(13, 22, 13, 24, "~")
l.walk(8); l.jump(16); l.wait(30); l.walk(20); l.jump(28); l.finish(30)

l = Room(67, "冰塔折返", "冰塔每一層的缺口都在另一邊；落地後先煞車，再換方向下樓", 25, 19)
l.start(2, 3); l.goal(2, 16)
l.rect(4, 1, 4, 17, "I"); l.rect(5, 1, 5, 17, "@")
l.rect(8, 6, 8, 23, "I"); l.rect(9, 6, 9, 23, "@")
l.rect(12, 1, 12, 17, "I"); l.rect(13, 1, 13, 17, "@")
l.rect(17, 1, 17, 23, "I")
l.walk(20); l.brake(); l.walk(3); l.brake(); l.walk(20); l.brake(); l.finish(2)

l = Room(68, "冰塊送上樓", "把天花板上的冰送到右端，再從下層走回左邊登階；終點不在冰的終點", 29)
l.start(2, 4); l.goal(2, 10)
l.rect(5, 1, 5, 6, "@"); l.put(4, 4, "#")
l.rect(3, 7, 3, 21, "@"); l.put(4, 7, "I"); l.put(4, 22, "@")
l.sensors.add((21, 4))
l.put(7, 10, "#"); l.rail((10, 7), (10, 12))
l.wire((21, 4), (21, 6), (10, 6), (10, 7))
l.rect(11, 1, 13, 6, "@"); l.rect(13, 7, 13, 8, "@")
l.walk(3); l.eat(4, 4); l.shoot(7, 4); l.wait(140)
l.walk(15); l.wait(60); l.walk(11); l.jump(10); l.jump(7); l.jump(4); l.finish(2)

# Sand maps are excavation and construction: remove it, rescue it, or shape it.
l = Room(73, "側挖砂牆", "從地面打開砂牆下層，讓上層依次落下；邊挖邊前進", 25)
l.rect(11, 10, 13, 10, "A"); l.rect(10, 8, 10, 12, "@")
l.walk(9)
for _ in range(3):
    l.walk(9); l.eat(10); l.walk(7); l.shoot(3, 4); l.wait(14)
l.finish(22)

l = Room(74, "往下挖", "吞掉腳邊的砂，把砂吐進左側收集槽；最後移除泥土支撐，落入地下出口", 23)
l.start(10, 3)
l.rect(4, 1, 12, 21, "@"); l.rect(4, 9, 6, 9, ".")
l.rect(4, 10, 6, 10, "A"); l.put(7, 10, "#"); l.rect(8, 10, 12, 10, ".")
l.goal(19, 13)
for row in range(4, 7):
    l.eat(10, row); l.shoot(7 if row == 6 else 9, 1 if row == 6 else row); l.wait(20)
l.eat(10, 7); l.wait(60)
l.finish(19)

l = Room(76, "救下最後一粒", "砂落到尖刺會消失；先吞下左側砂粒，再把它送進虛空缺口", 28)
l.put(12, 5, "A"); l.put(13, 5, "@"); l.rect(3, 12, 6, 12, "A")
l.rect(13, 11, 13, 12, "~")
l.rect(1, 19, 11, 19, "@"); l.put(13, 19, "O")
l.walk(4); l.eat(5, 12); l.walk(10); l.jump(15); l.walk(17); l.shoot(19); l.finish(25)

l = Room(77, "把砂搬上台", "在低處吞下砂，帶上左邊階梯；從高台把砂吐進高處的虛空", 31)
l.put(13, 4, "A")
l.rect(12, 8, 13, 10, "@"); l.rect(10, 13, 13, 17, "@")
l.rect(10, 18, 13, 29, "@"); l.rect(1, 18, 7, 19, "@"); l.put(9, 18, "O"); l.put(9, 19, "O")
l.goal(27, 9)
l.walk(3); l.eat(4); l.walk(6); l.jump(9); l.jump(15)
l.walk(17); l.shoot(18, 9); l.walk(17); l.eat(18, 9); l.walk(18); l.shoot(19, 9); l.finish(27)

# Transport requires starting a train, changing trains or using the delivered
# cargo. The first elevator stays as a readable first-contact lesson.
l = Room(82, "運來的是踏腳", "站在地面啟動貨運；等泥土到站後跳上貨物，再登上高台", 28)
l.put(13, 4, "#"); l.pocket(5)
l.put(11, 8, "#"); l.rail((8, 11), (13, 11))
l.wire((5, 13), (5, 14), (8, 14), (8, 11))
l.rect(9, 17, 13, 26, "@"); l.goal(24, 8)
l.walk(3); l.eat(4); l.shoot(5); l.wait(90)
l.walk(11); l.jump(13); l.jump(18); l.finish(24)

l = Room(83, "自己發車", "先吞下左側泥土，在車頂向左覆蓋開關；發車後跟著列車轉彎", 29)
l.start(4, 12); l.put(13, 4, "#"); l.put(12, 3, "#")
l.sensors.add((1, 12)); l.put(13, 1, "@"); l.rail((4, 13), (11, 13), (11, 8), (19, 8))
l.wire((1, 12), (4, 12), (4, 13))
l.rect(9, 20, 13, 27, "@"); l.goal(26, 8)
l.eat(3, 12); l.shoot(2, 12); l.wait(260); l.finish(26)

def transfer(slot, third=False):
    l = Room(slot, "三站換乘" if third else "下車再換乘", "第一站先下車取泥土，再登上第二輛車啟動；不要在第一台車上等到最後", 39 if third else 30)
    l.start(4, 12); l.put(13, 4, "#"); l.put(13, 2, "#"); l.sensors.add((2, 13))
    l.wire((2, 13), (4, 13)); l.rail((4, 13), (4, 10), (8, 10))
    l.rect(11, 9, 13, 13, "@"); l.put(10, 10, "#")
    l.put(10, 14, "#"); l.rail((14, 10), (14, 6), (22, 6))
    l.pocket(16, 9); l.wire((16, 9), (16, 10), (14, 10))
    l.rect(7, 23, 13, l.width-2, "@"); l.goal(l.width-3, 6)
    l.wait(110); l.walk(9); l.eat(10, 10); l.jump(14); l.shoot(16, 9); l.wait(210)
    if third:
        l.rect(7, 29, 13, 36, "."); l.rect(7, 37, 13, 37, ".")
        l.put(6, 24, "A"); l.put(6, 29, "#")
        l.rail((29, 6), (29, 11), (33, 11))
        l.pocket(31, 5); l.wire((31, 5), (31, 6), (29, 6))
        l.put(6, 31, "@"); l.rect(13, 29, 13, 33, "~")
        l.put(5, 28, "@")
        l.rect(12, 34, 13, 37, "@"); l.goal(36, 11)
        l.walk(23); l.eat(24, 6); l.walk(26); l.jump(29); l.shoot(31, 5); l.wait(150)
    l.finish(l.width-3)

transfer(84)
transfer(89, True)

l = Room(85, "別把貨物吃掉", "踩著泥土車下降到中層；到站後跳向右邊平台，貨物是最後的踏腳", 26, 20)
l.start(4, 5); l.put(6, 4, "#"); l.put(6, 2, "#"); l.sensors.add((2, 6))
l.wire((2, 6), (4, 6)); l.rail((4, 6), (11, 6), (11, 14))
l.rect(17, 6, 17, 17, "~"); l.rect(13, 16, 18, 24, "@"); l.goal(22, 12)
l.wait(205); l.jump(17); l.finish(22)

l = Room(86, "回程有路障", "先向左搭車；到站後吞掉兩塊擋路泥土，騰出下車通道", 29)
l.start(22, 12); l.put(13, 22, "#"); l.put(13, 24, "#"); l.sensors.add((24, 13))
l.wire((24, 13), (22, 13)); l.rail((22, 13), (13, 13), (13, 7), (6, 7))
l.rect(8, 1, 13, 5, "@"); l.rect(5, 1, 5, 4, "@"); l.put(7, 4, "#"); l.put(7, 3, "#")
l.goal(2, 7); l.wait(310); l.walk(5); l.eat(4, 7); l.shoot(12, 2); l.walk(4); l.eat(3, 7); l.shoot(12, 2); l.finish(2)

l = Room(87, "兩件貨物都要帶", "兩塊泥土各填一處虛空；先用第一件貨物，再回站取第二件，別吞掉已磨損的填充塊", 31)
l.put(13, 2, "#"); l.start(4, 13); l.sensors.add((2, 13))
l.put(11, 6, "#"); l.put(11, 7, "#"); l.rail((6, 11), (12, 11)); l.wire((2, 13), (2, 11), (6, 11))
l.rect(12, 14, 13, 29, "@")
l.rect(1, 19, 9, 20, "@"); l.put(11, 19, "O"); l.put(11, 20, "O"); l.goal(27, 11)
l.wait(100); l.walk(10); l.jump(12); l.eat(12, 11); l.jump(15); l.walk(18); l.shoot(19, 11)
l.walk(15); l.jump(12); l.eat(12, 11); l.jump(15); l.walk(19); l.shoot(20, 11); l.finish(27)

l = Room(88, "先送砂再搭車", "第一輛車送來砂；取走砂、登上第二台車，用砂覆蓋它的開關後升高", 31)
l.put(13, 2, "#"); l.sensors.add((2, 13)); l.start(4, 13)
l.put(12, 7, "A"); l.rail((7, 12), (12, 12)); l.wire((2, 13), (2, 12), (7, 12))
l.put(13, 16, "#"); l.rail((16, 13), (16, 8), (23, 8))
l.pocket(19, 12); l.put(13, 19, "@"); l.wire((19, 12), (16, 12), (16, 13))
l.rect(9, 24, 13, 29, "@"); l.goal(28, 8)
l.wait(100); l.walk(11); l.eat(12, 12); l.jump(16); l.shoot(19, 12); l.wait(220); l.finish(28)

# Demolition creates passages above and below, with supplies in different rooms.
l = Room(93, "往下爆破", "從上層射中下方炸藥，炸開玻璃地板；等連鎖结束再沿缺口下樓", 26, 21)
l.start(2, 5); l.goal(22, 19)
l.rect(6, 1, 6, 24, "@"); l.rect(6, 12, 6, 14, "X"); l.put(5, 12, "T")
l.rect(11, 1, 11, 24, "@"); l.rect(11, 12, 11, 14, "X"); l.put(10, 16, "T")
l.put(5, 4, "#"); l.put(10, 9, "#")
l.walk(3); l.eat(4, 5); l.walk(9); l.shoot(12, 5); l.wait(65)
l.walk(13); l.wait(60); l.walk(10); l.eat(9, 10); l.walk(12); l.shoot(16, 10); l.wait(65)
l.walk(14); l.wait(70); l.finish(22)

l = Room(94, "先拆身後的牆", "右側的開關會引爆左側炸藥；先確認爆破結束，再回頭找到左側出口", 29)
l.start(14, 13); l.goal(2, 13)
l.put(13, 14, "P"); l.put(13, 9, "T"); l.rect(1, 8, 13, 8, "X")
l.put(13, 18, "#"); l.pocket(20); l.wire((20, 13), (20, 14), (9, 14), (9, 13))
l.walk(17); l.eat(18); l.shoot(20); l.wait(70); l.finish(2)

l = Room(95, "高台上的引信", "先爬上左側平台，移除砂粒支撐；信號炸開右下層的玻璃後再下樓", 30)
l.rect(12, 6, 13, 8, "@"); l.rect(10, 10, 13, 14, "@"); l.put(9, 12, "#"); l.put(8, 12, "A")
l.sensors.add((12, 10)); l.put(10, 12, ".")
l.glass_gate(22, True); l.wire((12, 10), (12, 14), (22, 14), (22, 13))
l.walk(4); l.jump(7); l.jump(11); l.eat(12, 9); l.shoot(4, 5); l.wait(80); l.finish(27)

l = Room(96, "帶炸藥下樓", "先把 TNT 帶下高台，在中層投向玻璃；下樓時別猛烈撞擊", 28, 20)
l.start(2, 5); l.goal(25, 10)
l.rect(6, 1, 18, 7, "@"); l.put(5, 4, "T")
l.rect(11, 8, 18, 13, "@"); l.rect(1, 18, 18, 18, "X"); l.rect(11, 19, 18, 26, "@")
l.walk(3); l.eat(4, 5); l.walk(11); l.wait(40); l.walk(12); l.shoot(18, 10); l.wait(70); l.jump(20); l.finish(25)

l = Room(97, "爆破後往上走", "先炸開上方玻璃帽，再沿階梯登上高處出口；地面直走不會通關", 28)
l.put(13, 4, "T"); l.rect(12, 8, 13, 10, "@"); l.rect(10, 13, 13, 16, "@"); l.rect(8, 19, 13, 26, "@")
l.rect(7, 19, 7, 21, "X"); l.put(7, 20, "T"); l.goal(25, 7)
l.walk(3); l.eat(4); l.walk(6); l.jump(9); l.jump(14); l.shoot(19, 5); l.wait(70); l.walk(16); l.jump(20); l.finish(25)

l = Room(98, "炸藥藏在樓下", "帶著冰走下高台，先在冰面煞車再射中 TNT；爆炸也會打碎部分冰地板", 30, 20)
l.start(2, 5); l.goal(26, 17)
l.rect(6, 1, 17, 7, "@"); l.put(5, 4, "I")
l.rect(1, 19, 17, 19, "X"); l.put(17, 19, "T")
l.rect(18, 8, 18, 28, "I")
l.walk(3); l.eat(4, 5); l.walk(12); l.wait(40); l.brake(); l.walk(15); l.brake(); l.shoot(19, 17); l.wait(70); l.finish(26)

l = Room(99, "地下爆破工地", "遠距炸開地板後下井挖砂；用最後一粒砂填掉虛空，再吞回砂清出出口", 37)
l.start(2, 5)
l.rect(6, 1, 6, 35, "@"); l.rect(6, 14, 6, 16, "X"); l.put(5, 15, "T")
l.rect(11, 1, 13, 35, "@"); l.goal(33, 10)
l.put(5, 4, "#"); l.pocket(5, 5); l.wire((5, 5), (5, 4), (15, 4), (15, 5))
l.rect(8, 21, 8, 25, "@"); l.put(9, 23, "A"); l.put(10, 23, "A")
l.rect(9, 26, 9, 28, "@"); l.put(10, 27, "O")
l.walk(3); l.eat(4, 5); l.shoot(5, 5); l.wait(70); l.walk(15); l.wait(55)
l.walk(22); l.eat(23, 10); l.walk(20); l.shoot(17, 7)
l.walk(22); l.eat(23, 10); l.walk(25); l.shoot(27, 10); l.walk(26); l.eat(27, 10); l.finish(33)

assert len(SLOTS) == 45
for slot, doc in SLOTS.items():
    rows = doc["rows"]
    assert len({len(r) for r in rows}) == 1
    assert sum(row.count("P") for row in rows) == 1, slot
    assert sum(row.count("$") for row in rows) == 1, slot

(ROOT / "data/levels/mechanism_levels.json").write_text(
    json.dumps({"format": 2, "slots": SLOTS, "lessons": LESSONS}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
(ROOT / "tests/fixtures/mechanism_solutions.json").write_text(
    json.dumps(ROUTES, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
print("Built 45 mechanism stages and 45 input routes; boss rooms preserved.")
