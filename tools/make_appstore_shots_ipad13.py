from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import textwrap

root = Path('/Users/carvicfranco/proserve_hub')
out = root / 'app_store_assets' / 'ios_ipad_13_2064x2752'
src = root / 'assets' / 'pitch'
out.mkdir(parents=True, exist_ok=True)

W, H = 2064, 2752

slides = [
    {
        'file': '01_find_contractors.png',
        'title': 'Find Trusted\nLocal Pros',
        'subtitle': 'Browse verified contractors, compare ratings, and hire with confidence.',
        'asset': 'pin_card.png',
        'bg': ((11, 20, 44), (19, 84, 122)),
        'accent': (56, 189, 248)
    },
    {
        'file': '02_get_quotes.png',
        'title': 'Compare\nDetailed Quotes',
        'subtitle': 'Request estimates and review transparent pricing before booking.',
        'asset': 'estimate_card.png',
        'bg': ((23, 12, 53), (89, 49, 151)),
        'accent': (167, 139, 250)
    },
    {
        'file': '03_track_profit.png',
        'title': 'Track Jobs\nAnd Revenue',
        'subtitle': 'Monitor milestones, payouts, and business performance in one place.',
        'asset': 'profit_chart.png',
        'bg': ((7, 34, 46), (8, 99, 117)),
        'accent': (45, 212, 191)
    },
    {
        'file': '04_check_reviews.png',
        'title': 'Choose With\nReal Reviews',
        'subtitle': 'See client feedback and reputation signals to pick the right pro.',
        'asset': 'review_card.png',
        'bg': ((37, 15, 60), (99, 27, 107)),
        'accent': (244, 114, 182)
    },
    {
        'file': '05_estimate_costs.png',
        'title': 'Plan Smart\nProject Budgets',
        'subtitle': 'Use cost insights to stay on track from quote to completion.',
        'asset': 'cost_estimator.png',
        'bg': ((17, 23, 58), (37, 99, 235)),
        'accent': (96, 165, 250)
    },
]

font_candidates = [
    '/System/Library/Fonts/SFNS.ttf',
    '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
]
body_candidates = [
    '/System/Library/Fonts/Supplemental/Arial.ttf',
]


def pick_font(cands, size):
    for path in cands:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


f_title = pick_font(font_candidates, 176)
f_sub = pick_font(body_candidates, 64)
f_brand = pick_font(font_candidates, 58)

icon_path = root / 'assets' / 'icon' / 'icon-192.png'
icon = Image.open(icon_path).convert('RGBA').resize((116, 116), Image.Resampling.LANCZOS) if icon_path.exists() else None

for slide in slides:
    c1, c2 = slide['bg']
    bg = Image.new('RGB', (W, H), c1)
    draw_bg = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / (H - 1)
        r = int(c1[0] * (1 - t) + c2[0] * t)
        g = int(c1[1] * (1 - t) + c2[1] * t)
        b = int(c1[2] * (1 - t) + c2[2] * t)
        draw_bg.line([(0, y), (W, y)], fill=(r, g, b))

    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse([W - 900, -220, W + 320, 950], fill=(*slide['accent'], 70))
    glow_draw.ellipse([-360, H - 1200, 900, H - 180], fill=(*slide['accent'], 55))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    bg = Image.alpha_composite(bg.convert('RGBA'), glow).convert('RGBA')

    draw = ImageDraw.Draw(bg)
    draw.multiline_text((140, 170), slide['title'], fill=(255, 255, 255, 255), font=f_title, spacing=12)
    draw.multiline_text(
        (140, 610),
        textwrap.fill(slide['subtitle'], width=42),
        fill=(228, 236, 248, 255),
        font=f_sub,
        spacing=14,
    )

    card_x, card_y = 112, 980
    card_w, card_h = W - 224, 1620

    shadow = Image.new('RGBA', (card_w + 120, card_h + 120), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle([60, 60, card_w + 60, card_h + 60], radius=86, fill=(0, 0, 0, 130))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    bg.paste(shadow, (card_x - 60, card_y - 20), shadow)

    card = Image.new('RGBA', (card_w, card_h), (248, 250, 255, 255))
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle([0, 0, card_w, card_h], radius=78, fill=(248, 250, 255, 255))
    card_draw.rounded_rectangle([42, 42, card_w - 42, 152], radius=34, fill=(240, 244, 252, 255))
    card_draw.ellipse([70, 66, 92, 88], fill=(148, 163, 184, 255))
    card_draw.rounded_rectangle([118, 64, 520, 92], radius=14, fill=(203, 213, 225, 255))

    asset_path = src / slide['asset']
    if asset_path.exists():
        shot = Image.open(asset_path).convert('RGBA')
        max_w, max_h = card_w - 140, card_h - 320
        scale = min(max_w / shot.width, max_h / shot.height)
        new_w, new_h = int(shot.width * scale), int(shot.height * scale)
        shot = shot.resize((new_w, new_h), Image.Resampling.LANCZOS)
        card_draw.rounded_rectangle(
            [70, 188, card_w - 70, card_h - 96],
            radius=48,
            fill=(255, 255, 255, 255),
            outline=(228, 234, 246, 255),
            width=4,
        )
        sx = (card_w - new_w) // 2
        sy = 230 + max(0, ((card_h - 380) - new_h) // 2)
        card.paste(shot, (sx, sy), shot)

    card_draw.rounded_rectangle([70, card_h - 128, card_w - 70, card_h - 62], radius=28, fill=(235, 242, 255, 255))

    mask = Image.new('L', (card_w, card_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, card_w, card_h], radius=78, fill=255)
    bg.paste(card, (card_x, card_y), mask)

    if icon:
        bg.paste(icon, (140, H - 168), icon)
    draw.text((284, H - 150), 'ProServeHub', fill=(243, 248, 255, 255), font=f_brand)
    draw.text((W - 290, H - 140), 'iPad', fill=(207, 222, 241, 255), font=f_brand)

    bg.convert('RGB').save(out / slide['file'], format='PNG', optimize=True)

print('DONE')
for path in sorted(out.glob('*.png')):
    with Image.open(path) as image:
        print(f'{path} -> {image.width}x{image.height}')