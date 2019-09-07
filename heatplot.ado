*! version 1.0.5  07sep2019  Ben Jann

capt which colorpalette
if _rc {
    di as err "the palettes package needs to be installed; type {stata ssc install palettes, replace}"
    exit 499
}

program heatplot, rclass
    version 13

    // some tempnames for scalars
    tempname CUTS MIN MAX
    local scalars y_K y_MIN y_MAX y_LB y_UB y_WD x_K x_MIN x_MAX x_LB x_UB x_WD
    tempname `scalars'
    foreach scalar of local scalars {
        scalar ``scalar'' = .
    }

    // syntax
    // - list of common options
    local zopts LEVels(int 0) CUTs(str) Colors(str asis) ///
        size srange(numlist max=2 >=0) TRANSform(str asis) ///
        MISsing MISsing2(str) VALues VALues2(str) HEXagon HEXagon2(str asis) ///
        scatter SCATTER2(str asis) KEYlabels(str asis) p(str) ///
        RAMP RAMP2(str asis) BACKFill BACKFill2(str)
    local yxopts ///
         bins(str)  BWidth(str)  DISCRete  DISCRete2(numlist max=1) ///
        xbins(str) XBWidth(str) XDISCRete XDISCRete2(numlist max=1) ///
        ybins(str) YBWidth(str) YDISCRete YDISCRete2(numlist max=1) ///
        clip lclip rclip tclip bclip
    local matopts lower upper noDIAGonal drop(numlist)
    local gopts noGRaph addplot(str asis) ADDPLOTNOPReserve ///
        GENerate GENerate2(str) Replace noPREServe ///
        YAXis(passthru) XAXis(passthru) *
    _parse comma matrix rest : 0
    capt _parse_mata, `matrix'
    if _rc==0 {                                   // syntax 2: heatplot mata(M)
        local syntax 2
        local 0 `"`rest'"'
        syntax [, `zopts' Statistic(name) fast `yxopts' `matopts' noLabel `gopts' ]
        capt mata mata describe `mata'
        if _rc {
            di as err `"Mata matrix `mata' not found"'
            exit _rc
        }
    }
    else if `: list sizeof matrix'==1 {            // syntax 3: heatplot matrix
        local syntax 3
        syntax [anything(name=matrix)] [, `zopts' `matopts'  ///
            EQuations EQuations2(str) Label `gopts' ]
        confirm matrix `matrix'
        if `"`equations2'"'!="" local equations equations
    }
    else {                                        // syntax 1: heatplot [z] y x
        local syntax 1
        syntax varlist(min=2 max=3 fv) [if] [in] [aw fw iw pw] [, ///
            `zopts' Statistic(name) fast SIZEProp SIZE2(str asis) RECenter ///
            `yxopts' FILLin(numlist max=2 missingok) noLabel ///
            idgenerate(str) /// undocumented
            `gopts' ]
    }
    // - handle hexagon option (must do this first)
    if `"`hexagon2'"'!="" local hexagon hexagon
    if "`hexagon'"!="" {
        _parse_hex, `hexagon2' // returns hexdir hexorder hexodd
    }
    // - collect variables
    if `syntax'==1 {
        gettoken z0 y0 : varlist
        gettoken y0  x0 : y0
        gettoken x0    : x0
        if `"`x0'"'=="" {
            local x0 `"`y0'"'
            local y0 `"`z0'"'
            local z0
        }
        if "`hexdir'"=="1" { // flip variables
            local tmp `x0'
            local x0 `y0'
            local y0 `tmp'
        }
        if "`z0'"!="" {
            capt confirm numeric variable `z0'
        }
    }
    // - handle discrete()
    if inlist(`syntax',1,2) {
        if "`discrete2'"!="" local discrete discrete
        if "`discrete2'"=="" local discrete2 1 // default width: 1 unit
        foreach v in x y {
            if "`discrete'"!=""     local `v'discrete `v'discrete
            if "``v'discrete2'"!="" local `v'discrete `v'discrete
            if "``v'discrete2'"=="" local `v'discrete2 `discrete2'
        }
    }
    // - handle categorical variable (i. or string)
    if `syntax'==1 {
        foreach v in x y {
            if substr("``v'0'",1,2)=="i." {
                local `v'0 = substr("``v'0'",3,.)
                local `v'cat `v'cat
            }
            else {
                capt confirm numeric variable ``v'0'
                if _rc local `v'cat `v'cat
            }
            if "``v'cat'``v'discrete'"!="" {
                if "``v'cat'"!="" local `v'discrete ""
                scalar ``v'_WD' = ``v'discrete2'
            }
        }
    }
    // - handle z-options: levels(), cuts(), missing(), values(), keyabels()
    if `"`cuts'"'!="" {
        if `levels'>0 {
            di as err "only one of levels() and cuts() allowed"
            exit 198
        }
        _check_cuts `CUTS', cuts(`cuts')
    }
    if `"`missing2'"'!="" local missing missing
    if "`missing'"!=""    _parse_missing, `missing2'
    if `"`values2'"'!=""  local values values
    if "`values'"!=""     _parse_values, `values2'
    if `"`ramp2'"'!=""    local ramp ramp
    if "`ramp'"!="" {
        if `"`keylabels'"'!="" {
            di as err "ramp() and keylabels() not both allowed"
            exit 198
        }
        tempvar ramp_ID ramp_Y ramp_X
        _parse_ramp `ramp_Y' `ramp_X', `ramp2'
    }
    else {
        _parse_keylab `keylabels'
    }
    if `"`backfill2'"'!="" local backfill backfill
    if "`backfill'"!=""    _parse_backfill, `backfill2'
    // - handle bins()
    if inlist(`syntax',1,2) {
        if `"`bins'`bwidth'"'!="" {
            if "`xcat'`xdiscrete'"!="" & "`ycat'`ydiscrete'"!="" &  {
                di as err "bins()/bwidth() not allowed with categorical/discrete variables"
                exit 198
            }
            if `"`bins'"'!="" {
                if `"`bwidth'"'!="" {
                    di as err "bins() and bwidth() not both allowed"
                    exit 198
                }
            }
        }
        foreach v in x y {
            if `"``v'bins'``v'bwidth'"'!="" {
                if "``v'cat'``v'discrete'"!="" {
                    di as err "`v'bins() not allowed with categorical/discrete `v'"
                    exit 198
                }
                if `"``v'bins'"'!="" {
                    if `"``v'bwidth'"'!="" {
                        di as err "`v'bins() and `v'bwidth() not both allowed"
                        exit 198
                    }
                    _parse_bins `v' 0 ``v'_K' ``v'_LB' ``v'_UB' ``v'_WD' ``v'bins'
                }
                else _parse_bins `v' 1 ``v'_K' ``v'_LB' ``v'_UB' ``v'_WD' ``v'bwidth'
            }
            else if "``v'cat'``v'discrete'"=="" {
                if `"`bins'"'!="" ///
                    _parse_bins `v' 0 ``v'_K' ``v'_LB' ``v'_UB' ``v'_WD' `bins'
                else              ///
                    _parse_bins `v' 1 ``v'_K' ``v'_LB' ``v'_UB' ``v'_WD' `bwidth'
            }
        }
    }
    // - clip option
    if "`clip'"!="" {
        local xclip clip
        local yclip clip
    }
    else {
        if "`rclip'"!="" & "`lclip'"!="" local xclip clip
        else if "`rclip'"!=""            local xclip rclip
        else if "`lclip'"!=""            local xclip lclip
        if "`tclip'"!="" & "`bclip'"!="" local yclip clip
        else if "`tclip'"!=""            local yclip rclip
        else if "`bclip'"!=""            local yclip lclip
    }
    if "`hexdir'"=="1" {
        local tmp `xclip'
        local xclip `yclip'
        local yclip `tmp'
    }
    // - handle recenter
    if `syntax'==1 {
        if "`recenter'"!="" {
            if "`xcat'`xdiscrete'"=="" local xrecenter xrecenter
            if "`ycat'`ydiscrete'"=="" local yrecenter yrecenter
        }
    }
    // - handle statistic() and size()
    if `syntax'==1 {
        if `"`statistic'"'=="" {
            if "`z0'"=="" local statistic "percent"
            else          local statistic "mean"
        }
        else if `"`statistic'"'=="asis" & "`z0'"=="" {
            di as err "statistic(asis) only allowed if z variable is specified"
            exit 198
        }
        if (("`size'"!="") + ("`sizeprop'"!="") + (`"`size2'"'!=""))>1 {
            di as err "only one of size, sizeprop, and size() allowed"
            exit 198
        }
    }
    else if `syntax'==2 {
        if `"`statistic'"'=="" {
            if "`ydiscrete'"!="" & "`xdiscrete'"!="" local statistic asis
            else                                     local statistic sum
        }
    }
    else /*syntax==3*/ local statistic asis
    // - handle scatter option
    if `"`scatter2'"'!="" local scatter scatter
    if "`scatter'"!="" {
        if "`hexagon'"!="" {
            di as err "hexagon and scatter not both allowed"
            exit 198
        }
        if `"`scatter2'"'!="" {
            _symbolpalette `scatter2'
            local scatter2 `"`r(p)'"'
        }
        if `"`scatter2'"'=="" local scatter2 O
    }
    // - handle lower/upper
    if inlist(`syntax',2,3) {
        if "`upper'"!="" & "`lower'"!="" {
            di as err "upper and lower not both allowed"
            exit 198
        }
    }
    // - handle graph options, including p#()
    if `syntax'==1 {
        _get_gropts, graphopts(`options') gettwoway grbyable getbyallowed(LEGend) missingallowed
        local by "`s(varlist)'"
        if "`by'"!="" {
            local bymissing "`s(missing)'"
            _parse_bylegend, `s(by_legend)' `ramp' // returns bylegend
            local byopt by(`by', `byopt' `bymissing' `bylegend' `s(byopts)')
        }
    }
    else {
        _get_gropts, graphopts(`options') gettwoway
    }
    local options `s(twowayopts)'
    _parse_popts `s(graphopts)'
    _check_gropts, `graphopts'
    local options `options' `graphopts'
    local AXIS `yaxis' `xaxis' // need to pass through to each plot
    if "`ramp'"!="" {
        _parse_ramp_gropts, `options'
    }
    // generate option
    _parse_generate `generate2'
    if "`generate2'"!="" local generate generate
    if "`generate'"!="" {
        foreach v0 in _Z _Zid _Y _Yshape _X _Xshape _Size {
            gettoken v generate2 : generate2
            if `"`v'"'=="" local v `v0'
            if "`replace'`preserve'"=="" confirm new variable `v'
            local vnames `vnames' `v'
        }
    }
    
    // (remove once support for density with hex implemented)
    if "`hexagon'"!="" {
        if "`yclip'`xclip'"!="" {
            if `"`statistic'"'=="density" {
                di as err "combining statistic(density) with clip is currently not supported in hexagon plots"
                exit 198
            }
        }
    }
    
    // prepare data
    // - preserve
    if `"`idgenerate'"'!="" { // undocumented
        tempvar ID
        gen double `ID' = _n
    }
    preserve
    qui count
    local N0 = r(N)
    // - write matrix to data
    if inlist(`syntax',2,3) {
        tempvar x0 y0 z0
        qui gen double `z0' = .
        qui gen double `y0' = .
        qui gen double `x0' = .
        if      `syntax'==2 mata: writematamatrixtodata(`mata')
        else if `syntax'==3 mata: writematrixtodata()
        if "`hexdir'"=="1" { // flip variables
            local tmp `x0'
            local x0 `y0'
            local y0 `tmp'
        }
    }
    // - select sample
    marksample touse, novarlist
    markout `touse' `y0' `x0', strok
    if "`missing'"=="" {
        if "`z0'"!="" markout `touse' `z0'
    }
    if `syntax'==1 {
        if "`by'"!="" & "`bymissing'"=="" markout `touse' `by', strok
    }
    if `"`size2'"'!="" {
        tempvar z2
        qui gen double `z2' = abs(`size2') if `touse'
        markout `touse' `z2'
    }
    qui keep if `touse'
    // - handle weights and count observations
    if `syntax'==1 {
        if "`weight'"!="" {
            tempvar w
            qui gen double `w' `exp'
            local wgt "[`weight' = `w']"
            if "`weight'"=="pweight" local swgt "[aw = `w']"
            else                     local swgt "[`weight' = `w']"
            su `touse' `swgt', meanonly
            local N = r(N)
        }
        else {
            qui count
            local N = r(N)
        }
    }
    else {
        qui count
        local N = r(N)
    }
    // - drop all irrelevant variables
    keep `y0' `x0' `z0' `z2' `w' `by' `ID'

    // collect titles for axes and legend
    if `syntax'==1 {
        if "`xcat'"=="" | `"`: value label `x0''"'=="" | "`label'"!="" {
            if "`label'"==""    local xtitle: var lab `x0'
            if `"`xtitle'"'=="" local xtitle `x0'
        }
        if "`ycat'"=="" | `"`: value label `y0''"'=="" | "`label'"!="" {
            if "`label'"==""    local ytitle: var lab `y0'
            if `"`ytitle'"'=="" local ytitle `y0'
        }
    }
    else if `syntax'==2 {
        local xtitle Columns
        local ytitle Rows
    }
    if "`z0'"=="" local ztitle "`statistic'"
    else {
        if `syntax'==2 {
            if "`statistic'"!="asis" local ztitle "`statistic'"
            else                     local ztitle "`mata'"
        }
        else if `syntax'==3 local ztitle "`matrix'"
        else                local ztitle "`z0'"
    }
    if `"`transform'"'!="" & `"`retransform'"'=="" {
        local ztitle: subinstr local transform "@" `"`ztitle'"', all
    }

    // make bins of x and y
    if `"`idgenerate'"'!="" {   // undocumented
        gettoken IDY IDX : idgenerate
        gettoken IDX     : IDX
    }
    tempname x y
    if inlist(`syntax',1,2) {
        foreach v in x y {
            if "``v'cat'"!="" ///
                _makebin_categorical "`fast'" `v' ``v'' ``v'0' ``v'_K' ///
                    ``v'_LB' ``v'_MIN' ``v'_UB' ``v'_MAX' "`label'"
            else if "``v'discrete'"!="" {
                 if `syntax'==1 _makebin_discrete ``v'' ``v'0' ``v'_K' ///
                     ``v'_LB' ``v'_MIN' ``v'_UB' ``v'_MAX' ``v'_WD'
                 else {
                     rename ``v'0' ``v''
                     if "``v'discrete2'"!="" scalar ``v'_WD' = ``v'discrete2'
                 }
            }
            else if "`hexagon'"=="" ///
                _makebin_continuous `v' ``v'' ``v'0' ``v'_K' ``v'_LB' ///
                    ``v'_MIN' ``v'_UB' ``v'_MAX' ``v'_WD' "``v'tight'" ///
                    "``v'clip'" "`swgt'"
            else /// hexagon
                _hexbin_prepare `v' ``v'' ``v'0' ``v'_K' ``v'_LB' ///
                    ``v'_MIN' ``v'_UB' ``v'_MAX' ``v'_WD' "``v'tight'" ///
                    `hexodd' "`swgt'"
        }
    }
    else {
        rename `x0' `x'
        rename `y0' `y'
    }
    if "`hexagon'"!="" {
        if "`xrecenter'"!="" clonevar `x0' = `x'
        if "`yrecenter'"!="" clonevar `y0' = `y'
        _hexbin `x' `x_LB' `x_UB' `x_WD' `x_MIN' `x_MAX' "`xtight'" "`xclip'" ///
                `y' `y_LB' `y_UB' `y_WD' `y_MIN' `y_MAX' "`ytight'" "`yclip'" ///
                `hexorder'
    }
    if `"`idgenerate'"'!="" {   // undocumented
        gettoken IDY IDX : idgenerate
        gettoken IDX     : IDX
        sort `y'
        qui gen `IDY' = sum(`y'!=`y'[_n-1]) if `y'<.
        sort `x'
        qui gen `IDX' = sum(`x'!=`x'[_n-1]) if `x'<.
        sort `ID'
        tempfile idgentmp
        qui save `idgentmp'
        restore
        capt drop `IDY'
        capt drop `IDX'
        qui merge 1:1 `ID' using `idgentmp', nogenerate
        preserve
    }
    
    // aggregate outcome and handle transformation and size variable
    if "`sizeprop'"!="" {
        tempvar z2
        if "`w'"!="" qui gen double `z2' = `w'
        else         qui gen double `z2' = 1
    }
    if `"`statistic'"'!="asis" {
        if "`z0'"=="" {
            tempvar z0
            qui gen double `z0' = 1
        }
        if "`sizeprop'"!=""  local z2stat (percent) `z2'
        else if "`z2'"!=""   local z2stat (mean)    `z2'
        if "`xrecenter'"!="" local xrcstat (mean) `x0'
        if "`yrecenter'"!="" local yrcstat (mean) `y0'
        if "`statistic'"=="density" {
            local statistic0 density
            local statistic percent
        }
        else if "`statistic'"=="proportion" {
            local statistic0 proportion
            local statistic percent
        }
        if "`fast'"!="" local collapse gcollapse // requires gtools
        else            local collapse collapse
        `collapse' (`statistic') `z0' `z2stat' `xrcstat' `yrcstat' ///
            `wgt', fast by(`by' `y' `x')
        if "`statistic0'"=="density" {
            local statistic `statistic0'
        }
        else if "`statistic0'"=="proportion" {
            qui replace `z0' = `z0' / 100
            local statistic `statistic0'
        }
    }
    qui drop if `x'>=. | `y'>=. // no longer needed (missings were relevant 
                                // only for computing percentages by collapse)

    // compute areas in case of clip
    if "`statistic0'"=="density" {
        if "`yclip'`xclip'"!="" {
            tempname CTAG
            qui gen byte `CTAG' = 0
            foreach v in y x {
                if "``v'clip'"!="" {
                    if "``v'clip'"!="rclip" ///
                        qui replace `CTAG' = 1 if ``v'' < (``v'_LB'+``v'_WD'/2)
                    if "``v'clip'"!="lclip" ///
                        qui replace `CTAG' = 1 if (``v''+``v'_WD'/2) > ``v'_UB'
                }
            }
            tempname AREA
            qui gen double `AREA' = cond(`CTAG', 1, `y_WD' * `x_WD')
            mata: setarea("y")
            mata: setarea("x")
            qui replace `z0' = `z0' / 100 / (`AREA')
            drop `CTAG' `AREA'
        }
        else qui replace `z0' = `z0' / 100 / (`y_WD' * `x_WD')
    }
    
     // z: apply display format and rename (to prevent name conflict later on)
    tempname z
    rename `z0' `z'
    if `"`valuesfmt'"'!="" format `valuesfmt' `z'
    
    // apply transform
    if `"`transform'"'!="" {
        local transform: subinstr local transform "@" "`z'", all
        qui replace `z' = `transform'
    }
    
    // handle size
    if "`size'"!="" {
        tempvar z2
        qui gen double `z2' = abs(`z')
        qui replace `z2' = 0 if `z2'>=.
    }
    if "`z2'"!="" {
        if "`scatter'"=="" {
            gettoken size_min size_max : srange
            gettoken size_max          : size_max
            su `z2', meanonly
            if "`size_min'"=="" {
                qui replace `z2' = sqrt(`z2'/r(max))
            }
            else {
                if "`size_max'"=="" local size_max 1
                qui replace `z2' = sqrt(`z2'/r(max) * ///
                    (`size_max'-`size_min') + `size_min')
            }
        }
    }
    
    // fillin
    _fillin "`fillin'" `x' `x_K' `x_LB' `x_WD' "`xtight'" "`xcat'`xdiscrete'" ///
                       `y' `y_K' `y_LB' `y_WD' "`ytight'" "`ycat'`ydiscrete'" ///
                       `z' "`z2'" "`by'" "`hexagon'" `hexorder' `hexodd'
    
    // determine range of data and set levels if cuts contains @min/@max
    su `z', meanonly
    scalar `MIN' = r(min)
    scalar `MAX' = r(max)
    if "`cuts'"!="" {
        _parse_cuts `CUTS' `MIN' `MAX' `"`cuts'"'
    }
    
    // if cuts() has been specified: add intervals at bottom and top, if needed
    capt confirm matrix `CUTS'
    if _rc==0 {
        if `MIN'<`CUTS'[1,1] {
            local ++levels
            matrix `CUTS' = J(1, `levels'+1, .) \ (`MIN', `CUTS')
            matrix `CUTS' = `CUTS'[2,1...] // so that colnames are correct
        }
        if `MAX'>`CUTS'[1,`levels'+1] {
            local ++levels
            matrix `CUTS' = `CUTS', `MAX'
        }
    }
    
    // get colors
    if "`colors'"=="" {
        if c(stata_version)<14.2 local colors "viridis"
        else                     local colors "hcl, viridis"
    }
    if `levels'==0 {
        _colorpalette `levels' `colors'
        if `"`backfill'"'!="" local levels = r(n) - 1
        else                  local levels = r(n)
    }
    else {
        if `"`backfill'"'!="" _colorpalette `=`levels'+1' `colors'
        else                  _colorpalette `levels' `colors'
    }
    local colors `"`r(p)'"'
    if `"`backfill'"'!="" {
        if `"`backfill_last'"'=="" {
            gettoken backfill_color colors0 : colors, quotes
            gettoken colors colors0 : colors0, quotes
            while (1) {
                gettoken color colors0 : colors0, quotes
                if `"`color'"'=="" continue, break
                local colors `"`colors' `color'"'
            }
        }
        else {
            gettoken colors colors0 : colors, quotes
            while (1) {
                gettoken color colors0 : colors0, quotes
                if `"`colors0'"'=="" { // last color
                    local backfill_color `"`color'"'
                    continue, break
                }
                local colors `"`colors' `color'"'
            }
        }
    }
    if "`missing'"!="" & "`ramp'"=="" {
        local legend - " " 1 `missing_label'
    }

    // set cuts
    capt confirm matrix `CUTS'
    if _rc {
        matrix `CUTS' = J(1, `levels', .)
        matrix `CUTS'[1,1] = `MIN'
        forv i = 2/`levels' {
            matrix `CUTS'[1,`i'] = `MIN' + (`i'-1) * (`MAX' - `MIN') / `levels'
        }
        matrix `CUTS' = `CUTS', `MAX'
    }

    // prepare legend
    if "`keylabels'"=="" & "`ramp'"=="" {
        if `levels' <= 24 local keylabels "all"
        else {
            local keylabels = ceil(`levels'/24)
            numlist "`=1+`keylabels''(`keylabels')`=`levels'-`keylabels''"
            local keylabels "1 `r(numlist)' `levels'"
        }
    }

    // categorize outcome and collect legend keys
    tempvar Z
    qui gen byte `Z' = .z
    qui replace  `Z' = 1 if `z'<. // (set first bin)
    local ul = `CUTS'[1,1]
    forv i = 1/`levels' {
        // categorize  (skip first bin)
        if `i'>1 {
            qui replace `Z' = `Z' + (`z'>=`CUTS'[1,`i']) if `z'<.
        }
        if "`ramp'"!="" continue
        // key labels
        local ll `ul'
        local ul = `CUTS'[1,`i'+1]
        if "`keylabels'"=="none"                  local keylab
        else if "`keylabels'"=="all"              local keylab ok
        else if `:list posof "`i'" in keylabels'  local keylab ok
        else                                      local keylab
        if "`keylab'"!="" {
            if "`keylab_interval'`keylab_range'"=="" {
                local keylab = (`ll'+`ul')/2
                if `"`retransform'"'!="" {
                    local keylab: subinstr local retransform "@" "`keylab'", all
                }
                local keylab `: di `keylab_format' `keylab''
            }
            else {
                local ll0 `ll'
                local ul0 `ul'
                if `"`retransform'"'!="" {
                    local ll0: subinstr local retransform "@" "`ll0'", all
                    local ul0: subinstr local retransform "@" "`ul0'", all
                }
                local ll0 `:di `keylab_format' `ll0''
                if "`keylab_interval'"!="" {
                    local ul0 `:di `keylab_format' `ul0''
                    if `i'<`levels' local keylab "[`ll0', `ul0')"
                    else local keylab "[`ll0', `ul0']"
                }
                else {
                    if `i'<`levels' local ul0 = `ul0' - `keylab_range'
                    local ul0 `:di `keylab_format' `ul0''
                    local keylab "`ll0'-`ul0'"
                }
            }
        }
        local ii = `i' + ("`missing'"!="")
        local legend `ii' "`keylab'" `legend'
        if "`keylabels'"=="minmax" {
            if `i'==1 {
                local keylab `:di `keylab_format' `ll''
                local legend `legend' - "`keylab'"
            }
            else if `i'==`levels' {
                local keylab `:di `keylab_format' `ul''
                local legend  - "`keylab'" `legend'
            }
        }
    }

    // expand data
    tempvar X Y
    if "`scatter'"=="" {
        tempvar id
        qui gen `id' = _n
        if "`hexagon'"!="" {
            qui expand 7
            sort `id'
            qui by `id': gen double `X' = cond(inlist(_n,5,6), -1, 1) * ///
                cond(inlist(_n,1,4), 0, `x_WD'/2) if _n<7
            qui by `id': gen double `Y' = cond(inlist(_n,1,2,6), -1, 1) / ///
                cond(inlist(_n,1,4), 1, 2) * `y_WD' * (2/3) if _n<7
        }
        else {
            qui expand 5
            sort `id'
            qui by `id': gen double `X' = cond(inlist(_n,1,2), -`x_WD'/2, `x_WD'/2) if _n<5
            qui by `id': gen double `Y' = cond(inlist(_n,1,4), -`y_WD'/2, `y_WD'/2) if _n<5
        }
        if "`yclip'`xclip'"!="" {
            tempname CTAG
            qui gen byte `CTAG' = 0
            foreach v in y x {
                local V = strupper("`v'")
                if "``v'clip'"!="" {
                    if "``v'clip'"!="rclip" ///
                        qui replace `CTAG' = 1 if (``v'' + ``V'') < ``v'_LB' & ``V''<.
                    if "``v'clip'"!="lclip" ///
                        qui replace `CTAG' = 1 if (``v''+``V'') > ``v'_UB' & ``V''<.
                }
            }
            if "`hexagon'"!="" mata: cliphexborders()
            else {
                mata: clipborders("y")
                mata: clipborders("x")
            }
            drop `CTAG'
        }
        if "`z2'"!="" {
            qui replace `X' = `X'*`z2'
            qui replace `Y' = `Y'*`z2'
        }
    }
    if "`xrecenter'"!="" {
        qui replace `x' = `x0' if `x0'<.
        drop `x0'
    }
    if "`yrecenter'"!="" {
        qui replace `y' = `y0' if `y0'<.
        drop `y0'
    }
    if "`scatter'"=="" {
        qui replace `X' = `x' + `X'
        qui replace `Y' = `y' + `Y'
        qui by `id': replace `x' = . if _n!=1
        qui by `id': replace `y' = . if _n!=1
        qui by `id': replace `z' = . if _n!=1
        drop `id'
    }
    else {
        qui gen `X' = .
        qui gen `Y' = .
    }

    // addplot: get original data back in
    if `"`addplot'"'!="" & "`addplotnopreserve'"=="" {
        tempfile plotdata
        if "`by'"!="" {
            tempvar byindex sortindex
            sort `by'
            qui by `by': gen double `byindex' = _n
            qui save `"`plotdata'"', replace
            restore, preserve
            qui gen double `sortindex' = _n
            sort `by'
            qui by `by': gen double `byindex' = _n
            qui merge 1:1 `by' `byindex' using `"`plotdata'"', ///
                keep(match master using) nogenerate
            sort `sortindex'
            drop `byindex' `sortindex'
        }
        else {
            qui save `"`plotdata'"', replace
            restore, preserve
            qui merge 1:1 _n using `"`plotdata'"', ///
                keep(match master using) nogenerate
        }
        capt erase `"`plotdata'"'
    }

    // swap x and y if hexdir==1
    if "`hexdir'"=="1" mata: swapxy()

    // compile plot
    local plots
    if "`scatter'"=="" | "`keylab_area'"!="" {
        // in case of scatter: include area plots to create legend
        if "`missing'"!="" {
            local plots (area `Y' `X' if `Z'==.z, `AXIS' nodropbase/*
                */ cmissing(n) color(black) finten(100) /*`lopts' */`missing2' )
        }
        local clist
        forv i = 1/`levels' {
            gettoken c clist : clist
            if `"`c'"'=="" {    // recycle
                gettoken c clist : colors
            }
            local plots `plots' (area `Y' `X' if `Z'==`i', `AXIS' nodropbase/*
                */ cmissing(n) color("`c'") finten(100) `p' `p`i'')
        }
    }
    if "`scatter'"!="" {
        if "`missing'"!="" {
            local plots `plots' (scatter `y' `x' if `Z'==.z, `AXIS'/*
                */ ms(X) color(black) `missing2')
        }
        if "`z2'"!="" {
            local zwgt [aw = `z2']
            forv i = 1/`levels' {
                tempname y`i'
                qui gen `y`i'' = `y' if `Z'==`i'
            }
        }
        local clist
        local mslist
        forv i = 1/`levels' {
            gettoken c clist : clist
            if `"`c'"'=="" {    // recycle
                gettoken c clist : colors
            }
            gettoken ms mslist : mslist
            if `"`ms'"'=="" {    // recycle
                gettoken ms mslist : scatter2
            }
            if "`z2'"!="" local tmp `y`i'' `x' [aw = `z2']
            else          local tmp `y' `x' if `Z'==`i'
            local plots `plots' (scatter `tmp', `AXIS' ms(`ms') color("`c'")/*
                */ `p' `p`i'')
        }
    }
    if "`equations'"!="" {
        local plots `plots' (scatteri `eqcoords', `AXIS' recast(area)/*
            */ nodropbase cmissing(n) fcolor(none) lstyle(xyline)/*
            */ lalign(center) `equations2')
    }
    if "`values'"!="" {
        local plots `plots' (scatter `y' `x' if `z'<., `AXIS' ms(i)/*
            */ mlabel(`z') mlabpos(0) mlabcolor(black) `values2')
    }
    if `"`addplot'"'!="" {
        local plots `plots' || `addplot' ||
    }
    if "`ramp'"=="" {
        if "`by'"=="" local legendopt order(`legend') position(3)
        else          local legendopt order(`legend')
        local legendopt legend(all subtitle(`ztitle', size(medsmall)) ///
             `legendopt' cols(1) rowgap(0) size(vsmall) keygap(tiny) ///
             symxsize(medlarge) `keylab_opts')
    }
    if `syntax'==3 {
        local yscale yscale(reverse)
        local yhor ylabel(, angle(0))
    }
    else if `syntax'==2 {
        local yscale yscale(reverse)
        local xscale xscale(alt)
    }
    else if "`ycat'"!="" {
        local yhor ylabel(, angle(0))
    }
    if "`backfill'"!="" {
        if "`backfill_inner'"!="" {
            local backfill `"plotregion(icolor(`backfill_color'))"'
        }
        else {
            local backfill `"plotregion(color(`backfill_color') icolor(`backfill_color'))"'
        }
    }
    if "`graph'"=="" {
        if "`ramp'"!="" {
            tempname maingraph legendgraph
            local options `ramp_mopts' name(`maingraph') `options'
        }
        else {
            local options `legendopt' `options'
        }
        graph twoway `plots', ytitle(`"`ytitle'"') xtitle(`"`xtitle'"') ///
            `yscale' `yhor' `ylabel' `xscale' `xlabel' `backfill' ///
            `byopt' `options'
        if "`ramp'"!="" {
            // generate color ramp
            qui gen long `ramp_ID' = .
            qui gen double `ramp_Y' = .
            qui gen double `ramp_X' = .
            mata: generatescalecoords(st_matrix("`CUTS'"), ///
                ("`ramp_ID'", "`ramp_Y'", "`ramp_X'"))
            if `"`retransform'"'!="" {
                local tmptransform: subinstr local retransform "@" "`ramp_Y'", all
                qui replace `ramp_Y' = `tmptransform' if `ramp_Y'<.
            }
            local plots
            local clist
            forv i = 1/`levels' {
                gettoken c clist : clist
                if `"`c'"'=="" {    // recycle
                    gettoken c clist : colors
                }
                local plots `plots' (area `ramp_YX' if `ramp_ID'==`i',/*
                    */ nodropbase cmissing(n) color("`c'") finten(100) `p' `p`i'')
            }
            local ymin = `CUTS'[1,1]
            local ymax = `CUTS'[1,`levels'+1]
            if `"`retransform'"'!="" {
                local tmptransform: subinstr local retransform "@" "`ymin'", all
                local ymin = `tmptransform'
                local tmptransform: subinstr local retransform "@" "`ymax'", all
                local ymax = `tmptransform'
            }
            if `"`ramp_ylabel'"'=="" local ramp_ylabel `ymin' `ymax'
            else {
                local ramp_ylabel: subinstr local ramp_ylabel "@min" "`ymin'", all
                local ramp_ylabel: subinstr local ramp_ylabel "@max" "`ymax'", all
            }
            graph twoway `plots', name(`legendgraph') `ramp_opts'
            if "`ramp_N_preserve'"!="" {
                // remove observation added by generatescalecoords()
                qui keep in 1/`ramp_N_preserve'
            }
            // put graphs together
            if "`ramp_pos'"=="right"     local grcombine `maingraph' `legendgraph', rows(1)
            else if "`ramp_pos'"=="left" local grcombine `legendgraph' `maingraph', rows(1)
            else if "`ramp_pos'"=="top"  local grcombine `legendgraph' `maingraph', cols(1)
            else /*bottom*/              local grcombine `maingraph' `legendgraph', cols(1)
            graph combine `grcombine' iscale(1) commonscheme `ramp_combopts' `ramp_gropts'
        }
    }
    
    // generate
    if "`generate'"!="" {
        if `"`addplot'"'!="" & "`addplotnopreserve'"=="" {
            if "`preserve'"!="" { // get rid of orig data
                keep `z' `Z' `y' `Y' `x' `X' `z2'
                keep if `Z'<. | `Z'==.z
            }
            else {
                qui count
                if (r(N)>`N0') {
                    di as txt "number of observations will be reset to " r(N)
                    di as txt "Press any key to continue, or Break to abort"
                    more
                }
            }
        }
        else if "`preserve'"=="" {
            tempfile plotdata
            if "`by'"!="" {
                tempvar byindex sortindex
                sort `by'
                qui by `by': gen double `byindex' = _n
                qui save `"`plotdata'"', replace
                restore, preserve
                qui gen double `sortindex' = _n
                sort `by'
                qui by `by': gen double `byindex' = _n
                qui merge 1:1 `by' `byindex' using `"`plotdata'"', ///
                    keep(match master using) nogenerate
                sort `sortindex'
                drop `byindex' `sortindex'
            }
            else {
                qui save `"`plotdata'"', replace
                restore, preserve
                qui merge 1:1 _n using `"`plotdata'"', ///
                    keep(match master using) nogenerate
            }
            capt erase `"`plotdata'"'
            qui count
            if (r(N)>`N0') {
                di as txt "number of observations will be reset to " r(N)
                di as txt "Press any key to continue, or Break to abort"
                more
            }
        }
        lab var `z' "Z value"
        lab var `Z' "Z id"
        lab var `y' "Y value (midpoint)"
        lab var `Y' "Y shape (coordinates)"
        lab var `x' "X value (midpoint)"
        lab var `X' "X shape (coordinates)"
        if "`z2'"!="" {
            lab var `z2' "shape scaling size"
        }
        foreach v0 in `z' `Z' `y' `Y' `x' `X' `z2' {
            gettoken v vnames : vnames
            if "`replace'"!="" {
                capt confirm new var `v', exact
                if _rc drop `v'
            }
            rename `v0' `v'
            local vdescribe `vdescribe' `v'
        }
        order `vdescribe', last
        describe `vdescribe'
    }
    
    // returns
    foreach v in x y {
        return scalar `v'_ub  = ``v'_UB'
        return scalar `v'_lb  = ``v'_LB'
        return scalar `v'_wd  = ``v'_WD'
        return scalar `v'_k   = ``v'_K'
    }
    return local eqcoords `"`eqcoords'"'
    return local keylabels `"`legend'"'
    return local colors `"`colors'"'
    return scalar levels = `levels'
    return local xtitle `"`xtitle'"'
    return local ytitle `"`ytitle'"'
    return local ztitle `"`ztitle'"'
    return matrix cuts = `CUTS'
    return scalar N = `N'
    
    // skip restore if appropriate
    if "`generate'"!="" restore, not
end

program _parse_mata
    syntax, mata(name)
    c_local mata `mata'
end

program _parse_bins
    gettoken x 0 : 0
    gettoken iswd 0 : 0
    gettoken K  0 : 0
    gettoken LB 0 : 0
    gettoken UB 0 : 0
    gettoken WD 0 : 0
    _parse comma bins 0 : 0
    syntax [, tight ltight rtight ]
    if "`ltight'"!="" & "`rtight'"!="" local tight tight
    else if "`tight'"==""              local tight `ltight' `rtight'
    numlist `"`bins'"', min(0) max(4) missingokay
    local bins `r(numlist)'
    if `iswd' gettoken wd  lb : bins
    else      gettoken k   lb : bins
    gettoken lb ub : lb
    gettoken ub rest : ub
    if `"`rest'"'!="" {
        di as err `"`rest' not allowed"'
        exit 198
    }
    if "`k'"=="" local k .
    if  "`k'"!="." {
        capt numlist "`k'", integer max(1) range(>0)
        if _rc {
            di as err "`k' not allowed; number of bins must be a positive integer"
            exit 198
        }
    }
    if "`wd'"=="" local wd .
    if "`wd'"!="." {
        if `wd'<=0 {
            di as err "`wd' not allowed; bin width must be positive"
            exit 198
        }
    }
    if "`lb'"=="" local lb .
    if "`ub'"=="" local ub .
    scalar `K'  = `k'
    scalar `LB' = `lb'
    scalar `UB' = `ub'
    scalar `WD' = `wd'
    c_local `x'tight `tight'
end

program _parse_hex
    syntax [, VERTical HORizontal odd even left right ]
    local dir `vertical' `horizontal'
    if `: list sizeof dir'>1 {
        di as err "only one of vertical and horizontal allowed"
        exit 198
    }
    local order `right' `left'
    if `: list sizeof order'>1 {
        di as err "only one of left and right allowed"
        exit 198
    }
    local odd `even' `odd'
    if `: list sizeof odd'>1 {
        di as err "only one of odd and even allowed"
        exit 198
    }
    c_local hexdir   = ("`dir'"=="horizontal")
    c_local hexorder = ("`order'"=="left")
    c_local hexodd   = ("`odd'"=="odd")
end

program _parse_bylegend
    syntax [, legend(str asis) ramp ]
    if "`ramp'"!="" {
        if `"`legend'"'=="" local legend legend(off)
        c_local bylegend `legend'
        exit
    }
    local 0 `", `legend'"'
    syntax [, POSition(passthru) * ]
    if `"`position'"'=="" c_local bylegend legend(position(3) `options')
    else                  c_local bylegend legend(`options')
end

program _parse_popts
    local opts `0'
    while (`"`opts'"'!="") {
        gettoken opt  opts : opts, bind
        gettoken next      : opts, bind
        if substr(`"`next'"', 1, 1)=="(" {
            gettoken next opts : opts, bind
            local opt `opt'`next'
        }
        if substr(`"`opt'"', 1, 1)=="p" {
            if regexm(`"`opt'"', "^p([0-9]+)") {
                local num = regexs(1)
                local 0 `", `opt'"'
                capt syntax, P`num'(str)
                if _rc==0 {
                    c_local p`num' `"`p`num''"'
                    continue
                }
            }
        }
        local graphopts `graphopts' `opt'
    }
    c_local graphopts `graphopts'
end

program _check_gropts  
    // allow some additional options that do not seem to be covered by
    // _get_gropts, gettwoway; this possibly has to be updated for
    // future Stata versions
    syntax [, ///
        LEGend(passthru)     ///
        play(passthru)       ///
        PCYCle(passthru)     ///
        YVARLabel(passthru)  ///
        XVARLabel(passthru)  ///
        YVARFormat(passthru) ///
        XVARFormat(passthru) ///
        YOVERHANGs           ///
        XOVERHANGs           ///
        /// recast(passthru)     ///
        fxsize(passthru)     ///
        fysize(passthru)     ///
        ]
end

program _parse_values
    syntax [, Format(str) * ]
    if `"`format'"'!="" {
        confirm numeric format `format'
    }
    c_local valuesfmt `format'
    c_local values2 `options'
end

program _parse_backfill
    syntax [, Inner Last ]
    c_local backfill_inner `inner'
    c_local backfill_last `last'
end

program _parse_missing
    syntax [, Label(str asis) * ]
    if `"`label'"'=="" local label `""missing""'
    else {
        gettoken trash: label, qed(qed)
        if `qed'==0 {
            // if first token unquoted: pack complete string into quotes
            local label `"`"`label'"'"'
        }
        else {
            // if first token quoted: pack all tokens into quotes
            mata: st_local("label", quotetokens(st_local("label")))
        }
    }
    c_local missing_label `"`label'"'
    c_local missing2 `"`options'"'
end

program _check_cuts
    _parse comma CUTS 0 : 0
    if strpos(`"`0'"', "@min") exit // do parsing later, when min is known
    if strpos(`"`0'"', "@max") exit // do parsing later, when max is known
    if strpos(`"`0'"', "{") __parse_cuts `0'
    else syntax [, cuts(numlist ascending) ]
    local levels: list sizeof cuts
    matrix `CUTS' = J(1,`levels',.)
    forv i = 1/`levels' {
        gettoken cut cuts : cuts
        matrix `CUTS'[1,`i'] = `cut'
    }
    c_local cuts
    c_local levels = `levels' - 1
end

program _parse_cuts
    args CUTS MIN MAX cuts
    local min = `MIN'
    local max = `MAX'
    local cuts: subinstr local cuts "@min" "`min'", all
    local cuts: subinstr local cuts "@max" "`max'", all
    __parse_cuts, cuts(`cuts')
    local levels: list sizeof cuts
    matrix `CUTS' = J(1,`levels',.)
    forv i = 1/`levels' {
        gettoken cut cuts : cuts
        if `cut'==`min'      matrix `CUTS'[1,`i'] = `MIN' // preserve precision
        else if `cut'==`max' matrix `CUTS'[1,`i'] = `MAX' // preserve precision
        else matrix `CUTS'[1,`i'] = `cut'
    }
    c_local cuts
    c_local levels = `levels' - 1
end

program __parse_cuts
    syntax [, cuts(str asis) ]
    if strpos(`"`cuts'"', "{") {
        local rest `"`cuts'"'
        local cuts
        while (`"`rest'"'!="") {
            gettoken t rest : rest, parse("{")
            if `"`t'"'=="{" {
                gettoken t rest : rest, parse("}")
                if `"`rest'"'=="" { // closing brace not found
                    local cuts `"`0'"'
                    continue, break
                }
                local t = `t'
                local cuts `"`cuts'`t'"'
                gettoken t rest : rest, parse("}")
                continue
            }
            local cuts `"`cuts'`t'"'
        }
    }
    local 0 `", cuts(`cuts')"'
    syntax [, cuts(numlist ascending) ]
    c_local cuts `cuts'
end

program _parse_keylab
    _parse comma keylab 0 : 0
    syntax [, Format(str) TRANSform(str asis) INTERval RANge(numlist max=1) area * ]
    if "`interval'"!="" & "`range'"!="" {
        di as err "interval and range() are not both allowed"
        exit 198
    }
    if      `"`keylab'"'=="all"    c_local keylabels "all"
    else if `"`keylab'"'=="none"   c_local keylabels "none"
    else if `"`keylab'"'=="minmax" c_local keylabels "minmax"
    else if `"`keylab'"'!="" {
        capt n numlist `"`keylab'"', ascending integer range(>0)
        if _rc {
            di as err `"`keylab' not allowed in keylabels()"'
            exit _rc
        }
        c_local keylabels "`r(numlist)'"
    }
    else c_local keylabels
    if `"`format'"'!="" {
        confirm numeric format `format'
    }
    else local format %7.0g
    c_local keylab_format `"`format'"'
    c_local keylab_interval `interval'
    c_local keylab_range `range'
    c_local keylab_area `area'
    c_local keylab_opts `"`options'"'
    c_local retransform `"`transform'"'
end

program _parse_ramp
    syntax anything [, Left Right Top Bottom ///
        LABels(str asis) ///
        Format(passthru) ///
        Length(numlist max=1 >=0 <=100) ///
        Space(numlist max=1 >=0 <=100) ///
        TRANSform(str asis) ///
        Combine(str asis) /// 
        fysize(passthru) fxsize(passthru) * ]
    gettoken y anything : anything
    gettoken x          : anything 
    local pos `left' `right' `top' `bottom'
    if `:list sizeof pos'>1 {
        di as err "ramp(): only one of left, right, top, and bottom allowed"
        exit 198
    }
    if "`pos'"=="" local pos bottom
    if "`pos'"=="right" {
        local Y y
        local X x
        local alt "alt "
        local angle "angle(0) "
        local margin "l=0 t=0 b=0"
        local tiopt "span position(11) margin(l=0 r=0 t=0 b=2)"
        if "`length'"=="" local length 60
        if "`space'"=="" local space  20
    }
    else if "`pos'"=="left" {
        local Y y
        local X x
        local angle "angle(0) "
        local margin "r=0 t=0 b=0"
        local tiopt "span position(12) margin(l=0 r=0 t=0 b=2)"
        if "`length'"=="" local length 60
        if "`space'"=="" local space  20
    }
    else if "`pos'"=="top" {
        local Y x
        local X y
        local margin "l=0 r=0 b=0"
        local tiopt "position(9) margin(l=0 r=1 t=0 b=0)"
        if "`length'"=="" local length 80
        if "`space'"=="" local space 12
    }
    else {
        local Y x
        local X y
        local margin "l=0 r=0 t=0"
        local tiopt "position(9) margin(l=0 r=1 t=0 b=0)"
        if "`length'"=="" local length 80
        if "`space'"=="" local space 12
    }
    if "`f`Y'size'"=="" local f`Y'size `length'
    if "`f`X'size'"=="" local f`X'size `space'
    _parse comma lhs rhs : labels
    if `"`rhs'"'!="" {
        gettoken comma rhs : rhs, parse(",")
        local rhs `" `rhs'"'
    }
    if `"`format'"'=="" local format format(%7.0g)
    c_local ramp_YX ``Y'' ``X''
    c_local ramp_pos `pos'
    c_local ramp_ylabel `"`lhs'"'
    c_local ramp_opts `X'scale(off) `X'label(, nogrid)/*
        */ `Y'title("") `Y'scale(`alt'noextend)/*
        */ `Y'label(\`ramp_ylabel', `format' `angle'nogrid`rhs')/*
        */ subtitle(\`ztitle', size(medsmall) `tiopt')/*
        */ legend(off) f`Y'size(`f`Y'size') f`X'size(`f`X'size')/*
        */ plotregion(margin(zero) style(none)) graphr(margin(zero))/*
        */ nodraw `options'
    c_local ramp_mopts legend(off) nodraw graphregion(margin(`margin'))
    c_local ramp_combopts `"`combine'"'
    c_local retransform `"`transform'"'
end

program _parse_ramp_gropts
    syntax [, ///
        TItle(passthru) SUBtitle(passthru) note(passthru) CAPtion(passthru) ///
        YSIZe(passthru) XSIZe(passthru) nodraw scheme(passthru) ///
        name(passthru) saving(passthru) * ]
    c_local ramp_gropts `title' `subtitle' `note' `caption' `ysize' `xsize' `draw' `scheme' `name' `saving'
    c_local options `options'
end

program _parse_generate
    syntax [namelist] [, noPReserve ]
    c_local generate2 `namelist'
    c_local nopreserve `preserve'
end

program _makebin_categorical
    gettoken fast 0 : 0
    gettoken xy   0 : 0
    if "`fast'"=="" _makebin_categorical_std `0'
    else            _makebin_categorical_fast `0'
    c_local `xy'label `xy'label(`lbls')
end

program _makebin_categorical_std, sortpreserve
    args v x K LB MIN UB MAX label
    sort `x'
    qui by `x': gen double `v' = (`x'!=`x'[_n-1])
    mata: collectlbls("`x'", "`v'") // returns local lbls and sets scalar K
    qui replace `v' = `v' + `v'[_n-1] in 2/l
    scalar `LB' = 1
    scalar `MIN' = 1
    scalar `UB' = `K'
    scalar `MAX' = `K'
    c_local lbls `"`lbls'"'
end

program _makebin_categorical_fast  // requires gtoolss
    args v x K LB MIN UB MAX label
    tempvar tag
    gegen long `v' = group(`x')
    gegen byte `tag' = tag(`v')
    mata: collectlbls("`x'", "`tag'", "`v'") // returns local lbls and sets scalar K
    scalar `LB' = 1
    scalar `MIN' = 1
    scalar `UB' = `K'
    scalar `MAX' = `K'
    c_local lbls `"`lbls'"'
end

program _makebin_discrete
    args v x K LB MIN UB MAX WD
    rename `x' `v'
    qui su `v', meanonly
    scalar `MIN' = r(min)
    scalar `MAX' = r(max)
    scalar `K' = round((`MAX'-`MIN')/`WD') + 1
    scalar `LB' = `MIN'
    scalar `UB' = `MAX'
end

program _makebin_continuous
    args xy v x K LB MIN UB MAX WD tight clip wgt
    // setup
    su `x' `wgt', meanonly
    local N   = r(N)
    scalar `MIN' = r(min)
    scalar `MAX' = r(max)
    if `LB'>=. scalar `LB' = `MIN'
    if `UB'>=. scalar `UB' = `MAX'
    // determine step width
    local UBtight = 0
    if `WD'>=. {
        if  `K'>=. {
            scalar `K' = max(1, trunc(min(sqrt(`N'), 10*ln(`N')/ln(10))))
            if (`UB'-`LB')<(`MAX'-`MIN') {
                // reduce k if range has been restricted
                scalar `K' = ceil(`K' * (`UB'-`LB') / (`MAX'-`MIN'))
            }
        }
        if `K'<2 {
            if `UB'>`LB' & "`tight'"=="" {
                scalar `K' = 2 // set minimum
                di as txt "(number of `xy'bins reset to 2)"
            }
        }
        if `UB'<=`LB'               scalar `WD' = 1
        else if "`tight'"=="tight"  scalar `WD' = (`UB' - `LB') /  `K'
        else if "`tight'"=="ltight" scalar `WD' = (`UB' - `LB') / (`K'-.5)
        else if "`tight'"=="rtight" scalar `WD' = (`UB' - `LB') / (`K'-.5)
        else                        scalar `WD' = (`UB' - `LB') / (`K'-1)
        if inlist("`tight'", "tight", "rtight") & `UB'>`LB' local UBtight = 1
    }
    else {
        local lb st_numscalar("`LB'")
        local ub st_numscalar("`UB'")
        local wd st_numscalar("`WD'")
        if "`tight'"=="tight"       mata: countbins(`lb'+`wd'/2, `ub', `wd', `wd'/2, 1)
        else if "`tight'"=="ltight" mata: countbins(`lb'+`wd'/2, `ub', `wd', `wd'/2, 0)
        else if "`tight'"=="rtight" mata: countbins(`lb', `ub', `wd', `wd'/2, 1)
        else                        mata: countbins(`lb', `ub', `wd', `wd'/2, 0)
        if inlist("`tight'", "tight", "rtight") {
            if "`tight'"=="tight" local UBtight = (abs((`LB' + `K'*`WD') - `UB') / (`WD'+1)) < 1e-12
            else                  local UBtight = (abs((`LB' + (`K'-.5)*`WD') - `UB') / (`WD'+1)) < 1e-12
        }
    }
    // compute bin midpoints
    qui gen double `v' = floor((`x' - `LB') / `WD' * 2)
    if inlist("`tight'", "tight", "ltight") {
        if "`tight'"=="tight" & `UBtight' ///
            qui replace `v' = floor((`v' - (mod(`v', 2)==0 & `x'==`UB'))/2) * 2 + 1
        else qui replace `v' = floor(`v'/2) * 2 + 1
    }
    else {
        if "`tight'"=="rtight" & `UBtight' ///
             qui replace `v' = floor((`v'+1 - (mod(`v'+1, 2)==0 & `x'==`UB'))/2) * 2
        else qui replace `v' = floor((`v'+1)/2) * 2
    }
    qui replace `v' = `LB' + `v'/2 * `WD'
    // remove bins that are out of range
    if `LB'>`MIN' qui replace `v' = . if `v' < `LB'
    if `UB'<`MAX' {
        if inlist("`tight'", "tight", "rtight") ///
            qui replace `v' = . if `v' >= (`UB' + `WD'/2)
        else ///
            qui replace `v' = . if `v' > (`UB' + `WD'/2)
    }
    // clip: omit data that is out of range
    if "`clip'"!="" {
        if "`clip'"!="rclip" & `LB'>`MIN' qui replace `v' = . if `x' < `LB'
        if "`clip'"!="lclip" & `UB'<`MAX' qui replace `v' = . if `x' > `UB'
    }
    // note on omitted data
    if `LB'>`MIN' | `UB'<`MAX' {
        qui count if `v'>=.
        if r(N) {
            di as txt "(`r(N)' observations outside range of `xy'bins)"
        }
    }
end

program _hexbin_prepare
    args xy v x K LB MIN UB MAX WD tight odd wgt
    // setup
    su `x' `wgt', meanonly
    local N   = r(N)
    scalar `MIN' = r(min)
    scalar `MAX' = r(max)
    if `LB'>=. scalar `LB' = `MIN'
    if `UB'>=. scalar `UB' = `MAX'
    // determine step width
    if `WD'>=. {
        if  `K'>=. {
            scalar `K' = max(1, trunc(min(sqrt(`N'), 10*ln(`N')/ln(10))))
            if (`UB'-`LB')<(`MAX'-`MIN') {
                // reduce k if range has been restricted
                if "`xy'"=="y" scalar `K' = ceil(`K' * (`UB'-`LB') / (`MAX'-`MIN'))
                else scalar `K' = ceil(2 * `K' * (`UB'-`LB') / (`MAX'-`MIN')) / 2
            }
        }
        if `K'<2 {
            if `UB'>`LB' & "`tight'"=="" {
                scalar `K' = 2 // set minimum
                di as txt "(number of `xy'bins reset to 2)"
            }
        }
        if `UB'<=`LB'                   scalar `WD' = 1
        else if "`xy'"=="y" {
            if "`tight'"=="tight"       scalar `WD' = (`UB' - `LB') / (`K'-1/3)
            else if "`tight'"=="ltight" scalar `WD' = (`UB' - `LB') / (`K'-2/3)
            else if "`tight'"=="rtight" scalar `WD' = (`UB' - `LB') / (`K'-2/3)
            else                        scalar `WD' = (`UB' - `LB') / (`K'-1)
        }
        else {
            if "`tight'"=="tight"       scalar `WD' = (`UB' - `LB') / (`K'-.5 -`odd'*.5)
            else if "`tight'"=="ltight" scalar `WD' = (`UB' - `LB') / (`K'-3/4-`odd'*.5)
            else if "`tight'"=="rtight" scalar `WD' = (`UB' - `LB') / (`K'-3/4-`odd'*.5)
            else                        scalar `WD' = (`UB' - `LB') / (`K'-1  -`odd'*.5)
        }
    }
    else {
        local lb st_numscalar("`LB'")
        local ub st_numscalar("`UB'")
        local wd st_numscalar("`WD'")
        if "`xy'"=="y" {
            if "`tight'"=="tight"       mata: countbins(`lb'       , `ub', `wd', `wd'/2, 1)
            else if "`tight'"=="ltight" mata: countbins(`lb'       , `ub', `wd', `wd'/2, 0)
            else if "`tight'"=="rtight" mata: countbins(`lb'-`wd'/4, `ub', `wd', `wd'/2, 1)
            else                        mata: countbins(`lb'-`wd'/4, `ub', `wd', `wd'/2, 0)
        }
        else {
            if "`tight'"=="tight"       mata: countbins(`lb'+`wd'/3, `ub', `wd', `wd'*2/3, 1, `odd')
            else if "`tight'"=="ltight" mata: countbins(`lb'+`wd'/3, `ub', `wd', `wd'*2/3, 0, `odd')
            else if "`tight'"=="rtight" mata: countbins(`lb'       , `ub', `wd', `wd'*2/3, 1, `odd')
            else                        mata: countbins(`lb'       , `ub', `wd', `wd'*2/3, 0, `odd')
        }
    }
    rename `x' `v'
end

program _hexbin
    args x x_LB x_UB x_WD x_MIN x_MAX xtight xclip ///
         y y_LB y_UB y_WD y_MIN y_MAX ytight yclip order
    // y
    tempvar y1 y2
    qui gen double `y1' = floor((`y' - `y_LB') / `y_WD' * 3)
    if inlist("`ytight'", "tight", "ltight") {
        qui gen double `y2' = floor((`y1'-2)/6) * 6 + 4
        qui replace    `y1' = floor((`y1'+1)/6) * 6 + 1
    }
    else {
        qui gen double `y2' = floor((`y1'-1)/6) * 6 + 3
        qui replace    `y1' = floor((`y1'+2)/6) * 6
    }
    if inlist("`ytight'", "tight", "ltight") {
        // make sure that obs on lower edge are not put in bin below
        qui replace `y2' = `y2' + 6 if `y2'<0 & `y'==`y_LB'
    }
    if inlist("`ytight'", "tight", "rtight") {
        // make sure that obs on upper edge are not put in bin above
        qui replace `y1' = `y1' - 6 if `y'==`y_UB' & ///
            (abs((`y_LB' + ((`y1'-2)/3) * `y_WD') - `y_UB') / (`y_WD'+1)) < 1e-12
        qui replace `y2' = `y2' - 6 if `y'==`y_UB' & ///
            (abs((`y_LB' + ((`y2'-2)/3) * `y_WD') - `y_UB') / (`y_WD'+1)) < 1e-12
    }
    qui replace `y1' = `y_LB' + `y1'/3 * `y_WD'
    qui replace `y2' = `y_LB' + `y2'/3 * `y_WD'
    // x
    tempvar x1 x2
    qui gen double `x1' = floor((`x' - `x_LB') / `x_WD' * 4)
    if inlist("`xtight'", "tight", "ltight") {
        qui gen double `x2' = floor((`x1'+2)/4) * 4
        qui replace    `x1' = floor(`x1'/4) * 4 + 2
    }
    else {
        qui gen double `x2' = floor((`x1'+3)/4) * 4 - 1
        qui replace    `x1' = floor((`x1'+1)/4) * 4 + 1
    }
    if inlist("`xtight'", "tight", "rtight") {
        // make sure that obs on right edge are not put in bin on the right
        qui replace `x1' = `x1' - 4 if `x'==`x_UB' & ///
            (abs((`x_LB' + ((`x1'-2)/4) * `x_WD') - `x_UB') / (`x_WD'+1)) < 1e-12
        qui replace `x2' = `x2' - 4 if `x'==`x_UB' & ///
            (abs((`x_LB' + ((`x2'-2)/4) * `x_WD') - `x_UB') / (`x_WD'+1)) < 1e-12
    }
    if `order' {
        local tmp `x1'
        local x1 `x2'
        local x2 `tmp'
    }
    qui replace `x1' = `x_LB' + `x1'/4 * `x_WD'
    qui replace `x2' = `x_LB' + `x2'/4 * `x_WD'
    // pick position
    tempvar d
    qui gen byte `d' = (((`x'-`x1')/`x_WD')^2 + 3/4*((`y'-`y1')/`y_WD')^2) ///
                     < (((`x'-`x2')/`x_WD')^2 + 3/4*((`y'-`y2')/`y_WD')^2)
    qui replace `x1' = `x2' if `d'==0
    qui replace `y1' = `y2' if `d'==0
    // remove bins that are out of range
    if `y_LB'>`y_MIN' {
        if inlist("`ytight'", "tight", "rtight") ///
            qui replace `y1' = . if `y1' < `y_LB'
        else ///
            qui replace `y1' = . if (`y1'+ 2*`y_WD'/3) <= `y_LB'
    }
    if `y_UB'<`y_MAX' {
        if inlist("`ytight'", "tight", "rtight") ///
            qui replace `y1' = . if `y1' >= (`y_UB' + 2*`y_WD'/3)
        else ///
            qui replace `y1' = . if `y1' > (`y_UB' + 2*`y_WD'/3)
    }
    if `x_LB'>`x_MIN' {
        if inlist("`xtight'", "tight", "ltight") /// 
            qui replace `x1' = . if `x1' < `x_LB'
        else ///
            qui replace `x1' = . if (`x1'+ `x_WD'/2) <= `x_LB'
    }
    if `x_UB'<`x_MAX' {
        if inlist("`xtight'", "tight", "rtight") ///
            qui replace `x1' = . if `x1' >= (`x_UB' + `x_WD'/2)
        else ///
            qui replace `x1' = . if `x1' >  (`x_UB' + `x_WD'/2)
    }
    // clip: omit data that is out or range
    if "`yclip'"!="" {
        if "`yclip'"!="rclip" & `y_LB'>`y_MIN' qui replace `y1' = . if `y' < `y_LB'
        if "`yclip'"!="lclip" & `y_UB'<`y_MAX' qui replace `y1' = . if `y' > `y_UB'
    }
    if "`xclip'"!="" {
        if "`xclip'"!="rclip" & `x_LB'>`x_MIN' qui replace `x1' = . if `x' < `x_LB'
        if "`xclip'"!="lclip" & `x_UB'<`x_MAX' qui replace `x1' = . if `x' > `x_UB'
    }
    drop `x' `y'
    rename `x1' `x'
    rename `y1' `y'
    // note on omitted data
    if `x_LB'>`x_MIN' | `x_UB'<`x_MAX' {
        qui count if `x'>=.
        if r(N) {
            di as txt "(`r(N)' observations outside range of xbins)"
        }
    }
    if `y_LB'>`y_MIN' | `y_UB'<`y_MAX' {
        qui count if `y'>=.
        if r(N) {
            di as txt "(`r(N)' observations outside range of ybins)"
        }
    }
end

program _fillin
    args fillin x x_K x_LB x_WD xtight xcat y y_K y_LB y_WD ytight ycat ///
        z z2 by hexagon hexorder hexodd 
    if "`fillin'"=="" exit
    tempname byindex
    if "`by'"!="" {
        sort `by'
        by `by': qui gen double `byindex' = (_n==1)
        qui replace `byindex' = `byindex'[_n-1] + `byindex' in 2/l
    }
    else qui gen byte `byindex' = 1
    if "`hexagon'"!="" {
        tempname xold
        rename `x' `xold'
        if inlist("`xtight'", "tight", "ltight") local xoff .25
        else                                      local xoff 0
        qui gen double `x' = `x_LB' + ///
            (round((`xold' - `x_LB') / `x_WD' - `xoff') + `xoff') * `x_WD'
    }
    tempfile plotdata
    qui save `"`plotdata'"', replace
    keep `byindex' `x' `y'
    mata: fillingaps()
    tempvar merge
    qui merge 1:1 `byindex' `x' `y' using `"`plotdata'"', ///
        keep(match master using) generate(`merge')
    // capt assert (`merge'==1 | `merge'==3)
    // if _rc {
    //     di as err "unexpected error; fillin algorithm returned inconsistent results"
    //     exit 499
    // }
    if "`hexagon'"!="" {
        if inlist("`ytight'", "tight", "ltight") {
            if `hexorder'==0    local yoff 1/3
            else                local yoff 4/3
        }
        else if `hexorder'==0   local yoff 0
        else                    local yoff 1
        qui replace `x' = `x' + (`x_WD'/4) * ///
            cond(mod(round((`y' - `y_LB') / `y_WD' - `yoff'), 2), -1, 1) ///
            if `xold'>=.
        if `hexodd' { // remove last half-column
            qui replace `x' = . if `xold'>=. ///
                & ((`x' - `x_LB') / `x_WD' - `xoff') > (`x_K'-1)
            qui keep if `x'<.
        }
        qui replace `xold' = `x' if `xold'>=.
        drop `x'
        rename `xold' `x'
    }
    qui replace `z' = `:word 1 of `fillin'' if `merge'==1
    if "`z2'"!="" {
        if `"`:word 2 of `fillin''"'!="" {
            qui replace `z2' = `:word 2 of `fillin'' if `merge'==1
        }
        else {
            qui replace `z2' = 1 if `merge'==1
        }
    }
    if "`by'"!="" {
        // fillin by variables
        sort `byindex' `by'
        foreach v of local by {
            by `byindex': qui replace `v' = `v'[1]
        }
    }
end

program _colorpalette
    gettoken N 0 : 0
    _parse comma p 0 : 0
    syntax [, n(passthru) IPolate(passthru) * ]
    if c(stata_version)<14.2 {
        if `N'>0 {
            if `"`n'"'==""       local n n(`N')
            if `"`ipolate'"'=="" local ipolate ipolate(`N')
        }
        colorpalette9 `p', nograph `n' `ipolate' `options'
        exit
    }
    if `N'>0 {
        if `"`n'`ipolate'"'=="" local n n(`N')
    }
    colorpalette `p', nograph `n' `ipolate' `options'
end

program _symbolpalette
    _parse comma p 0 : 0
    syntax [, * ]
    symbolpalette `p', nograph `options'
end

version 9.2
mata:
mata set matastrict on

void writematamatrixtodata(transmorphic M)
{
    if (isreal(M)) _writematamatrixtodata(M)
    else {
        display("{err}matrix must be real")
        exit(3253)
    }
}

void writematrixtodata()
{
    real matrix M
    
    // write matrix
    M = st_matrix(st_local("matrix"))
    _writematamatrixtodata(M)
    
    // generate labels
    if (st_local("equations")=="") {
        // standard labels
        writematrixlbls(st_matrixrowstripe(st_local("matrix")), "y")
        writematrixlbls(st_matrixcolstripe(st_local("matrix")), "x")
    }
    else {
        // label equations and compile outline coordinates
        writematrixeqs(st_matrixrowstripe(st_local("matrix")), 
                       st_matrixcolstripe(st_local("matrix")))
    }
}

void _writematamatrixtodata(real matrix M)
{
    real scalar i, j, k, r, c, z, y, x, hasdrop, N, upper, lower, nodiag, 
                xmin, xmax, ymin, ymax, d
    real rowvector drop
    
    z = st_varindex(st_local("z0"))
    y = st_varindex(st_local("y0"))
    x = st_varindex(st_local("x0"))
    drop = strtoreal(tokens(st_local("drop")))
    upper = st_local("upper")!=""
    lower = st_local("lower")!=""
    nodiag = st_local("diagonal")!=""
    hasdrop = (length(drop)>0)
    r = rows(M); c = cols(M); d = min((r,c)); k = r*c
    if (nodiag)      k = k - d
    if      (lower)  k = k - (d*d-d)/2 - (c>r ? (c-r)*r : 0)
    else if (upper)  k = k - (d*d-d)/2 - (r>c ? (r-c)*c : 0)
    N = st_nobs()
    if (N < k) st_addobs(k - N)
    if (!(hasdrop+lower+upper+nodiag)) {
        // write full matrix (faster than the general code below)
        k = 0
        for (j=1; j<=c; j++) {
            i = k + 1; k = j * r
            st_store((i,k), z, M[,j])
            st_store((i,k), y, 1::r)
            st_store((i,k), x, J(r,1,j))
        }
    }
    else {
        // write partial matrix (general element-by-element code; speed could
        // be improved by writing custom code for different situations)
        k = 0
        for (i=1; i<=r; i++) {
            for (j=(upper ? i : 1); j<=(lower ? min((i,c)) : c); j++) {
                if (nodiag) {
                    if (i==j) continue
                }
                if (hasdrop) {
                    if (anyof(drop, M[i,j])) continue
                }
                k++
                _st_store(k, z, M[i,j])
                _st_store(k, y, i)
                _st_store(k, x, j)
            }
        }
        if (k < st_nobs() & k>N) {  // possible if hasdrop
            stata("qui keep in 1/" + strofreal(k))
        }
    }
    if (st_local("syntax")=="3" | st_local("ydiscrete")!="") {
        ymin = 1 + (lower & nodiag); ymax = (upper ? min((r,c-nodiag)) : r)
        st_numscalar(st_local("y_K"),   ymax-ymin+1)
        st_numscalar(st_local("y_LB"),  ymin)
        st_numscalar(st_local("y_UB"),  ymax)
        st_numscalar(st_local("y_MIN"), ymin)
        st_numscalar(st_local("y_MAX"), ymax)
        st_numscalar(st_local("y_WD"),  1)
    }
    if (st_local("syntax")=="3" | st_local("xdiscrete")!="") {
        xmin = 1 + (upper & nodiag); xmax = (lower ? min((c,r-nodiag)) : c)
        st_numscalar(st_local("x_K"),   xmax-xmin+1)
        st_numscalar(st_local("x_LB"),  xmin)
        st_numscalar(st_local("x_UB"),  xmax)
        st_numscalar(st_local("x_MIN"), xmin)
        st_numscalar(st_local("x_MAX"), xmax)
        st_numscalar(st_local("x_WD"),  1)
    }
}

void writematrixlbls(string matrix stripe, string scalar x)
{
    real scalar   r, i, eq, label
    string scalar lbl, lbls
    pragma unset  lbls
    
    label = st_local("label")!=""
    eq = any(stripe[,1]:!=stripe[1,1])
    i = st_numscalar(st_local(x+"_MIN"))
    r = st_numscalar(st_local(x+"_MAX"))
    for (; i<=r; i++) {
        lbl = stripe[i,2]
        if (label) {
            if (_st_varindex(lbl)<.) {
                lbl = st_varlabel(lbl)
                if (lbl=="") lbl = stripe[i,2]
            }
        }
        if (eq) lbl =  "`" + `"""' + stripe[i,1] + `":""' + "' " + 
                       "`" + `"""' + lbl + `"""' + "'"
        lbls = lbls + (i>1 ? " " : "") + strofreal(i) + " " +
               "`" + `"""' + lbl + `"""' + "'"
    }
    st_local(x+"label", x+"label(" + lbls + ")")
}

void writematrixeqs(string matrix R, string matrix C)
{
    string colvector req, ceq
    real matrix      rlu, clu
    pragma unset req
    pragma unset ceq
    pragma unset rlu
    pragma unset clu

    geteqinfo(req, rlu, R)
    writeeqlbls(req, rlu, "y")
    geteqinfo(ceq, clu, C)
    writeeqlbls(ceq, clu, "x")
    writeeqcoords(req, rlu, ceq, clu)
}

void geteqinfo(string colvector eq, real matrix lu, string matrix S)
{
    real scalar   i, j, r
    string scalar s
    
    r = rows(S)
    eq = J(r, 1, "")
    lu = J(r, 2, .)
    j = 0
    for (i=1; i<=r; i++) {
        j++
        s = S[i,1]; eq[j] = s; lu[j,1] = i
        for (; i<=r; i++) {
            if (i<r) {
                if (S[i+1,1]==s) continue
            }
            lu[j,2] = i
            break
        }
    }
    eq = eq[|1 \ j|]
    lu = lu[|1,1 \ j,2|]
}

void writeeqlbls(string colvector eq, real matrix lu, string scalar x)
{
    real scalar   i, r, label
    string scalar lbl, lbls, ticks
    pragma unset  lbls
    
    label = st_local("label")!=""
    r = rows(eq)
    ticks = ".5"
    for (i=1; i<=r; i++) {
        lbl = eq[i]
        if (label) {
            if (_st_varindex(lbl)<.) {
                lbl = st_varlabel(lbl)
                if (lbl=="") lbl = eq[i]
            }
        }
        lbls = lbls + (i>1 ? " " : "") + strofreal((lu[i,2]+lu[i,1])/2) + 
               " " + "`" + `"""' + lbl + `"""' + "'"
        ticks = ticks + " " + strofreal(lu[i,2]+.5)
    }
    st_local(x+"label", x+"label(" + lbls + ", notick) " + 
                        x+"tick(" + ticks + ")")
}

void writeeqcoords(string colvector req, real matrix rlu, 
    string colvector ceq, real matrix clu)
{
    real scalar   i, n
    string scalar coord, rlo, rup, clo, cup
    pragma unset  coord
    
    n = min((rows(req), rows(ceq)))
    for (i=1; i<=n; i++) {
        rlo = strofreal(rlu[i,1]-.5); rup = strofreal(rlu[i,2]+.5)
        clo = strofreal(clu[i,1]-.5); cup = strofreal(clu[i,2]+.5)
        coord = coord + (i>1 ? " " : "") + rlo + " " + clo + 
                                     " " + rlo + " " + cup +
                                     " " + rup + " " + cup +
                                     " " + rup + " " + clo +
                                     " " + "." + " " + "."
    }
    st_local("eqcoords", coord)
}

void countbins(
    real scalar x0,     // midpoint of first bin
    real scalar ub,     // upper bound 
    real scalar wd,     // step width
    real scalar h,      // halfwidth of bin
    real scalar r,      // right inclusive
  | real scalar odd)    // hex: odd
{
    real scalar k, x
    
    k = 1
    x = x0
    while (1) {
        if (odd==1) x = x0 + k/2*wd
        else        x = x0 + k*wd
        if (r) {
            if (x>=(ub+h)) break
        }
        else {
            if (x>(ub+h)) break
        }
        k++
    }
    if (odd==1) k = ceil((k+1)/2)
    st_numscalar(st_local("K"), k)
}

void collectlbls(string scalar X, string scalar tag, | string scalar ID)
{
    real scalar             i, str, k
    string scalar           lbls, lab, vlab
    transmorphic colvector  x
    real colvector          id
    pragma unset            lbls
    
    str = st_isstrvar(X)
    if (str) {
        x = st_sdata(., X, tag)
    }
    else {
        x = st_data(., X, tag)
        vlab = st_varvaluelabel(X)
    }
    k = rows(x)
    if (ID=="") id = 1::k
    else        id = st_data(., ID, tag)
    for (i=1; i<=k; i++) {
        if (str) lab = x[i]
        else if (vlab!="") {
            lab = st_vlmap(vlab, x[i])
            if (lab=="") lab = strofreal(x[i])
        }
        else lab = strofreal(x[i])
        lbls = lbls + (i>1 ? " " : "") + strofreal(id[i]) + " " +
                    "`" + `"""' + lab + `"""' + "'"
    }
    st_local("lbls", lbls)
    st_numscalar(st_local("K"), k)
}

void fillingaps()
{
    real scalar    r, rby, ryx, ry, rx, i, j, a, b, aa, bb
    real colvector by, y, x, bynew, ynew, xnew
    
    // input
    by = uniqrows(st_data(., st_local("byindex")))
    y  = _fillingaps("y")
    x  = _fillingaps("x")
    
    // expand
    rby = rows(by); ry = rows(y); rx = rows(x)
    ryx = ry * rx
    r   = rby * ryx
    bynew = ynew = xnew = J(r, 1, .)
    for (i=1; i<=rby; i++) {
        a = 1 + (i-1) * ryx
        b = a + ryx - 1
        bynew[|a \ b|] = J(ryx, 1, by[i])
        for (j=1; j<=ry; j++) {
            aa = a + (j-1) * rx
            bb = aa + rx - 1
            ynew[|aa \ bb|] = J(rx, 1, y[j])
            xnew[|aa \ bb|] = x
        }
    }
    
    // put back
    if (st_nobs()<(r)) st_addobs(r-st_nobs())
    st_store(., st_local("byindex"), bynew)
    st_store(., st_local("y"), ynew)
    st_store(., st_local("x"), xnew)
}

real colvector _fillingaps(string scalar s)
{
    real scalar    min, wd, r, rnew, i, j, xi, ll
    real colvector x, xnew
    
    x = uniqrows(st_data(., st_local(s)))
    if (st_local(s+"cat")!="") return(x) // use existing values only
    r    = rows(x)
    rnew = st_numscalar(st_local(s+"_K"))
    min  = st_numscalar(st_local(s+"_LB"))
    wd   = st_numscalar(st_local(s+"_WD"))
    if (anyof(("tight", "ltight"), st_local(s+"tight"))) {
        if (st_local("hexagon")!="") {
            if (s=="y") min = min + wd/3
            else        min = min + wd/4
        }
        else min = min + wd/2
    }
    xnew = J(rnew, 1, .)
    j = 1
    for (i=1; i<=rnew; i++) {
        xi = min + (i-1)*wd
        ll = xi - wd/4
        while (x[j]<ll) {
            if (j==r) break
            j++
        }
        if (x[j]>=ll & x[j]<=(xi+wd/4)) xnew[i] = x[j]
        else                            xnew[i] = xi
    }
    return(xnew)
}

void setarea(string scalar v)
{
    real scalar    lb, ub, wd0, wd, i
    real colvector x, A
    string scalar  clip
    pragma unset   x
    pragma unset   A
    
    clip = st_local(v+"clip")
    if (clip!="") {
        if (clip!="rclip") lb = st_numscalar(st_local(v+"_LB"))
        if (clip!="lclip") ub = st_numscalar(st_local(v+"_UB"))
    }
    wd0 = st_numscalar(st_local(v+"_WD"))
    st_view(A, ., st_local("AREA"), st_local("CTAG"))
    st_view(x, ., st_local(v), st_local("CTAG"))
    for (i=rows(x); i; i--) {
        wd = wd0
        if (lb<.) {
            if (x[i]<(lb+wd/2)) wd = wd - (lb - x[i] + wd/2)
        }
        if (ub<.) {
            if ((x[i]+wd/2)>ub) wd = wd - (x[i] - ub + wd/2)
        }
        A[i] = A[i] * wd
    }
}

void clipborders(string scalar v)
{
    real scalar    lb, ub, i
    real colvector x, X
    string scalar  clip
    pragma unset   x
    pragma unset   X 
    
    clip = st_local(v+"clip")
    if (clip!="") {
        if (clip!="rclip") lb = st_numscalar(st_local(v+"_LB"))
        if (clip!="lclip") ub = st_numscalar(st_local(v+"_UB"))
    }
    st_view(x, ., st_local(v), st_local("CTAG"))
    st_view(X, ., st_local(strupper(v)), st_local("CTAG"))
    for (i=rows(x); i; i--) {
        if (lb<.) {
            if (X[i]<0) { // shift lower edge
                if ((x[i]+X[i])<lb) X[i] = lb - x[i]
            }
        }
        if (ub<.) {
            if (X[i]>0) { // shift upper edge
                if ((x[i]+X[i])>ub) X[i] = ub - x[i]
            }
        }
    }
}

void cliphexborders()
{
    real scalar    ylb, yub, ywd, xlb, xub, xwd, i, slope, tmp
    real colvector y, Y, x, X
    string scalar  yclip, xclip
    pragma unset   y
    pragma unset   Y
    pragma unset   x
    pragma unset   X 
    
    yclip = st_local("yclip")
    ywd = st_numscalar(st_local("y_WD")) / 3
    if (yclip!="") {
        if (yclip!="rclip") ylb = st_numscalar(st_local("y_LB"))
        if (yclip!="lclip") yub = st_numscalar(st_local("y_UB"))
    }
    st_view(y, ., st_local("y"), st_local("CTAG"))
    st_view(Y, ., st_local("Y"), st_local("CTAG"))
    xclip = st_local("xclip")
    xwd = st_numscalar(st_local("x_WD")) / 2
    if (xclip!="") {
        if (xclip!="rclip") xlb = st_numscalar(st_local("x_LB"))
        if (xclip!="lclip") xub = st_numscalar(st_local("x_UB"))
    }
    slope = ywd / xwd
    st_view(x, ., st_local("x"), st_local("CTAG"))
    st_view(X, ., st_local("X"), st_local("CTAG"))
    for (i=rows(y); i; i--) {
        if (xlb<.) {
            if ((x[i]+X[i])<xlb) {
                if (xlb<x[i]) tmp = xlb - x[i] + xwd 
                else          tmp = x[i] - xlb + xwd
                tmp = ywd + slope * tmp
                if (Y[i]>0) Y[i] = tmp
                else        Y[i] = -tmp
                X[i] = xlb - x[i]
            }
        }
        if (xub<.) {
            if ((x[i]+X[i])>xub) {
                if (xub>x[i]) tmp = x[i] - xub + xwd
                else          tmp = xub - x[i] + xwd
                tmp = ywd + slope * tmp
                if (Y[i]>0) Y[i] = tmp
                else        Y[i] = -tmp
                X[i] = xub - x[i]
            }
        }
        if (ylb<.) {
            if ((y[i]+Y[i])<ylb) Y[i] = ylb - y[i]
        }
        if (yub<.) {
            if ((y[i]+Y[i])>yub) Y[i] = yub - y[i]
        }
    }
}

string scalar quotetokens(string scalar s0)
{
    real scalar      i
    string scalar    s, space
    string colvector S
    pragma unset     s
    pragma unset     space
    
    S = tokens(s0)
    for (i=length(S); i; i--) {
        s =  "`" + `"""' + S[i] + `"""' + "'" + space + s
        space = " "
    }
    return(s)
}

void swapxy()
{
    real scalar      i
    string scalar    tmp
    string colvector l
    
    l = ("0", "", "_K", "_LB", "_UB", "_MIN", "_MAX", "_WD", "tight", "clip",
        "cat", "discrete", "label", "title")
    for (i=cols(l); i; i--) {
        tmp = st_local("x"+l[i])
        st_local("x"+l[i], st_local("y"+l[i]))
        st_local("y"+l[i], tmp)
    }
    tmp = st_local("X")
    st_local("X", st_local("Y"))
    st_local("Y", tmp)
}

void generatescalecoords(real rowvector cuts, string rowvector vnames)
{
    real scalar i, j, n, lo, up
    real matrix coord // ID Y X

    n = cols(cuts)
    coord = J(5*(n-1), 3, .)
    j = 0
    up = cuts[1]

    for (i=1;i<n;i++) {
        lo = up
        up = cuts[i+1]
        coord[++j,] = (i, lo, 0)
        coord[++j,] = (i, lo, 1)
        coord[++j,] = (i, up, 1)
        coord[++j,] = (i, up, 0)
        coord[++j,] = (i,  ., .)
    }
    n = rows(coord)
    if (n>st_nobs()) {
        st_local("ramp_N_preserve", strofreal(n-st_nobs()))
        st_addobs(n-st_nobs())
    }
    st_store((1,n), vnames, coord)
}

end

exit
