from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import textwrap

root = Path('/Users/carvicfranco/proserve_hub')
out = root / 'app_store_assets' / 'ios_6_5'
src = root / 'assets' / 'pitch'
out.mkdir(parents=True, exist_ok=True)

W, H = 1242, 2688

slides = [
    {
        'file':'01_find_contractors.png',
        'title':'Find Trusted\nLocal Pros',
        'subtitle':'Browse verified contractors, compare ratings, and hire with confidence.',
        'asset':'pin_card.png',
        'bg':((11,20,44),(19,84,122)),
        'accent':(56,189,248)
    },
    {
        'file':'02_get_quotes.png',
        'title':'Compare\nDetailed Quotes',
        'subtitle':'Request estimates and review transparent pricing before booking.',
        'asset':'estimate_card.png',
        'bg':((23,12,53),(89,49,151)),
        'accent':(167,139,250)
    },
    {
        'file':'03_track_profit.png',
        'title':'Track Jobs\nAnd Revenue',
        'subtitle':'Monitor milestones, payouts, and business performance in one place.',
        'asset':'profit_chart.png',
        'bg':((7,34,46),(8,99,117)),
        'accent':(45,212,191)
    },
    {
        'file':'04_check_reviews.png',
        'title':'Choose With\nReal Reviews',
        'subtitle':'See client feedback and reputation signals to pick the right pro.',
        'asset':'review_card.png',
        'bg':((37,15,60),(99,27,107)),
        'accent':(244,114,182)
    },
    {
        'file':'05_estimate_costs.png',
        'title':'Plan Smart\nProject Budgets',
        'subtitle':'Use cost insights to stay on track from quote to completion.',
        'asset':'cost_estimator.png',
        'bg':((17,23,58),(37,99,235)),
        'accent':(96,165,250)
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
    for p in cands:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()

f_title = pick_font(font_candidates, 112)
f_sub = pick_font(body_candidates, 44)
f_brand = pick_font(font_candidates, 40)

icon_path = root / 'assets' / 'icon' / 'icon-192.png'
icon = Image.open(icon_path).convert('RGBA').resize((78,78), Image.Resampling.LANCZOS) if icon_path.exists() else None

for s in slides:
    c1, c2 = s['bg']
    bg = Image.new('RGB', (W,H), c1)
    dr = ImageDraw.Draw(bg)
    for y in range(H):
        t = y/(H-1)
        r = int(c1[0]*(1-t)+c2[0]*t)
        g = int(c1[1]*(1-t)+c2[1]*t)
        b = int(c1[2]*(1-t)+c2[2]*t)
        dr.line([(0,y),(W,y)], fill=(r,g,b))

    glow = Image.new('RGBA', (W,H), (0,0,0,0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([W-540,-120,W+180,620], fill=(*s['accent'],70))
    gd.ellipse([-220,H-820,520,H-120], fill=(*s['accent'],55))
    glow = glow.filter(ImageFilter.GaussianBlur(55))
    bg = Image.alpha_composite(bg.convert('RGBA'), glow).convert('RGBA')

    draw = ImageDraw.Draw(bg)
    draw.multiline_text((86,120), s['title'], fill=(255,255,255,255), font=f_title, spacing=8)
    draw.multiline_text((86,400), textwrap.fill(s['subtitle'], width=43), fill=(228,236,248,255), font=f_sub, spacing=10)

    card_x, card_y = 68, 690
    card_w, card_h = W-136, 1760

    shadow = Image.new('RGBA', (card_w+80, card_h+80), (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([40,40,card_w+40,card_h+40], radius=72, fill=(0,0,0,135))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    bg.paste(shadow, (card_x-40, card_y-14), shadow)

    card = Image.new('RGBA', (card_w, card_h), (248,250,255,255))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0,0,card_w,card_h], radius=66, fill=(248,250,255,255))
    cd.rounded_rectangle([34,34,card_w-34,120], radius=28, fill=(240,244,252,255))
    cd.ellipse([56,56,72,72], fill=(148,163,184,255))
    cd.rounded_rectangle([92,54,360,80], radius=12, fill=(203,213,225,255))

    ap = src / s['asset']
    if ap.exists():
        shot = Image.open(ap).convert('RGBA')
        max_w, max_h = card_w-96, card_h-300
        scale = min(max_w/shot.width, max_h/shot.height)
        nw, nh = int(shot.width*scale), int(shot.height*scale)
        shot = shot.resize((nw, nh), Image.Resampling.LANCZOS)
        cd.rounded_rectangle([48,150,card_w-48,card_h-90], radius=42, fill=(255,255,255,255), outline=(228,234,246,255), width=3)
        sx = (card_w-nw)//2
        sy = 190 + max(0, ((card_h-320)-nh)//2)
        card.paste(shot, (sx, sy), shot)

    cd.rounded_rectangle([48, card_h-116, card_w-48, card_h-54], radius=24, fill=(235,242,255,255))

    mask = Image.new('L', (card_w, card_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,card_w,card_h], radius=66, fill=255)
    bg.paste(card, (card_x, card_y), mask)

    if icon:
        bg.paste(icon, (86, H-128), icon)
    draw.text((182, H-116), 'ProServeHub', fill=(243,248,255,255), font=f_brand)
    draw.text((W-300, H-108), 'iOS', fill=(207,222,241,255), font=f_brand)

    bg.convert('RGB').save(out / s['file'], format='PNG', optimize=True)

print('DONE')
for p in sorted(out.glob('*.png')):
    print(p)
