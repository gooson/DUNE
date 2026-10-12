"""Regenerate the single DUNE Watch workout design board from repo assets."""

from base64 import b64encode
from html import escape
from pathlib import Path
import math

import subprocess


ROOT = Path(__file__).resolve().parent
REPO_ROOT = next((p for p in (ROOT, *ROOT.parents) if (p / 'DUNEWatch').is_dir()), None)
if REPO_ROOT is None:
    raise RuntimeError('Run this script from inside the Health repository')
ASSETS = REPO_ROOT / 'DUNEWatch/Resources/Assets.xcassets/Equipment'
W, H = 374, 446  # Existing DUNE simulator screenshot pixel canvas, not watchOS points.
BG = '#030606'
PANEL = '#142025'
PANEL2 = '#223137'
WHITE = '#F4F8F7'
MUTED = '#A9BBBE'
TEAL = '#23D4CA'
HEART = '#FF6F88'
SAND = '#DBA881'
RED = '#FA5B62'


def t(x, y, value, size=16, color=WHITE, weight=600, anchor='start'):
    return (f'<text x="{x}" y="{y}" font-family="-apple-system, Apple SD Gothic Neo, Arial, sans-serif" '
            f'font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" fill="{color}">'
            f'{escape(str(value))}</text>')


def box(x, y, w, h, fill=PANEL, r=20):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"/>'


def line(x1, y1, x2, y2, color=PANEL2, width=1):
    return f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{width}"/>'


def equipment(name, x, y, size=42):
    path = ASSETS / f'equipment.{name}.imageset' / f'equipment.{name}.png'
    data = b64encode(path.read_bytes()).decode('ascii')
    return (box(x, y, size, size, PANEL2, 13)
            + f'<image x="{x+5}" y="{y+5}" width="{size-10}" height="{size-10}" '
              f'href="data:image/png;base64,{data}" filter="url(#sandIcon)"/>')


def shell(title, active=1, clock_size=18):
    s = box(0, 0, W, H, '#3B4448', 73) + box(5, 5, W-10, H-10, BG, 69)
    s += t(28, 48, title, 17, WHITE, 680)
    s += t(W-28, 48, '08:30', clock_size, WHITE, 720, 'end')
    if active is not None:
        for i in range(3):
            s += f'<circle cx="362" cy="{199+i*16}" r="{4 if i==active else 3}" fill="{WHITE if i==active else "#4D595B"}"/>'
    return s


def button(x, y, w, label, fill, color=WHITE, h=57, font=19):
    return box(x, y, w, h, fill, 27) + t(x+w/2, y+h/2+7, label, font, color, 720, 'middle')


def home():
    s = shell('오늘', None)
    s += t(28, 99, '오늘의 운동', 25, WHITE, 730)
    s += box(22, 117, 330, 192, PANEL, 29)
    s += equipment('barbell', 39, 136, 50)
    s += t(103, 162, '상체 근력', 20, WHITE, 720)
    s += t(103, 187, '6개 운동 · 약 35분', 14, MUTED, 540)
    s += line(42, 211, 332, 211)
    s += t(42, 247, '다음', 13, MUTED, 570)
    s += t(42, 278, '벤치 프레스', 19, WHITE, 650)
    s += t(327, 278, '4세트', 14, SAND, 650, 'end')
    s += button(22, 344, 330, '운동 시작', TEAL, BG)
    return s


def strength():
    s = shell('근력 운동', 1)
    s += equipment('barbell', 27, 75, 48)
    s += t(87, 98, '벤치 프레스', 20, WHITE, 700)
    s += t(87, 121, '2 / 4세트', 14, MUTED, 560)
    s += t(28, 184, '현재 세트', 14, MUTED, 590)
    s += t(27, 251, '60', 70, WHITE, 760)
    s += t(118, 246, 'kg', 26, MUTED, 630)
    s += t(175, 245, '×', 27, MUTED, 570)
    s += t(217, 251, '10', 70, WHITE, 760)
    s += line(28, 286, 344, 286)
    s += t(28, 316, '♥  108 bpm', 16, HEART, 650)
    s += t(342, 316, '지난 세트  60 kg × 10', 13, MUTED, 520, 'end')
    s += button(22, 350, 330, '세트 완료', TEAL, BG)
    return s


def rest():
    s = shell('휴식', 1)
    s += equipment('barbell', 27, 71, 44)
    s += t(83, 92, '벤치 프레스', 18, WHITE, 700)
    s += t(83, 115, '다음 3 / 4세트', 13, MUTED, 560)
    cx, cy, r = 187, 231, 97
    c = 2 * math.pi * r
    s += f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{PANEL2}" stroke-width="9"/>'
    s += (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{TEAL}" stroke-width="9" '
          f'stroke-linecap="round" stroke-dasharray="{c*.68:.1f} {c:.1f}" transform="rotate(-90 {cx} {cy})"/>')
    s += t(cx, 229, '0:44', 66, WHITE, 770, 'middle')
    s += t(cx, 261, '♥  94 bpm', 16, HEART, 630, 'middle')
    s += t(cx, 292, 'RPE 7  ›', 14, TEAL, 650, 'middle')
    s += button(22, 350, 156, '+30초', PANEL2, WHITE)
    s += button(190, 350, 162, '건너뛰기', TEAL, BG)
    return s


def cardio():
    s = shell('', 1)
    # Preview glyph for WorkoutActivityType+Icon.swift's running SF Symbol.
    s += '<circle cx="38" cy="29" r="3" fill="#DBA881"/>'
    s += '<path d="M 37 34 L 32 42 M 37 34 L 45 38 M 34 39 L 28 42 M 32 42 L 40 47" fill="none" stroke="#DBA881" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
    s += t(57, 48, '달리기', 17, WHITE, 680)
    s += t(28, 112, '경과 시간', 15, MUTED, 580)
    s += t(26, 191, '24:18', 73, WHITE, 760)
    s += line(28, 217, 342, 217)
    s += t(28, 252, '거리', 14, MUTED, 550)
    s += t(28, 300, '5.20', 43, WHITE, 700)
    s += t(131, 299, 'km', 18, MUTED, 570)
    s += t(219, 252, '심박', 14, MUTED, 550)
    s += t(219, 300, '148', 43, WHITE, 700)
    s += t(304, 299, 'bpm', 14, HEART, 590)
    s += box(28, 340, 314, 11, PANEL2, 6)
    s += box(28, 340, 186, 11, TEAL, 6)
    s += t(28, 386, '현재 구간  3 / 5', 15, TEAL, 630)
    s += t(342, 386, '›', 23, MUTED, 550, 'end')
    return s


def controls(paused=False, cardio=False):
    """Control hierarchy shared by X01/X02/X03; sizes are visual pixels."""
    s = shell('', None, 26)
    s += t(28, 53, '운동 제어', 32, WHITE, 710)
    s += t(28, 91, '달리기' if cardio else '상체 근력 · 2/6', 23, MUTED, 550)
    if cardio:
        s += box(22, 107, 330, 129, '#2B2719', 29)
        s += t(187, 178, '▶' if paused else 'Ⅱ', 43, '#F8C44B', 700, 'middle')
        s += t(187, 215, '운동 재개' if paused else '일시정지', 30, WHITE, 710, 'middle')
        s += box(22, 258, 330, 129, '#2A191D', 29)
        s += t(187, 329, '×', 53, RED, 520, 'middle')
        s += t(187, 366, '운동 종료', 30, WHITE, 710, 'middle')
        return s
    x1, x2, bw = 22, 199, 153
    s += box(x1, 107, bw, 150, '#2B2719', 28)
    s += t(x1+bw/2, 188, '▶' if paused else 'Ⅱ', 42, '#F8C44B', 700, 'middle')
    s += t(x1+bw/2, 231, '운동 재개' if paused else '일시정지', 29, WHITE, 710, 'middle')
    s += box(x2, 107, bw, 150, '#2A191D', 28)
    s += t(x2+bw/2, 184, '×', 54, RED, 520, 'middle')
    s += t(x2+bw/2, 231, '운동 종료', 29, WHITE, 710, 'middle')
    s += box(x1, 280, bw, 105, PANEL2, 26)
    s += t(x1+bw/2, 331, '»', 37, WHITE, 580, 'middle')
    s += t(x1+bw/2, 361, '건너뛰기', 25, WHITE, 650, 'middle')
    s += box(x2, 280, bw, 105, PANEL2, 26)
    s += t(x2+bw/2, 331, '↕', 33, WHITE, 580, 'middle')
    s += t(x2+bw/2, 361, '순서 변경', 25, WHITE, 650, 'middle')
    return s


def rpe():
    s = shell('운동 강도', 2)
    s += equipment('barbell', 27, 76, 45)
    s += t(84, 96, '벤치 프레스', 18, WHITE, 680)
    s += t(84, 119, '2세트 완료', 13, MUTED, 540)
    s += t(187, 181, 'RPE', 15, MUTED, 610, 'middle')
    s += t(187, 277, '7.0', 82, WHITE, 760, 'middle')
    s += box(28, 292, 72, 53, PANEL2, 24) + t(64, 329, '−', 29, WHITE, 640, 'middle')
    s += box(274, 292, 72, 53, PANEL2, 24) + t(310, 329, '+', 29, WHITE, 640, 'middle')
    s += button(22, 354, 330, 'RPE 저장', TEAL, BG)
    return s


def preview_error():
    """P05 direction: keep the workout preview visible with a concise inline error."""
    s = shell('운동 미리보기', None)
    s += t(28, 99, '상체 근력', 25, WHITE, 730)
    s += t(28, 124, '6개 운동 · 24세트', 16, MUTED, 540)
    s += box(22, 142, 330, 140, PANEL, 27)
    s += equipment('barbell', 39, 158, 39)
    s += t(91, 180, '벤치 프레스', 19, WHITE, 670)
    s += t(91, 201, '4 × 8 · 60 kg', 14, MUTED, 520)
    s += line(41, 211, 332, 211)
    s += equipment('dumbbell', 39, 224, 39)
    s += t(91, 248, '덤벨 컬', 19, WHITE, 670)
    s += t(329, 248, '외 4개', 14, MUTED, 540, 'end')
    s += box(22, 290, 330, 66, '#2C1B20', 18)
    s += '<circle cx="47" cy="323" r="13" fill="#FA5B62"/>'
    s += t(47, 329, '!', 18, BG, 750, 'middle')
    s += t(72, 318, '운동을 시작하지 못했어요', 18, WHITE, 650)
    s += t(72, 340, '잠시 후 다시 시도해 주세요', 14, '#E6BFC3', 520)
    s += button(22, 366, 330, '다시 시도', TEAL, BG, font=21)
    return s


def preview_workout():
    s = shell('운동 미리보기', None)
    s += t(28, 98, '상체 근력', 26, WHITE, 730)
    s += t(28, 125, '6개 운동 · 24세트', 16, MUTED, 540)
    s += box(22, 143, 330, 188, PANEL, 27)
    for i, (name, detail, asset) in enumerate([
        ('벤치 프레스', '4 × 8 · 60 kg', 'barbell'),
        ('스쿼트', '4 × 10 · 80 kg', 'barbell'),
        ('덤벨 컬', '3 × 12 · 12 kg', 'dumbbell'),
    ]):
        y = 157 + i * 57
        s += equipment(asset, 39, y, 40)
        s += t(91, y + 18, name, 18, WHITE, 660)
        s += t(91, y + 38, detail, 13, MUTED, 520)
    s += button(22, 350, 330, '운동 시작', TEAL, BG)
    return s


def summary(save_error=False):
    s = shell('운동 완료', None)
    s += t(28, 98, '상체 근력 완료', 25, WHITE, 720)
    s += t(28, 125, '오늘 · 6개 운동', 16, MUTED, 540)
    s += t(28, 194, '32:18', 63, WHITE, 760)
    s += t(28, 221, '총 운동 시간', 15, MUTED, 550)
    s += line(28, 242, 342, 242)
    s += t(28, 275, '완료 세트', 15, MUTED, 550)
    s += t(342, 275, '24세트', 20, WHITE, 680, 'end')
    s += t(28, 309, '운동 강도', 15, MUTED, 550)
    s += t(342, 309, '7 / 10', 20, WHITE, 680, 'end')
    if save_error:
        s += box(22, 318, 330, 39, '#2C1B20', 17)
        s += t(38, 344, '운동 기록을 저장하지 못했어요', 16, WHITE, 630)
        s += button(22, 363, 330, '다시 시도', TEAL, BG, h=49, font=19)
    else:
        s += button(22, 350, 330, '완료', TEAL, BG)
    return s


PANELS = [
    ('H01  오늘의 운동', home),
    ('P01  운동 미리보기', preview_workout),
    ('P05  시작 오류', preview_error),
    ('S01  현재 세트', strength),
    ('S09  휴식 타이머', rest),
    ('S10  RPE 입력', rpe),
    ('C01  유산소 지표', cardio),
    ('X01  근력 제어', controls),
    ('X02  일시정지 후', lambda: controls(paused=True)),
    ('X03  유산소 제어', lambda: controls(cardio=True)),
    ('F01  운동 완료', summary),
    ('F06  저장 오류', lambda: summary(save_error=True)),
]


def make():
    gap, margin, top = 40, 42, 85
    width = margin * 2 + W * 3 + gap * 2
    height = top + (H + 98) * 4 + 36
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{width}" height="{height}" viewBox="0 0 {width} {height}">']
    svg.append('<defs><filter id="sandIcon"><feColorMatrix type="matrix" values="0 0 0 0 .86  0 0 0 0 .66  0 0 0 0 .50  0 0 0 1 0"/></filter></defs>')
    svg.append(box(0, 0, width, height, '#0B1113', 0))
    svg.append(t(margin, 44, 'DUNE  /  WATCH FINAL DESIGN', 24, WHITE, 750))
    svg.append(t(width-margin, 44, '374 × 446 PX   ·   12 KEY STATES', 13, MUTED, 600, 'end'))
    for i, (label, fn) in enumerate(PANELS):
        x = margin + (i % 3) * (W + gap)
        y = top + (i // 3) * (H + 98)
        svg.append(f'<g transform="translate({x} {y})">{fn()}</g>')
        svg.append(t(x, y + H + 29, label, 15, SAND, 700))
    svg.append('</svg>')
    data = ''.join(svg)
    out = ROOT / 'watch-workout-design'
    out.with_suffix('.svg').write_text(data, encoding='utf-8')
    subprocess.run(['rsvg-convert', '-w', str(width*2), '-h', str(height*2),
                    '-o', str(out.with_suffix('.png')), str(out.with_suffix('.svg'))], check=True)
    print(out.with_suffix('.png'))


if __name__ == '__main__':
    make()
