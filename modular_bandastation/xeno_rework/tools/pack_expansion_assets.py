"""Package generated hive sprites and selected TGMC frames without repainting source pixels."""
import argparse
import hashlib
import re
import shutil
from pathlib import Path

from PIL import Image

from pack_sprites import ICONS, write_dmi


SOURCES = {"barricades": "icons/Marine/barricades.dmi"}


def read_states(path):
    image = Image.open(path).convert("RGBA")
    description = Image.open(path).info["Description"]
    width = int(re.search(r"\bwidth = (\d+)", description).group(1))
    height = int(re.search(r"\bheight = (\d+)", description).group(1))
    columns = image.width // width
    result = {}
    index = 0
    for match in re.finditer(r'state = "([^"]+)"(.*?)(?=\nstate =|\n# END|$)', description, re.S):
        state, metadata = match.groups()
        directions = int(re.search(r"dirs = (\d+)", metadata).group(1))
        count = directions * int(re.search(r"frames = (\d+)", metadata).group(1))
        tiles = [image.crop(((tile % columns) * width, (tile // columns) * height,
                             (tile % columns + 1) * width, (tile // columns + 1) * height))
                 for tile in range(index, index + count)]
        result.setdefault(state, (tiles, directions))
        index += count
    return width, height, result


def generated():
    (ICONS / "brood").mkdir(exist_ok=True)
    source = Image.open(ICONS / "source" / "hive_core.png").convert("RGBA")
    cells = [source.crop((column * source.width // 4, 0, (column + 1) * source.width // 4, source.height)) for column in range(4)]
    boxes = [cell.getbbox() for cell in cells]
    bounds = (min(box[0] for box in boxes), min(box[1] for box in boxes), max(box[2] for box in boxes), max(box[3] for box in boxes))
    scale = min(56 / (bounds[2] - bounds[0]), 56 / (bounds[3] - bounds[1]))
    frames = []
    for cell in cells:
        crop = cell.crop(bounds)
        crop = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", (64, 64))
        canvas.paste(crop, ((64 - crop.width) // 2, 60 - crop.height))
        frames.append(canvas)
    write_dmi("brood/hive_core.dmi", 64, [("core", frames, 1)], delay=5)


def ports(source_root):
    destination = ICONS / "fortifications"
    originals = destination / "source"
    originals.mkdir(parents=True, exist_ok=True)
    if source_root:
        for key, relative in SOURCES.items():
            shutil.copyfile(source_root / relative, originals / f"{key}.dmi")
        (originals / "SHA256SUMS.txt").write_text("\n".join(
            f"{hashlib.sha256((originals / f'{key}.dmi').read_bytes()).hexdigest()}  {key}.dmi"
            for key, relative in SOURCES.items()) + "\n", encoding="utf-8")
    selections = {"barricades": {f"folding_{stage}": f"folding_{stage}" for stage in range(4)}}
    for key, selection in selections.items():
        width, height, states = read_states(originals / f"{key}.dmi")
        write_dmi(f"fortifications/{key}.dmi", width,
                  [(new, *states[old]) for old, new in selection.items()], height=height)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tgmc-source", type=Path, help="Import the upstream original atlases once; omitted for portable rebuilds")
    arguments = parser.parse_args()
    generated()
    ports(arguments.tgmc_source)
