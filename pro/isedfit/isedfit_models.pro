;+
; NAME:
;   ISEDFIT_MODELS
;
; PURPOSE:
;   Synthesize photometry on a grid of redshift for all the
;   models generated by ISEDFIT_MONTEGRIDS.
;
; INPUTS:
;   isedfit_paramfile - iSEDfit parameter file
;
; OPTIONAL INPUTS:
;   params - data structure with the same information contained in
;     ISEDFIT_PARAMFILE (over-rides ISEDFIT_PARAMFILE)
;   thissfhgrid - if ISEDFIT_PARAMFILE contains multiple grids then
;     build this SFHgrid (may be a vector)
;   isedfit_dir - full directory path where the iSEDfit models and
;     output files should be written (default PWD=present working
;     directory) 
;   montegrids_dir - full directory path where the Monte Carlo grids
;     written by ISEDFIT_MONTEGRIDS can be found (default 'montegrids'
;     subdirectory of the PWD=present working directory)
;
; KEYWORD PARAMETERS:
;   clobber - overwrite existing files of the same name (the default
;     is to check for existing files and if they exist to exit
;     gracefully)  
;
; OUTPUTS:
;   Binary FITS tables containing the convolved photometry are written
;   to the appropriate subdirectory of ISEDFIT_DIR, but these should
;   be transparent to most users. 
;
; OPTIONAL OUTPUTS:
;
; COMMENTS:
;   Should include a bit more info about the output data tables. 
;
; EXAMPLES:
;
; MODIFICATION HISTORY:
;   J. Moustakas, 2011 Sep 01, UCSD - I began writing iSEDfit in 2005
;     while at the U of A, adding updates off-and-on through 2007;
;     however, the code has evolved so much that the old modification
;     history became obsolete!  Future changes to the officially
;     released code will be documented here.
;   jm13jan13siena - documentation rewritten and updated to reflect
;     many major changes
;   jm13aug09siena - updated to conform to a new and much simpler data
;     model; documentation updated
;
; Copyright (C) 2011, 2013, John Moustakas
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

pro isedfit_models, isedfit_paramfile, params=params, isedfit_dir=isedfit_dir, $
  montegrids_dir=montegrids_dir, thissfhgrid=thissfhgrid, clobber=clobber

    if n_elements(isedfit_paramfile) eq 0 and n_elements(params) eq 0 then begin
       doc_library, 'isedfit_models'
       return
    endif

; read the parameter file; parse to get the relevant path and
; filenames
    if n_elements(params) eq 0 then params = $
      read_isedfit_paramfile(isedfit_paramfile,thissfhgrid=thissfhgrid)

    if n_elements(isedfit_dir) eq 0 then isedfit_dir = get_pwd()
    if n_elements(montegrids_dir) eq 0 then montegrids_dir = get_pwd()+'montegrids/'

; treat each SFHgrid separately
    ngrid = n_elements(params)
    if ngrid gt 1 then begin
       for ii = 0, ngrid-1 do begin
          isedfit_models, params=params[ii], isedfit_dir=isedfit_dir, $
            montegrids_dir=montegrids_dir, clobber=clobber
       endfor 
       return
    endif 

    fp = isedfit_filepaths(params,isedfit_dir=isedfit_dir,montegrids_dir=montegrids_dir)
    if file_test(fp.models_fullpath,/dir) eq 0 then begin
       splog, 'Creating directory '+fp.models_fullpath
       file_mkdir, fp.models_fullpath
    endif

    modelfile = strtrim(fp.models_chunkfiles[0],2) ; check the first file
    if file_test(modelfile+'*') and keyword_set(clobber) eq 0 then begin
       splog, 'First ISEDFIT_MODELS ChunkFile '+modelfile+' exists; use /CLOBBER'
       return
    endif

    montefile = strtrim(fp.montegrids_chunkfiles[0],2) ; check the first file
    if file_test(montefile+'*') eq 0 then begin
       splog, 'First ISEDFIT_MONTEGRIDS ChunkFile '+montefile+' not found!'
       return
    endif

; clean up old files which might conflict with this routine
    delfiles = file_search(fp.models_fullpath+strtrim(params.prefix,2)+'_'+$
      strtrim(params.spsmodels,2)+'_'+strtrim(params.imf,2)+'_chunk_*.fits*',count=ndel)
    if ndel ne 0 then file_delete, delfiles, /quiet
    
    splog, 'SPSMODELS='+strtrim(params.spsmodels,2)+', '+$
      'REDCURVE='+strtrim(params.redcurve,2)+', IMF='+$
      strtrim(params.imf,2)+', '+'SFHGRID='+$
      string(params.sfhgrid,format='(I2.2)')

; filters and redshift grid
    filterlist = strtrim(params.filterlist,2)
    nfilt = n_elements(filterlist)

    splog, 'Synthesizing photometry in '+$
      string(nfilt,format='(I0)')+' bandpasses:'
    niceprint, replicate('  ',nfilt), filterlist

    redshift = params.redshift
    nredshift = n_elements(redshift)
    splog, 'Redshift grid: '
    if params.user_redshift then splog, '  USE_REDSHIFT adopted.'
    splog, '  zmin = '+strtrim(string(min(redshift),format='(F12.3)'),2)
    splog, '  zmax = '+strtrim(string(max(redshift),format='(F12.3)'),2)
    splog, '  nzz  = '+string(params.nzz,format='(I0)')
    if params.user_redshift eq 0 then begin
       if params.zlog then splog, '  zlog=1' else $
         splog, '  zbin = '+string(params.zbin,format='(G0.0)')
    endif 

    if (im_double(min(redshift)) le 0D) then begin
       splog, 'REDSHIFT should be positive and non-zero'
       return
    endif
    
; if REDSHIFT is not monotonic then FINDEX(), below, can't be
; used to interpolate the model grids properly; this only really
; matters if USE_REDSHIFT is passed    
    if monotonic(redshift) eq 0 then begin
       splog, 'REDSHIFT should be a monotonically increasing or decreasing array!'
       return
    endif
    
    pc10 = 3.085678D19 ; fiducial distance [10 pc in cm]
    dlum = pc10*10D^(lf_distmod(redshift,omega0=params.omega0,$ ; [cm]
      omegal0=params.omegal)/5D)/params.h100 
;   dlum = dluminosity(redshift,/cm) ; luminosity distance [cm]

; IGM attenuation    
    if params.igm then begin
       igmfile = getenv('IMPRO_DIR')+'/etc/igmtau_grid.fits.gz'
       splog, 'Reading IGM attenuation lookup table '+igmfile
       if file_test(igmfile) eq 0 then begin
          splog, 'File '+igmfile+' not found!'
          return
       endif
       igmgrid = gz_mrdfits(igmfile,1)
    endif else begin
       splog, 'Neglecting IGM absorption'
    endelse 

; now loop on each "chunk" of models (spectra) and compute the model
; photometry (modelmaggies)
    nchunk = params.nmodelchunk
    splog, 'NCHUNK = '+string(nchunk,format='(I0)')
    t1 = systime(1)
    mem1 = memory(/current)
    for ichunk = 0, nchunk-1 do begin
       t0 = systime(1)
       mem0 = memory(/current)
       print, format='("ISEDFIT_MODELS: Chunk ",I0,"/",I0, A10,$)', $
         ichunk+1, nchunk, string(13b)
;      splog, 'Reading '+fp.montegrids_chunkfiles[ichunk]
       chunk = gz_mrdfits(fp.montegrids_chunkfiles[ichunk],1,/silent)
       nmodel = n_elements(chunk)
       npix = n_elements(chunk[0].flux)
       distfactor = rebin(reform((pc10/dlum)^2.0,nredshift,1),nredshift,nmodel)
; initialize the output structure
       isedfit_models = struct_trimtags(chunk,except=['WAVE','FLUX'])
       isedfit_models = struct_addtags(temporary(isedfit_models),$
         replicate({modelmaggies: fltarr(nfilt,nredshift)},nmodel))
; build the IGM absorption vector
       if (params.igm eq 1) then begin
          igm = fltarr(npix,nredshift)
          for iz = 0, nredshift-1 do begin
             zwave = chunk[0].wave*(1.0+redshift[iz])
             windx = findex(igmgrid.wave,zwave)
             zindx = findex(igmgrid.zgrid,redshift[iz])
             igm[*,iz] = interpolate(igmgrid.igm,windx,zindx,/grid,missing=1.0)
;            plot, zwave, igm[*,iz], xr=[0,9000], xsty=3, ysty=3
;            get_element, igmgrid.zgrid, redshift[iz], jj                                   
;            plot, igmgrid.wave, igmgrid.igm[*,jj], ysty=3
          endfor
       endif
; every (rest-frame) wavelength array is the same
       flux = chunk.flux ; [NPIX,NMODEL]
       wave_edges = k_lambda_to_edges(chunk[0].wave)

; project the filters onto each SED and scale by the distance ratio;
; the code below is fast, but it doesn't include IGM attenuation
       if (params.igm eq 0) then begin
          k_projection_table, rmatrix, flux, wave_edges, $
            redshift, filterlist, /silent
          for ff = 0, nfilt-1 do rmatrix[*,*,ff] = rmatrix[*,*,ff]*distfactor
          isedfit_models.modelmaggies = reform(transpose(rmatrix,[2,0,1]),nfilt,nredshift,nmodel)
       endif else begin
; reasonably fast code that includes IGM absorption; we have to loop
; unfortunately because the IGM array changes with redshift 
          for iz = 0, nredshift-1 do begin
             bigigm = rebin(igm[*,iz],npix,nmodel)
             k_projection_table, rmatrix1, flux*bigigm, wave_edges, $
               redshift[iz], filterlist, /silent
             isedfit_models.modelmaggies[*,iz] = $
               reform(transpose(rmatrix1*distfactor[iz,0],[2,0,1]))
;; test that I'm doing the distance ratio right
;             mindx = 27
;             ff = flux[*,mindx]/(1.0+redshift[iz])*distfactor[iz,0]
;             ww = k_lambda_to_edges(chunk[0].wave)*(1.0+redshift[iz])
;             mm = k_project_filters(ww,ff,filterlist=filterlist)
;             niceprint, mm, isedfit_models.modelmaggies[*,iz]
          endfor
       endelse
       if (ichunk eq 0) then begin
          splog, 'First chunk = '+string((systime(1)-t0)/60.0,format='(G0)')+$
            ' minutes, '+strtrim(string((memory(/high)-mem0)/1.07374D9,format='(F12.3)'),2)+' GB'
       endif
       im_mwrfits, isedfit_models, fp.models_chunkfiles[ichunk], /clobber, /silent
    endfor 
    splog, 'All chunks = '+string((systime(1)-t1)/60.0,format='(G0)')+$
      ' minutes, '+strtrim(string((memory(/high)-mem1)/1.07374D9,format='(F12.3)'),2)+' GB'

return
end
