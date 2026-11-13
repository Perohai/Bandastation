"""Adapt checked-in TGMC atlases to Banda's five adult icon states, without repainting."""
import re
from PIL import Image

from pack_sprites import write_dmi, ICONS


def main():
    for caste in ("crusher", "boiler", "hunter"):
        source = Image.open(ICONS / "tgmc" / f"{caste}_castes.dmi")
        description = source.info["Description"]
        width = int(re.search(r"width = (\d+)", description).group(1))
        height = int(re.search(r"height = (\d+)", description).group(1))
        columns = source.width // width
        frames_by_state = {}
        index = 0
        for match in re.finditer(r'state = "([^"]+)"(.*?)(?=\nstate =|\n# END|$)', description, re.S):
            state, metadata = match.groups()
            directions = int(re.search(r"dirs = (\d+)", metadata).group(1))
            frames = int(re.search(r"frames = (\d+)", metadata).group(1))
            if state not in frames_by_state:
                tiles = []
                for offset in range(directions):
                    tile = index + offset
                    image = source.crop(((tile % columns) * width, (tile // columns) * height,
                                         (tile % columns + 1) * width, (tile // columns + 1) * height)).convert("RGBA")
                    canvas = Image.new("RGBA", (64, 64))
                    canvas.paste(image, ((64 - width) // 2, 64 - height))
                    tiles.append(canvas)
                frames_by_state[state] = (tiles, directions)
            index += directions * frames
        states = []
        for suffix, original in (("", "Walking"), ("_sleep", "Sleeping"),
                                 ("_unconscious", "Knocked Down"), ("_dead", "Dead"), ("_husked", "Dead")):
            tiles, directions = frames_by_state[f"{caste.title()} {original}"]
            states.append((f"alien{caste}{suffix}", tiles, directions))
        write_dmi(f"tgmc/{caste}_adapted.dmi", 64, states)


if __name__ == "__main__":
    main()
