"""Pack the testmerge feedback artwork and the credited native TGMC Carrier frames."""
from PIL import Image

from pack_sprites import ICONS, write_dmi
from pack_expansion_assets import read_states


def visible_box(image):
    # Low-alpha generation noise must not alter native-resolution sprite alignment.
    return image.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0).getbbox()


def fit(image, canvas_size, body_size, *, opaque_bounds=False):
    image = image.crop(visible_box(image) if opaque_bounds else image.getbbox())
    scale = min(body_size / image.width, body_size / image.height)
    image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.NEAREST)
    output = Image.new("RGBA", (canvas_size, canvas_size))
    output.paste(image, ((canvas_size - image.width) // 2, canvas_size - 2 - image.height))
    return output


def cells(name, columns, rows):
    prefix = "fix15" if name in ("actions_palette", "generator_stable") else "feedback"
    source = Image.open(ICONS / "source" / f"{prefix}_{name}.png").convert("RGBA")
    return [source.crop((x * source.width // columns, y * source.height // rows,
                         (x + 1) * source.width // columns, (y + 1) * source.height // rows))
            for y in range(rows) for x in range(columns)]


def generator_shell():
    source = Image.open(ICONS / "source" / "generator_style_matched.png").convert("RGBA")
    shell = fit(source, 64, 62, opaque_bounds=True)
    # Full-color downsampling leaves hundreds of near-duplicate colors and noisy edges.
    # Match the native sprites' indexed ramps, with Spitter's olive ramp for the acid.
    _, _, native_states = read_states(ICONS / "big_xenos.dmi")
    colors = {pixel[:3] for name in ("aliendrone", "alienpraetorian")
              for pixel in native_states[name][0][0].getdata() if pixel[3] >= 128}
    colors.update(pixel[:3] for pixel in native_states["alienspitter"][0][0].getdata()
                  if pixel[3] >= 128 and pixel[1] > pixel[0] > pixel[2] * 2)
    palette = Image.new("P", (1, 1))
    palette.putpalette([channel for color in sorted(colors) for channel in color]
                       + [0] * (768 - len(colors) * 3))
    indexed = shell.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    indexed.putalpha(shell.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0))
    return indexed


def main():
    for name in ("beetle", "mantis", "scorpion"):
        frames = [fit(frame, 32, 29) for frame in cells(name, 4, 2)]
        write_dmi(f"brood/{name}.dmi", 32, [(name, frames[:4], 4),
                  (f"{name}_sleep", frames[4:], 4), (f"{name}_dead", frames[4:], 4)])
    from pack_nov17_assets import pack_generator, pack_arrow, pack_baneling, pack_rally_track
    pack_generator(generator_shell())
    pack_arrow()
    pack_baneling()
    pack_rally_track()
    brood_actions = []
    for state, filename in (("beetle_charge", "charge"), ("rally", "rally")):
        source = Image.open(ICONS / "source" / f"feedback14_{filename}.png").convert("RGBA")
        brood_actions.append((state, [fit(source, 32, 30, opaque_bounds=True)], 1))
    write_dmi("brood_actions.dmi", 32, brood_actions)
    names = ("roster", "development", "swallow", "emp", "carrier", "pheromones")
    write_dmi("hive_actions.dmi", 32, [(name, [fit(frame, 32, 30, opaque_bounds=True)], 1)
              for name, frame in zip(names, cells("actions_palette", 3, 2))])
    _, _, states = read_states(ICONS / "tgmc" / "minions_source" / "carrier.dmi")
    output = []
    for state, donor in (("aliencarrier", "Carrier Walking"), ("aliencarrier_sleep", "Carrier Sleeping"),
                         ("aliencarrier_unconscious", "Carrier Knocked Down"), ("aliencarrier_dead", "Carrier Dead"),
                         ("aliencarrier_husked", "Carrier Dead"), ("aliencarrier_pounce", "Carrier Walking")):
        frames, directions = states[donor]
        output.append((state, frames[:directions], directions))
    for name, (frames, directions) in states.items():
        if name.startswith("clinger_"):
            output.append((name, frames[:directions], directions))
    write_dmi("tgmc/carrier_adapted.dmi", 64, output)


if __name__ == "__main__":
    main()
