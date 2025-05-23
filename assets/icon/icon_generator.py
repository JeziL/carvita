import math
import cairo


SQRT_3 = math.sqrt(3)


def draw_carvita_icon(filename, colors, img_size=512, side_width=60, fill_bg=False):
    b = side_width
    a = img_size - 2 * SQRT_3 / 3 * b

    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, img_size, img_size)
    ctx = cairo.Context(surface)

    if fill_bg:
        # white background
        ctx.set_line_width(0)
        ctx.set_source_rgb(1, 1, 1)
        ctx.rectangle(0, 0, img_size, img_size)
        ctx.fill()

    # make the icon vertically centered
    ctx.translate(0, img_size - (2 - SQRT_3) / 4 * a - (2 * SQRT_3 + 3) / 6 * b)
    # flip y axis
    ctx.scale(1, -1)

    # L-shaped path
    path_points = [
        (0, 0),
        (a - 2 * SQRT_3 / 3 * b, 0),
        (a - SQRT_3 * b, b),
        (SQRT_3 * b, b),
        (a / 2 + 2 * SQRT_3 / 3 * b, SQRT_3 * a / 2),
        (a / 2, SQRT_3 * a / 2),
    ]

    # first path
    ctx.set_source_rgb(*[c / 255 for c in colors[0]])
    ctx.new_path()
    ctx.move_to(*path_points[0])
    for point in path_points[1:]:
        ctx.line_to(*point)
    ctx.close_path()
    ctx.fill_preserve()

    # copy & rotate to second path
    original_path = ctx.copy_path()
    ctx.set_source_rgb(*[c / 255 for c in colors[1]])
    ctx.new_path()
    ctx.append_path(original_path)
    ctx.rotate(math.radians(120))
    ctx.translate(-2 * SQRT_3 / 3 * b - a / 2, -SQRT_3 * a / 2)
    ctx.new_path()
    ctx.append_path(original_path)
    ctx.fill()

    # copy & rotate to third path
    ctx.set_source_rgb(*[c / 255 for c in colors[2]])
    ctx.new_path()
    ctx.append_path(original_path)
    ctx.rotate(math.radians(120))
    ctx.translate(-a / 2 - 2 * SQRT_3 / 3 * b, -SQRT_3 * a / 2)
    ctx.new_path()
    ctx.append_path(original_path)
    ctx.fill()

    # write to png
    surface.write_to_png(filename)


if __name__ == "__main__":
    draw_carvita_icon(
        "icon.png",
        img_size=1024,
        side_width=120,
        colors=[
            [108, 175, 201],
            [228, 235, 246],
            [52, 76, 129],
        ],
    )
