from PIL import Image
import json

# Open an image file
img = Image.open("test.png")

# Alternatively, using getpixel method
level = []

for r in range(200):
    level.append([])
    for c in range(200):
        level[r].append(0)
        coordinate = (c, r)
        pixel = img.getpixel(coordinate)
        if pixel[0] == 255:
            level[r][c] = 1
            print(r, c, level[r][c])
        if pixel[1] == 255 and pixel[2] == 0:
            level[r][c] = 2
            print(r, c, level[r][c])
        if pixel[1] == 255 and pixel[2] == 220:
            level[r][c] = 3
            print(r, c, level[r][c])

with open("test.json", "w", encoding="utf-8") as wf:
    wf.write(json.dumps(level))
