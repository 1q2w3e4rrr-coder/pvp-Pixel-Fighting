import time
import pygame

from ui.hpbar import HPBar
from core.asset_loader import load_scaled_image


class SceneFight:

    def __init__(self, game, p1_class, p2_class, p1_name, p2_name):
        self.game = game

        t0 = time.time()
        print("SceneFight init start")

        self.bg = load_scaled_image(
            "assets/战斗地图/background1.jpg",
            (1500, 800),
            alpha=False
        )
        print("bg loaded:", time.time() - t0)

        self.floor_y = 548

        self.p1 = p1_class(260, self.floor_y, True)
        print("p1 loaded:", time.time() - t0)

        self.p2 = p2_class(1080, self.floor_y, False)
        print("p2 loaded:", time.time() - t0)

        self.p1.enemy = self.p2
        self.p2.enemy = self.p1

        self.p1_name = p1_name
        self.p2_name = p2_name

        self.hpbar = HPBar(self.p1_name, self.p2_name)
        print("hpbar loaded:", time.time() - t0)

        self.p1_hit_lock = 0
        self.p2_hit_lock = 0

        self.font = pygame.font.SysFont("SimHei", 28)

        self.game_over = False
        self.winner_text = ""

        self.body_width = 80
        self.hit_registry = set()

        print("SceneFight init done:", time.time() - t0)

    def handle_event(self, event):
        pass

    def update_face_direction(self):
        # 朝向由最后一次方向输入决定
        pass

    def keep_player_spacing(self):
        self.p1.x = max(0, min(1420, self.p1.x))
        self.p2.x = max(0, min(1420, self.p2.x))
    def is_blocking_attack(self, attacker, defender):
        if defender.state.state != "defend":
            return False
        return attacker.dir != defender.dir

    def _registry_key(self, box_type, attacker, defender):
        if box_type == "body":
            return (box_type, id(attacker), id(defender), attacker.action_serial)
        return (box_type, id(attacker), id(defender), attacker.effect_action_serial)

    def process_single_hitbox(self, attacker, defender, hitbox, defender_lock_name, box_type):
        if hitbox is None:
            return False

        reg_key = self._registry_key(box_type, attacker, defender)
        if reg_key in self.hit_registry:
            return False

        defender_lock = getattr(self, defender_lock_name)
        if defender_lock > 0:
            return False

        if hitbox.colliderect(defender.hitbox):
            if self.is_blocking_attack(attacker, defender):
                attacker.apply_blockstop(3)
                defender.apply_blockstop(3)
                self.hit_registry.add(reg_key)
                return True

            damage = attacker.current_damage()
            knockback = attacker.current_knockback()
            hitstun = attacker.current_hitstun()

            defender.take_hit(
                damage,
                attacker_dir=attacker.dir,
                knockback=knockback,
                hitstun=hitstun
            )

            # 命中停顿
            attacker.apply_hitstop(2)
            defender.apply_hitstop(2)

            setattr(self, defender_lock_name, hitstun)
            self.hit_registry.add(reg_key)
            return True

        return False

    def process_hit(self, attacker, defender, defender_lock_name):
        if self.process_single_hitbox(attacker, defender, attacker.attack_box, defender_lock_name, "body"):
            return

        self.process_single_hitbox(attacker, defender, attacker.get_effect_hitbox(), defender_lock_name, "effect")

    def update_hit_locks(self):
        if self.p1_hit_lock > 0:
            self.p1_hit_lock -= 1
        if self.p2_hit_lock > 0:
            self.p2_hit_lock -= 1

    def cleanup_registry(self):
        active_keys = set()
        active_keys.add(("body", id(self.p1), id(self.p2), self.p1.action_serial))
        active_keys.add(("effect", id(self.p1), id(self.p2), self.p1.effect_action_serial))
        active_keys.add(("body", id(self.p2), id(self.p1), self.p2.action_serial))
        active_keys.add(("effect", id(self.p2), id(self.p1), self.p2.effect_action_serial))

        self.hit_registry = {k for k in self.hit_registry if k in active_keys}

    def check_game_over(self):
        if self.p1.hp <= 0:
            self.p1.hp = 0
            self.game_over = True
            self.winner_text = "P2 WIN"
        elif self.p2.hp <= 0:
            self.p2.hp = 0
            self.game_over = True
            self.winner_text = "P1 WIN"

    def update(self):
        if self.game_over:
            return

        keys = pygame.key.get_pressed()

        self.p1.enemy = self.p2
        self.p2.enemy = self.p1

        self.update_face_direction()

        self.p1.update(keys)
        self.p2.update(keys)

        self.keep_player_spacing()

        self.process_hit(self.p1, self.p2, "p2_hit_lock")
        self.process_hit(self.p2, self.p1, "p1_hit_lock")

        self.update_hit_locks()
        self.cleanup_registry()
        self.check_game_over()

    def draw(self, screen):
        screen.blit(self.bg, (0, 0))
        self.p1.draw(screen)
        self.p2.draw(screen)
        self.hpbar.draw(screen, self.p1, self.p2)

        if self.game_over:
            text = self.font.render(self.winner_text, True, (255, 0, 0))
            screen.blit(text, (680, 120))