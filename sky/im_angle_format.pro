function im_angle_format, angle
; jm05apr05uofa
; place an angle in the interval [0-180]

    if (n_elements(angle) eq 0L) then begin
       print, 'Syntax - newangle = im_angle_format(angle)'
       return, -1L
    endif

    newangle = angle
    
    neg = where(newangle lt 0.0,nneg)
    if (nneg ne 0L) then newangle[neg] = 360D + newangle[neg]

    pos = where(newangle gt 180.0,npos)
    if (npos ne 0L) then newangle[pos] = newangle[pos] - 180D
    
return, newangle
end
