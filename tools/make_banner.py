"""
tools/make_banner.py - Generates TV Banners and Adaptive Launcher Icons for Binge
Utilises Pillow and bundled Inter font.
"""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

COLOR_BLACK = (0, 0, 0, 255)
COLOR_YELLOW = (255, 214, 0, 255)       # #FFD600
COLOR_PURPLE = (124, 58, 237, 255)      # #7C3AED
COLOR_DEEP_PURPLE = (76, 29, 149, 255)  # #4C1D95

FONT_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts', 'Inter-Variable.ttf')
RES_DIR = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SOURCE_ICON = os.path.join(PROJECT_DIR, 'icon.png')
SOURCE_BANNER = os.path.join(PROJECT_DIR, 'banner.png')

def fit_source(path, size):
    """Scale supplied artwork without distortion, centered on transparency."""
    if not os.path.isfile(path):
        raise FileNotFoundError(f'Required brand asset is missing: {path}')
    source = Image.open(path).convert('RGBA')
    source.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', size, (0, 0, 0, 0))
    canvas.alpha_composite(
        source,
        ((size[0] - source.width) // 2, (size[1] - source.height) // 2),
    )
    return canvas

def fit_banner(path, size):
    """Fit banner artwork inside an opaque 16:9 canvas without distortion."""
    if not os.path.isfile(path):
        raise FileNotFoundError(f'Required brand asset is missing: {path}')
    source = Image.open(path).convert('RGBA')
    source.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', size, COLOR_BLACK)
    canvas.alpha_composite(
        source,
        ((size[0] - source.width) // 2, (size[1] - source.height) // 2),
    )
    return canvas.convert('RGB')


def draw_purple_glow(canvas, center_x, center_y, rx, ry, max_alpha=170):
    """Draws an elliptical radial purple glow behind the text."""
    glow_layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)

    steps = 40
    for i in range(steps, 0, -1):
        ratio = i / float(steps)
        curr_rx = int(rx * ratio)
        curr_ry = int(ry * ratio)
        alpha = int(max_alpha * (1.0 - ratio) * (1.0 - ratio))
        bbox = [
            center_x - curr_rx,
            center_y - curr_ry,
            center_x + curr_rx,
            center_y + curr_ry
        ]
        glow_draw.ellipse(bbox, fill=(124, 58, 237, alpha))

    # Blur glow layer for organic diffusion
    blurred = glow_layer.filter(ImageFilter.GaussianBlur(radius=canvas.width * 0.03))
    canvas.alpha_composite(blurred)

def create_master_banner(width=2880, height=1620):
    """
    Renders high-res 16:9 banner at 3x scale of 960x540.
    - Pure black background
    - Purple gradient glow in center
    - 'Binge' text in bold yellow filling 60-65% width
    - Vertically centered
    - Purple play-triangle accent
    - 10% safe margin
    """
    img = Image.new('RGBA', (width, height), COLOR_BLACK)
    cx, cy = width // 2, height // 2

    # Draw ambient purple glow
    draw_purple_glow(img, cx, cy, rx=int(width * 0.42), ry=int(height * 0.35))

    draw = ImageDraw.Draw(img)

    # Calculate font size so text fills ~62% of width
    target_text_width = width * 0.62
    font_size = 100
    font = ImageFont.truetype(FONT_PATH, font_size)

    # Iterative sizing
    while True:
        bbox = draw.textbbox((0, 0), "Binge", font=font)
        w = bbox[2] - bbox[0]
        if w >= target_text_width or font_size >= height * 0.55:
            break
        font_size += 8
        font = ImageFont.truetype(FONT_PATH, font_size)

    # Final bounding box
    bbox = draw.textbbox((0, 0), "Binge", font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    text_x = (width - text_w) // 2 - int(bbox[0])
    text_y = (height - text_h) // 2 - int(bbox[1])

    # Draw subtle text drop shadow
    shadow_offset = int(height * 0.012)
    draw.text((text_x + shadow_offset, text_y + shadow_offset), "Binge", font=font, fill=(20, 10, 40, 220))

    # Draw main text in bold yellow
    draw.text((text_x, text_y), "Binge", font=font, fill=COLOR_YELLOW)

    # Draw purple play-triangle accent next to 'Binge'
    tri_size = int(text_h * 0.30)
    tri_x = text_x + text_w + int(width * 0.02)
    tri_y = cy - (tri_size // 2)

    triangle_points = [
        (tri_x, tri_y),
        (tri_x + tri_size, tri_y + (tri_size // 2)),
        (tri_x, tri_y + tri_size)
    ]
    draw.polygon(triangle_points, fill=COLOR_PURPLE)

    return img

def create_master_icon(size=1024):
    """Creates a high-res square launcher icon: yellow 'B' with purple play triangle."""
    img = Image.new('RGBA', (size, size), COLOR_BLACK)
    cx, cy = size // 2, size // 2

    # Subtle purple ambient glow
    draw_purple_glow(img, cx, cy, rx=int(size * 0.38), ry=int(size * 0.38), max_alpha=150)

    draw = ImageDraw.Draw(img)

    # Font sizing for 'B'
    font_size = int(size * 0.65)
    font = ImageFont.truetype(FONT_PATH, font_size)
    bbox = draw.textbbox((0, 0), "B", font=font)
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]

    bx = (size - bw) // 2 - int(bbox[0]) - int(size * 0.04)
    by = (size - bh) // 2 - int(bbox[1])

    # Draw 'B'
    draw.text((bx, by), "B", font=font, fill=COLOR_YELLOW)

    # Accent triangle inside or next to 'B'
    tri_size = int(size * 0.16)
    tx = bx + bw + int(size * 0.02)
    ty = cy - (tri_size // 2)
    triangle_points = [
        (tx, ty),
        (tx + tri_size, ty + (tri_size // 2)),
        (tx, ty + tri_size)
    ]
    draw.polygon(triangle_points, fill=COLOR_PURPLE)

    return img

def main():
    print("[1/3] Packaging supplied TV banner...")
    source_banner = Image.open(SOURCE_BANNER).convert('RGBA')
    print(f" -> Source banner: {source_banner.size[0]}x{source_banner.size[1]}")

    banner_targets = [
        ('drawable-mdpi', (320, 180)),
        ('drawable-hdpi', (480, 270)),
        ('drawable-xhdpi', (640, 360)),
        ('drawable-xxhdpi', (960, 540)),
        ('drawable', (320, 180)),
    ]

    for folder, dims in banner_targets:
        dir_path = os.path.join(RES_DIR, folder)
        os.makedirs(dir_path, exist_ok=True)
        out_path = os.path.join(dir_path, 'tv_banner.png')
        resized = fit_banner(SOURCE_BANNER, dims)
        resized.save(out_path, format='PNG', optimize=True)
        print(f" -> Saved {out_path} ({dims[0]}x{dims[1]})")

    print("[2/3] Packaging supplied launcher icon...")
    source_icon = Image.open(SOURCE_ICON).convert('RGBA')
    print(f" -> Source icon: {source_icon.size[0]}x{source_icon.size[1]}")

    # Foreground for adaptive icon
    fg_dir = os.path.join(RES_DIR, 'drawable')
    os.makedirs(fg_dir, exist_ok=True)
    fg_path = os.path.join(fg_dir, 'ic_launcher_foreground.png')
    fit_source(SOURCE_ICON, (432, 432)).save(fg_path, format='PNG', optimize=True)
    print(f" -> Saved {fg_path} (432x432)")

    # Legacy mipmaps
    mipmap_targets = [
        ('mipmap-mdpi', (48, 48)),
        ('mipmap-hdpi', (72, 72)),
        ('mipmap-xhdpi', (96, 96)),
        ('mipmap-xxhdpi', (144, 144)),
        ('mipmap-xxxhdpi', (192, 192)),
    ]

    for folder, dims in mipmap_targets:
        dir_path = os.path.join(RES_DIR, folder)
        os.makedirs(dir_path, exist_ok=True)
        out_path = os.path.join(dir_path, 'ic_launcher.png')
        resized = fit_source(SOURCE_ICON, dims)
        resized.save(out_path, format='PNG', optimize=True)
        print(f" -> Saved {out_path} ({dims[0]}x{dims[1]})")

    print("[3/3] Creating adaptive XML definitions...")
    # mipmap-anydpi-v26/ic_launcher.xml
    v26_dir = os.path.join(RES_DIR, 'mipmap-anydpi-v26')
    os.makedirs(v26_dir, exist_ok=True)
    xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/black" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""
    with open(os.path.join(v26_dir, 'ic_launcher.xml'), 'w', encoding='utf-8') as f:
        f.write(xml_content)

    # values/colors.xml for black
    values_dir = os.path.join(RES_DIR, 'values')
    with open(os.path.join(values_dir, 'colors.xml'), 'w', encoding='utf-8') as f:
        f.write("""<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="black">#FF000000</color>
    <color name="binge_yellow">#FFFFD600</color>
    <color name="binge_purple">#FF7C3AED</color>
</resources>
""")

    # Clean up duplicate files from drawable-nodpi
    nodpi_dir = os.path.join(RES_DIR, 'drawable-nodpi')
    if os.path.exists(nodpi_dir):
        for f in ['tv_banner.png', 'tv_banner_640.png', 'binge_icon.png']:
            p = os.path.join(nodpi_dir, f)
            if os.path.exists(p):
                os.remove(p)
                print(f" -> Removed obsolete duplicate {p}")
        try:
            if not os.listdir(nodpi_dir):
                os.rmdir(nodpi_dir)
        except Exception:
            pass

    print("Banner and icon generation complete!")

if __name__ == '__main__':
    main()
