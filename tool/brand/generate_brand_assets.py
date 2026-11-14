import math
import pathlib
from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(r"c:\Users\MS1\Desktop\LocalBridge-main\LocalBridge-main")
ARTIFACT_DIR = pathlib.Path(
    r"C:\Users\MS1\.gemini\antigravity\brain\e292533d-b3b8-4200-9134-efb4f8630e6d"
)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(c1, c2, t: float):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(lerp(c1[i], c2[i], t))) for i in range(len(c1)))


def draw_masterpiece_logo(size: int = 1024) -> Image.Image:
    S = size
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # 1. Squircle background with deep obsidian-to-midnight gradient
    mask = Image.new("L", (S, S), 0)
    mdraw = ImageDraw.Draw(mask)
    pad = int(S * 0.04)
    radius = int(S * 0.225)
    mdraw.rounded_rectangle([pad, pad, S - pad, S - pad], radius=radius, fill=255)

    bg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(bg)
    top_col = (10, 15, 28, 255)
    mid_col = (7, 10, 18, 255)
    bot_col = (4, 6, 12, 255)
    for y in range(pad, S - pad):
        t = (y - pad) / max(1, (S - 2 * pad))
        c = lerp_color(top_col, mid_col, t * 1.4) if t < 0.6 else lerp_color(mid_col, bot_col, (t - 0.6) / 0.4)
        bdraw.line([(pad, y), (S - pad, y)], fill=c)

    # Ambient radial aurora glow in the center-top of the badge
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    cx, cy = int(S * 0.5), int(S * 0.44)
    max_r = int(S * 0.44)
    for r in range(max_r, 0, -4):
        k = (1.0 - r / max_r) ** 1.8
        col = (38, 160, 245, int(78 * k))
        gdraw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col)
    bg = Image.alpha_composite(bg, glow)

    # Subtle architectural grid lines inside the badge
    grid = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grdraw = ImageDraw.Draw(grid)
    step = int(S * 0.08)
    for x in range(pad + step, S - pad, step):
        grdraw.line([(x, pad), (x, S - pad)], fill=(56, 189, 248, 11), width=max(1, S // 512))
    for y in range(pad + step, S - pad, step):
        grdraw.line([(pad, y), (S - pad, y)], fill=(56, 189, 248, 11), width=max(1, S // 512))
    bg = Image.alpha_composite(bg, grid)

    img.paste(bg, (0, 0), mask)

    # Outer metallic cyan-indigo rim border
    rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(rim)
    rdraw.rounded_rectangle(
        [pad, pad, S - pad, S - pad],
        radius=radius,
        outline=(56, 189, 248, 95),
        width=max(2, int(S * 0.012)),
    )
    rdraw.rounded_rectangle(
        [pad + int(S * 0.012), pad + int(S * 0.012), S - pad - int(S * 0.012), S - pad - int(S * 0.012)],
        radius=max(4, radius - int(S * 0.012)),
        outline=(255, 255, 255, 22),
        width=max(1, int(S * 0.004)),
    )
    img = Image.alpha_composite(img, rim)

    # 2. Bridge geometry layer (drawn with glow + crisp foreground)
    art = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    adraw = ImageDraw.Draw(art)

    deck_y = S * 0.62
    x0, x1 = S * 0.13, S * 0.87
    tower1_x, tower2_x = S * 0.29, S * 0.71
    tower_top_y = S * 0.23
    tower_bot_y = S * 0.80

    c_cyan = (56, 189, 248, 255)     # #38BDF8
    c_teal = (45, 212, 191, 255)     # #2DD4BF
    c_blue = (99, 102, 241, 255)     # #6366F1
    c_white = (244, 248, 255, 255)

    def bridge_grad(u: float):
        if u < 0.5:
            return lerp_color(c_teal, c_cyan, u * 2.0)
        return lerp_color(c_cyan, c_blue, (u - 0.5) * 2.0)

    # Helper for smooth thick gradient curves
    def draw_grad_curve(pts, width: float, alpha_scale: float = 1.0, white_mix: float = 0.0):
        r = max(1.5, width / 2.0)
        n = len(pts)
        for i, (px, py) in enumerate(pts):
            u = i / max(1, n - 1)
            col = bridge_grad(u)
            if white_mix > 0:
                col = lerp_color(col, c_white, white_mix)
            col = (col[0], col[1], col[2], int(col[3] * alpha_scale))
            adraw.ellipse([px - r, py - r, px + r, py + r], fill=col)

    # Upper main arch (spanning from x0 to x1, peaking at y = 0.20 * S)
    arch_pts = []
    steps = 260
    peak_y = S * 0.16
    for i in range(steps + 1):
        u = i / steps
        x = lerp(x0, x1, u)
        y = (1 - u) ** 2 * deck_y + 2 * (1 - u) * u * peak_y + (u ** 2) * deck_y
        arch_pts.append((x, y))

    # Secondary inner structural arch
    arch2_pts = []
    peak2_y = S * 0.27
    for i in range(steps + 1):
        u = i / steps
        x = lerp(x0 + S * 0.04, x1 - S * 0.04, u)
        y = (1 - u) ** 2 * deck_y + 2 * (1 - u) * u * peak2_y + (u ** 2) * deck_y
        arch2_pts.append((x, y))

    # Vertical tension hangers between main arch and deck
    hanger_us = [0.20, 0.29, 0.38, 0.46, 0.54, 0.62, 0.71, 0.80]
    hanger_w = max(2, int(S * 0.015))
    for u in hanger_us:
        hx = lerp(x0, x1, u)
        hy_top = (1 - u) ** 2 * deck_y + 2 * (1 - u) * u * peak_y + (u ** 2) * deck_y
        col = bridge_grad(u)
        adraw.line(
            [(hx, hy_top), (hx, deck_y)],
            fill=(col[0], col[1], col[2], 210),
            width=hanger_w,
        )

    # Draw secondary arch & main arch
    draw_grad_curve(arch2_pts, S * 0.022, alpha_scale=0.75)
    draw_grad_curve(arch_pts, S * 0.046, alpha_scale=1.0, white_mix=0.12)

    # Twin architectural piers / towers
    pier_w = max(3, int(S * 0.036))
    for tx, u in [(tower1_x, 0.29), (tower2_x, 0.71)]:
        hy_top = (1 - u) ** 2 * deck_y + 2 * (1 - u) * u * peak_y + (u ** 2) * deck_y
        adraw.rounded_rectangle(
            [tx - pier_w // 2, hy_top - pier_w // 2, tx + pier_w // 2, tower_bot_y],
            radius=pier_w // 2,
            fill=(238, 246, 255, 245),
        )

    # Main horizontal bridge deck
    deck_pts = [(lerp(x0 - S * 0.02, x1 + S * 0.02, i / 200), deck_y) for i in range(201)]
    draw_grad_curve(deck_pts, S * 0.044, alpha_scale=1.0, white_mix=0.28)

    # Water / data wave reflections below
    for idx, (wy, span, alpha) in enumerate([(S * 0.84, 0.26, 195), (S * 0.895, 0.16, 125)]):
        w_pts = [
            (lerp(S * (0.5 - span), S * (0.5 + span), i / 120), wy)
            for i in range(121)
        ]
        draw_grad_curve(w_pts, S * 0.020, alpha_scale=alpha / 255.0)

    # Add soft bloom behind the bridge art, clipped cleanly to the squircle mask
    bloom = art.filter(ImageFilter.GaussianBlur(radius=max(2, S // 36)))
    combined_art = Image.alpha_composite(bloom, art)
    masked_art = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    masked_art.paste(combined_art, (0, 0), mask)
    img = Image.alpha_composite(img, masked_art)
    return img


def main():
    logo_1024 = draw_masterpiece_logo(1024)
    logo_512 = logo_1024.resize((512, 512), Image.Resampling.LANCZOS)

    (ROOT / "assets" / "brand").mkdir(parents=True, exist_ok=True)
    logo_1024.save(ROOT / "assets" / "brand" / "logo.png")
    logo_512.save(ROOT / "assets" / "brand" / "logo_512.png")
    logo_1024.save(ROOT / "assets" / "logo.png")
    logo_1024.save(ROOT / "assets" / "icon.png")
    logo_1024.save(ARTIFACT_DIR / "logo_preview.png")

    # Windows multi-resolution .ico
    ico_sizes = [(16, 16), (20, 20), (24, 24), (32, 32), (40, 40), (48, 48), (64, 64), (128, 128), (256, 256)]
    ico_path_1 = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_path_2 = ROOT / "assets" / "app_icon.ico"
    logo_1024.save(ico_path_1, format="ICO", sizes=ico_sizes)
    logo_1024.save(ico_path_2, format="ICO", sizes=ico_sizes)

    # Android mipmap launcher icons & drawable launch logos
    mipmaps = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    res_dir = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, px in mipmaps.items():
        d = res_dir / folder
        d.mkdir(parents=True, exist_ok=True)
        resized = logo_1024.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(d / "ic_launcher.png")
        resized.save(d / "ic_launcher_round.png")
        fg = logo_1024.resize((int(px * 2.25), int(px * 2.25)), Image.Resampling.LANCZOS)
        fg.save(d / "ic_launcher_foreground.png")
        fg.save(d / "ic_launcher_monochrome.png")

    drawables = {
        "drawable-mdpi": 96,
        "drawable-hdpi": 144,
        "drawable-xhdpi": 192,
        "drawable-xxhdpi": 288,
        "drawable-xxxhdpi": 384,
    }
    for folder, px in drawables.items():
        d = res_dir / folder
        d.mkdir(parents=True, exist_ok=True)
        resized = logo_1024.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(d / "launch_logo.png")

    print("Generated all new 3.0.6 brand assets successfully.")


if __name__ == "__main__":
    main()
