"""Pack animated liquid over the unchanged shell and adapt the native direction glyph."""
from PIL import Image, ImageChops

from pack_sprites import ICONS, write_dmi
from pack_feedback_assets import fit, generator_shell
from pack_expansion_assets import read_states


def pack_generator(shell):
    atlas = Image.open(ICONS / "source" / "nov17_generator_liquid.png").convert("RGBA")
    liquids = []
    for y in range(2):
        for x in range(4):
            frame = fit(atlas.crop((x * atlas.width // 4, y * atlas.height // 2,
                                   (x + 1) * atlas.width // 4, (y + 1) * atlas.height // 2)),
                        64, 62, opaque_bounds=True)
            mask = Image.new("L", frame.size)
            mask.putdata([255 if a >= 128 and g > r > b * 1.5 and g > 25 else 0
                          for r, g, b, a in frame.getdata()])
            frame.putalpha(mask)
            liquids.append(frame)
    union = liquids[0].getchannel("A")
    for frame in liquids[1:]:
        union = ImageChops.lighter(union, frame.getchannel("A"))
    bounds = union.getbbox()
    colors = [(20, 24, 5), (40, 45, 10), (60, 66, 18),
              (88, 98, 28), (108, 111, 36), (150, 157, 63)]
    palette = Image.new("P", (1, 1))
    palette.putpalette([value for color in colors for value in color] + [0] * (768 - len(colors) * 3))
    frames = []
    for liquid in liquids:
        liquid = liquid.crop(bounds).resize((24, 13), Image.Resampling.NEAREST)
        indexed = liquid.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        indexed.putalpha(liquid.getchannel("A"))
        frame = shell.copy()
        # Preserve the original bowl rim; only a central bubble may rise above its surface.
        for y in range(13):
            for x in range(24):
                target_x, target_y = x + 19, y + 32
                r, g, b, a = shell.getpixel((target_x, target_y))
                surface = a >= 128 and g > r > b * 2 and r > 20
                bubble = 25 <= target_x <= 33 and 33 <= target_y <= 38
                if (surface or bubble) and indexed.getpixel((x, y))[3]:
                    frame.putpixel((target_x, target_y), indexed.getpixel((x, y)))
        frames.append(frame)
    write_dmi("biomass_generator.dmi", 64, [("generator", frames, 1)], delay=2.5)
    preview = []
    for frame in frames:
        background = Image.new("RGBA", (64, 64), "#30343a")
        background.alpha_composite(frame)
        preview.append(background.convert("RGB").resize((384, 384), Image.Resampling.NEAREST))
    preview[0].save(ICONS / "source" / "nov17_generator_preview.gif", save_all=True,
                    append_images=preview[1:], duration=250, loop=0)


def pack_arrow():
    donor = ICONS.parents[2] / "icons/effects/vent_indicator.dmi"
    # Freeze the native inward-pointing glyph at a visible middle animation frame.
    glyph = read_states(donor)[2]["arrow"][0][21]
    glyph = glyph.crop(glyph.getbbox()).resize((14, 14), Image.Resampling.NEAREST)
    white = Image.new("RGBA", glyph.size, "white")
    white.putalpha(glyph.getchannel("A"))
    south = Image.new("RGBA", (32, 32))
    south.alpha_composite(white, (9, 9))
    # The source glyph points south; DMI order is S/N/E/W/SE/SW/NE/NW.
    angles = (0, 180, 90, -90, 45, -45, 135, -135)
    write_dmi("rally_pointer.dmi", 32, [("arrow", [south.rotate(angle) for angle in angles], 8)])


def pack_baneling():
    _, _, originals = read_states(ICONS / "tgmc" / "minions_source" / "baneling.dmi")
    states = []
    for suffix, donor in (("", "Baneling Walking"), ("_sleep", "Baneling Sleeping"),
                          ("_dead", "Baneling Dead")):
        originals_frames, directions = originals[donor]
        frames = [None] * len(originals_frames)
        for direction in range(directions):
            directional = originals_frames[direction::directions]
            boxes = [frame.getbbox() for frame in directional]
            # Shared bounds keep walking frames anchored at one scale and position.
            bounds = (min(box[0] for box in boxes), min(box[1] for box in boxes),
                      max(box[2] for box in boxes), max(box[3] for box in boxes))
            scale = min(29 / (bounds[2] - bounds[0]), 29 / (bounds[3] - bounds[1]))
            size = (round((bounds[2] - bounds[0]) * scale), round((bounds[3] - bounds[1]) * scale))
            for frame_number, original in enumerate(directional):
                reduced = original.crop(bounds).resize(size, Image.Resampling.NEAREST)
                frame = Image.new("RGBA", (32, 32))
                frame.paste(reduced, ((32 - size[0]) // 2, 30 - size[1]))
                frames[frame_number * directions + direction] = frame
        states.append((f"baneling{suffix}", frames, directions))
    write_dmi("brood/baneling.dmi", 32, states, delay=4, movement_states=("baneling",))


def pack_rally_track():
    source = Image.open(ICONS / "source" / "nov17_rally_track.png").convert("RGBA")
    glyph = fit(source, 32, 30, opaque_bounds=True)
    glyph.putalpha(glyph.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0))
    write_dmi("rally_track.dmi", 32, [("track", [glyph], 1)])


if __name__ == "__main__":
    pack_generator(generator_shell())
    pack_arrow()
    pack_baneling()
    pack_rally_track()
