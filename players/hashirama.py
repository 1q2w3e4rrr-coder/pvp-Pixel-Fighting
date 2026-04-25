import os
import pygame

from core.animation import Animation
from core.animator import Animator
from core.sprite import SpriteSheet
from players.player import Player


class PlayerHashirama(Player):

    def __init__(self, x, y, is_p1=True):
        super().__init__(x, y, is_p1)

        self.frame_w = 80
        self.frame_h = 120
        base = "assets/人物图集/千手柱间/"

        self.animator = Animator()

        def pick(*names: str) -> str:
            for name in names:
                path = base + name
                if os.path.exists(path):
                    return path
            raise FileNotFoundError(f"None of these files exist: {names}")

        walk2 = pick("行走动画2.jpg")
        defend2 = pick("防御2.jpg")
        hit2 = pick("被打2.jpg")
        dodge2 = pick("闪避2.jpg")

        atk12 = pick("攻击12.jpg")
        atk22 = pick("攻击22.jpg", "攻击12.jpg")
        atk32 = pick("攻击32.jpg", "攻击12.jpg")

        sk12 = pick("技能12.jpg")
        sk22 = pick("技能22.jpg")
        sk32 = pick("技能32.jpg")

        jump_mask = pick("跳跃12.jpg", "跳跃2.jpg")
        jump_color = pick("跳跃11.jpg", "跳跃1.jpg")
        jumpatk_mask = pick("跳攻1.jpg")
        jumpatk_color = pick("跳攻2.jpg")

        walk_r = self.build_row_anim(walk2, 0, self.frame_w, self.frame_h, 6, True)
        walk_l = self.build_row_anim(walk2, 1, self.frame_w, self.frame_h, 6, True)
        idle_r = self.build_idle_from_walk(walk_r, "right")
        idle_l = self.build_idle_from_walk(walk_l, "left")

        atk1_r = self._build_atk1_anim(atk12, right_facing=True)
        atk1_l = self._build_atk1_anim(atk12, right_facing=False)

        atk2_r = self.build_row_anim(atk22, 0, self.frame_w, self.frame_h, 5, False)
        atk2_l = self.build_row_anim(atk22, 1, self.frame_w, self.frame_h, 5, False, True)

        atk3_r = self.build_row_anim(atk32, 0, self.frame_w, self.frame_h, 5, False)
        atk3_l = self.build_row_anim(atk32, 1, self.frame_w, self.frame_h, 5, False, True)

        # 4 / 5 / 6 的 body 只作为姿势来源
        skill_u_body_r = self._hold_first_frame(sk12, 0, 13)
        skill_u_body_l = self._hold_first_frame(sk12, 1, 13)

        skill_i_body_r = self._hold_first_frame(sk22, 0, 13)
        skill_i_body_l = self._hold_first_frame(sk22, 1, 13)

        skill_o_body_r = self._hold_first_frame(sk32, 0, 41)
        skill_o_body_l = self._hold_first_frame(sk32, 1, 41)

        hit_r = self.build_vertical_dir_anim(hit2, True, self.frame_w, self.frame_h)
        hit_l = self.build_vertical_dir_anim(hit2, False, self.frame_w, self.frame_h)

        defend_r = self.build_row_anim(defend2, 0, self.frame_w, self.frame_h, 8, False)
        defend_l = self.build_row_anim(defend2, 1, self.frame_w, self.frame_h, 8, False, True)

        dodge_r = self.build_row_anim(dodge2, 0, self.frame_w, self.frame_h, 5, False)
        dodge_l = self.build_row_anim(dodge2, 1, self.frame_w, self.frame_h, 5, False, True)

        jump_r = self.build_vertical_pair_anim(jump_mask, jump_color, True, self.frame_w, self.frame_h, 6, False)
        jump_l = self.build_vertical_pair_anim(jump_mask, jump_color, False, self.frame_w, self.frame_h, 6, False)
        jump_atk_r = self.build_vertical_pair_anim(jumpatk_mask, jumpatk_color, True, self.frame_w, self.frame_h, 6, False)
        jump_atk_l = self.build_vertical_pair_anim(jumpatk_mask, jumpatk_color, False, self.frame_w, self.frame_h, 6, False)

        for name, anim in {
            "idle_r": idle_r, "idle_l": idle_l,
            "walk_r": walk_r, "walk_l": walk_l,
            "atk1_r": atk1_r, "atk1_l": atk1_l,
            "atk2_r": atk2_r, "atk2_l": atk2_l,
            "atk3_r": atk3_r, "atk3_l": atk3_l,
            "skill_u_r": skill_u_body_r, "skill_u_l": skill_u_body_l,
            "skill_i_r": skill_i_body_r, "skill_i_l": skill_i_body_l,
            "skill_o_r": skill_o_body_r, "skill_o_l": skill_o_body_l,
            "hit_r": hit_r, "hit_l": hit_l,
            "defend_r": defend_r, "defend_l": defend_l,
            "dodge_r": dodge_r, "dodge_l": dodge_l,
            "jump_r": jump_r, "jump_l": jump_l,
            "jump_atk_r": jump_atk_r, "jump_atk_l": jump_atk_l,
        }.items():
            self.animator.add(name, anim)

        self.skill_u_sheet = SpriteSheet(sk12, colorkey=(255, 255, 255))
        self.skill_i_sheet = SpriteSheet(sk22, colorkey=(255, 255, 255))
        self.skill_o_sheet = SpriteSheet(sk32, colorkey=(255, 255, 255))

        # 预切缓存：避免柱间4前几次释放时每帧现场裁切 400x400 导致卡顿
        self.skill_u_cache_r = self._build_skill_u_cache(right=True)
        self.skill_u_cache_l = self._build_skill_u_cache(right=False)

        self.skill_i_body_keep_r, self.skill_i_body_keep_l = self._build_skill_i_keep_bodies(
            skill_i_body_r, skill_i_body_l, idle_r, idle_l
        )

        # 手动技能状态机：真实时间驱动
        self.manual_skill = {
            "name": None,
            "frame": 0,
        }
        self.manual_skill_total = {
            "skill_u": 13,
            "skill_i": 13,
            "skill_o": 41,
        }

        # 每推进一帧所需的毫秒数
        self.manual_skill_interval_ms = {
            "skill_u": 100,
            "skill_i": 80,
            "skill_o": 50,
        }

        self.manual_skill_last_ms = {
            "skill_u": 0,
            "skill_i": 0,
            "skill_o": 0,
        }

        self.manual_skill_last_applied_frame = -1

        self.state.set("idle")
        self.play_dir_anim("idle")

    def _safe_sheet_get(self, sheet, x, y, w, h):
        img_w = sheet.image.get_width()
        img_h = sheet.image.get_height()
        if x < 0 or y < 0 or x + w > img_w or y + h > img_h:
            return pygame.Surface((w, h), pygame.SRCALPHA)
        return sheet.get(x, y, w, h)

    def _hold_first_frame(self, path, row, total_frames):
        src = self.build_row_anim(path, row, self.frame_w, self.frame_h, 5, False, row == 1)
        frame = src.frames[0] if src.frames else pygame.Surface((80, 120), pygame.SRCALPHA)
        return Animation([frame] * total_frames, 1, False)

    def _build_atk1_anim(self, path, right_facing=True):
        sheet = SpriteSheet(path, colorkey=(255, 255, 255))
        y = 0 if right_facing else 120
        frames = []

        for i in range(4):
            src_x = i * 100
            frame = self._safe_sheet_get(sheet, src_x, y, 100, 120)

            canvas = pygame.Surface((120, 120), pygame.SRCALPHA)
            if right_facing:
                canvas.blit(frame, (10, 0))
            else:
                canvas.blit(frame, (0, 0))

            frames.append(canvas)

        return Animation(frames, 5, False)

    def _build_skill_u_cache(self, right=True):
        cache = [None] * 13

        for k in range(13):
            if right:
                if k <= 2:
                    cache[k] = None
                elif k <= 9:
                    cache[k] = self._safe_sheet_get(
                        self.skill_u_sheet,
                        240 + (k - 3) * 400, 0, 400, 400
                    ).copy()
                else:
                    cache[k] = self._safe_sheet_get(
                        self.skill_u_sheet,
                        2640, 0, 400, 400
                    ).copy()
            else:
                if k <= 2:
                    cache[k] = None
                elif k <= 9:
                    cache[k] = self._safe_sheet_get(
                        self.skill_u_sheet,
                        (9 - k) * 400, 400, 400, 400
                    ).copy()
                else:
                    cache[k] = self._safe_sheet_get(
                        self.skill_u_sheet,
                        0, 400, 400, 400
                    ).copy()

        return cache

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

    def _choose_visible_body_frame(self, preferred, fallback):
        if self._surface_has_visible_pixels(preferred):
            return preferred.copy()
        if self._surface_has_visible_pixels(fallback):
            return fallback.copy()
        return pygame.Surface((self.frame_w, self.frame_h), pygame.SRCALPHA)

    def _build_skill_i_keep_bodies(self, skill_i_body_r, skill_i_body_l, idle_r, idle_l):
        preferred_r = skill_i_body_r.frames[0] if skill_i_body_r and skill_i_body_r.frames else None
        preferred_l = skill_i_body_l.frames[0] if skill_i_body_l and skill_i_body_l.frames else None
        idle_r_frame = idle_r.frames[0] if idle_r and idle_r.frames else None
        idle_l_frame = idle_l.frames[0] if idle_l and idle_l.frames else None

        # 右向：优先用技能22的本体帧，不可见再回退到 idle
        body_r = self._choose_visible_body_frame(preferred_r, idle_r_frame)

        # 左向：你当前素材链里左向结果不对，直接镜像右向正确技能 pose
        body_l = pygame.transform.flip(body_r, True, False)

        # 如果镜像结果异常，再退回到左向素材 / idle
        if not self._surface_has_visible_pixels(body_l):
            body_l = self._choose_visible_body_frame(preferred_l, idle_l_frame)

        return body_r, body_l

    def _reset_manual_skill(self):
        name = self.manual_skill["name"]
        if name in self.manual_skill_last_ms:
            self.manual_skill_last_ms[name] = 0
        self.manual_skill["name"] = None
        self.manual_skill["frame"] = 0
        self.manual_skill_last_applied_frame = -1

    def start_action(self, state_name, anim_name=None):
        super().start_action(state_name, anim_name)

        if state_name in {"skill_u", "skill_i", "skill_o"}:
            self.manual_skill["name"] = state_name
            self.manual_skill["frame"] = 0
            self.manual_skill_last_applied_frame = -1
            self.manual_skill_last_ms[state_name] = pygame.time.get_ticks()

            self.action_frame = 0
            self.attack_box = None
            self.effect_box = None
            self.effect_sprite = None
            self.effect_draw_rect = None

    def get_action_total_frames(self, state_name):
        if state_name in {"skill_u", "skill_i", "skill_o"}:
            return self.manual_skill_total[state_name]
        return None

    def get_recovery_frames(self):
        return {}

    def get_damage_map(self):
        return {
            "atk1": 15,
            "atk2": 10,
            "atk3": 10,
            "jump_atk": 9,
            "skill_u": 30,
            "skill_i": 10,
            "skill_o": 10,
        }

    def get_knockback_map(self):
        return {
            "atk1": 18,
            "atk2": 24,
            "atk3": 30,
            "jump_atk": 16,
            "skill_u": 30,
            "skill_i": 26,
            "skill_o": 22,
        }

    def get_hitstun_map(self):
        return {
            "atk1": 10,
            "atk2": 13,
            "atk3": 16,
            "jump_atk": 10,
            "skill_u": 18,
            "skill_i": 15,
            "skill_o": 16,
        }

    def get_frame_events(self, state_name):
        if state_name == "atk1":
            return {6: {"body_hit": True}}
        if state_name == "atk2":
            return {2: {"body_hit": True}}
        if state_name == "atk3":
            return {3: {"body_hit": True}}
        if state_name == "jump_atk":
            return {0: {"body_hit": True}}

        if state_name == "dodge":
            return {
                1: {"move_dx": 115},
                2: {"move_dx": 95},
            }

        if state_name == "skill_u":
            return {i: {"effect_hit": True} for i in range(11, 14)}

        if state_name == "skill_i":
            return {i: {"effect_hit": True} for i in range(4, 14)}

        if state_name == "skill_o":
            return {i: {"effect_hit": True} for i in range(7, 42)}

        return {}

    def get_attack_box_for_state(self, state_name):
        if state_name == "atk1":
            return pygame.Rect(self.x + 30, self.y + 14, 78, 86) if self.dir == 1 else pygame.Rect(self.x - 78, self.y + 14, 78, 86)

        if state_name == "atk2":
            return pygame.Rect(self.x + 100, self.y + 14, 70, 82) if self.dir == 1 else pygame.Rect(self.x - 70, self.y + 14, 70, 82)

        if state_name == "atk3":
            return pygame.Rect(self.x + 104, self.y + 10, 82, 92) if self.dir == 1 else pygame.Rect(self.x - 82, self.y + 10, 82, 92)

        if state_name == "jump_atk":
            return pygame.Rect(self.x + 88, self.y + 16, 62, 74) if self.dir == 1 else pygame.Rect(self.x - 62, self.y + 16, 62, 74)

        return None

    def _apply_manual_skill_events(self):
        state = self.manual_skill["name"]
        if state is None:
            return

        self.attack_box = None
        events = self.get_frame_events(state)
        frame_events = events.get(self.action_frame, {})

        if self.manual_skill_last_applied_frame == self.action_frame:
            if frame_events.get("body_hit", False):
                self.attack_box = self.get_attack_box_for_state(state)
            return

        move_dx = frame_events.get("move_dx", 0)
        if move_dx != 0:
            self.x += move_dx if self.dir == 1 else -move_dx
            self.x = max(0, min(1420, self.x))

        if frame_events.get("body_hit", False):
            self.attack_box = self.get_attack_box_for_state(state)

        if frame_events.get("effect_hit", False):
            self.effect_action_serial += 1

        self.manual_skill_last_applied_frame = self.action_frame

    def _advance_manual_skill(self):
        state = self.manual_skill["name"]
        if state is None:
            return

        total = self.manual_skill_total[state]
        interval = self.manual_skill_interval_ms[state]
        now = pygame.time.get_ticks()

        while now - self.manual_skill_last_ms[state] >= interval and self.manual_skill["frame"] < total:
            self.manual_skill["frame"] += 1
            self.manual_skill_last_ms[state] += interval

        self.action_frame = self.manual_skill["frame"]

        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        self._apply_manual_skill_events()
        self.update_effect()

        if self.manual_skill["frame"] >= total and now - self.manual_skill_last_ms[state] >= interval:
            finished_state = self.state.state

            self.attack_box = None
            self.effect_box = None
            self.effect_sprite = None
            self.effect_draw_rect = None

            self._reset_manual_skill()

            if not self.start_recovery(finished_state):
                self.state.set("idle" if self.on_ground else "jump")
                self.play_dir_anim("idle" if self.on_ground else "jump")

    def update_effect(self):
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        state = self.state.state
        if state not in {"skill_u", "skill_i", "skill_o"}:
            return

        f = max(0, self.action_frame - 1)

        if state == "skill_u":
            k = min(f, 12)

            if self.dir == 1:
                img = self.skill_u_cache_r[k]
            else:
                img = self.skill_u_cache_l[k]

            if img is None:
                return

            self.effect_sprite = img
            self.effect_draw_rect = (self.x - 160, self.y - 280)

            if k >= 10:
                self.effect_box = pygame.Rect(self.x - 120, self.y - 240, 300, 320)

            return

        if state == "skill_i":
            k = min(f, 12)

            if self.dir == 1:
                old_x = self.x + 130
                if k <= 2:
                    return
                elif k <= 6:
                    img = self._safe_sheet_get(self.skill_i_sheet, 240 + (k - 3) * 200, 0, 200, 200)
                    pos = (old_x, self.y - 80)
                    self.effect_box = pygame.Rect(old_x + 20, self.y - 55, 150, 150)
                else:
                    img = self._safe_sheet_get(self.skill_i_sheet, 1040 + (k - 7) * 500, 0, 500, 200)
                    pos = (old_x, self.y - 80)
                    self.effect_box = pygame.Rect(old_x + 55, self.y - 55, 360, 150)
            else:
                old_x = self.x - 210
                if k <= 2:
                    return
                elif k <= 6:
                    img = self._safe_sheet_get(self.skill_i_sheet, 3000 + (6 - k) * 200, 200, 200, 200)
                    pos = (old_x, self.y - 80)
                    self.effect_box = pygame.Rect(old_x + 20, self.y - 55, 150, 150)
                else:
                    img = self._safe_sheet_get(self.skill_i_sheet, (12 - k) * 500, 200, 500, 200)
                    pos = (old_x - 300, self.y - 80)
                    self.effect_box = pygame.Rect(old_x - 215, self.y - 55, 360, 150)

            self.effect_sprite = img
            self.effect_draw_rect = pos
            return

        if state == "skill_o":
            k = min(f, 40)

            if self.dir == 1:
                if k <= 5:
                    img = self._safe_sheet_get(self.skill_o_sheet, 80 + k * 400, 0, 400, 600)
                    self.effect_sprite = img
                    self.effect_draw_rect = (self.x - 160, self.y - 480)
                    return
                else:
                    cycle_index = min(4, (k - 6) // 7)
                    cycle_frame = (k - 6) % 7
                    old_x = self.x + 200 + cycle_index * 200

                    base_img = self._safe_sheet_get(self.skill_o_sheet, 2080, 0, 400, 600)
                    canvas = pygame.Surface((900, 700), pygame.SRCALPHA)
                    canvas.blit(base_img, (0, 0))

                    if cycle_frame <= 2:
                        old_y = self.y + 100 * (cycle_frame + 1)
                        extra = self._safe_sheet_get(self.skill_o_sheet, 2480, 0, 400, 400)
                        canvas.blit(extra, (old_x - (self.x - 160), old_y - 580 - (self.y - 480)))
                        self.effect_box = pygame.Rect(old_x + 40, old_y - 540, 280, 260)
                    else:
                        extra = self._safe_sheet_get(self.skill_o_sheet, 2480 + (cycle_frame - 3) * 400, 0, 400, 400)
                        canvas.blit(extra, (old_x - (self.x - 160), self.y - 280 - (self.y - 480)))
                        self.effect_box = pygame.Rect(old_x + 40, self.y - 240, 280, 240)

                    self.effect_sprite = canvas
                    self.effect_draw_rect = (self.x - 160, self.y - 480)
                    return

            else:
                if k <= 5:
                    img = self._safe_sheet_get(self.skill_o_sheet, 2000 + (5 - k) * 400, 600, 400, 600)
                    self.effect_sprite = img
                    self.effect_draw_rect = (self.x - 160, self.y - 480)
                    return
                else:
                    cycle_index = min(4, (k - 6) // 7)
                    cycle_frame = (k - 6) % 7
                    old_x = self.x - 500 - cycle_index * 200

                    base_img = self._safe_sheet_get(self.skill_o_sheet, 2000, 600, 400, 600)
                    canvas = pygame.Surface((900, 700), pygame.SRCALPHA)
                    canvas.blit(base_img, (250, 0))

                    if cycle_frame <= 2:
                        old_y = self.y + 100 * (cycle_frame + 1)
                        extra = self._safe_sheet_get(self.skill_o_sheet, 1600, 600, 400, 400)
                        canvas.blit(extra, (old_x - (self.x - 410), old_y - 580 - (self.y - 480)))
                        self.effect_box = pygame.Rect(old_x + 40, old_y - 540, 280, 260)
                    else:
                        extra = self._safe_sheet_get(self.skill_o_sheet, 1600 - (cycle_frame - 3) * 400, 600, 400, 400)
                        canvas.blit(extra, (old_x - (self.x - 410), self.y - 280 - (self.y - 480)))
                        self.effect_box = pygame.Rect(old_x + 40, self.y - 240, 280, 240)

                    self.effect_sprite = canvas
                    self.effect_draw_rect = (self.x - 410, self.y - 480)
                    return

    def get_effect_hitbox(self):
        return self.effect_box

    def draw(self, screen):
        if self.state.state == "skill_i":
            # 柱间5：先画特效，再强制画专用本体帧，确保本体保留
            if self.effect_sprite is not None and self.effect_draw_rect is not None:
                screen.blit(self.effect_sprite, self.effect_draw_rect)

            body = self.skill_i_body_keep_r if self.dir == 1 else self.skill_i_body_keep_l
            screen.blit(body, (self.x, self.y))
            return

        hide_body = (
            (self.state.state == "skill_u" and self.action_frame >= 3 and self.effect_sprite is not None) or
            (self.state.state == "skill_o" and self.action_frame >= 2 and self.effect_sprite is not None)
        )

        if not hide_body:
            img = self.animator.get()
            if img:
                screen.blit(img, (self.x, self.y))

        if self.effect_sprite is not None and self.effect_draw_rect is not None:
            screen.blit(self.effect_sprite, self.effect_draw_rect)

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

        if self.state.state in {"skill_u", "skill_i", "skill_o"}:
            self._advance_manual_skill()
            return

        if self.state.state in {"atk1", "atk2", "atk3", "jump_atk", "dodge"}:
            self.handle_busy_state()
            return

        if dodge_just and self.can_start_neutral_ground_action(keys, left, right):
            self.start_action("dodge")
            return

        if keys[defend]:
            if self.state.state != "defend":
                self.state.set("defend")
                self.play_dir_anim("defend")
            else:
                self.play_dir_anim("defend")
            return

        if jump_just:
            if self.try_start_jump():
                return

        if not self.on_ground:
            if attack_just:
                self.start_action("jump_atk")
            else:
                self.state.set("jump")
                self.play_dir_anim("jump")
            return

        if u_just and self.can_start_neutral_ground_action(keys, left, right):
            self.start_action("skill_u")
            return

        if i_just and self.can_start_neutral_ground_action(keys, left, right):
            self.start_action("skill_i")
            return

        if o_just and self.can_start_neutral_ground_action(keys, left, right):
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