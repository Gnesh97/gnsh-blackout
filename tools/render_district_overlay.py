"""Render the native district edges into one lightweight transparent map layer."""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw


OUTPUT_SIZE = 2048
SUPERSAMPLE = 4


def project(point: tuple[float, float], projection: dict[str, float]) -> tuple[int, int]:
    world_x, world_y = point
    pixel_x = float(projection["originX"]) + (world_x * float(projection["scaleX"]))
    pixel_y = float(projection["originY"]) - (world_y * float(projection["scaleY"]))
    return round(pixel_x * SUPERSAMPLE), round(pixel_y * SUPERSAMPLE)


def edge_key(edge: list[float]) -> tuple[tuple[float, float], tuple[float, float]]:
    first = (round(float(edge[0]), 2), round(float(edge[1]), 2))
    second = (round(float(edge[2]), 2), round(float(edge[3]), 2))
    return tuple(sorted((first, second)))


def render(source_path: Path, output_path: Path) -> None:
    data = json.loads(source_path.read_text(encoding="utf-8"))
    projection = data["projection"]
    edges: list[list[float]] = []
    seen: set[tuple[tuple[float, float], tuple[float, float]]] = set()

    for district in data.get("districts", {}).values():
        for edge in district.get("edges", []):
            key = edge_key(edge)
            if key in seen:
                continue
            seen.add(key)
            edges.append(edge)

    size = OUTPUT_SIZE * SUPERSAMPLE
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # A quiet under-stroke keeps the boundary legible on both light city blocks
    # and dark water without reintroducing the old SVG glow/filter cost.
    for edge in edges:
        start = project((edge[0], edge[1]), projection)
        end = project((edge[2], edge[3]), projection)
        draw.line((start, end), fill=(7, 16, 19, 205), width=11)
        draw.line((start, end), fill=(215, 255, 235, 232), width=5)

    image = image.resize((OUTPUT_SIZE, OUTPUT_SIZE), Image.Resampling.LANCZOS)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, format="PNG", optimize=True)
    print(f"rendered {len(edges)} unique edges -> {output_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: render_district_overlay.py <district-json> <output-png>")
    render(Path(sys.argv[1]), Path(sys.argv[2]))
