"""Pack generated Matron Sac frames with a fixed shell and pixel-aligned interiors."""
from PIL import Image, ImageDraw

from pack_sprites import ICONS, write_dmi
from pack_feedback_assets import fit


def frames(name):
    atlas = Image.open(ICONS / "source" / f"matron_{name}.png").convert("RGBA")
    return [fit(atlas.crop((x * atlas.width // 4, y * atlas.height // 2,
                           (x + 1) * atlas.width // 4, (y + 1) * atlas.height // 2)),
                64, 62, opaque_bounds=True) for y in range(2) for x in range(4)]


def main():
    idle, birth = frames("idle"), frames("birth")
    shell = idle[0]
    mask = Image.new("L", (64, 64))
    drawing = ImageDraw.Draw(mask)
    # The generated sheets vary slightly outside the animated organs: retain one shell.
    drawing.ellipse((25, 37, 40, 56), fill=255)
    drawing.polygon(((7, 29), (14, 23), (18, 28), (16, 42), (9, 41)), fill=255)
    drawing.polygon(((47, 28), (53, 25), (57, 32), (55, 42), (48, 42)), fill=255)
    output = [Image.composite(frame, shell, mask) for frame in idle + birth]
    # A shared indexed palette prevents color flicker between animation states.
    strip = Image.new("RGBA", (64 * len(output), 64))
    for index, frame in enumerate(output):
        strip.paste(frame, (index * 64, 0))
    palette = strip.convert("RGB").quantize(colors=32, dither=Image.Dither.NONE)
    packed = []
    for frame in output:
        indexed = frame.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
        indexed.putalpha(frame.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
        packed.append(indexed)
    write_dmi("brood/brood_core.dmi", 64,
              [("core", packed[:8], 1), ("core_birth", packed[8:], 1)],
              delay={"core": 3, "core_birth": 1.5})
    for name, sequence, delay in (("idle", packed[:8], 300), ("birth", packed[8:], 150)):
        preview = []
        for frame in sequence:
            background = Image.new("RGBA", (64, 64), "#30343a")
            background.alpha_composite(frame)
            preview.append(background.convert("RGB").resize((384, 384), Image.Resampling.NEAREST))
        preview[0].save(ICONS / "source" / f"matron_{name}_preview.gif", save_all=True,
                        append_images=preview[1:], loop=0, duration=delay)
    sheet = Image.new("RGBA", (8 * 64, 2 * 64), "#30343a")
    for index, frame in enumerate(packed):
        sheet.alpha_composite(frame, ((index % 8) * 64, (index // 8) * 64))
    sheet.resize((1024, 256), Image.Resampling.NEAREST).save(ICONS / "source" / "matron_frames.png")


if __name__ == "__main__":
    main()
