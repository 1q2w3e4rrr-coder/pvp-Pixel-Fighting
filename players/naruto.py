import os
import pygame

from core.animation import Animation
from core.animator import Animator
from core.sprite import SpriteSheet
from players.player import Player


class PlayerNaruto(Player):

    def __init__(self, x, y, is_p1=True):
        super().__init__(x, y, is_p1)

        self.frame_w = 80
        self.frame_h = 120
        base = "assets/人物图集/鸣人/"

        self.animator = Animator()

        def pick(*names):
            for name in names:
                path = base + name
                if os.path.exists(path):
                    return path
            raise FileNotFoundError(f"None of these files exist: {names}")

        def hold_first_frame(anim, total_frames):
            frame = anim.frames[0] if anim.frames else pygame.Surface((80, 120), pygame.SRCALPHA)
            return Animation([frame] * total_frames, 1, False)

        walk_sheet = pick("行走动画2.jpg")

        # 右向行走保持当前正常版本
        walk_r = self._build_selected_walk_anim(walk_sheet, row=0, cols=[1, 2], speed=6)
        # 左向行走改为镜像右向的稳定帧，避免当前左向素材链抽搐
        walk_l = self._build_mirrored_walk_anim(walk_r, speed=6)

        idle_r = self._build_single_frame_anim(walk_sheet, row=0, col=0)
        # 左向待机保持当前已修好的安全逻辑
        idle_l = self._build_safe_left_idle_anim(walk_sheet, idle_r)

        atk1_r = self.build_row_anim(base + "攻击12.jpg", 0, self.frame_w, self.frame_h, 5, False)
        atk1_l = self.build_row_anim(base + "攻击12.jpg", 1, self.frame_w, self.frame_h, 5, False)
        atk2_r = self.build_row_anim(base + "攻击22.jpg", 0, self.frame_w, self.frame_h, 5, False)
        atk2_l = self.build_row_anim(base + "攻击22.jpg", 1, self.frame_w, self.frame_h, 5, False)
        atk3_r = self.build_row_anim(base + "攻击32.jpg", 0, self.frame_w, self.frame_h, 5, False)
        atk3_l = self.build_row_anim(base + "攻击32.jpg", 1, self.frame_w, self.frame_h, 5, False)

        skill_u_src_r = self.build_row_anim(base + "技能12.jpg", 0, self.frame_w, self.frame_h, 5, False)
        skill_u_src_l = self.build_row_anim(base + "技能12.jpg", 1, self.frame_w, self.frame_h, 5, False, True)
        skill_u_r = hold_first_frame(skill_u_src_r, 22)
        skill_u_l = hold_first_frame(skill_u_src_l, 22)

        skill_i_src_r = self.build_row_anim(base + "技能22.jpg", 0, self.frame_w, self.frame_h, 5, False)
        skill_i_src_l = self.build_row_anim(base + "技能22.jpg", 1, self.frame_w, self.frame_h, 5, False, True)
        skill_i_r = hold_first_frame(skill_i_src_r, 5)
        skill_i_l = hold_first_frame(skill_i_src_l, 5)

        skill_o_src_r = self.build_row_anim(base + "技能32.jpg", 0, self.frame_w, self.frame_h, 5, False)
        skill_o_src_l = self.build_row_anim(base + "技能32.jpg", 1, self.frame_w, self.frame_h, 5, False, True)
        skill_o_r = hold_first_frame(skill_o_src_r, 24)
        skill_o_l = hold_first_frame(skill_o_src_l, 24)

        hit_r = self.build_vertical_dir_anim(base + "被打2.jpg", True, self.frame_w, self.frame_h)
        hit_l = self.build_vertical_dir_anim(base + "被打2.jpg", False, self.frame_w, self.frame_h)
        defend_r = self.build_vertical_dir_anim(base + "防御2.jpg", True, self.frame_w, self.frame_h, 8, True)
        defend_l = self.build_vertical_dir_anim(base + "防御2.jpg", False, self.frame_w, self.frame_h, 8, True)
        dodge_r = self.build_vertical_dir_anim(base + "闪避2.jpg", True, self.frame_w, self.frame_h, 5, False)
        dodge_l = self.build_vertical_dir_anim(base + "闪避2.jpg", False, self.frame_w, self.frame_h, 5, False)

        # jump 保持当前已修好的资源绑定
        jump_mask = pick("跳跃1.jpg", "跳跃12.jpg")
        jump_color = pick("跳跃2.jpg", "跳跃11.jpg")
        jumpatk_mask = pick("跳攻1.jpg")
        jumpatk_color = pick("跳攻2.jpg")

        jump_r = self.build_vertical_pair_anim(jump_mask, jump_color, True, 80, 120, 6, False)
        jump_l = self.build_vertical_pair_anim(jump_mask, jump_color, False, 80, 120, 6, False)
        jump_atk_r = self.build_vertical_pair_anim(jumpatk_mask, jumpatk_color, True, 80, 120, 6, False)
        jump_atk_l = self.build_vertical_pair_anim(jumpatk_mask, jumpatk_color, False, 80, 120, 6, False)

        for name, anim in {
            "idle_r": idle_r, "idle_l": idle_l,
            "walk_r": walk_r, "walk_l": walk_l,
            "atk1_r": atk1_r, "atk1_l": atk1_l,
            "atk2_r": atk2_r, "atk2_l": atk2_l,
            "atk3_r": atk3_r, "atk3_l": atk3_l,
            "skill_u_r": skill_u_r, "skill_u_l": skill_u_l,
            "skill_i_r": skill_i_r, "skill_i_l": skill_i_l,
            "skill_o_r": skill_o_r, "skill_o_l": skill_o_l,
            "hit_r": hit_r, "hit_l": hit_l,
            "defend_r": defend_r, "defend_l": defend_l,
            "dodge_r": dodge_r, "dodge_l": dodge_l,
            "jump_r": jump_r, "jump_l": jump_l,
            "jump_atk_r": jump_atk_r, "jump_atk_l": jump_atk_l,
        }.items():
            self.animator.add(name, anim)

        self.skill_u_sheet = SpriteSheet(base + "技能12.jpg", colorkey=(255, 255, 255))
        self.skill_i_sheet = SpriteSheet(base + "技能22.jpg", colorkey=(255, 255, 255))
        self.skill_o_sheet = SpriteSheet(base + "技能32.jpg", colorkey=(255, 255, 255))

        # Naruto 的 U / I / O 手动减速
        self.skill_tick_counter = {
            "skill_u": 0,
            "skill_i": 0,
            "skill_o": 0,
        }
        self.skill_step_interval = {
            "skill_u": 2,
            "skill_i": 3,
            "skill_o": 2,
        }

        self.state.set("idle")
        self.play_dir_anim("idle")

    def _build_selected_walk_anim(self, path, row, cols, speed=6):
        sheet = SpriteSheet(path, colorkey=(255, 255, 255))
        frames = []
        y = row * self.frame_h
        for col in cols:
            x = col * self.frame_w
            frames.append(sheet.get(x, y, self.frame_w, self.frame_h))
        return Animation(frames, speed, True)

    def _build_mirrored_walk_anim(self, base_anim, speed=6):
        frames = []
        for frame in base_anim.frames:
            frames.append(pygame.transform.flip(frame, True, False))
        return Animation(frames, speed, True)

    def _build_single_frame_anim(self, path, row, col):
        sheet = SpriteSheet(path, colorkey=(255, 255, 255))
        y = row * self.frame_h
        x = col * self.frame_w
        frame = sheet.get(x, y, self.frame_w, self.frame_h)
        return Animation([frame], 10, True)

    def _surface_has_visible_pixels(self, surf):
        if surf is None:
            return False

        w, h = surf.get_size()
        if w == 0 or h == 0:
            return False

        step_x = max(1, w // 8)
        step_y = max(1, h // 8)

        for x in range(0, w, step_x):
            for y in range(0, h, step_y):
                pixel = surf.get_at((x, y))
                if len(pixel) >= 4:
                    if pixel[3] > 10:
                        return True
                else:
                    return True
        return False

    def _build_safe_left_idle_anim(self, path, idle_r_anim):
        sheet = SpriteSheet(path, colorkey=(255, 255, 255))
        left_frame = sheet.get(3 * self.frame_w, 1 * self.frame_h, self.frame_w, self.frame_h)

        if not self._surface_has_visible_pixels(left_frame):
            right_frame = idle_r_anim.frames[0] if idle_r_anim and idle_r_anim.frames else pygame.Surface((self.frame_w, self.frame_h), pygame.SRCALPHA)
            left_frame = pygame.transform.flip(right_frame, True, False)

        return Animation([left_frame], 10, True)

    def _safe_sheet_get(self, sheet, x, y, w, h):
        img_w = sheet.image.get_width()
        img_h = sheet.image.get_height()
        if x < 0 or y < 0 or x + w > img_w or y + h > img_h:
            return pygame.Surface((w, h), pygame.SRCALPHA)
        return sheet.get(x, y, w, h)

    def start_action(self, state_name, anim_name=None):
        super().start_action(state_name, anim_name)
        if state_name in {"skill_u", "skill_i", "skill_o"}:
            self.skill_tick_counter[state_name] = 0

    def handle_busy_state(self):
        state = self.state.state

        if state not in {"skill_u", "skill_i", "skill_o"}:
            return super().handle_busy_state()

        # 只减慢 Naruto 的 U / I / O，其他动作保持当前已修好的速度
        self.skill_tick_counter[state] += 1

        self.attack_box = None
        self.update_effect()

        if self.skill_tick_counter[state] < self.skill_step_interval[state]:
            return False

        self.skill_tick_counter[state] = 0

        self.step_action()
        self.apply_frame_events()

        total_frames = self.get_action_total_frames(state)
        finished = self.action_frame >= total_frames

        if finished:
            finished_state = self.state.state

            self.attack_box = None
            self.effect_box = None
            self.effect_sprite = None
            self.effect_draw_rect = None

            self.skill_tick_counter[state] = 0

            if not self.start_recovery(finished_state):
                self.state.set("idle" if self.on_ground else "jump")
                self.play_dir_anim("idle" if self.on_ground else "jump")
            return True

        return False

    def get_action_total_frames(self, state_name):
        if state_name == "skill_u":
            return 22
        if state_name == "skill_i":
            return 5
        if state_name == "skill_o":
            return 24
        return None

    def get_recovery_frames(self):
        return {}

    def get_damage_map(self):
        return {
            "atk1": 9,
            "atk2": 11,
            "atk3": 14,
            "jump_atk": 8,
            "skill_u": 10,
            "skill_i": 20,
            "skill_o": 5,
        }

    def get_knockback_map(self):
        return {
            "atk1": 14,
            "atk2": 20,
            "atk3": 28,
            "jump_atk": 18,
            "skill_u": 18,
            "skill_i": 28,
            "skill_o": 18,
        }

    def get_hitstun_map(self):
        return {
            "atk1": 10,
            "atk2": 12,
            "atk3": 14,
            "jump_atk": 10,
            "skill_u": 12,
            "skill_i": 16,
            "skill_o": 14,
        }

    def get_frame_events(self, state_name):
        if state_name == "atk1":
            return {1: {"body_hit": True}}
        if state_name == "atk2":
            return {1: {"body_hit": True}, 2: {"body_hit": True}}
        if state_name == "atk3":
            return {1: {"body_hit": True}, 2: {"body_hit": True}}
        if state_name == "jump_atk":
            return {0: {"body_hit": True}}
        if state_name == "dodge":
            return {1: {"move_dx": 300}}

        if state_name == "skill_u":
            return {i: {"effect_hit": True} for i in range(9, 23)}

        if state_name == "skill_i":
            return {
                3: {"effect_hit": True},
                4: {"effect_hit": True},
            }

        if state_name == "skill_o":
            return {i: {"effect_hit": True} for i in range(6, 25)}

        return {}

    def get_attack_box_for_state(self, state_name):
        if state_name == "atk1":
            return pygame.Rect(self.x + 76, self.y + 18, 70, 88) if self.dir == 1 else pygame.Rect(self.x - 70, self.y + 18, 70, 88)
        if state_name == "atk2":
            return pygame.Rect(self.x + 78, self.y + 16, 80, 92) if self.dir == 1 else pygame.Rect(self.x - 80, self.y + 16, 80, 92)
        if state_name == "atk3":
            return pygame.Rect(self.x + 82, self.y + 10, 92, 98) if self.dir == 1 else pygame.Rect(self.x - 92, self.y + 10, 92, 98)
        if state_name == "jump_atk":
            return pygame.Rect(self.x + 76, self.y + 14, 64, 80) if self.dir == 1 else pygame.Rect(self.x - 64, self.y + 14, 64, 80)
        return None

    def update_effect(self):
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        state = self.state.state
        if state not in {"skill_u", "skill_i", "skill_o"}:
            return

        f = max(0, self.action_frame - 1)

        if state == "skill_i":
            k = min(f, 4)

            if self.dir == 1:
                if k == 0:
                    img = self._safe_sheet_get(self.skill_i_sheet, 0, 0, 80, 140)
                    pos = (self.x, self.y - 20)
                elif k == 1:
                    img = self._safe_sheet_get(self.skill_i_sheet, 80, 0, 160, 140)
                    pos = (self.x - 90, self.y - 20)
                elif k == 2:
                    img = self._safe_sheet_get(self.skill_i_sheet, 240, 0, 270, 140)
                    pos = (self.x - 90, self.y - 20)
                    self.effect_box = pygame.Rect(self.x - 90, self.y - 20, 270, 140)
                elif k == 3:
                    img = self._safe_sheet_get(self.skill_i_sheet, 510, 0, 160, 140)
                    pos = (self.x + 25, self.y - 20)
                    self.effect_box = pygame.Rect(self.x + 25, self.y - 20, 160, 140)
                else:
                    img = self._safe_sheet_get(self.skill_i_sheet, 670, 0, 80, 140)
                    pos = (self.x, self.y - 20)
            else:
                if k == 0:
                    img = self._safe_sheet_get(self.skill_i_sheet, 670, 140, 80, 140)
                    pos = (self.x, self.y - 20)
                elif k == 1:
                    img = self._safe_sheet_get(self.skill_i_sheet, 510, 140, 160, 140)
                    pos = (self.x + 10, self.y - 20)
                elif k == 2:
                    img = self._safe_sheet_get(self.skill_i_sheet, 240, 140, 270, 140)
                    pos = (self.x - 100, self.y - 20)
                    self.effect_box = pygame.Rect(self.x - 100, self.y - 20, 270, 140)
                elif k == 3:
                    img = self._safe_sheet_get(self.skill_i_sheet, 80, 140, 160, 140)
                    pos = (self.x - 105, self.y - 20)
                    self.effect_box = pygame.Rect(self.x - 105, self.y - 20, 160, 140)
                else:
                    img = self._safe_sheet_get(self.skill_i_sheet, 0, 140, 80, 140)
                    pos = (self.x, self.y - 20)

            self.effect_sprite = img
            self.effect_draw_rect = pos
            return

        if state == "skill_u":
            k = min(f, 21)

            if self.dir == 1:
                if k <= 7:
                    return
                elif k <= 18:
                    old_x = self.x + (k - 7) * 50
                    img = self._safe_sheet_get(self.skill_u_sheet, 640 + (k - 8) * 100, 0, 100, 100)
                    self.effect_sprite = img
                    self.effect_draw_rect = (old_x, self.y)
                    self.effect_box = pygame.Rect(old_x, self.y, 100, 100)
                else:
                    old_x = self.x + 550
                    img = self._safe_sheet_get(self.skill_u_sheet, 1740 + (k - 19) * 300, 0, 300, 400)
                    self.effect_sprite = img
                    self.effect_draw_rect = (old_x, self.y - 280)
                    self.effect_box = pygame.Rect(old_x, self.y - 280, 300, 400)
            else:
                if k <= 7:
                    return
                elif k <= 18:
                    old_x = self.x - (k - 7) * 50
                    img = self._safe_sheet_get(self.skill_u_sheet, 2540 - (k - 8) * 100, 400, 100, 100)
                    self.effect_sprite = img
                    self.effect_draw_rect = (old_x, self.y)
                    self.effect_box = pygame.Rect(old_x, self.y, 100, 100)
                else:
                    old_x = self.x - 750
                    img = self._safe_sheet_get(self.skill_u_sheet, 1540 - (k - 18) * 300, 400, 300, 400)
                    self.effect_sprite = img
                    self.effect_draw_rect = (old_x, self.y - 280)
                    self.effect_box = pygame.Rect(old_x, self.y - 280, 300, 400)
            return

        if state == "skill_o":
            k = min(f, 23)

            if self.dir == 1:
                if k <= 3:
                    return
                elif k == 4:
                    self.effect_sprite = self._safe_sheet_get(self.skill_o_sheet, 320, 0, 130, 120)
                    self.effect_draw_rect = (self.x + 10, self.y)
                    return
                else:
                    cycle = 0 if k <= 13 else 1
                    local_k = k if k <= 13 else k - 9
                    old_x = self.x - 10 + 150 * (cycle + 1)

                    self.effect_sprite = self._safe_sheet_get(self.skill_o_sheet, 450 + (local_k - 5) * 200, 0, 200, 300)
                    self.effect_draw_rect = (old_x, self.y - 100)
                    self.effect_box = pygame.Rect(old_x, self.y - 100, 200, 300)
                    return
            else:
                if k <= 3:
                    return
                elif k == 4:
                    self.effect_sprite = self._safe_sheet_get(self.skill_o_sheet, 2000, 300, 130, 120)
                    self.effect_draw_rect = (self.x - 60, self.y)
                    return
                else:
                    cycle = 0 if k <= 13 else 1
                    local_k = k if k <= 13 else k - 9
                    old_x = self.x - 100 - 150 * (cycle + 1)

                    self.effect_sprite = self._safe_sheet_get(self.skill_o_sheet, 2000 - (local_k - 4) * 200, 300, 200, 300)
                    self.effect_draw_rect = (old_x, self.y - 100)
                    self.effect_box = pygame.Rect(old_x, self.y - 100, 200, 300)
                    return

    def get_effect_hitbox(self):
        return self.effect_box

    def control(self, keys):
        if self.is_p1:
            left, right, defend = pygame.K_a, pygame.K_d, pygame.K_s
            attack, dodge, jump = pygame.K_j, pygame.K_l, pygame.K_k
            skill_u, skill_i, skill_o = pygame.K_u, pygame.K_i, pygame.K_o
        else:
            left, right, defend = pygame.K_LEFT, pygame.K_RIGHT, pygame.K_DOWN
            attack, dodge, jump = pygame.K_KP1, pygame.K_KP3, pygame.K_KP2
            skill_u, skill_i, skill_o = pygame.K_KP4, pygame.K_KP5, pygame.K_KP6

        attack_pressed = keys[attack]
        jump_pressed = keys[jump]
        dodge_pressed = keys[dodge]
        u_pressed = keys[skill_u]
        i_pressed = keys[skill_i]
        o_pressed = keys[skill_o]

        attack_just = attack_pressed and not self.prev_attack_pressed
        jump_just = jump_pressed and not self.prev_jump_pressed
        dodge_just = dodge_pressed and not self.prev_dodge_pressed
        u_just = u_pressed and not self.prev_skill_u_pressed
        i_just = i_pressed and not self.prev_skill_i_pressed
        o_just = o_pressed and not self.prev_skill_o_pressed

        self.prev_attack_pressed = attack_pressed
        self.prev_jump_pressed = jump_pressed
        self.prev_dodge_pressed = dodge_pressed
        self.prev_skill_u_pressed = u_pressed
        self.prev_skill_i_pressed = i_pressed
        self.prev_skill_o_pressed = o_pressed

        self.attack_box = None
        self.update_effect()

        if self.state.is_state("hit"):
            self.play_dir_anim("hit")
            if (not self.hit_reaction_active()) and self.get_dir_anim("hit").finished:
                self.state.set("idle")
                self.play_dir_anim("idle")
            return

        if self.in_recovery():
            self.handle_recovery()
            return

        if self.state.state in {"atk1", "atk2", "atk3", "jump_atk", "dodge", "skill_u", "skill_i", "skill_o"}:
            self.handle_busy_state()
            return

        if dodge_just:
            self.start_action("dodge")
            return

        if keys[defend]:
            self.state.set("defend")
            self.play_dir_anim("defend")
            return

        if jump_just and self.on_ground:
            self.vy = self.jump_speed
            self.on_ground = False
            self.state.set("jump")
            self.play_dir_anim("jump")
            return

        if not self.on_ground:
            if attack_just:
                self.start_action("jump_atk")
            else:
                self.state.set("jump")
                self.play_dir_anim("jump")
            return

        if u_just:
            self.start_action("skill_u")
            return

        if i_just:
            self.start_action("skill_i")
            return

        if o_just:
            self.start_action("skill_o")
            return

        if attack_just and self.attack_cooldown == 0:
            self.combo = 1
            self.start_action("atk1")
            self.attack_cooldown = 8
            return

        moving = False
        if keys[right]:
            self.x += self.move_speed
            self.dir = 1
            moving = True
        if keys[left]:
            self.x -= self.move_speed
            self.dir = -1
            moving = True

        self.state.set("walk" if moving else "idle")
        self.play_dir_anim("walk" if moving else "idle")
