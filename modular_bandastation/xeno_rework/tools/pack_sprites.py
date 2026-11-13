"""Pack the generated source atlases into BYOND DMI files; requires Pillow."""
import math
import re
from pathlib import Path

from PIL import Image, PngImagePlugin

ICONS = Path(__file__).resolve().parents[1] / "icons"


def cells(name, size=32, columns=4, rows=3):
    source = Image.open(ICONS / "source" / f"{name}.png").convert("RGBA")
    width, height = source.size
    return [
        source.crop((column * width // columns, row * height // rows,
                     (column + 1) * width // columns, (row + 1) * height // rows))
        .resize((size, size), Image.Resampling.NEAREST)
        for row in range(rows) for column in range(columns)
    ]


def write_dmi(name, size, states):
    count = sum(len(frames) for _, frames, _ in states)
    columns = min(8, count)
    image = Image.new("RGBA", (columns * size, math.ceil(count / columns) * size))
    description = ["# BEGIN DMI", "version = 4.0", f"\twidth = {size}", f"\theight = {size}"]
    index = 0
    for state, frames, directions in states:
        animation_frames = len(frames) // directions
        description += [f'state = "{state}"', f"\tdirs = {directions}", f"\tframes = {animation_frames}"]
        if animation_frames > 1:
            description += ["\tdelay = " + ",".join(["2"] * animation_frames), "\tloop = 0"]
        for frame in frames:
            image.paste(frame, ((index % columns) * size, (index // columns) * size))
            index += 1
    description.append("# END DMI")
    metadata = PngImagePlugin.PngInfo()
    metadata.add_text("Description", "\n".join(description), zip=True)
    image.save(ICONS / name, format="PNG", pnginfo=metadata)


def inhand_positions():
    source = Image.open(ICONS / "big_xenos.dmi")
    columns = source.width // 64
    index = 0
    positions = {}
    for match in re.finditer(r'state = "([^\"]+)"(.*?)(?=\nstate =|\n# END|$)', source.info["Description"], re.S):
        state, data = match.groups()
        directions = int(re.search(r"dirs = (\d+)", data).group(1))
        frames = int(re.search(r"frames = (\d+)", data).group(1))
        if state in ("facehuggerdrone_l", "facehuggerdrone_r"):
            positions[state[-1]] = []
            for direction in range(4):
                tile = index + direction
                frame = source.crop(((tile % columns) * 64, (tile // columns) * 64,
                                     (tile % columns + 1) * 64, (tile // columns + 1) * 64))
                bounds = frame.getbbox()
                if bounds is None:
                    positions[state[-1]].append(None)
                    continue
                left, top, right, bottom = bounds
                positions[state[-1]].append(((left + right) // 2, (top + bottom) // 2))
        index += directions * frames
    return positions


def main():
    fruit_names = ("unstable", "greater", "spore", "alacrity", "cruor")
    fruit_cells = cells("fruits")
    fruit_states = []
    for index, name in enumerate(fruit_names):
        fruit_states += [(name + "_immature", [fruit_cells[index * 2]], 1),
                         (name, [fruit_cells[index * 2 + 1]], 1)]
    write_dmi("resin_fruits.dmi", 32, fruit_states)

    action_names = ("toxic_spit", "toxic_claws", "toxic_sting", "neuro_spit",
                    "acid_spit", "toggle_spit", "acid_volley", "acid_line",
                    "acid_cone", "grow_fruit", "empower", "scissor_cut")
    write_dmi("new_actions.dmi", 32, [(name, [frame], 1) for name, frame in zip(action_names, cells("actions"))])
    combat_names = ("fortify", "warrior_throw", "warrior_fling", "warrior_punch")
    write_dmi("combat_actions.dmi", 32, [(name, [frame], 1) for name, frame in zip(combat_names, cells("combat", columns=2, rows=2))])
    effects = cells("effects")
    write_dmi("xeno_effects.dmi", 32, [
        ("intox_low", [effects[0]], 1), ("intox_medium", [effects[1]], 1),
        ("intox_high", [effects[2]], 1), ("intox_critical", [effects[3]], 1),
        ("acid_pool", effects[4:8], 1),
    ])
    hand_states = []
    for index, name in enumerate(fruit_names):
        fruit = fruit_cells[index * 2 + 1].resize((14, 14), Image.Resampling.NEAREST)
        for hand, positions in inhand_positions().items():
            frames = []
            for position in positions:
                frame = Image.new("RGBA", (64, 64))
                if position is not None:
                    x, y = position
                    frame.paste(fruit, (x - 7, y - 7))
                frames.append(frame)
            hand_states.append((f"{name}drone_{hand}", frames, 4))
    write_dmi("fruit_inhands.dmi", 64, hand_states)


if __name__ == "__main__":
    main()
