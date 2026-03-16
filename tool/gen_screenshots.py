from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

os.makedirs('assets/screenshots', exist_ok=True)

# Brand colors
BG = (12, 17, 35)
CARD = (22, 30, 55)
ACCENT = (255, 152, 0)
WHITE = (255, 255, 255)
GRAY = (160, 170, 190)
GREEN = (76, 175, 80)
BLUE = (33, 150, 243)
RED = (244, 67, 54)

W, H = 1080, 1920

nav_items = ['Home', 'Jobs', 'Proof', 'Chat', 'Profile']

def load_fonts():
    try:
        return {
            'hero': ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 52),
            'title': ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 38),
            'subtitle': ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 30),
            'body': ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 26),
            'small': ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 22),
            'badge': ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 20),
            'big': ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 64),
        }
    except:
        d = ImageFont.load_default()
        return {k: d for k in ['hero','title','subtitle','body','small','badge','big']}

fonts = load_fonts()

def make_base(headline, subtext):
    img = Image.new('RGB', (W, H), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, W, 80], fill=(8, 12, 25))
    draw.rectangle([0, 80, W, 280], fill=CARD)
    try:
        icon = Image.open('assets/icon/icon-512.png').resize((80, 80), Image.LANCZOS)
        img.paste(icon, (40, 120), icon)
    except:
        pass
    draw.text((140, 120), headline, fill=WHITE, font=fonts['hero'])
    draw.text((140, 185), subtext, fill=ACCENT, font=fonts['subtitle'])
    return img, draw

def draw_card(draw, x, y, w, h, radius=20):
    draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, fill=CARD)

def draw_bottom(draw, headline_text, sub_text, active_nav=0):
    draw.rectangle([0, H-220, W, H-120], fill=(15, 20, 40))
    tw = fonts['title'].getlength(headline_text)
    draw.text((W//2 - tw//2, H-195), headline_text, fill=WHITE, font=fonts['title'])
    sw = fonts['body'].getlength(sub_text)
    draw.text((W//2 - sw//2, H-150), sub_text, fill=GRAY, font=fonts['body'])
    draw.rectangle([0, H-120, W, H], fill=(8, 12, 25))
    for i, item in enumerate(nav_items):
        nx = i * (W//5) + (W//10)
        itw = fonts['small'].getlength(item)
        col = ACCENT if i == active_nav else GRAY
        draw.text((nx - itw//2, H-70), item, fill=col, font=fonts['small'])
        if i == active_nav:
            draw.ellipse([nx-4, H-85, nx+4, H-77], fill=ACCENT)


# ============ SCREENSHOT 1: Dashboard ============
img, draw = make_base('Dashboard', 'Your business at a glance')

stats = [('Active Jobs', '5', ACCENT), ('Completed', '23', GREEN), ('Revenue', '$4,850', BLUE)]
card_w = 310
for i, (label, val, col) in enumerate(stats):
    cx = 40 + i * (card_w + 25)
    draw_card(draw, cx, 320, card_w, 160)
    draw.text((cx+25, 340), label, fill=GRAY, font=fonts['small'])
    draw.text((cx+25, 380), val, fill=col, font=fonts['big'])

jobs = [
    ('Kitchen Remodel', 'Sarah M.', 'In Progress', ACCENT),
    ('Bathroom Tile Install', 'James K.', 'In Progress', ACCENT),
    ('Deck Staining', 'Maria L.', 'Scheduled', BLUE),
    ('Roof Repair', 'Tom W.', 'Completed', GREEN),
    ('Fence Installation', 'Lisa P.', 'Completed', GREEN),
]

draw.text((40, 520), 'Recent Jobs', fill=WHITE, font=fonts['title'])

for i, (name, client, status, col) in enumerate(jobs):
    cy = 580 + i * 130
    draw_card(draw, 40, cy, W-80, 115)
    draw.text((70, cy+15), name, fill=WHITE, font=fonts['subtitle'])
    draw.text((70, cy+55), client, fill=GRAY, font=fonts['body'])
    sw2 = fonts['badge'].getlength(status) + 24
    draw.rounded_rectangle([W-70-sw2, cy+20, W-70, cy+52], radius=16, fill=col)
    draw.text((int(W-58-sw2), cy+24), status, fill=WHITE, font=fonts['badge'])

draw_bottom(draw, 'Manage Jobs Effortlessly', 'Track every project from start to finish', 0)
img.save('assets/screenshots/screenshot_1_dashboard.png', 'PNG')
print('Screenshot 1: Dashboard saved')


# ============ SCREENSHOT 2: AI Estimate ============
img, draw = make_base('AI Estimates', 'Generate quotes in seconds')

draw_card(draw, 40, 320, W-80, 300)
draw.text((W//2-80, 380), 'JOB PHOTO', fill=GRAY, font=fonts['title'])
draw.rounded_rectangle([W//2-60, 440, W//2+60, 510], radius=15, fill=(40, 50, 80))
draw.text((W//2-35, 460), 'SNAP', fill=ACCENT, font=fonts['body'])
draw.text((W//2 - fonts['small'].getlength('Upload job site photos')//2, 540), 'Upload job site photos', fill=GRAY, font=fonts['small'])

draw_card(draw, 40, 660, W-80, 180)
draw.text((70, 680), 'AI Analysis', fill=ACCENT, font=fonts['title'])
draw.text((70, 730), 'Scope: Interior painting, 3 rooms', fill=WHITE, font=fonts['body'])
draw.text((70, 770), 'Area: ~450 sq ft  |  Complexity: Medium', fill=GRAY, font=fonts['body'])

draw_card(draw, 40, 880, W-80, 420)
draw.text((70, 900), 'Generated Estimate', fill=GREEN, font=fonts['title'])
items = [('Labor (3 rooms)', '$1,200'), ('Materials (paint, primer)', '$380'), ('Prep & cleanup', '$150'), ('Equipment rental', '$75')]
for i, (item, price) in enumerate(items):
    iy = 960 + i * 55
    draw.text((70, iy), item, fill=WHITE, font=fonts['body'])
    pw = fonts['body'].getlength(price)
    draw.text((W-110-pw, iy), price, fill=WHITE, font=fonts['body'])
    if i < len(items)-1:
        draw.line([(70, iy+45), (W-110, iy+45)], fill=(40, 50, 80), width=1)

draw.line([(70, 1200), (W-110, 1200)], fill=ACCENT, width=2)
draw.text((70, 1220), 'TOTAL', fill=ACCENT, font=fonts['title'])
tw = fonts['title'].getlength('$1,805')
draw.text((W-110-tw, 1220), '$1,805', fill=ACCENT, font=fonts['title'])

draw.rounded_rectangle([40, 1340, W-40, 1420], radius=30, fill=ACCENT)
btw = fonts['title'].getlength('Send to Client')
draw.text((W//2 - btw//2, 1355), 'Send to Client', fill=WHITE, font=fonts['title'])

draw_bottom(draw, 'AI-Powered Estimates', 'From photos to quote in seconds', 1)
img.save('assets/screenshots/screenshot_2_ai_estimate.png', 'PNG')
print('Screenshot 2: AI Estimate saved')


# ============ SCREENSHOT 3: Proof Feed ============
img, draw = make_base('Proof Feed', 'Document your quality work')

proofs = [
    ('Kitchen Remodel - Day 3', '2:45 PM', 'Cabinets installed, countertop measured'),
    ('Bathroom Tile - Progress', '11:20 AM', 'Subway tile 70% complete, grouting tomorrow'),
    ('Deck Staining - Before', '9:15 AM', 'Pressure washed, ready for stain application'),
]

y_pos = 320
for i, (title, time, desc) in enumerate(proofs):
    draw_card(draw, 40, y_pos, W-80, 360)
    
    # Photo placeholder
    draw.rounded_rectangle([65, y_pos+20, W-65, y_pos+220], radius=12, fill=(35, 45, 70))
    draw.text((W//2 - 40, y_pos+100), 'PHOTO', fill=GRAY, font=fonts['body'])
    
    # Timestamp + GPS badge
    draw.text((65, y_pos+235), title, fill=WHITE, font=fonts['subtitle'])
    tw2 = fonts['small'].getlength(time)
    draw.text((W-65-tw2, y_pos+240), time, fill=GRAY, font=fonts['small'])
    draw.text((65, y_pos+275), desc, fill=GRAY, font=fonts['body'])
    
    # Tags
    tag_x = 65
    for tag, col in [('Timestamped', BLUE), ('Geotagged', GREEN)]:
        tag_w = fonts['badge'].getlength(tag) + 20
        draw.rounded_rectangle([tag_x, y_pos+315, tag_x+tag_w, y_pos+343], radius=12, fill=col)
        draw.text((tag_x+10, y_pos+319), tag, fill=WHITE, font=fonts['badge'])
        tag_x += tag_w + 10
    
    y_pos += 385

# Add photo button
draw.rounded_rectangle([W//2-120, y_pos+20, W//2+120, y_pos+80], radius=30, fill=ACCENT)
btw2 = fonts['subtitle'].getlength('+ Add Proof Photo')
draw.text((W//2 - btw2//2, y_pos+35), '+ Add Proof Photo', fill=WHITE, font=fonts['subtitle'])

draw_bottom(draw, 'Build Your Portfolio', 'Timestamped & geotagged proof of work', 2)
img.save('assets/screenshots/screenshot_3_proof_feed.png', 'PNG')
print('Screenshot 3: Proof Feed saved')


# ============ SCREENSHOT 4: Escrow Payments ============
img, draw = make_base('Payments', 'Secure escrow with Stripe')

# Balance card
draw_card(draw, 40, 320, W-80, 200)
draw.text((70, 345), 'Available Balance', fill=GRAY, font=fonts['subtitle'])
draw.text((70, 390), '$3,250.00', fill=GREEN, font=fonts['big'])
draw.rounded_rectangle([70, 460, 270, 500], radius=16, fill=GREEN)
btw3 = fonts['badge'].getlength('Withdraw')
draw.text((170 - btw3//2, 466), 'Withdraw', fill=WHITE, font=fonts['badge'])

draw.rounded_rectangle([290, 460, 530, 500], radius=16, fill=BLUE)
btw4 = fonts['badge'].getlength('View History')
draw.text((410 - btw4//2, 466), 'View History', fill=WHITE, font=fonts['badge'])

# Pending escrow
draw.text((40, 560), 'Escrow Payments', fill=WHITE, font=fonts['title'])

payments = [
    ('Kitchen Remodel', 'Sarah M.', '$2,400', 'In Escrow', ACCENT),
    ('Bathroom Tile', 'James K.', '$1,800', 'In Escrow', ACCENT),
    ('Deck Staining', 'Maria L.', '$950', 'Released', GREEN),
    ('Roof Repair', 'Tom W.', '$3,200', 'Released', GREEN),
    ('Fence Install', 'Lisa P.', '$1,650', 'Released', GREEN),
]

for i, (name, client, amount, status, col) in enumerate(payments):
    cy = 620 + i * 120
    draw_card(draw, 40, cy, W-80, 105)
    draw.text((70, cy+12), name, fill=WHITE, font=fonts['subtitle'])
    draw.text((70, cy+50), client, fill=GRAY, font=fonts['small'])
    
    aw = fonts['subtitle'].getlength(amount)
    draw.text((W-90-aw, cy+12), amount, fill=WHITE, font=fonts['subtitle'])
    
    stw = fonts['badge'].getlength(status) + 24
    draw.rounded_rectangle([W-90-stw, cy+50, W-90, cy+80], radius=12, fill=col)
    draw.text((int(W-78-stw), cy+54), status, fill=WHITE, font=fonts['badge'])

# How it works
draw.text((40, 1250), 'How Escrow Works', fill=ACCENT, font=fonts['title'])
steps = [
    '1. Client books job & pays upfront',
    '2. Funds held securely by Stripe',
    '3. You complete the job with proof',
    '4. Funds released to your account',
]
for i, step in enumerate(steps):
    draw.text((70, 1305 + i * 40), step, fill=GRAY, font=fonts['body'])

draw_bottom(draw, 'Get Paid, Guaranteed', 'Secure escrow protects both sides', 0)
img.save('assets/screenshots/screenshot_4_payments.png', 'PNG')
print('Screenshot 4: Payments saved')

print('\nAll 4 screenshots generated in assets/screenshots/')
