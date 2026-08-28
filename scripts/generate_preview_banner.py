import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
ICON_PATH = os.path.join(PROJECT_ROOT, "assets", "branding", "FrogDropIcon.png")
OUTPUT_PREVIEW = os.path.join(PROJECT_ROOT, "assets", "branding", "preview.png")

def render_preview_banner():
    # 16:9 Aspect Ratio (1400 x 788)
    W, H = 1400, 788
    
    # 1. Base Gradient Canvas
    img = Image.new("RGBA", (W, H), (11, 15, 23, 255))
    gradient = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(gradient)
    for y in range(H):
        r = int(11 + (y / H) * 8)
        g = int(15 + (y / H) * 12)
        b = int(23 + (y / H) * 16)
        g_draw.line([(0, y), (W, y)], fill=(r, g, b, 255))
    img = Image.alpha_composite(img, gradient)

    # 2. Ambient Mesh Glows
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Top center emerald glow
    glow_draw.ellipse([W//2 - 280, -60, W//2 + 280, 240], fill=(16, 185, 129, 40))
    # Left cyan ambient
    glow_draw.ellipse([80, 220, 520, 680], fill=(6, 182, 212, 25))
    # Right purple ambient
    glow_draw.ellipse([W - 520, 220, W - 80, 680], fill=(139, 92, 246, 25))
    # Center bottom glow
    glow_draw.ellipse([W//2 - 250, H - 180, W//2 + 250, H], fill=(16, 185, 129, 30))
    
    glow = glow.filter(ImageFilter.GaussianBlur(55))
    img = Image.alpha_composite(img, glow)

    # 3. Typography Fonts (Apple SF Pro / Helvetica)
    font_candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf"
    ]
    
    f_title = None
    f_sub = None
    f_card_title = None
    f_card_body = None
    f_badge = None
    f_btn = None
    
    for fpath in font_candidates:
        try:
            f_title = ImageFont.truetype(fpath, 46)
            f_sub = ImageFont.truetype(fpath, 18)
            f_card_title = ImageFont.truetype(fpath, 19)
            f_card_body = ImageFont.truetype(fpath, 14)
            f_card_sub = ImageFont.truetype(fpath, 12)
            f_badge = ImageFont.truetype(fpath, 12)
            f_btn = ImageFont.truetype(fpath, 16)
            break
        except Exception:
            continue
            
    if not f_title:
        f_title = ImageFont.load_default()
        f_sub = ImageFont.load_default()
        f_card_title = ImageFont.load_default()
        f_card_body = ImageFont.load_default()
        f_card_sub = ImageFont.load_default()
        f_badge = ImageFont.load_default()
        f_btn = ImageFont.load_default()

    # 4. Header Section (Frog Icon + Title + Badges)
    try:
        if os.path.exists(ICON_PATH):
            frog = Image.open(ICON_PATH).convert("RGBA")
            isize = 72
            frog = frog.resize((isize, isize), Image.Resampling.LANCZOS)
            img.paste(frog, (W // 2 - isize // 2, 34), frog)
    except Exception as e:
        print("Icon load error:", e)

    draw = ImageDraw.Draw(img)

    # Title: FrogDrop
    title_text = "FrogDrop"
    tb = draw.textbbox((0, 0), title_text, font=f_title)
    tw = tb[2] - tb[0]
    draw.text((W // 2 - tw // 2, 114), title_text, font=f_title, fill=(245, 250, 255, 255))

    # Subtitle
    sub_text = "A tiny frog in your Menu Bar • A powerful native productivity layer on your Mac"
    sb = draw.textbbox((0, 0), sub_text, font=f_sub)
    sw = sb[2] - sb[0]
    draw.text((W // 2 - sw // 2, 172), sub_text, font=f_sub, fill=(156, 175, 196, 255))

    # Pill Badges Ribbon
    badges = [
        ("Native Swift 5.9 & AppKit", (16, 185, 129)),
        ("100% Local-First", (56, 189, 248)),
        ("Apple Neural Engine (OCR)", (168, 85, 247)),
        ("Zero Subscriptions", (245, 158, 11))
    ]
    
    # Measure total width
    badge_widths = []
    for btext, _ in badges:
        bb = draw.textbbox((0, 0), btext, font=f_badge)
        badge_widths.append(bb[2] - bb[0] + 24)
    
    total_badge_w = sum(badge_widths) + (len(badges) - 1) * 12
    bx = (W - total_badge_w) // 2
    by = 210
    
    for (btext, bcol), bw in zip(badges, badge_widths):
        bh = 26
        # Dark pill container with vibrant border and subtle background
        draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=13, fill=(17, 24, 39, 220), outline=(*bcol, 160), width=1)
        draw.text((bx + 12, by + 5), btext, font=f_badge, fill=(*bcol, 255))
        bx += bw + 12

    # 5. Three Glassmorphic Feature Cards
    card_w = 384
    card_h = 405
    card_y = 260
    spacing = 28
    total_w = 3 * card_w + 2 * spacing
    start_x = (W - total_w) // 2

    cards_data = [
        {
            "header": "Smart Floating Shelf",
            "tag": "ZERO-PERMISSION",
            "accent": (16, 185, 129),
            "items": [
                ("Shake-to-Drop Gesture", "Wiggle cursor to summon floating card deck"),
                ("QuickLook Previews", "Tap Spacebar for instant native preview"),
                ("On-Device Vision OCR", "1-click text extraction from screenshots"),
                ("AVIF & WebP Optimizer", "70%+ file size reduction & EXIF stripper"),
                ("PDF Toolkit & Eyedropper", "Combine PDFs & sample screen colors")
            ]
        },
        {
            "header": "Focus & Ambient Suite",
            "tag": "OFFLINE AUDIO",
            "accent": (56, 189, 248),
            "items": [
                ("Glowing Radial Timer", "Smooth animated ring with 1-tap presets"),
                ("Procedural Soundscapes", "Rain, Forest, Ocean & 40Hz Focus beats"),
                ("Gamified Evolution", "Streaks evolve frog (Tadpole to King Frog)"),
                ("Dynamic Focus Pill HUD", "Glanceable PiP overlay over full-screen apps"),
                ("Blooming Dashboard", "Daily progress flower visualizer")
            ]
        },
        {
            "header": "Clipboard History",
            "tag": "LOCAL & ENCRYPTED",
            "accent": (168, 85, 247),
            "items": [
                ("Frosted HUD Preview", "Hover to inspect full multi-line snippets"),
                ("In-Place Text Editor", "Edit & modify copied text before pasting"),
                ("Fuzzy Search Highlight", "Instant green keyword matches across history"),
                ("App Privacy Exclusion", "Auto-ignore 1Password, Bitwarden & keys"),
                ("Pinning & Expiry Rules", "Custom retention with 1-click TinyURL")
            ]
        }
    ]

    for idx, cdata in enumerate(cards_data):
        cx = start_x + idx * (card_w + spacing)
        col = cdata["accent"]
        
        # Card Background (Dark Glass)
        card_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        c_draw = ImageDraw.Draw(card_layer)
        c_draw.rounded_rectangle(
            [cx, card_y, cx + card_w, card_y + card_h],
            radius=18,
            fill=(17, 24, 39, 235),
            outline=(*col, 100),
            width=1
        )
        
        # Header background inside card
        c_draw.rounded_rectangle(
            [cx, card_y, cx + card_w, card_y + 56],
            radius=18,
            fill=(*col, 18)
        )
        img = Image.alpha_composite(img, card_layer)
        draw = ImageDraw.Draw(img)

        # Card Title
        draw.text((cx + 18, card_y + 17), cdata["header"], font=f_card_title, fill=(245, 250, 255, 255))

        # Tag
        tag_text = cdata["tag"]
        tb = draw.textbbox((0, 0), tag_text, font=f_badge)
        tag_w = tb[2] - tb[0] + 16
        draw.rounded_rectangle([cx + card_w - tag_w - 16, card_y + 15, cx + card_w - 16, card_y + 37], radius=6, fill=(*col, 35), outline=(*col, 140), width=1)
        draw.text((cx + card_w - tag_w - 8, card_y + 19), tag_text, font=f_badge, fill=(*col, 255))

        # Divider
        draw.line([(cx + 18, card_y + 56), (cx + card_w - 18, card_y + 56)], fill=(255, 255, 255, 18), width=1)

        # Items
        item_y = card_y + 72
        for title, desc in cdata["items"]:
            # Circular indicator
            draw.ellipse([cx + 20, item_y + 4, cx + 28, item_y + 12], fill=(*col, 220))
            # Title
            draw.text((cx + 36, item_y), title, font=f_card_body, fill=(245, 250, 255, 255))
            # Description
            draw.text((cx + 36, item_y + 20), desc, font=f_card_sub, fill=(156, 175, 196, 230))
            item_y += 60

    # 6. Bottom Banner CTA: YouTube Demo Watch
    btn_w = 460
    btn_h = 46
    btn_x = (W - btn_w) // 2
    btn_y = H - 90

    # Glow under button
    btn_glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(btn_glow)
    bg_draw.rounded_rectangle([btn_x - 12, btn_y - 6, btn_x + btn_w + 12, btn_y + btn_h + 6], radius=24, fill=(16, 185, 129, 65))
    btn_glow = btn_glow.filter(ImageFilter.GaussianBlur(16))
    img = Image.alpha_composite(img, btn_glow)
    draw = ImageDraw.Draw(img)

    # Button body
    draw.rounded_rectangle(
        [btn_x, btn_y, btn_x + btn_w, btn_y + btn_h],
        radius=23,
        fill=(13, 20, 28, 250),
        outline=(16, 185, 129, 200),
        width=1
    )

    # Play Icon triangle
    px = btn_x + 30
    py = btn_y + 15
    draw.polygon([(px, py), (px + 14, py + 8), (px, py + 16)], fill=(16, 185, 129, 255))

    # Button text
    btn_text = "Watch Full 1080p 60fps Interactive Video Demo →"
    draw.text((px + 24, btn_y + 13), btn_text, font=f_btn, fill=(245, 250, 255, 255))

    # Save output
    os.makedirs(os.path.dirname(OUTPUT_PREVIEW), exist_ok=True)
    img.save(OUTPUT_PREVIEW, format="PNG", optimize=True)
    print(f"✅ Generated Retina 16:9 Showcase Banner at: {OUTPUT_PREVIEW} ({W}x{H})")

if __name__ == "__main__":
    render_preview_banner()
