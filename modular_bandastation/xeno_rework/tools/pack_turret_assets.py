from pathlib import Path
from PIL import Image, ImageDraw, ImageOps, PngImagePlugin

icons = Path(__file__).resolve().parents[1] / "icons"
source = icons / "source"

def fit(source_image):
    art = source_image.convert("RGBA")
    art = art.crop(art.getchannel("A").point(lambda value: 255 if value > 96 else 0).getbbox())
    art.thumbnail((29, 29), Image.Resampling.NEAREST)
    tile = Image.new("RGBA", (32, 32))
    tile.alpha_composite(art, ((32 - art.width) // 2, 30 - art.height))
    return tile

side = fit(Image.open(source / "acid_turret_drip_approved.png"))
stand = side.copy()
stand.paste((0, 0, 0, 0), (0, 0, 32, 15))
board = Image.open(source / "acid_turret_directions_approved.png").convert("RGBA")
# Crop just the south-east head. The mockup includes arrows, stand and droplet.
diagonal = board.crop((985, 211, 1186, 445))
for y in range(diagonal.height):
    for x in range(diagonal.width):
        red, green, blue, alpha = diagonal.getpixel((x, y))
        if (abs(red - 35) < 9 and abs(green - 35) < 9 and abs(blue - 43) < 9) or green > blue + 12:
            diagonal.putpixel((x, y), (0, 0, 0, 0))
diagonal.thumbnail((17, 17), Image.Resampling.NEAREST)
south_east = stand.copy()
south_east.alpha_composite(diagonal, (9, 1))
south_west = stand.copy()
south_west.alpha_composite(ImageOps.mirror(diagonal), (32 - 9 - diagonal.width, 1))
west = stand.copy()
west.alpha_composite(ImageOps.mirror(side.crop((0, 0, 32, 17))), (0, 0))

def head(direction):
    """Near and far views retain the same hinge and resin stand."""
    im = stand.copy()
    d = ImageDraw.Draw(im)
    edge, dark, plate, ridge, glint = "#13131b", "#262530", "#393c4c", "#50586d", "#68738b"
    if direction == "south":
        d.polygon([(11, 3), (20, 3), (23, 7), (23, 14), (20, 18), (11, 18), (8, 14), (8, 7)], fill=edge)
        d.polygon([(11, 5), (20, 5), (22, 8), (20, 12), (11, 12), (9, 8)], fill=plate)
        d.line([(10, 7), (13, 5), (18, 5), (21, 7)], fill=ridge)
        d.line([(12, 14), (19, 14)], fill=dark, width=2)
        d.line([(12, 16), (19, 16)], fill=ridge)
        d.point((14, 13), fill=glint)
        d.point((17, 13), fill=glint)
    else:
        dx = 2 if direction == "north-east" else 0
        d.polygon([(10+dx, 4), (18+dx, 2), (23+dx, 6), (22+dx, 12), (19, 16), (12, 16), (8, 12), (8, 8)], fill=edge)
        d.polygon([(11+dx, 5), (18+dx, 3), (22+dx, 6), (21+dx, 10), (17, 14), (11, 13), (9, 10)], fill=plate)
        d.line([(11+dx, 5), (17+dx, 4), (20+dx, 6), (19+dx, 8)], fill=ridge, width=2)
        d.line([(10, 11), (14, 13), (19, 11)], fill=dark)
    return im

north_east = head("north-east")
north_west = stand.copy()
north_west.alpha_composite(ImageOps.mirror(north_east.crop((0, 0, 32, 16))), (0, 0))
directions = [
    (head("south"), 16, 17), (head("north"), 15, 10),
    (side, 24, 14), (west, 7, 14),
    (south_east, 22, 16), (south_west, 9, 16),
    (north_east, 24, 10), (north_west, 7, 10),
]

delays = [5.6, 1.6, 1.0, 0.95, 0.75, 0.85, 1.0]
frames = []
for phase in range(len(delays)):
    for body, mouth_x, mouth_y in directions:
        tile = body.copy()
        dot = (160, 174, 85, 255)
        if phase in (1, 2, 3, 4):
            drop_y = mouth_y + (0, 0, 2, 6, 11)[phase]
            tile.putpixel((mouth_x, drop_y), dot)
            if phase > 1:
                tile.putpixel((mouth_x, drop_y+1), (106, 121, 58, 255))
        elif phase >= 5:
            tile.putpixel((mouth_x, 29), (106, 121, 58, 255))
            if phase == 5:
                tile.putpixel((mouth_x-1, 29), dot)
                tile.putpixel((mouth_x+1, 29), dot)
        frames.append(tile)

frames.append(fit(Image.open(source / "hugger_trap_jump_approved.png")))
low_profile = Image.open(source / "fortification_low_profile.png")
frames.extend(low_profile.crop((x, 0, x+32, 32)) for x in (0, 32))
sheet = Image.new("RGBA", (256, 32 * ((len(frames) + 7) // 8)))
for index, frame in enumerate(frames):
    sheet.paste(frame, (index % 8 * 32, index // 8 * 32))
metadata = PngImagePlugin.PngInfo()
metadata.add_text("Description", '# BEGIN DMI\nversion = 4.0\n\twidth = 32\n\theight = 32\n'
    'state = "acid_turret"\n\tdirs = 8\n\tframes = 7\n\tdelay = ' + ','.join(map(str, delays)) + '\n'
    + ''.join(f'state = "{name}"\n\tdirs = 1\n\tframes = 1\n' for name in ("hugger_trap_action", "hugger_trap", "acid_mine"))
    + '# END DMI\n', zip=True)
sheet.save(icons / "hive_fortifications.dmi", format="PNG", pnginfo=metadata)
