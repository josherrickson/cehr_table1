program define cehr_table1
  preserve

  ******************
  ***** Syntax *****
  ******************

  syntax anything [if] [in] [using/],  ///
    BY(varlist max=2)                  ///
    [  REPlace                         ///
      SECONDarystatposition(string)    ///
      PRint                            ///
      DIgits(integer 2)                ///
      PERDIgits(integer 1)             ///
      PDIgits(integer 3)               ///
      COUNTLabel(string)               ///
      SECTIONDECoration(string)        ///
      VARIABLEDECoration(string)       ///
      noCATegoricalindent              ///
      nostddiff                        ///
      PVals                            ///
      ADJUSTPVals                      ///
    ]


  ************************
  ***** Input checks *****
  ************************

  **** Are we diff-in-diff?
  tokenize `by'
  local upperby `1'
  local lowerby `2'

  * If we are NOT diff-in-diff, pretend we are by generating an upper-level group
  * variable that is constant.
  local onelevel = "False"
  if "`lowerby'" == "" {
    local lowerby `upperby'
    local onelevel = "True"
    tempvar upperbyvar
    gen `upperbyvar' = 1
    local upperby `upperbyvar'
  }

  **** Sure treatment variable(s) with at least 2 levels
  tempname lowergroups
  tempname uppergroups

  qui tab `upperby' `if' `in', matrow(`uppergroups')
  local numuppergroups = rowsof(`uppergroups')
  qui tab `lowerby' `if' `in', matrow(`lowergroups')
  local numlowergroups = rowsof(`lowergroups')
  if (`numuppergroups' < 2 & "`onelevel'" == "False") | `numlowergroups' < 2 {
    if "`if'" != "" | "`in'" != "" {
      local suberror = " in the subgroup"
    }
    display as error "Variables in {bf:by()} must contain at least two levels`suberror'."
    exit
  }

  * If either grouping variable has no value label, display a warning
  local uppervallab : value label `upperby'
  if "`uppervallab'" == "" & "`onelevel'" == "False" {
    display as error "Grouping variable {bf:`upperby'} has no value label, using numeric labels."
  }
  local lowervallab : value label `lowerby'
  if "`lowervallab'" == "" {
    display as error "Grouping variable {bf:`lowerby'} has no value label, using numeric labels."
  }

  * Ensure digits is a realistic choice.
  if `digits' < 0 {
    display as error "Option {bf:{ul:di}gits()} must be a non-negative integer."
    exit
  }

  * Ensure perdigits is a realistic choice.
  if `perdigits' < 0 {
    display as error "Option {bf:{ul:perdi}gits()} must be a non-negative integer."
    exit
  }

  * Ensure pdigits is a realistic choice.
  if `pdigits' < 0 {
    display as error "Option {bf:{ul:pdi}gits()} must be a non-negative integer."
    exit
  }

  * Ensure `secondarypos` is proper
  if "`secondarystatposition'" == "" {
    local secondarystatposition "parentheses"
  }
  if !inlist("`secondarystatposition'", "below", "Below", "Parentheses", "parentheses", "none", "None") {
    display as error `"Option {bf:{ul:seconda}rystatposition()} must contain either "none", "parentheses" or "below"."'
    exit
  }
  local second = strlower(substr("`secondarystatposition'", 1, 5))

  * Ensure decorations are appropriate.
  foreach dec in sectiondecoration variabledecoration {
    if !inlist("``dec''", "border", "bold", "both", "none") {
      if "``dec''" == "" {
        local `dec' none
      }
      else {
        display as error `"Invalid {opt `dec'}: "``dec''"."'
        display as error "   Valid options: none, border, bold, both."
      }
    }
  }

  * Default for countlabel
  if "`countlabel'" == "" {
    local countlabel "Number of Patients, No."
  }

  * Define indent
  if "`categoricalindent'" == "" {
    local indent "     "
  }
  else {
    local indent ""
  }

  * Should we generate standardized diffs? No if groups > 2, yes if groups = 2 and
  *  NOT passed `nostddiff' option
  local displaystddiff "False"
  if `numlowergroups' == 2 & "`stddiff'" == "" {
    local displaystddiff "True"
  }

  * Should we report p-values? No if groups > 2, yes if groups = 2 and
  *  passed `pvals' option
  local displaypv "False"
  if `numlowergroups' == 2 & "`pvals'" == "pvals" {
    local displaypv "True"
  }

  * If pvals are not requested, but adjustpvals are, produced warning
  if "`displaypv'" == "False" & "`adjustpvals'" == "adjustpvals" {
    display as error "Option {bf:adjustpvals} ignored when p-values are not requested."
    local adjustpvals  ""
  }

  ***********************************
  ***** Group numbers and names *****
  ***********************************

  * Store the names of the groups for use in printing
  forvalues ln = 1/`numlowergroups' {
    local lowernum`ln' = `lowergroups'[`ln', 1]
    local lowergroup`ln'name : label (`lowerby') `lowernum`ln''
  }
  forvalues un = 1/`numuppergroups' {
    local uppernum`un' = `uppergroups'[`un', 1]
    local uppergroup`un'name : label (`upperby') `uppernum`un''
  }

  * Store sample size in each group for later use when using p-values
  if "`displaypv'" == "True" {
    forvalues un = 1/`numuppergroups' {
      qui count if `lowerby' == `lowernum1' & `upperby' == `uppernum`un''
      local n`un'1 = r(N)
      qui count if `lowerby' == `lowernum2' & `upperby' == `uppernum`un''
      local n`un'2 = r(N)
    }
  }

  *********************************
  ***** Generate Storage Data *****
  *********************************

  * Generate temporary variables which will store results
  tempvar v_rownames v_valnames
  qui gen str100 `v_rownames' = ""
  qui gen str100 `v_valnames' = ""
  forvalues un = 1/`numuppergroups' {
    forvalues ln = 1/`numlowergroups' {
      tempvar v_mean`un'`ln'
      qui gen `v_mean`un'`ln'' = .
      if "`second'" != "below" {
        * If we're using "below" for the secondary, no need for `v_secondary'
        tempname v_secondary`un'`ln'
        qui gen `v_secondary`un'`ln'' = .
      }
    }
    if "`displaystddiff'" == "True" {
      tempname v_stdiff`un'
      qui gen `v_stdiff`un'' = .
    }
    if "`displaypv'" == "True" {
      tempname v_pvals`un'
      qui gen `v_pvals`un'' = .
    }
  }

  * A few temporary matrices to use inside the loop
  tempname B SD Total Count RowMat

  tokenize _ `anything'
  local i = 2 // Counter of which variable
  local row = 3 // Row for printing
  * Starts in 3rd row because row 1 = upper group, row 2 = lower group.
  *   Row 1 will be dropped later if no upper group

  * Loop over all variables
  while "``i''" != "" {

    **********************************************
    ***** Extract and Clean Up Variable Name *****
    **********************************************

    local varname "``i''"

    * remove any prefix
    local varname_noprefix = regexr("`varname'", "^[icb]\.", "")

    * Check if we have a variable name. If not, we've got a section header.
    capture confirm variable `varname_noprefix'
    if !_rc {

      * Extract variable label, warning as needed if not provided.
      local varlab: var label `varname_noprefix'
      if "`varlab'" == "" {
        display as error "Variable {bf:`varname_noprefix'} does not have a label, falling back to variable name."
        local varlab "`varname_noprefix'"
      }

      * Update prefix as needed.
      if regexm("`varname'", "^i\.") {
        local type "categorical"
      }
      if regexm("`varname'", "^b\.") {
        capture assert `varname_noprefix' == 0 | ///
                       `varname_noprefix' == 1 | ///
                       `varname_noprefix' >= .
        if _rc {
          display as error "Variable {bf:`varname_noprefix'} has none-0/1 values; binary variables (prefixed with {bf:b.}) must have values of 0 (absence) or 1 (presence)."
          break
        }
        local type "binary"
      }
      if regexm("`varname'", "^c\.") {
        local type "continuous"
      }
      if !regexm("`varname'", "^[icb]\.") {
        local type "continuous"
      }

      ********************************************************
      ***** Different paths for Continuous versus Factor *****
      ********************************************************

      * If we have a continuous variable, report it's mean and sd.
      if "`type'" == "continuous" {

        ********************************
        ***** Continuous Variables *****
        ********************************

        forvalues un = 1/`numuppergroups' {
          if "`if'" == "" {
            qui mean `varname_noprefix' if `upperby' == `uppernum`un'' `in', over(`lowerby')
          }
          else {
            qui mean `varname_noprefix' `if' & `upperby' == `uppernum`un'' `in', over(`lowerby')
          }
          qui replace `v_rownames' = "`varlab'" in `row'
          * Extract mean and sd
          matrix `B' = e(b)
          forvalues ln = 1/`numlowergroups' {
            local mean`ln' = `B'[1,`ln']
            qui replace `v_mean`un'`ln'' = `mean`ln'' in `row'
          }

          * This mata command moves e(V) into mata, takes the diagonal,
          * sqrts each element, multiplyes by sqrt(n) to move from SE to SD,
          * and pops it back into matrix "sd".
          mata: st_matrix("`SD'", diagonal(sqrt(diagonal(st_matrix("e(V)")))*sqrt(st_matrix("e(_N)"))))
          forvalues ln = 1/`numlowergroups' {
            local sd`ln' = `SD'[`ln',1]
            if "`second'" == "below" {
              * If we're using "below for secondary, stick the sd there, and add a unique
              * tag to `v_rownames' so we can identify it later
              qui replace `v_mean`un'`ln'' = `sd`ln'' in `=`row'+1'
              qui replace `v_rownames' = "[[second]]" in `=`row'+1'
            }
            else {
              qui replace `v_secondary`un'`ln'' = `sd`ln'' in `row'
            }
          }
          if "`displaystddiff'" == "True" {
            local standdiff = (`mean1' + `mean2')/sqrt(`sd1'^2 + `sd2'^2)
            qui replace `v_stdiff`un'' = `standdiff' in `row'
          }
          if "`displaypv'" == "True" {
            qui ttesti `n`un'1' `mean1' `sd1' `n`un'2' `mean2' `sd2'
            local pv = r(p)
            qui replace `v_pvals`un'' = `pv' in `row'
          }
        }
        if "`second'" == "below" {
          * Skipping down an extra row to account for SD
          local row = `row' + 2
        }
        else {
          local row = `row' + 1
        }
      }
      else if "`type'" == "categorical" {

        *********************************
        ***** Categorical Variables *****
        *********************************

        * Only report chi-sq if we need it for p-values.
        if "`displaypv'" == "True" {
          local chi2 "chi2"
        }

        qui replace `v_rownames' = "`varlab'" in `row'
*        local row = `row' + 1

        forvalues un = 1/`numuppergroups' {
          * Generate a table, saving the count and levels.
          if "`if'" == "" {
            qui tab `varname_noprefix' `lowerby' if `upperby' == `uppernum`un'' `in', matcell(`Count') matrow(`RowMat') `chi2'
          }
          else {
            qui tab `varname_noprefix' `lowerby' `if' & `upperby' == `uppernum`un'' `in', matcell(`Count') matrow(`RowMat') `chi2'
          }
          * Get total by column to find percent later
          mata: st_matrix("`Total'", colsum(st_matrix("`Count'")))
          forvalues ln = 1/`numlowergroups' {
            local total`ln' = `Total'[1,`ln']
          }

          if "`displaypv'" == "True" {
            qui replace `v_pvals`un'' = r(p) in `row'
          }

          local valuecount = rowsof(`RowMat')
          forvalues vnum = 1/`valuecount' {
            local rowposition = `row' + `vnum'
            if "`second'" == "below" {
              local rowposition = `row' + (2*`vnum' - 1)
            }
            * Looping over each level to produce results
            local val = `RowMat'[`vnum',1]
            local vl : label (`varname_noprefix') `val'
            qui replace `v_valnames' = "`vl'" in `rowposition'

            forvalues ln = 1/`numlowergroups' {
              local count`ln' = `Count'[`vnum',`ln']
              local percent_val`ln' = `count`ln''/`total`ln''
              qui replace `v_mean`un'`ln'' = `count`ln'' in `rowposition'
              if "`second'" == "below" {
                qui replace `v_mean`un'`ln'' = `percent_val`ln'' in `=`rowposition'+1'
                qui replace `v_rownames' = "[[second]]" in `=`rowposition'+1'
              }
              else {
                qui replace `v_secondary`un'`ln'' = `percent_val`ln'' in `rowposition'
              }
            }
          }
        }
        if "`second'" == "below" {
          local row = `row' + 2*`valuecount' + 1
        }
        else {
          local row = `row' + `valuecount' + 1
        }
      }
      else if "`type'" == "binary" {

        ****************************
        ***** Binary Variables *****
        ****************************

        * Only report chi-sq if we need it for p-values.
        if "`displaypv'" == "True" {
          local chi2 "chi2"
        }

        forvalues un = 1/`numuppergroups' {
          * Generate table
          if "`if'" == "" {
            qui tab `varname_noprefix' `lowerby' if `upperby' == `uppernum`un'' `in', matcell(`Count') `chi2'
          }
          else {
            qui tab `varname_noprefix' `lowerby' `if' & `upperby' == `uppernum`un'' `in', matcell(`Count') `chi2'
          }
          qui replace `v_rownames' = "`varlab'" in `row'
          if "`displaypv'" == "True" {
            qui replace `v_pvals`un'' = r(p) in `row'
          }
          * Flag these binary variables to be properly formatted with percent below
          qui replace `v_valnames' = "__binary__" in `row'
          forvalues ln = 1/`numlowergroups' {
            local count`ln' = `Count'[2, `ln']
            mata: st_matrix("`Total'", colsum(st_matrix("`Count'")))
            local total`ln' = `Total'[1,`ln']
            local percent_val`ln' = `count`ln''/`total`ln''
            qui replace `v_mean`un'`ln'' = `count`ln'' in `row'

            if "`second'" == "below" {
              qui replace `v_mean`un'`ln'' = `percent_val`ln'' in `=`row'+1'
              qui replace `v_rownames' = "[[second]]" in `=`row'+1'
            }
            else {
              qui replace `v_secondary`un'`ln'' = `percent_val`ln'' in `row'
            }
          }

          if "`displaystddiff'" == "True"  {
            local standdiff = (`percent_val1' - `percent_val2')/sqrt((`percent_val1'*(1 - `percent_val1') + `percent_val2'*(1 - `percent_val2'))/2)
            qui replace `v_stdiff`un'' = `standdiff' in `row'
          }
        }

        if "`second'" == "below" {
          local row = `row' + 2
        }
        else {
          local row = `row' + 1
        }
      }
    }
    else {
      if "`varname'" == "_samplesize" {
        ***************************
        ***** Sample Size (N) *****
        ***************************

        qui replace `v_rownames' = "`countlabel'" in `row'
        forvalues un = 1/`numuppergroups' {
          forvalues ln = 1/`numlowergroups' {
            if "`if'" == "" {
              qui count if `upperby' == `uppernum`un'' & `lowerby' == `lowernum`ln'' `in'
            }
            else {
              qui count `if' & `upperby' == `uppernum`un'' & `lowerby' == `lowernum`ln'' `in'
            }
            qui replace `v_mean`un'`ln'' = r(N) in `row'
          }
        }
      }
      else {
        qui replace `v_rownames' = "__sec__`varname'" in `row'
      }
      local row = `row' + 1
    }

    local ++i
  }

  ****************************
  ***** Restructure Data *****
  ****************************

  * Perform p-value correction if requested
  * (adjustpvals is automatically false (blank) if pvals not requested
  if "`adjustpvals'" == "adjustpvals" {
    * Loop once over all upper groups, counting number of p-values...
    forvalues un = 1/`numuppergroups' {
      qui count if !missing(`v_pvals`un'')
      local rollingcount = `rollingcount' + `r(N)'
    }
    * ... then use that as the correction.
    forvalues un = 1/`numuppergroups' {
      qui replace `v_pvals`un'' = min(1, `v_pvals`un''*`rollingcount') if !missing(`v_pvals`un'')
    }
  }

  * For the numeric variables, we'll force them to strings first

  forvalues un = 1/`numuppergroups' {
    forvalues ln = 1/`numlowergroups' {
      * If there's a valname, the secondary is a percent, not a SD.
      if "`second'" == "below" {
        qui replace `v_mean`un'`ln'' = round(100*`v_mean`un'`ln'', .1^`perdigits') if `v_valnames'[_n-1] != ""
      }
      else {
        qui replace `v_secondary`un'`ln'' = round(100*`v_secondary`un'`ln'', .1^`perdigits') if `v_valnames' != ""
        string_better_round `v_secondary`un'`ln'', digits(`digits')
      }
      string_better_round `v_mean`un'`ln'', digits(`digits')
    }
    if "`displaystddiff'" == "True"  {
        qui replace `v_stdiff`un'' = round(100*`v_stdiff`un'', .1^`perdigits') if `v_valnames' == "__binary__"
        string_better_round `v_stdiff`un'', digits(`digits')
    }
    if "`displaypv'" == "True"  {
        string_better_round `v_pvals`un'', digits(`pdigits')
    }
  }

  * If option "None" is given

  if "`second'" == "none" {
    forvalues un = 1/`numuppergroups' {
      forvalues ln = 1/`numlowergroups' {
        qui drop `v_secondary`un'`ln''
        replace `v_mean`un'`ln'' = "" if `v_mean`un'`ln'' == "."
      }
    }
  }

  * If option "Parentheses" is given

  if "`second'" == "paren" {
    forvalues un = 1/`numuppergroups' {
      forvalues ln = 1/`numlowergroups' {
        qui replace `v_mean`un'`ln'' = `v_mean`un'`ln'' + " (" + `v_secondary`un'`ln'' + ")" ///
          if `v_valnames' == "" & `v_secondary`un'`ln'' != "."
        qui replace `v_mean`un'`ln'' = `v_mean`un'`ln'' + " (" + `v_secondary`un'`ln'' + "%)" ///
          if `v_valnames' != "" & `v_secondary`un'`ln'' != "."
        qui replace `v_mean`un'`ln'' = "" if `v_mean`un'`ln'' == "."
        drop `v_secondary`un'`ln''
      }
    }

  }

  * If option "Below" is given

  if "`second'" == "below" {
    forvalues un = 1/`numuppergroups' {
      forvalues ln = 1/`numlowergroups' {
        * We've flagged secondary stats with the "[[second]]" entry in rownames
        qui replace `v_mean`un'`ln'' = "(" + `v_mean`un'`ln'' + ")" if `v_rownames' == "[[second]]" & `v_valnames'[_n-1] == ""
        qui replace `v_mean`un'`ln'' = "(" + `v_mean`un'`ln'' + "%)" if `v_rownames' == "[[second]]" & `v_valnames'[_n-1] != ""
        qui replace `v_mean`un'`ln'' = "" if `v_mean`un'`ln'' == "."
      }
    }
    * Drop the flag in rownames
    qui replace `v_rownames' = "" if `v_rownames' == "[[second]]"
  }

  * In all options, clean up "." in stdiff and pv
  forvalues un = 1/`numuppergroups' {
    if "`displaystddiff'" == "True" {
      qui replace `v_stdiff`un'' = "" if `v_stdiff`un'' == "."
    }
    if "`displaypv'" == "True"  {
      qui replace `v_pvals`un'' = "" if `v_pvals`un'' == "."
    }
  }

  * Clean up stddiff and valnames for binary variables
  qui replace `v_valnames' = "" if `v_valnames' == "__binary__"

  *********************************
  ***** Generate Excel Output *****
  *********************************

  * Only if passed `using`
  if "`using'" != "" {

    * Merge variable & value names with indenting
    tempvar v_rownamestmp
    qui gen `v_rownamestmp' = `v_rownames'
    qui replace `v_rownamestmp' = "`indent'" + `v_valnames' if `v_valnames' != ""

    * Write the main data out to excel
    if "`displaypv'" == "True" {
    export excel `v_rownamestmp' `v_mean1'-`v_pvals' ///
      using "`using'" in 1/`=`row'-1', `replace'
    }
    else if "`displaystddiff'" == "True"  {
    export excel `v_rownamestmp' `v_mean1'-`v_stdiff' ///
      using "`using'" in 1/`=`row'-1', `replace'
    }
    else  {
    export excel `v_rownamestmp' `v_mean1'-`v_mean`numgroups'' ///
      using "`using'" in 1/`=`row'-1', `replace'
    }

    * Compute total number of non-empty columns
    local totalhlinecols = `=`numgroups'+1'
    if "`displaystddiff'" == "True"  {
      local totalhlinecols = `totalhlinecols' + 1
    }
    if "`displaypv'" == "True"  {
      local totalhlinecols = `totalhlinecols' + 1
    }

    ****** Nice formatting
    putexcel set "`using'", modify
    * Adding line under header
    qui putexcel A1:`=word(c(ALPHA), `totalhlinecols')'1, border(bottom)

    * Decorating count (if it exists
    local startrow 2

    forvalues r = `startrow'/`row' {
      * Decorating VARIABLES
      if !regexm(`v_rownames'[`r'], "^__sec__") & `v_rownames'[`r'] != "" {
        if inlist("`variabledecoration'", "bold", "both") {
          qui putexcel A`r', bold
        }
        if inlist("`variabledecoration'", "border", "both") {
          qui putexcel A`r':`=word(c(ALPHA), `totalhlinecols')'`r', border(bottom)
        }
      }

      * Decorating SECTIONS
      if regexm(`v_rownames'[`r'], "^__sec__") {
        qui putexcel A`r' = "`=regexr(`v_rownames'[`r'], "^__sec__", "")'"
        if inlist("`sectiondecoration'", "bold", "both") {
          qui putexcel A`r', bold
        }
        if inlist("`sectiondecoration'", "border", "both") {
          qui putexcel A`r':`=word(c(ALPHA), `totalhlinecols')'`r', border(bottom)
        }
      }
    }

    * Add group names
    forvalues n = 1/`numgroups' {
      qui putexcel `=word(c(ALPHA), `=`n'+1')'1 = "`group`n'name'"
    }
    if "`displaystddiff'" == "True"  {
      * Don't need to worry about any other place for this; only used with 2 groups
      qui putexcel D1 = ("Standard Difference")
    }
    if "`displaypv'" == "True"  {
      * Don't need to worry about any other place for this; only used with 2 groups
      qui putexcel E1 = ("P-values")
    }
  }

  ***********************************
  ***** Generate Printed Output *****
  ***********************************

  * If not passed a using, or if the `print` option is passed along with
  *  a using, display a table in output.
  if "`using'" == "" | ("`using'" != "" & "`print'" == "print") {

    * Replace the first row of data with appropriate column names
    if "`onelevel'" == "False" {
      local titlerow 2
      forvalues un = 1/`numuppergroups' {
        qui replace `v_mean`un'1' = "`uppergroup`un'name'" in 1
      }
    }
    else {
      local titlerow 1
      drop in 1
      local row = `row' - 1
    }
    qui replace `v_rownames' = "Variable" in `titlerow'
    qui replace `v_valnames' = "Value" in `titlerow'
    forvalues un = 1/`numuppergroups' {
      forvalues ln = 1/`numlowergroups' {
        qui replace `v_mean`un'`ln'' = "`lowergroup`ln'name'" in `titlerow'
      }
      if "`displaystddiff'" == "True" {
        qui replace `v_stdiff`un'' = "Standard Difference" in `titlerow'
      }
      if "`displaypv'" == "True" {
        qui replace `v_pvals`un'' = "P-value" in `titlerow'
      }
    }

    * Format sections nicely
    qui replace `v_rownames' = upper(regexr(`v_rownames', "^__sec__", "")) ///
      if regexm(`v_rownames', "^__sec__") == 1

    * Use a divider variable to separate headers from variables
    tempname v_divider
    qui gen `v_divider' = 0
    qui replace `v_divider' = 1 in 1/`titlerow'
    if "`displaypv'" == "True" {
      list `v_rownames'-`v_pvals`numuppergroups'' ///
          in 1/`=`row'-1', noobs sepby(`v_divider') noheader
    }
    else if "`displaystddiff'" == "True"  {
      list `v_rownames'-`v_stdiff`numuppergroups'' ///
          in 1/`=`row'-1', noobs sepby(`v_divider') noheader
    }
    else  {
      list `v_rownames'-`v_mean`numuppergroups'`numlowergroups'' ///
          in 1/`=`row'-1', noobs sepby(`v_divider') noheader
    }
  }

end

program define string_better_round
  syntax varname[, DIgits(integer 3)]

  tempname tmp inctmp

  * Create a string with normal Stata rounding.
  qui tostring `varlist', gen(varlist2) force format("%15.`digits'fc")

  * This is a correction to remove trailing 0's if
  *  the value has 0-2 non-zero decimals (since by
  *  default we're printing 3.
  if `digits' > 0 {
    * If `digits` is 0, we don't need to do this obviously.
    foreach k of numlist `=`digits'-1'/0 {
    * This works by creating new string variables of sharper rounding first...
      tempvar tmp
      qui tostring `varlist', gen(`tmp') force format("%15.`k'fc")
    * ... then, to avoid issues with numeric precision, generating a tmp
    *  variable which basically moves the decimal over the same number of
    *  places ...
      cap drop `inctmp'
      qui gen `inctmp' = 10^`k'*`varlist'
    * ... and if the new variable is an integer (e.g. with k = 0, 1 is
    *  an integer. With k = 1, 2.3 is an integer [since 10*2.3 = 23])
    *  then it replaces the string with the sharper rounded version.
      qui replace varlist2 = `tmp' if mod(`inctmp',1) == 0
      drop `tmp'
    }
    * This whole bit just helps more closely mimic what Excel output
    *  will look like since Excel supports the proper format (up to 3
    *  decimals as needed, as opposed to Stata which only supports an
    *  exact number of decimals [except in `g` format, which may truncate
    *  even worse just to fit the total width]).
  }
    order varlist2, after(`varlist')
    drop `varlist'
    rename varlist2 `varlist'
end
