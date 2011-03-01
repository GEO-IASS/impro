;+
; NAME:
;   IM_GALEX_TO_MAGGIES
;
; PURPOSE:
;   Convert an input GALEX photometric catalog to Galactic
;   extinction-corrected AB maggies. 
;
; INPUTS: 
;   galex - input catalog [NGAL]
;
; OPTIONAL INPUTS: 
;
; KEYWORD PARAMETERS: 
;
; OUTPUTS: 
;   maggies - [2,NGAL] output FUV/NUV maggies 
;   ivarmaggies - [2,NGAL] corresponding inverse variance
;
; OPTIONAL OUTPUTS:
;   filterlist - GALEX filterlist names
;
; COMMENTS:
;   A minimum photometric error of [0.052,0.026] for [FUV,NUV] is
;   applied, as recommended by Morrissey+07.  Uses the MAG_AUTO
;   photometry by default.
;
; MODIFICATION HISTORY:
;   J. Moustakas, 2010 Apr 30, UCSD - based loosely on
;     M. Blanton's GALEX_TO_MAGGIES. 
;
; Copyright (C) 2010, John Moustakas
; 
; This program is free software; you can redistribute it and/or modify 
; it under the terms of the GNU General Public License as published by 
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version. 
; 
; This program is distributed in the hope that it will be useful, but 
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details. 
;-

pro im_galex_to_maggies, galex, maggies, ivarmaggies, filterlist=filterlist

    ngal = n_elements(galex)
    if (ngal eq 0L) then begin
       doc_library, 'im_galex_to_maggies'
       return
    endif

    filterlist = galex_filterlist()
    nbands = n_elements(filterlist)

; correct for Galactic extinction; use the standard reddening values
; from Wyder+07; ignore the quadratic reddening term in the FUV
; channel, and also be sure to check for non-detections
    kl = [8.24,8.20] ; [FUV,NUV]
    ebv = fltarr(ngal)
    if tag_exist(galex,'alpha_j2000') then begin
       good = where(galex.alpha_j2000 gt -900.0,ngood)
       ra = galex[good].alpha_j2000
       dec = galex[good].delta_j2000
    endif else begin
       good = where(galex.ra gt -900.0,ngood)
       ra = galex[good].ra
       dec = galex[good].dec
    endelse
    if (ngood ne 0L) then begin
       glactc, ra, dec, 2000.0, gl, gb, 1, /deg
       ebv[good] = dust_getval(gl,gb,/interp,/noloop)
    endif

; magnitude zeropoints: see http://galex.stsci.edu/doc/GI_Doc_Ops7.pdf 
    fuv_zpt = 18.82
    nuv_zpt = 20.08

; convert to maggies; ignore artifacts; require an NUV detection for
; the FUV photometry
    obsmaggies = fltarr(2,ngal)-999.0
    obsmaggieserr = fltarr(2,ngal)-999.0
    
    good = where((galex.nuv_flux_auto gt -90.0),ngood)
    if (ngood ne 0L) then begin
       obsmaggies[1,good] = galex[good].nuv_flux_auto*10^(-0.4*nuv_zpt) ; galex flux-->maggies
       obsmaggieserr[1,good] = galex[good].nuv_fluxerr_auto*10^(-0.4*nuv_zpt)
; use the aperture-matched FUV photometry, if possible
       good_fuv = where(galex[good].fuv_ncat_flux gt -900.0,ngood_fuv)
       obsmaggies[0,good[good_fuv]] =  galex[good[good_fuv]].fuv_ncat_flux*10^(-0.4*23.9) ; microJy-->maggies
       obsmaggieserr[0,good[good_fuv]] =  galex[good[good_fuv]].fuv_ncat_fluxerr*10^(-0.4*23.9)
    endif

;; apply a variety of rules to pull out maximally reliable NUV and FUV
;; photometry; note: we allow photometry from sources with
;; NUV_ARTIFACT=1, following Wyder+07, and don't explicitly cut on
;; FUV_ARTIFACT; also note: no explicit cut on FOV_RADIUS, although
;; ARTIFACT bit 6 (=32) flags sources >0.6 deg from the center of the
;; detector (see http://galex.stsci.edu/GR6/?page=ddfaq);
;    obsmaggies = fltarr(2,ngal)-999.0
;    obsmaggieserr = fltarr(2,ngal)-999.0
;    
;; case 1) solid (artifact-free) NUV measurement    
;    case1 = where((galex.nuv_flux_auto gt -90.0) and (galex.nuv_artifact le 1),ncase1)
;    if (ncase1 ne 0L) then begin
;       obsmaggies[0,case1] = galex[case1].nuv_flux_auto*10^(-0.4*nuv_zpt) ; galex flux-->maggies
;       obsmaggieserr[0,case1] = galex[case1].nuv_fluxerr_auto*10^(-0.4*nuv_zpt)
;; use the aperture-matched FUV photometry, if possible
;       case1_fuv = where(galex[case1].fuv_ncat_flux gt -900.0,ncase1_fuv)
;       obsmaggies[1,case1[case1_fuv]] =  galex[case1[case1_fuv]].fuv_ncat_flux*10^(-0.4*23.9) ; microJy-->maggies
;       obsmaggieserr[1,case1[case1_fuv]] =  galex[case1[case1_fuv]].fuv_ncat_fluxerr*10^(-0.4*23.9)
;    endif
;
;; case 2) typically we should not trust the FUV photometry of objects
;; without an NUV detection; however, a special case is if the NUV
;; photometry is affected by artifacts and the FUV photometry is
;; artifact-free, in which case we just use the FUV photometry
;    case2 = where((galex.nuv_flux_auto gt -90.0) and (galex.nuv_artifact gt 1) and $
;      (galex.fuv_artifact le 1) and (galex.fuv_flux_auto gt -90.0),ncase2)
;    if (ncase2 ne 0L) then begin
;       obsmaggies[1,case2] = galex[case2].fuv_flux_auto*10^(-0.4*fuv_zpt) ; galex flux-->maggies
;       obsmaggieserr[1,case2] = galex[case2].fuv_fluxerr_auto*10^(-0.4*fuv_zpt)
;; use the aperture-matched NUV photometry, if possible
;       case2_nuv = where(galex[case2].nuv_fcat_flux gt -900.0,ncase2_nuv)
;       obsmaggies[0,case2[case2_nuv]] =  galex[case2[case2_nuv]].nuv_fcat_flux*10^(-0.4*23.9) ; microJy-->maggies
;       obsmaggieserr[0,case2[case2_nuv]] =  galex[case2[case2_nuv]].nuv_fcat_fluxerr*10^(-0.4*23.9)
;    endif
;
;  ww = where(obsmaggies[0,*] lt -900 and obsmaggies[1,*] lt -900)
;  niceprint, galex[ww].nuv_mag, galex[ww].nuv_artifact, galex[ww].fuv_mag, galex[ww].fuv_artifact
;  help, where(obsmaggies[0,*] lt -900 and obsmaggies[1,*] gt -900)

; now correct for extinction, convert to ivarmaggies, and return
    maggies = dblarr(2,ngal)
    ivarmaggies = dblarr(2,ngal)
    
    ngood = where((obsmaggies[1,*] gt -900.0),nngood)
    if (nngood ne 0L) then begin
       factor = 10^(+0.4*kl[1]*ebv[ngood])
       maggies[1,ngood] = obsmaggies[1,ngood]*factor
       ivarmaggies[1,ngood] = 1.0/(obsmaggieserr[1,ngood]*factor)^2.0
    endif

    fgood = where((obsmaggies[0,*] gt -900.0),nfgood)
    if (nfgood ne 0L) then begin
       factor = 10^(+0.4*kl[0]*ebv[fgood])
       maggies[0,fgood] = obsmaggies[0,fgood]*factor
       ivarmaggies[0,fgood] = 1.0/(obsmaggieserr[0,fgood]*factor)^2.0
    endif
    
;   bands = ['fuv','nuv']
;   tags = bands+'_mag'
;   maggies = fltarr(nbands,ngal)
;   ivarmaggies = fltarr(nbands,ngal)
;   errtags = bands+'_magerr'
;   for ii = 0, nbands-1 do begin
;      ftag = tag_indx(galex[0],tags[ii])
;      utag = tag_indx(galex[0],errtags[ii])
;      good = where($
;        (galex.(ftag) gt 0.0) and (galex.(ftag) lt 90.0) and $
;        (galex.(utag) gt 0.0) and (galex.(utag) lt 90.0),ngood)
;      magerr = galex[good].(utag)
;      mag = galex[good].(ftag) - kl[ii]*ebv[good]
;      maggies[ii,good] = 10.0^(-0.4*mag)
;      notzero = where((maggies[ii,good] gt 0.0),nnotzero)
;      if (nnotzero ne 0L) then ivarmaggies[ii,good[notzero]] = $
;        1.0/(0.4*alog(10.0)*(maggies[ii,good[notzero]]*magerr[notzero]))^2
;   endfor
    
; minimum photometric error from Morrissey+07, plus a little
    minerr = sqrt([0.052,0.026]^2 + [0.05,0.05]^2)
    k_minerror, maggies, ivarmaggies, minerr
    if (nzero ne 0L) then maggies[zero] = 0.0

return    
end
