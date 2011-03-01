;+
; NAME:
;       IM_IMGSCL()
;
; PURPOSE:
;
; CALLING SEQUENCE:
;
; INPUTS:
;
; OPTIONAL INPUTS:
;
; KEYWORD PARAMETERS:
;
; OUTPUTS:
;
; OPTIONAL OUTPUTS:
;
; PROCEDURES USED:
;
; COMMENTS:
;
; EXAMPLES:

; MODIFICATION HISTORY:
;       J. Moustakas, 2005 Mar 22, U of A - written
;       jm05jul25uofa - several improvements
;-

function im_imgscl, image, losig=losig, hisig=hisig, boxfrac=boxfrac, log=log, $
  sqrroot=sqrroot, negative=negative, topvalue=topvalue, minvalue=minvalue
    
    imsize = size(image,/dimension)
    xsize = imsize[0] & xcen = xsize/2.0
    ysize = imsize[1] & ycen = ysize/2.0
    
    if (n_elements(losig) eq 0L) then losig = -2.0
    if (n_elements(hisig) eq 0L) then hisig = 3.0
    if (n_elements(boxfrac) eq 0L) then boxfrac = 0.20
    if (n_elements(topvalue) eq 0L) then topvalue = 239L ; !d.table_size-2
    if (n_elements(minvalue) eq 0L) then minvalue = -10L
    
    xbox = fix(xsize*boxfrac)/2L
    ybox = fix(ysize*boxfrac)/2L

    if keyword_set(log) then im = alog10(float(image))
    if keyword_set(sqrroot) then im = sqrt(float(image))

    stats = im_stats(im,sigrej=5.0)
    substats = im_stats(im[xcen-xbox+1L:xcen+xbox-1L,ycen-ybox+1L:ycen+ybox-1L],sigrej=5.0)

    mmin = stats.minrej
    mmax = stats.maxrej

;   mmin = (mn+losig*rms);>min(im)
;   mmax = (mn+hisig*rms);<max(im)
    
    img = imgscl(im,min=mmin,max=mmax,top=topvalue)
    if keyword_set(negative) then img = bytscl(topvalue-img,$
      min=minvalue,max=topvalue)

; Hogg's image scaling
    
;   img = ((lo*rms+mean)-float(image))/(lo*rms-hi*rms) ; negative image
;   img = byte((floor(img*255.99) > 0) < 255)

; Christy's image scaling    
    
;   topvalue = 250L
;   minvalue = -40L

;   img = imgscl(image,min=(mean+lo*rms)>min(image),max=(mean+hi*rms)<max(image),top=topvalue)
;   img = bytscl(image,min=min(image),max=max(image),top=topvalue)
;   img = bytscl(topvalue-img,min=minvalue,top=topvalue)

;   img = imgscl(image,min=(mean+lo*rms)>(min(image)*0.5),max=(mean+hi*rms)<max(image))

; ATV's image scaling    
    
;   imgmin = min(image[xcen-xbox:xcen+xbox,ycen-ybox:ycen+ybox])
;   imgmax = max(image[xcen-xbox:xcen+xbox,ycen-ybox:ycen+ybox])
;   imgmin = min(image) & imgmax = max(image)
;   offset = imgmin - (imgmax-imgmin)*0.01

;   img = bytscl(alog10(image-offset),min=alog10(imgmin-offset),$
;     max=alog10(imgmax-offset),top=!d.table_size-2,/nan)

return, img
end    

