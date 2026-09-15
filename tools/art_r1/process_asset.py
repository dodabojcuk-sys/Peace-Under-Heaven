#!/usr/bin/env python3
import argparse
from pathlib import Path
import cv2
import numpy as np
from PIL import Image

p=argparse.ArgumentParser()
p.add_argument('source'); p.add_argument('output'); p.add_argument('--size',default='256x192')
a=p.parse_args()
w,h=map(int,a.size.split('x'))
source_rgba=cv2.imread(a.source,cv2.IMREAD_UNCHANGED)
if source_rgba is None: raise SystemExit('cannot read source')
bgr=source_rgba[:,:,:3]
hh,ww=bgr.shape[:2]
if source_rgba.shape[2] == 4 and int(source_rgba[:,:,3].min()) < 255:
 alpha=source_rgba[:,:,3]
else:
 mask=np.zeros((hh,ww),np.uint8)
 bgd=np.zeros((1,65),np.float64); fgd=np.zeros((1,65),np.float64)
 margin=max(12,int(min(ww,hh)*.045))
 cv2.grabCut(bgr,mask,(margin,margin,ww-2*margin,hh-2*margin),bgd,fgd,8,cv2.GC_INIT_WITH_RECT)
 alpha=np.where((mask==cv2.GC_FGD)|(mask==cv2.GC_PR_FGD),255,0).astype(np.uint8)
 count, labels, stats, _=cv2.connectedComponentsWithStats((alpha>0).astype(np.uint8),8)
 if count>1:
  idx=1+np.argmax(stats[1:,cv2.CC_STAT_AREA]); alpha=np.where(labels==idx,255,0).astype(np.uint8)
 alpha=cv2.GaussianBlur(alpha,(0,0),.75)
ys,xs=np.where(alpha>8)
if not len(xs): raise SystemExit('no foreground')
pad=8
x0=max(0,xs.min()-pad); x1=min(ww,xs.max()+pad+1); y0=max(0,ys.min()-pad); y1=min(hh,ys.max()+pad+1)
rgb=cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)[y0:y1,x0:x1]
a_crop=alpha[y0:y1,x0:x1]
im=Image.fromarray(np.dstack([rgb,a_crop]),'RGBA')
im.thumbnail((w,h),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(w,h),(0,0,0,0)); canvas.alpha_composite(im,((w-im.width)//2,(h-im.height)//2))
Path(a.output).parent.mkdir(parents=True,exist_ok=True); canvas.save(a.output,optimize=True)
print(a.output,canvas.size,canvas.getbbox())
