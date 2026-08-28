import os
import subprocess
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
ICON_PATH = os.path.join(PROJECT_ROOT, "assets", "branding", "FrogDropIcon.png")
DEFAULT_OUTPUT_DIR = os.path.join(PROJECT_ROOT, "assets", "dmg")

def render_background_layer(scale=1):
    w = int(500 * scale)
    h = int(300 * scale)
    
    # 1. Dark Gradient Canvas
    img = Image.new("RGBA", (w, h), (13, 17, 23, 255))
    gradient = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(gradient)
    for y in range(h):
        r = int(14 - (y / h) * 6)
        g = int(20 - (y / h) * 10)
        b = int(28 - (y / h) * 14)
        g_draw.line([(0, y), (w, y)], fill=(r, g, b, 255))
    img = Image.alpha_composite(img, gradient)

    # 2. Ambient Radial Glows
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Top center glow
    glow_draw.ellipse(
        [int(250 * scale - 140 * scale), int(40 * scale - 80 * scale), 
         int(250 * scale + 140 * scale), int(40 * scale + 80 * scale)], 
        fill=(16, 185, 129, 35)
    )
    # Left dropzone glow
    glow_draw.ellipse(
        [int(130 * scale - 70 * scale), int(170 * scale - 70 * scale), 
         int(130 * scale + 70 * scale), int(170 * scale + 70 * scale)], 
        fill=(16, 185, 129, 28)
    )
    # Right dropzone glow
    glow_draw.ellipse(
        [int(370 * scale - 70 * scale), int(170 * scale - 70 * scale), 
         int(370 * scale + 70 * scale), int(170 * scale + 70 * scale)], 
        fill=(56, 189, 248, 28)
    )
    # Center arrow glow
    glow_draw.ellipse(
        [int(250 * scale - 50 * scale), int(170 * scale - 35 * scale), 
         int(250 * scale + 50 * scale), int(170 * scale + 35 * scale)], 
        fill=(45, 212, 191, 40)
    )
    glow = glow.filter(ImageFilter.GaussianBlur(int(22 * scale)))
    img = Image.alpha_composite(img, glow)

    # 3. Fine Dot Pattern
    dot_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dot_draw = ImageDraw.Draw(dot_layer)
    step = int(24 * scale)
    for x in range(step, w, step):
        for y in range(step, h, step):
            dot_draw.point((x, y), fill=(255, 255, 255, 14))
    img = Image.alpha_composite(img, dot_layer)

    # 4. Target Dropzone Circles (Centered exactly at X=130, Y=170 and X=370, Y=170 in pt)
    dz_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dz_draw = ImageDraw.Draw(dz_layer)
    
    r_outer = int(58 * scale)
    r_inner = int(48 * scale)
    
    for cx_pt, col in [(130, (16, 185, 129)), (370, (56, 189, 248))]:
        cx = int(cx_pt * scale)
        cy = int(170 * scale)
        # Outer ring
        dz_draw.ellipse([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], outline=(*col, 40), width=max(1, int(1.5 * scale)))
        # Inner subtle target
        dz_draw.ellipse([cx - r_inner, cy - r_inner, cx + r_inner, cy + r_inner], fill=(*col, 18), outline=(*col, 70), width=max(1, int(1.5 * scale)))
    
    img = Image.alpha_composite(img, dz_layer)

    # 5. Centered Directional Flow (Capsule & Neon Arrow)
    arr_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    arr_draw = ImageDraw.Draw(arr_layer)
    
    cw = int(72 * scale)
    ch = int(36 * scale)
    cx = int(250 * scale)
    cy = int(170 * scale)
    
    arr_draw.rounded_rectangle(
        [cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2],
        radius=int(18 * scale),
        fill=(255, 255, 255, 14),
        outline=(45, 212, 191, 90),
        width=max(1, int(1.5 * scale))
    )
    
    # Arrow line & head
    line_w = max(2, int(3 * scale))
    arr_draw.line([(cx - int(15 * scale), cy), (cx + int(14 * scale), cy)], fill=(45, 212, 191, 245), width=line_w)
    arr_draw.line([(cx + int(6 * scale), cy - int(7 * scale)), (cx + int(15 * scale), cy)], fill=(45, 212, 191, 245), width=line_w)
    arr_draw.line([(cx + int(6 * scale), cy + int(7 * scale)), (cx + int(15 * scale), cy)], fill=(45, 212, 191, 245), width=line_w)
    
    img = Image.alpha_composite(img, arr_layer)

    # 6. Typography
    draw = ImageDraw.Draw(img)
    
    font_candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf"
    ]
    
    font_title = None
    font_sub = None
    
    for fpath in font_candidates:
        try:
            font_title = ImageFont.truetype(fpath, int(26 * scale))
            font_sub = ImageFont.truetype(fpath, int(13 * scale))
            break
        except Exception:
            continue
            
    if not font_title:
        font_title = ImageFont.load_default()
        font_sub = ImageFont.load_default()

    # Mascot frog icon
    try:
        frog = Image.open(ICON_PATH).convert("RGBA")
        isize = int(32 * scale)
        frog = frog.resize((isize, isize), Image.Resampling.LANCZOS)
        # Position centered above title
        img.paste(frog, (int(250 * scale - isize // 2), int(16 * scale)), frog)
    except Exception as e:
        print("Mascot load note:", e)

    # Title: FrogDrop
    title_str = "FrogDrop"
    tb = draw.textbbox((0, 0), title_str, font=font_title)
    tw = tb[2] - tb[0]
    draw.text((int(250 * scale - tw // 2), int(50 * scale)), title_str, font=font_title, fill=(240, 246, 252, 255))

    # Subtitle: Drag to Applications
    sub_str = "Drag FrogDrop into Applications to install"
    sb = draw.textbbox((0, 0), sub_str, font=font_sub)
    sw = sb[2] - sb[0]
    draw.text((int(250 * scale - sw // 2), int(86 * scale)), sub_str, font=font_sub, fill=(148, 163, 184, 255))

    return img

def generate_all_backgrounds(output_dir=None):
    if output_dir is None:
        output_dir = DEFAULT_OUTPUT_DIR
    os.makedirs(output_dir, exist_ok=True)
    
    img_1x = render_background_layer(scale=1)
    img_2x = render_background_layer(scale=2)
    
    p1 = os.path.join(output_dir, "dmg_bg_1x.png")
    p2 = os.path.join(output_dir, "dmg_bg_2x.png")
    ptiff = os.path.join(output_dir, "dmg_bg.tiff")
    ppng = os.path.join(output_dir, "dmg_bg.png")
    
    img_1x.save(p1, format="PNG")
    img_2x.save(p2, format="PNG")
    img_2x.save(ppng, format="PNG")
    
    # Run macOS native tiffutil to combine into multi-resolution Retina TIFF
    cmd = ["/usr/bin/tiffutil", "-cathidpicheck", p1, p2, "-out", ptiff]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0:
        print(f"✅ Generated native Retina TIFF: {ptiff}")
    else:
        print("tiffutil note:", res.stderr)
        # Fallback to direct tiff
        img_2x.save(ptiff, format="TIFF")

if __name__ == "__main__":
    generate_all_backgrounds()
