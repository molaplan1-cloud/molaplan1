"""t172u: Molaplan's built-in room pictures – stylised flat illustrations drawn here from
simple shapes (own work, released CC0 1.0; no third-party material). Re-run to regenerate:

    python3 tool/rooms/gen_rooms.py

Writes assets/rooms/<id>_<light|dark>.webp (960×540, WebP q≈62).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

W, H = 960, 540
S = 2  # supersampling
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'rooms')

PAL = {
    'light': dict(wall=(236, 230, 220), wall2=(226, 218, 206), floor=(196, 172, 140), floor2=(184, 158, 124),
                  wood=(194, 150, 104), wood2=(170, 126, 84), accent=(86, 140, 156), accent2=(214, 120, 92),
                  soft=(250, 247, 240), dark=(70, 72, 78), green=(110, 160, 110), sky=(178, 212, 232),
                  sky2=(226, 238, 244), metal=(170, 176, 184), glow=(255, 226, 150)),
    'dark': dict(wall=(38, 44, 54), wall2=(32, 37, 46), floor=(58, 50, 44), floor2=(50, 43, 38),
                 wood=(102, 76, 56), wood2=(84, 62, 46), accent=(60, 110, 126), accent2=(150, 84, 66),
                 soft=(70, 76, 88), dark=(20, 22, 26), green=(52, 88, 64), sky=(24, 34, 58), sky2=(40, 52, 80),
                 metal=(96, 102, 112), glow=(255, 206, 120)),
}


def R(d, x0, y0, x1, y1, fill, r=0):
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S, fill=fill)


def E(d, x0, y0, x1, y1, fill):
    d.ellipse([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill)


def P(d, pts, fill):
    d.polygon([(x * S, y * S) for x, y in pts], fill=fill)


def L(d, x0, y0, x1, y1, fill, w=2):
    d.line([x0 * S, y0 * S, x1 * S, y1 * S], fill=fill, width=w * S)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def room(d, p, floor_y=380):
    for y in range(floor_y):
        L(d, 0, y, W, y, mix(p['wall'], p['wall2'], y / floor_y), 1)
    R(d, 0, floor_y, W, H, p['floor'])
    for i in range(0, W, 120):
        L(d, i, floor_y, i - 60, H, p['floor2'], 2)
    R(d, 0, floor_y - 6, W, floor_y, p['floor2'])


def window(d, p, x, y, w, h, night=False):
    R(d, x - 8, y - 8, x + w + 8, y + h + 8, p['soft'], 6)
    for yy in range(h):
        L(d, x, y + yy, x + w, y + yy, mix(p['sky'], p['sky2'], yy / h), 1)
    if night:
        E(d, x + w * 0.65, y + h * 0.2, x + w * 0.65 + 34, y + h * 0.2 + 34, p['glow'])
    L(d, x + w / 2, y, x + w / 2, y + h, p['soft'], 6)
    L(d, x, y + h / 2, x + w, y + h / 2, p['soft'], 6)


def plant(d, p, x, y, s=1.0):
    R(d, x - 22 * s, y - 40 * s, x + 22 * s, y, p['accent2'], 6)
    for a in range(-60, 61, 30):
        rad = math.radians(a - 90)
        E(d, x + math.cos(rad) * 46 * s - 16 * s, y - 50 * s + math.sin(rad) * 46 * s - 26 * s,
          x + math.cos(rad) * 46 * s + 16 * s, y - 50 * s + math.sin(rad) * 46 * s + 26 * s, p['green'])


def lamp(d, p, x, y):
    L(d, x, 0, x, y, p['dark'], 2)
    P(d, [(x - 34, y + 40), (x + 34, y + 40), (x + 18, y), (x - 18, y)], p['accent'])
    E(d, x - 10, y + 34, x + 10, y + 50, p['glow'])


def bedroom(d, p):
    room(d, p)
    window(d, p, 600, 80, 220, 170, night=True)
    R(d, 120, 230, 520, 400, p['wood2'], 18)
    R(d, 110, 300, 540, 420, p['accent'], 20)
    R(d, 150, 260, 270, 310, p['soft'], 16)
    R(d, 290, 260, 410, 310, p['soft'], 16)
    R(d, 110, 330, 540, 360, mix(p['accent'], p['soft'], 0.25), 8)
    R(d, 570, 320, 660, 400, p['wood'], 8)
    R(d, 598, 270, 632, 320, p['dark'], 4)
    P(d, [(585, 270), (645, 270), (630, 236), (600, 236)], p['glow'])


def kitchen(d, p):
    room(d, p, 400)
    R(d, 60, 70, 900, 180, p['soft'], 6)
    for x in range(60, 900, 140):
        R(d, x + 4, 74, x + 136, 176, mix(p['soft'], p['wood'], 0.25), 4)
        R(d, x + 60, 150, x + 80, 156, p['metal'], 3)
    R(d, 60, 250, 900, 270, p['dark'], 4)
    R(d, 60, 270, 900, 400, p['wood'], 4)
    for x in range(60, 900, 140):
        L(d, x, 270, x, 400, p['wood2'], 3)
        R(d, x + 60, 290, x + 80, 296, p['metal'], 3)
    R(d, 380, 232, 520, 250, p['metal'], 4)
    for x in (410, 470):
        E(d, x - 18, 236, x + 18, 248, p['dark'])
    for x in (300, 660):
        lamp(d, p, x, 190)
    plant(d, p, 800, 250, 0.6)


def living(d, p):
    room(d, p)
    window(d, p, 80, 70, 200, 190)
    R(d, 380, 90, 600, 220, p['soft'], 4)
    P(d, [(400, 200), (470, 130), (520, 175), (560, 140), (580, 200)], p['accent'])
    E(d, 300, 380, 760, 470, mix(p['floor'], p['accent2'], 0.45))
    R(d, 330, 260, 720, 330, p['accent2'], 26)
    R(d, 310, 300, 740, 380, mix(p['accent2'], p['dark'], 0.15), 22)
    R(d, 320, 380, 336, 400, p['dark'])
    R(d, 714, 380, 730, 400, p['dark'])
    L(d, 820, 140, 820, 380, p['dark'], 3)
    P(d, [(780, 160), (860, 160), (840, 110), (800, 110)], p['glow'])
    plant(d, p, 200, 390, 1.0)


def bathroom(d, p):
    room(d, p, 400)
    for x in range(0, W, 60):
        L(d, x, 0, x, 400, p['wall2'], 2)
    for y in range(0, 400, 60):
        L(d, 0, y, W, y, p['wall2'], 2)
    R(d, 120, 280, 560, 400, p['soft'], 40)
    R(d, 140, 270, 540, 300, mix(p['soft'], p['accent'], 0.25), 14)
    R(d, 500, 160, 512, 280, p['metal'], 4)
    R(d, 470, 160, 512, 172, p['metal'], 4)
    E(d, 640, 80, 820, 250, p['sky2'])
    R(d, 650, 280, 810, 330, p['soft'], 10)
    R(d, 700, 330, 760, 400, p['soft'], 6)
    R(d, 860, 150, 920, 300, p['accent'], 10)


def sauna(d, p):
    for y in range(0, 400, 28):
        R(d, 0, y, W, y + 26, mix(p['wood'], p['wood2'], (y % 56) / 56), 2)
    R(d, 0, 400, W, H, p['wood2'])
    R(d, 80, 230, 600, 260, p['wood'], 4)
    R(d, 80, 330, 680, 360, p['wood'], 4)
    for x in range(100, 600, 120):
        R(d, x, 260, x + 16, 330, p['wood2'])
    for x in range(100, 680, 140):
        R(d, x, 360, x + 16, 420, p['wood2'])
    R(d, 720, 240, 880, 420, p['dark'], 10)
    random.seed(7)
    for _ in range(22):
        x, y = random.randint(730, 860), random.randint(205, 245)
        E(d, x, y, x + 26, y + 20, mix(p['metal'], p['dark'], random.random() * 0.5))
    R(d, 740, 330, 860, 380, mix(p['dark'], p['glow'], 0.35), 6)
    R(d, 620, 380, 680, 440, p['wood'], 8)
    L(d, 650, 380, 690, 340, p['wood2'], 4)
    window(d, p, 260, 60, 160, 110)


def hallway(d, p):
    room(d, p, 400)
    P(d, [(0, 0), (240, 120), (240, 380), (0, 470)], p['wall2'])
    P(d, [(W, 0), (720, 120), (720, 380), (W, 470)], p['wall2'])
    R(d, 400, 140, 560, 380, p['wood'], 6)
    E(d, 530, 260, 544, 274, p['metal'])
    P(d, [(380, 400), (580, 400), (680, H), (280, H)], p['accent2'])
    L(d, 760, 150, 900, 150, p['dark'], 4)
    for x in (790, 840, 880):
        L(d, x, 150, x, 175, p['dark'], 3)
    R(d, 780, 175, 812, 280, p['accent'], 10)
    R(d, 830, 175, 864, 260, p['accent2'], 10)
    R(d, 60, 330, 200, 360, p['wood'], 4)
    lamp(d, p, 480, 60)


def garage(d, p):
    room(d, p, 420)
    R(d, 120, 70, 840, 420, p['metal'], 4)
    for y in range(80, 420, 40):
        L(d, 120, y, 840, y, mix(p['metal'], p['dark'], 0.25), 3)
    P(d, [(260, 400), (300, 320), (380, 290), (560, 290), (650, 330), (700, 400)], p['accent'])
    R(d, 240, 360, 720, 410, p['accent'], 16)
    for x in (320, 620):
        E(d, x - 34, 380, x + 34, 448, p['dark'])
        E(d, x - 14, 400, x + 14, 428, p['metal'])
    P(d, [(395, 300), (480, 300), (480, 336), (360, 336)], p['sky2'])
    P(d, [(495, 300), (555, 300), (620, 336), (495, 336)], p['sky2'])


def yard(d, p):
    for y in range(330):
        L(d, 0, y, W, y, mix(p['sky'], p['sky2'], y / 330), 1)
    E(d, 760, 50, 840, 130, p['glow'])
    P(d, [(0, 330), (W, 310), (W, H), (0, H)], p['green'])
    P(d, [(0, 420), (W, 380), (W, H), (0, H)], mix(p['green'], p['dark'], 0.15))
    R(d, 470, 190, 720, 340, p['accent2'])
    P(d, [(450, 200), (595, 110), (740, 200)], p['dark'])
    R(d, 570, 260, 620, 340, p['wood2'])
    R(d, 500, 220, 545, 260, p['sky2'])
    R(d, 645, 220, 690, 260, p['sky2'])
    for x in range(0, W, 36):
        R(d, x, 360, x + 20, 430, p['soft'], 3)
    L(d, 0, 380, W, 380, p['soft'], 6)
    L(d, 0, 410, W, 410, p['soft'], 6)
    R(d, 180, 230, 204, 380, p['wood2'])
    E(d, 110, 130, 280, 280, mix(p['green'], p['dark'], 0.25))
    E(d, 150, 100, 250, 200, mix(p['green'], p['dark'], 0.1))


def technical(d, p):
    room(d, p, 420)
    R(d, 140, 90, 330, 420, p['soft'], 60)
    R(d, 160, 130, 310, 160, p['metal'], 6)
    E(d, 205, 220, 265, 280, p['dark'])
    L(d, 235, 250, 252, 232, p['accent2'], 4)
    for y, c in ((120, p['accent2']), (170, p['accent'])):
        L(d, 330, y, 900, y, c, 14)
    L(d, 600, 120, 600, 420, p['accent2'], 14)
    L(d, 680, 170, 680, 420, p['accent'], 14)
    R(d, 740, 220, 900, 380, p['metal'], 8)
    for i in range(4):
        R(d, 756, 236 + i * 34, 884, 260 + i * 34, mix(p['metal'], p['dark'], 0.35), 4)
    E(d, 580, 260, 620, 300, p['soft'])
    E(d, 660, 300, 700, 340, p['soft'])


def office(d, p):
    room(d, p)
    window(d, p, 640, 70, 220, 170)
    R(d, 160, 260, 620, 280, p['wood'], 4)
    R(d, 180, 280, 200, 400, p['wood2'])
    R(d, 580, 280, 600, 400, p['wood2'])
    R(d, 300, 140, 480, 250, p['dark'], 8)
    R(d, 312, 152, 468, 238, p['accent'], 4)
    R(d, 380, 250, 400, 262, p['dark'])
    R(d, 680, 300, 800, 330, p['accent2'], 12)
    R(d, 690, 230, 790, 300, p['accent2'], 12)
    L(d, 740, 330, 740, 390, p['dark'], 6)
    R(d, 60, 90, 140, 250, p['wood'], 4)
    for i, c in enumerate((p['accent'], p['accent2'], p['soft'], p['green'])):
        R(d, 70 + i * 16, 110, 82 + i * 16, 160, c, 2)
    plant(d, p, 560, 255, 0.5)


def kids(d, p):
    room(d, p)
    random.seed(3)
    for _ in range(30):
        x, y = random.randint(20, 940), random.randint(20, 300)
        E(d, x, y, x + 8, y + 8, p['glow'])
    R(d, 520, 270, 860, 380, p['accent2'], 18)
    R(d, 540, 240, 640, 290, p['soft'], 14)
    R(d, 520, 220, 540, 400, p['wood'], 6)
    R(d, 840, 250, 860, 400, p['wood'], 6)
    for i, c in enumerate((p['accent'], p['accent2'], p['green'], p['glow'])):
        R(d, 140 + i * 66, 340, 200 + i * 66, 400, c, 8)
    R(d, 205, 280, 265, 340, p['accent'], 8)
    R(d, 271, 280, 331, 340, p['green'], 8)
    L(d, 380, 120, 380, 260, p['dark'], 2)
    E(d, 340, 40, 420, 130, p['accent2'])


def cottage(d, p):
    for y in range(300):
        L(d, 0, y, W, y, mix(p['sky'], p['sky2'], y / 300), 1)
    R(d, 0, 300, W, H, mix(p['accent'], p['sky'], 0.35))
    for i in range(12):
        L(d, 60 + i * 70, 340 + (i % 3) * 40, 110 + i * 70, 340 + (i % 3) * 40, p['sky2'], 2)
    P(d, [(0, 300), (300, 280), (420, 300)], mix(p['green'], p['dark'], 0.3))
    for x, h in ((60, 160), (130, 210), (200, 150), (760, 200), (830, 240), (900, 170)):
        P(d, [(x - 34, 300), (x + 34, 300), (x, 300 - h)], mix(p['green'], p['dark'], 0.35))
    P(d, [(560, 300), (W, 300), (W, 360), (520, 360)], p['green'])
    R(d, 600, 210, 760, 300, (176, 52, 44) if p is PAL['light'] else (120, 40, 36))
    P(d, [(586, 214), (680, 160), (774, 214)], p['dark'])
    R(d, 640, 240, 670, 270, p['soft'])
    R(d, 700, 250, 728, 300, p['soft'])
    R(d, 380, 330, 560, 342, p['wood'])
    for x in (400, 460, 520):
        R(d, x, 342, x + 8, 380, p['wood2'])
    E(d, 800, 50, 870, 120, p['glow'])


ROOMS = {
    'bedroom': bedroom, 'kitchen': kitchen, 'living': living, 'bathroom': bathroom, 'sauna': sauna,
    'hallway': hallway, 'garage': garage, 'yard': yard, 'technical': technical, 'office': office,
    'kids': kids, 'cottage': cottage,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for name, fn in ROOMS.items():
        for v, p in PAL.items():
            img = Image.new('RGB', (W * S, H * S), p['wall'])
            fn(ImageDraw.Draw(img), p)
            img = img.resize((W, H), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.4))
            path = os.path.join(OUT, f'{name}_{v}.webp')
            img.save(path, 'WEBP', quality=62, method=6)
            total += os.path.getsize(path)
            # Thumbnail for the picker.
            th = img.resize((240, 135), Image.LANCZOS)
            tp = os.path.join(OUT, f'{name}_{v}_thumb.webp')
            th.save(tp, 'WEBP', quality=60, method=6)
            total += os.path.getsize(tp)
    print(f'{len(ROOMS) * 2} pictures + thumbnails, {total / 1024:.0f} KiB')


if __name__ == '__main__':
    main()
