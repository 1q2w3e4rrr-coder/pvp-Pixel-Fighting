import os
import pygame

from core.animation import Animation
from core.animator import Animator
from core.sprite import SpriteSheet
from players.player import Player


class PlayerPain(Player):

    def __init__(self, x, y, is_p1=True):
        super().__init__(x, y, is_p1)

        self.frame_w = 80
        self.frame_h = 120
        base = "assets/人物图集/佩恩/"

        self.animator = Animator()

        def pick(*names):
            for name in names:
                path = base + name
                if os.path.exists(path):
                    return path
            raise FileNotFoundError(f"None of these files exist: {names}")

        walk2 = pick("行走动画2.jpg")

        # Pain 行走按 C++：
        # 右向移动只循环 80 / 160
        # 左向移动只循环 80 / 160
        # 左向待机固定 240
        walk_r = self._build_selected_walk_anim(walk2, row=0, cols=[1, 2], speed=6)
        walk_l = self._build_selected_walk_anim(walk2, row=1, cols=[1, 2], speed=6)
        idle_r = self._build_single_frame_anim(walk2, row=0, col=0)
        idle_l = self._build_single_frame_anim(walk2, row=1, col=3)

        atk1_r = self.build_row_anim(base + "攻击12.jpg", 0, self.frame_w, self.frame_h, 5, False)
        atk1_l = self.build_row_anim(base + "攻击12.jpg", 1, self.frame_w, self.frame_h, 5, False)
        atk2_r = self.build_row_anim(base + "攻击22.jpg", 0, self.frame_w, self.frame_h, 5, False)
        atk2_l = self.build_row_anim(base + "攻击22.jpg", 1, self.frame_w, self.frame_h, 5, False)
        atk3_r = self.build_row_anim(base + "攻击32.jpg", 0, self.frame_w, self.frame_h, 5, False)
        atk3_l = self.build_row_anim(base + "攻击32.jpg", 1, self.frame_w, self.frame_h, 5, False)

        skill_u_r = self.build_row_anim(base + "技能12.jpg", 0, self.frame_w, self.frame_h, 5, False)
        skill_u_l = self.build_row_anim(base + "技能12.jpg", 1, self.frame_w, self.frame_h, 5, False, True)
        skill_i_r = self.build_row_anim(base + "技能22.jpg", 0, self.frame_w, self.frame_h, 5, False)
        skill_i_l = self.build_row_anim(base + "技能22.jpg", 1, self.frame_w, self.frame_h, 5, False, True)

        # O 技能本体固定施法姿势，时长单独锁
        skill_o_src_r = self.build_row_anim(base + "技能32.jpg", 0, self.frame_w, self.frame_h, 5, False)
        skill_o_src_l = self.build_row_anim(base + "技能32.jpg", 1, self.frame_w, self.frame_h, 5, False, True)
        skill_o_r = Animation([skill_o_src_r.frames[0]] * 10, 1, False)
        skill_o_l = Animation([skill_o_src_l.frames[0]] * 10, 1, False)

        hit_r = self.build_vertical_dir_anim(base + "被打2.jpg", True, self.frame_w, self.frame_h)
        hit_l = self.build_vertical_dir_anim(base + "被打2.jpg", False, self.frame_w, self.frame_h)
        defend_r = self.build_vertical_dir_anim(base + "防御2.jpg", True, self.frame_w, self.frame_h, 8, True)
        defend_l = self.build_vertical_dir_anim(base + "防御2.jpg", False, self.frame_w, self.frame_h, 8, True)
        dodge_r = self.build_vertical_dir_anim(base + "闪避2.jpg", True, self.frame_w, self.frame_h, 5, False)
        dodge_l = self.build_vertical_dir_anim(base + "闪避2.jpg", False, self.frame_w, self.frame_h, 5, False)

        # jump / jump_atk 保留已经验证过的正确顺序
        jump_mask = pick("跳跃12.jpg", "跳跃2.jpg")
        jump_color = pick("跳跃11.jpg", "跳跃1.jpg")
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

        effect_sheet = SpriteSheet(base + "技能32.jpg", colorkey=(255, 255, 255))
        self.effect_frames_r = []
        self.effect_frames_l = []

        effect_w = 100
        effect_h = 270
        img_w = effect_sheet.image.get_width()
        for i in range(2):
            sx = 80 + i * 100
            if sx + effect_w <= img_w:
                frame = effect_sheet.get(sx, 0, effect_w, effect_h)
                self.effect_frames_r.append(frame)
                self.effect_frames_l.append(frame)

        if not self.effect_frames_r:
            blank = pygame.Surface((100, 270), pygame.SRCALPHA)
            self.effect_frames_r = [blank, blank]
            self.effect_frames_l = [blank, blank]

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

    def _build_single_frame_anim(self, path, row, col):
        sheet = SpriteSheet(path, colorkey=(255, 255, 255))
        y = row * self.frame_h
        x = col * self.frame_w
        frame = sheet.get(x, y, self.frame_w, self.frame_h)
        return Animation([frame], 10, True)

    def get_action_total_frames(self, state_name):
        if state_name == "skill_o":
            return 10
        return None

    def get_damage_map(self):
        return {
            "atk1": 10,
            "atk2": 10,
            "atk3": 10,
            "jump_atk": 5,
            "skill_u": 10,
            "skill_i": 30,
            "skill_o": 10,
        }

    def get_knockback_map(self):
        return {
            "atk1": 16,
            "atk2": 18,
            "atk3": 22,
            "jump_atk": 12,
            "skill_u": 18,
            "skill_i": 42,
            "skill_o": 20,
        }

    def get_hitstun_map(self):
        return {
            "atk1": 10,
            "atk2": 10,
            "atk3": 12,
            "jump_atk": 8,
            "skill_u": 12,
            "skill_i": 18,
            "skill_o": 14,
        }

    def get_frame_events(self, state_name):
        if state_name == "atk1":
            return {1: {"body_hit": True}}
        if state_name == "atk2":
            return {1: {"body_hit": True}}
        if state_name == "atk3":
            return {
                1: {"body_hit": True},
                2: {"body_hit": True},
            }
        if state_name == "jump_atk":
            return {0: {"body_hit": True}}
        if state_name == "dodge":
            return {1: {"move_dx": 300}}
        if state_name == "skill_u":
            return {3: {"body_hit": True}}
        if state_name == "skill_i":
            return {
                5: {"move_dx": 200, "body_hit": True},
                6: {"move_dx": 200, "body_hit": True},
            }
        # 按你前面确认过的 O：一根一根小 -> 大
        if state_name == "skill_o":
            return {
                2: {"effect_hit": True},
                4: {"effect_hit": True},
                6: {"effect_hit": True},
                8: {"effect_hit": True},
                10: {"effect_hit": True},
            }
        return {}

    def get_attack_box_for_state(self, state_name):
        if state_name == "atk1":
            return pygame.Rect(self.x + 82, self.y + 22, 60, 78) if self.dir == 1 else pygame.Rect(self.x - 60, self.y + 22, 60, 78)

        if state_name == "atk2":
            return pygame.Rect(self.x + 84, self.y + 18, 68, 84) if self.dir == 1 else pygame.Rect(self.x - 68, self.y + 18, 68, 84)

        if state_name == "atk3":
            return pygame.Rect(self.x + 88, self.y + 16, 74, 88) if self.dir == 1 else pygame.Rect(self.x - 74, self.y + 16, 74, 88)

        if state_name == "jump_atk":
            return pygame.Rect(self.x + 78, self.y + 18, 56, 72) if self.dir == 1 else pygame.Rect(self.x - 56, self.y + 18, 56, 72)

        if state_name == "skill_u":
            return pygame.Rect(self.x + 86, self.y + 14, 74, 92) if self.dir == 1 else pygame.Rect(self.x - 74, self.y + 14, 74, 92)

        if state_name == "skill_i":
            return pygame.Rect(self.x + 70, self.y - 84, 240, 92) if self.dir == 1 else pygame.Rect(self.x - 240, self.y - 84, 240, 92)

        return None

    def update_effect(self):
        self.effect_box = None
        self.effect_sprite = None
        self.effect_draw_rect = None

        if self.state.state != "skill_o":
            return

        local_frame = max(0, self.action_frame - 1)
        if local_frame > 9:
            local_frame = 9

        pillar_index = local_frame // 2
        phase = local_frame % 2

        base_offset = 100
        step_x = 100
        draw_y = self.y - 150

        if self.dir == 1:
            draw_x = self.x + base_offset + pillar_index * step_x
            frame = self.effect_frames_r[0] if phase == 0 else self.effect_frames_r[1]
        else:
            draw_x = self.x - base_offset - pillar_index * step_x
            frame = self.effect_frames_l[0] if phase == 0 else self.effect_frames_l[1]

        self.effect_sprite = pygame.transform.scale(frame, (110, 250))
        self.effect_draw_rect = (draw_x, draw_y + 22)
        self.effect_box = pygame.Rect(draw_x + 20, draw_y + 52, 70, 190)

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
            self.combo += 1
            if self.combo > 3:
                self.combo = 1
            self.start_action(f"atk{self.combo}")
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