import sys
from PIL import Image, ImageDraw
# redact.py <png> x1 y1 x2 y2 [...]  (Koordinaten im 900-px-Raster)
p=sys.argv[1]; im=Image.open(p).convert("RGB"); s=im.width/900; d=ImageDraw.Draw(im)
a=list(map(int,sys.argv[2:]))
for i in range(0,len(a),4): d.rectangle((a[i]*s,a[i+1]*s,a[i+2]*s,a[i+3]*s),fill=(70,70,70))
im.save(p)
