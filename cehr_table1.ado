program define cehr_table1
  preserve

  ******************
  ***** Syntax *****
  ******************

  syntax anything [if] [in] [using/],  ///
    BY(varname)                        ///
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

  * Ensure that the treatment variable has at least 2 levels
  tempname Groups
  qui tab `by' `if' `in', matrow(`Groups')
  local numgroups = rowsof(`Groups')
  if `numgroups' < 2 {
    if "`if'" != "" | "`in'" != "" {
      display as error "option {bf:by()} must contain a variable with at least two levels in the subgroup"
    }
    else {
      display as error "option {bf:by()} must contain a variable with at least two levels"
    }
    exit
  }

  * Ensure digits is a realistic choice.
  if `digits' < 0 {
    display as error "option {bf:{ul:di}gits()} must be a non-negative interger"
    exit
  }

  * Ensure perdigits is a realistic choice.
  if `perdigits' < 0 {
    display as error "option {bf:{ul:perdi}gits()} must be a non-negative interger"
    exit
  }

  * Ensure pdigits is a realistic choice.
  if `pdigits' < 0 {
    display as error "option {bf:{ul:pdi}gits()} must be a non-negative interger"
    exit
  }

  * Ensure `secondarypos` is proper
  if "`secondarystatposition'" == "" {
    local secondarystatposition "parentheses"
  }
  if !inlist("`secondarystatposition'", "below", "Below", "Parentheses", "parentheses", "none", "None") {
    display as error `"option {bf:{ul:seconda}rystatposition()} must contain either "none", "parentheses" or "below""'
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
        display as error "   Valid options: none, border, bold, both"
      }
    }
  }

  * Default for countlabel
  if "`countlabel'" == "" {
    local countlabel "Number of Patients, No."
  }

	* Should we generate standardized diffs? No if groups > 2, yes if groups = 2 and
	*  NOT passed `nostddiff' option
	local displaystddiff "False"
	if `numgroups' == 2 & "`stddiff'" == "" {
		local displaystddiff "True"
	}

	* Should we report p-values? No if groups > 2, yes if groups = 2 and
	*  passed `pvals' option
	local displaypv "False"
	if `numgroups' == 2 & "`pvals'" == "pvals" {
		local displaypv "True"
	}

	* If pvals are not requested, but adjustpvals are, produced warning
	if "`displaypv'" == "False" & "`adjustpvals'" == "adjustpvals" {
		display as error "option {bf:adjustpvals} ignored when p-values are not requested"
		local adjustpvals  ""
	}

  ***********************************
  ***** Group numbers and names *****
  ***********************************

  * Store the names of the groups for use in printing
  forvalues n = 1/`numgroups' {
    local num`n' = `Groups'[`n', 1]
    local group`n'name : label (`by') `num`n''
  }

	* Store sample size in each group for later use when using p-values
	if "`displaypv'" == "True" {
		qui count if `by' == `num1'
		local n1 = r(N)
		qui count if `by' == `num2'
		local n2 = r(N)
	}
	*************************
	***** Define indent *****
	*************************

	if "`categoricalindent'" == "" {
		local indent "     "
	}
	else {
		local indent ""
	}

  *********************************
  ***** Generate Storage Data *****
  *********************************

  * Generate temporary variables which will store results
  tempvar v_rownames v_valnames v_stdiff v_pvals
  qui gen str100 `v_rownames' = ""
  qui gen str100 `v_valnames' = ""
  forvalues n = 1/`numgroups' {
    tempvar v_mean`n' v_secondary`n'
    qui gen `v_mean`n'' = .
    if "`second'" != "below" {
      * If we're using "below" for the secondary, no need for `v_secondary'
      qui gen `v_secondary`n'' = .
    }
  }
	if "`displaystddiff'" == "True" {
		qui gen `v_stdiff' = .
	}
	if "`displaypv'" == "True" {
		qui gen `v_pvals' = .
	}

  * A few temporary matrices to use inside the loop
  tempname B SD Total Count RowMat

  tokenize _ `anything'
  local i = 2 // Counter of which variable
  local row = 2 // Row for printing
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
          display as error "Variable {bf:`varname_noprefix'} has none-0/1 values; binary variables (prefixed with {bf:b.}) must have values of 0 (absense) or 1 (presence)"
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

        qui mean `varname_noprefix' `if' `in', over(`by')
        qui replace `v_rownames' = "`varlab'" in `row'
        * Extract mean and sd
        matrix `B' = e(b)
        forvalues n = 1/`numgroups' {
          local mean`n' = `B'[1,`n']
          qui replace `v_mean`n'' = `mean`n'' in `row'
        }

        * This mata command moves e(V) into mata, takes the diagonal,
        * sqrts each element, multiplyes by sqrt(n) to move from SE to SD,
        * and pops it back into matrix "sd".
        mata: st_matrix("`SD'", diagonal(sqrt(diagonal(st_matrix("e(V)")))*sqrt(st_matrix("e(_N)"))))
        forvalues n = 1/`numgroups' {
          local sd`n' = `SD'[`n',1]
          if "`second'" == "below" {
            * If we're using "below for secondary, stick the sd there, and add a unique
            * tag to `v_rownames' so we can identify it later
            qui replace `v_mean`n'' = `sd`n'' in `=`row'+1'
            qui replace `v_rownames' = "[[second]]" in `=`row'+1'
          }
          else {
            qui replace `v_secondary`n'' = `sd`n'' in `row'
          }
        }
        if "`displaystddiff'" == "True" {
          local standdiff = (`mean1' + `mean2')/sqrt(`sd1'^2 + `sd2'^2)
          qui replace `v_stdiff' = `standdiff' in `row'
        }
				if "`displaypv'" == "True" {
					qui ttesti `n1' `mean1' `sd1' `n2' `mean2' `sd2'
					local pv = r(p)
					qui replace `v_pvals' = `pv' in `row'
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

        * Generate a table, saving the count and levels.
        qui tab `varname_noprefix' `by' `if' `in', matcell(`Count') matrow(`RowMat') `chi2'
        * Get total by column to find percent later
        mata: st_matrix("`Total'", colsum(st_matrix("`Count'")))
        forvalues n = 1/`numgroups' {
          local total`n' = `Total'[1,`n']
        }

        qui replace `v_rownames' = "`varlab'" in `row'
        local row = `row' + 1
				if "`displaypv'" == "True" {
					qui replace `v_pvals' = r(p) in `row'
				}

        local valuecount = rowsof(`RowMat')
        forvalues vnum = 1/`valuecount' {
          * Looping over each level to produce results
          local val = `RowMat'[`vnum',1]
          local vl : label (`varname_noprefix') `val'
          qui replace `v_valnames' = "`vl'" in `row'

          forvalues n = 1/`numgroups' {
            local count`n' = `Count'[`vnum',`n']
            local percent_val`n' = `count`n''/`total`n''
            qui replace `v_mean`n'' = `count`n'' in `row'
            if "`second'" == "below" {
              qui replace `v_mean`n'' = `percent_val`n'' in `=`row'+1'
              qui replace `v_rownames' = "[[second]]" in `=`row'+1'
            }
            else {
              qui replace `v_secondary`n'' = `percent_val`n'' in `row'
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
      else if "`type'" == "binary" {

        ****************************
        ***** Binary Variables *****
        ****************************

				* Only report chi-sq if we need it for p-values.
				if "`displaypv'" == "True" {
					local chi2 "chi2"
				}

        * Generate table
        qui tab `varname_noprefix' `by' `if' `in', matcell(`Count') `chi2'
        qui replace `v_rownames' = "`varlab'" in `row'
				if "`displaypv'" == "True" {
					qui replace `v_pvals' = r(p) in `row'
				}
        * Flag these binary variables to be properly formatted with percent below
        qui replace `v_valnames' = "__binary__" in `row'
        forvalues n = 1/`numgroups' {
          local count`n' = `Count'[2, `n']
          mata: st_matrix("`Total'", colsum(st_matrix("`Count'")))
          local total`n' = `Total'[1,`n']
          local percent_val`n' = `count`n''/`total`n''
          qui replace `v_mean`n'' = `count`n'' in `row'

          if "`second'" == "below" {
            qui replace `v_mean`n'' = `percent_val`n'' in `=`row'+1'
            qui replace `v_rownames' = "[[second]]" in `=`row'+1'
          }
          else {
            qui replace `v_secondary`n'' = `percent_val`n'' in `row'
          }
        }

        if "`displaystddiff'" == "True"  {
          local standdiff = (`percent_val1' - `percent_val2')/sqrt((`percent_val1'*(1 - `percent_val1') + `percent_val2'*(1 - `percent_val2'))/2)
          qui replace `v_stdiff' = `standdiff' in `row'
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
        forvalues n = 1/`numgroups' {
          if "`if'" == "" {
            qui count if `by' == `num`n'' `in'
          }
          else {
            qui count `if' & `by' == `num`n'' `in'
          }
          qui replace `v_mean`n'' = r(N) in `row'
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
		qui count if !missing(`v_pvals')
		qui replace `v_pvals' = min(1, `v_pvals'*r(N)) if !missing(`v_pvals')
	}

  * For the numeric variables, we'll force them to strings first

  forvalues n = 1/`numgroups' {
    * If there's a valname, the secondary is a percent, not a SD.
    if "`second'" == "below" {
      qui replace `v_mean`n'' = round(100*`v_mean`n'', .1^`perdigits') if `v_valnames'[_n-1] != ""
    }
    else {
      qui replace `v_secondary`n'' = round(100*`v_secondary`n'', .1^`perdigits') if `v_valnames' != ""
      string_better_round `v_secondary`n'', digits(`digits')
    }
    string_better_round `v_mean`n'', digits(`digits')
  }
  if "`displaystddiff'" == "True"  {
    qui replace `v_stdiff' = round(100*`v_stdiff', .1^`perdigits') if `v_valnames' == "__binary__"
    string_better_round `v_stdiff', digits(`digits')
  }
  if "`displaypv'" == "True"  {
    string_better_round `v_pvals', digits(`pdigits')
  }

  * If option "None" is given

  if "`second'" == "none" {
    forvalues n = 1/`numgroups' {
      qui drop `v_secondary`n''
    }
  }

  * If option "Parentheses" is given

  if "`second'" == "paren" {
    forvalues n = 1/`numgroups' {
      qui replace `v_mean`n'' = `v_mean`n'' + " (" + `v_secondary`n'' + ")" ///
        if `v_valnames' == "" & `v_secondary`n'' != "."
      qui replace `v_mean`n'' = `v_mean`n'' + " (" + `v_secondary`n'' + "%)" ///
        if `v_valnames' != "" & `v_secondary`n'' != "."
      qui replace `v_mean`n'' = "" if `v_mean`n'' == "."
      drop `v_secondary`n''
    }

    if "`displaystddiff'" == "True"  {
      qui replace `v_stdiff' = "" if `v_stdiff' == "."
    }

    if "`displaypv'" == "True"  {
      qui replace `v_pvals' = "" if `v_pvals' == "."
    }


  }

  * If option "Below" is given

  if "`second'" == "below" {
    forvalues n = 1/`numgroups' {
      * We've flagged secondary stats with the "[[second]]" entry in rownames
      qui replace `v_mean`n'' = "(" + `v_mean`n'' + ")" if `v_rownames' == "[[second]]" & `v_valnames'[_n-1] == ""
      qui replace `v_mean`n'' = "(" + `v_mean`n'' + "%)" if `v_rownames' == "[[second]]" & `v_valnames'[_n-1] != ""
      qui replace `v_mean`n'' = "" if `v_mean`n'' == "."
    }
    * Drop the flag in rownames
    qui replace `v_rownames' = "" if `v_rownames' == "[[second]]"
    if "`displaystddiff'" == "True" {
      qui replace `v_stdiff' = "" if `v_stdiff' == "."
    }
    if "`displaypv'" == "True"  {
      qui replace `v_pvals' = "" if `v_pvals' == "."
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
    qui replace `v_rownames' = "Variable" in 1
    qui replace `v_valnames' = "Value" in 1
    forvalues n = 1/`numgroups' {
      qui replace `v_mean`n'' = "`group`n'name'" in 1
    }
    if "`displaystddiff'" == "True" {
      qui replace `v_stdiff' = "Standard Difference" in 1
    }
    if "`displaypv'" == "True" {
      qui replace `v_pvals' = "P-value" in 1
    }

    * Format sections nicely
    qui replace `v_rownames' = upper(regexr(`v_rownames', "^__sec__", "")) ///
      if regexm(`v_rownames', "^__sec__") == 1

    * Use a divider variable to separate headers from variables
    tempname v_divider
    qui gen `v_divider' = 0
    qui replace `v_divider' = 1 in 1
		if "`displaypv'" == "True" {
      list `v_rownames'-`v_pvals' ///
          in 1/`=`row'-1', noobs sepby(`v_divider') noheader
		}
    else if "`displaystddiff'" == "True"  {
      list `v_rownames'-`v_stdiff' ///
          in 1/`=`row'-1', noobs sepby(`v_divider') noheader
    }
    else  {
      list `v_rownames'-`v_mean`numgroups'' ///
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
