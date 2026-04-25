import pygame
from typing import Dict, Tuple, List

from core.state import StateMachine
from core.animator import Animator
from core.asset_loader import load_image


_ROW_FRAME_CACHE: Dict[Tuple[str, int, int, int, bool], List[pygame.Surface]] = {}
_VERTICAL_FRAME_CACHE: Dict[Tuple[str, bool, int, int], List[pygame.Surface]] = {}
_PAIR_FRAME_CACHE: Dict[Tuple[str, str, bool, int, int], List[pygame.Surface]] = {}


class Player:

    def __init__(self, x, y, is_p1=True):
        self.x = x
        self.y = y
        self.is_p1 = is_p1

        self.dir = 1 if is_p1 else -1
        self.enemy = None

        self.max_hp = 300
        self.hp = self.max_hp
        self.power = 0
        self.combo = 0

        self.state = StateMachine()
        self.animator = Animator()

        self.hitbox = pygame.Rect(self.x, self.y, 80, 120)
        self.attack_box = None

        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        self.vx = 0
        self.vy = 0
        self.on_ground = True

        self.move_speed = 5
        self.jump_speed = -18
        self.gravity = 1
        self.ground_y = y

        self.jump_count = 0
        self.max_air_jumps = 1

        self.attack_cooldown = 0

        self.prev_attack_pressed = False
        self.prev_skill_u_pressed = False
        self.prev_skill_i_pressed = False
        self.prev_skill_o_pressed = False
        self.prev_jump_pressed = False
        self.prev_dodge_pressed = False

        self.action_frame = 0
        self.action_serial = 0
        self.effect_action_serial = 0

        self.hit_push_dir = 0
        self.hit_push_steps = 0
        self.hit_push_tick = 0
        self.hit_push_distance = 0

        self.recovery_timer = 0
        self.recovery_anim_name = None

        self.hitstop_timer = 0
        self.blockstop_timer = 0

    def update(self, keys):
        if self.hitstop_timer > 0:
            self.hitstop_timer -= 1
            self.sync_hitbox()
            return

        if self.blockstop_timer > 0:
            self.blockstop_timer -= 1
            self.sync_hitbox()
            return

        self.state.update()
        self.control(keys)

        if self.state.is_state("hit"):
            self.update_hit_reaction()

        if not self.on_ground:
            self.vy += self.gravity
            self.y += self.vy
            if self.y >= self.ground_y:
                self.y = self.ground_y
                self.vy = 0
                self.on_ground = True
                self.jump_count = 0

        if self.attack_cooldown > 0:
            self.attack_cooldown -= 1

        # 固定总帧数技能不再依赖 animator.update 推进，
        # 避免第二次以后速度漂移
        if self.get_action_total_frames(self.state.state) is None:
            self.animator.update()

        self.sync_hitbox()
        self.x = max(0, min(1420, self.x))

    def sync_hitbox(self):
        self.hitbox.x = self.x
        self.hitbox.y = self.y

    def apply_hitstop(self, frames):
        self.hitstop_timer = max(self.hitstop_timer, int(frames))

    def apply_blockstop(self, frames):
        self.blockstop_timer = max(self.blockstop_timer, int(frames))

    def update_hit_reaction(self):
        if self.hit_push_steps <= 0:
            return

        if self.hit_push_tick == 0:
            if self.hit_push_dir == 1:
                self.x += self.hit_push_distance
            else:
                self.x -= self.hit_push_distance
            self.x = max(0, min(1420, self.x))

        self.hit_push_tick += 1
        if self.hit_push_tick >= 5:
            self.hit_push_tick = 0
            self.hit_push_steps -= 1

    def hit_reaction_active(self):
        return self.hit_push_steps > 0 or self.hit_push_tick > 0

    def get_recovery_frames(self):
        return {}

    def get_action_total_frames(self, state_name):
        return None

    def in_recovery(self):
        return self.recovery_timer > 0

    def start_recovery(self, state_name):
        frames = self.get_recovery_frames().get(state_name, 0)
        if frames <= 0:
            return False

        self.recovery_timer = frames
        self.recovery_anim_name = self.get_action_anim_name(state_name)
        self.state.set("recover")

        self.attack_box = None
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None
        return True

    def handle_recovery(self):
        self.attack_box = None
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        if self.recovery_anim_name:
            self.play_dir_anim(self.recovery_anim_name)

        self.recovery_timer -= 1
        if self.recovery_timer <= 0:
            self.recovery_timer = 0
            self.recovery_anim_name = None
            self.state.set("idle" if self.on_ground else "jump")
            self.play_dir_anim("idle" if self.on_ground else "jump")

    def start_action(self, state_name, anim_name=None):
        self.recovery_timer = 0
        self.recovery_anim_name = None

        self.state.set(state_name)
        self.action_frame = 0
        self.attack_box = None
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        self.action_serial += 1
        self.effect_action_serial = self.action_serial

        base_name = anim_name or state_name
        anim_key = base_name + ("_r" if self.dir == 1 else "_l")

        if anim_key in self.animator.animations:
            self.animator.current = anim_key
            self.animator.animations[anim_key].reset()

    def step_action(self):
        self.action_frame += 1

    def draw(self, screen):
        img = self.animator.get()
        if img:
            screen.blit(img, (self.x, self.y))

        if self.effect_sprite is not None and self.effect_draw_rect is not None:
            screen.blit(self.effect_sprite, self.effect_draw_rect)

    def take_hit(self, damage, attacker_dir=1, knockback=18, hitstun=10):
        self.recovery_timer = 0
        self.recovery_anim_name = None

        self.hp -= damage
        if self.hp < 0:
            self.hp = 0

        self.power += 5
        if self.power > 100:
            self.power = 100

        self.state.set("hit")
        self.action_frame = 0
        self.attack_box = None
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        self.hit_push_dir = attacker_dir
        self.hit_push_steps = max(1, round(hitstun / 5))
        self.hit_push_tick = 0
        self.hit_push_distance = max(10, min(34, int(knockback)))

    def build_row_anim(self, path, row, frame_w, frame_h, speed=6, loop=True, fallback_to_row0=False):
        from core.sprite import SpriteSheet
        from core.animation import Animation

        cache_key = (path, row, frame_w, frame_h, fallback_to_row0)

        if cache_key not in _ROW_FRAME_CACHE:
            sheet = SpriteSheet(path, colorkey=(255, 255, 255))
            img_w = sheet.image.get_width()
            img_h = sheet.image.get_height()

            use_row = row
            if img_h < frame_h * 2 and fallback_to_row0:
                use_row = 0

            y = use_row * frame_h
            if y + frame_h > img_h:
                y = 0

            frame_count = img_w // frame_w
            frames = []
            for i in range(frame_count):
                x = i * frame_w
                if x + frame_w <= img_w:
                    frames.append(sheet.get(x, y, frame_w, frame_h))

            _ROW_FRAME_CACHE[cache_key] = frames

        return Animation(_ROW_FRAME_CACHE[cache_key], speed, loop)

    def build_vertical_dir_anim(self, path, upper, frame_w, frame_h, speed=8, loop=False):
        from core.sprite import SpriteSheet
        from core.animation import Animation

        cache_key = (path, upper, frame_w, frame_h)

        if cache_key not in _VERTICAL_FRAME_CACHE:
            sheet = SpriteSheet(path, colorkey=(255, 255, 255))
            img_h = sheet.image.get_height()

            y = 0 if upper else frame_h
            if y + frame_h > img_h:
                y = 0

            frame = sheet.get(0, y, frame_w, frame_h)
            _VERTICAL_FRAME_CACHE[cache_key] = [frame]

        return Animation(_VERTICAL_FRAME_CACHE[cache_key], speed, loop)

    def build_vertical_pair_anim(self, mask_path, color_path, upper, frame_w, frame_h, speed=8, loop=False):
        from core.animation import Animation

        cache_key = (mask_path, color_path, upper, frame_w, frame_h)

        if cache_key not in _PAIR_FRAME_CACHE:
            mask_img = load_image(mask_path, alpha=True)
            color_img = load_image(color_path, alpha=True)

            y = 0 if upper else frame_h

            if y + frame_h > mask_img.get_height():
                y = 0
            if y + frame_h > color_img.get_height():
                y = 0

            mask_rect = pygame.Rect(0, y, frame_w, frame_h).clip(mask_img.get_rect())
            color_rect = pygame.Rect(0, y, frame_w, frame_h).clip(color_img.get_rect())

            w = min(mask_rect.w, color_rect.w)
            h = min(mask_rect.h, color_rect.h)

            out = pygame.Surface((frame_w, frame_h), pygame.SRCALPHA)

            if w > 0 and h > 0:
                mask_frame = mask_img.subsurface((mask_rect.x, mask_rect.y, w, h)).copy()
                color_frame = color_img.subsurface((color_rect.x, color_rect.y, w, h)).copy().convert_alpha()

                for px in range(w):
                    for py in range(h):
                        mr, mg, mb, _ = mask_frame.get_at((px, py))
                        cr, cg, cb, _ = color_frame.get_at((px, py))
                        alpha = max(mr, mg, mb)
                        out.set_at((px, py), (cr, cg, cb, alpha))

            _PAIR_FRAME_CACHE[cache_key] = [out]

        return Animation(_PAIR_FRAME_CACHE[cache_key], speed, loop)

    def build_idle_from_walk(self, walk_anim, facing: str):
        from core.animation import Animation

        if not walk_anim.frames:
            blank = pygame.Surface((80, 120), pygame.SRCALPHA)
            return Animation([blank], 10, True)

        if facing == "right":
            idx = 0
        else:
            idx = min(3, len(walk_anim.frames) - 1)

        return Animation([walk_anim.frames[idx]], 10, True)

    def play_dir_anim(self, base_name):
        self.animator.play(base_name + ("_r" if self.dir == 1 else "_l"))

    def get_dir_anim(self, base_name):
        return self.animator.animations[base_name + ("_r" if self.dir == 1 else "_l")]

    def get_damage_map(self):
        return {}

    def get_knockback_map(self):
        return {}

    def get_hitstun_map(self):
        return {}

    def get_attack_box_for_state(self, state_name):
        return None

    def get_action_anim_name(self, state_name):
        return state_name

    def get_frame_events(self, state_name):
        return {}

    def current_damage(self):
        return self.get_damage_map().get(self.state.state, 8)

    def current_knockback(self):
        return self.get_knockback_map().get(self.state.state, 15)

    def current_hitstun(self):
        return self.get_hitstun_map().get(self.state.state, 12)

    def update_effect(self):
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

    def get_effect_hitbox(self):
        return self.effect_box

    def apply_frame_events(self):
        self.attack_box = None
        self.update_effect()

        events = self.get_frame_events(self.state.state)
        if not events:
            return

        frame_events = events.get(self.action_frame, {})

        move_dx = frame_events.get("move_dx", 0)
        if move_dx != 0:
            self.x += move_dx if self.dir == 1 else -move_dx
            self.x = max(0, min(1420, self.x))

        if frame_events.get("body_hit", False):
            self.attack_box = self.get_attack_box_for_state(self.state.state)

        if frame_events.get("effect_hit", False):
            self.effect_action_serial += 1
            self.update_effect()

    def handle_busy_state(self):
        self.step_action()
        anim_name = self.get_action_anim_name(self.state.state)
        self.apply_frame_events()

        total_frames = self.get_action_total_frames(self.state.state)
        if total_frames is not None:
            finished = self.action_frame >= total_frames
        else:
            self.play_dir_anim(anim_name)
            finished = self.get_dir_anim(anim_name).finished

        if finished:
            finished_state = self.state.state

            self.attack_box = None
            self.effect_box = None
            self.effect_sprite = None
            self.effect_draw_rect = None

            if not self.start_recovery(finished_state):
                self.state.set("idle" if self.on_ground else "jump")
                self.play_dir_anim("idle" if self.on_ground else "jump")
            return True

        return False

    def is_busy_state(self):
        if self.in_recovery():
            return True
        return self.state.state in {
            "hit", "atk1", "atk2", "atk3", "jump_atk",
            "dodge", "skill_u", "skill_i", "skill_o"
        }

    def can_start_neutral_ground_action(self, keys, left, right):
        return self.on_ground and (not keys[left]) and (not keys[right]) and (not self.is_busy_state())

    def try_start_jump(self):
        if self.on_ground:
            self.vy = self.jump_speed
            self.on_ground = False
            self.state.set("jump")
            self.play_dir_anim("jump")
            return True

        if self.jump_count < self.max_air_jumps:
            self.jump_count += 1
            self.vy = self.jump_speed
            self.on_ground = False
            self.state.set("jump")
            self.play_dir_anim("jump")
            return True

        return False

    def control(self, keys):
        raise NotImplementedError("Subclasses must implement control().")