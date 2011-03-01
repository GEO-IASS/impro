function im_headerforage, fitslist, ext=ext
; jm05apr07uofa
; jm08aug06nyu - removed DATAPATH input; absolute file name now
;   assumed; EXT optional input added

    if (n_elements(fitslist) eq 0L) then begin
       print, 'Syntax - forage = im_headerforage()'
       return, -1
    endif

    fitslist = file_search(fitslist,count=nfits)
    if (n_elements(ext) eq 0L) then ext = 0L
    next = n_elements(ext)

    for jj = 0L, nfits-1L do begin

       for ii = 0L, next-1L do begin
          
          h = headfits(fitslist[jj],ext=ext[ii])
          s = im_hdr2struct(h)
          forage1 = struct_trimtags(s,except='*HISTORY*')

; add tags here

          add = {fitsfile: fitslist[jj], extension: ext[ii]}
          forage1 = struct_addtags(add,forage1)

          if (n_elements(forage) eq 0L) then forage = forage1 else begin
             forage = struct_trimtags(forage,select=tag_names(forage1))
             forage1 = struct_trimtags(forage1,select=tag_names(forage[0]))
             forage = [forage,forage1]
          endelse

       endfor
          
    endfor

return, reform(forage)
end    
