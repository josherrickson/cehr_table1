program define cehr_table1

	******************
	***** Syntax *****
	******************
	
	syntax varlist(min=1 fv) [if] [in] [using/], BY(varname) [nosd REPlace PRint DIgits(integer 3)] 
	
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
		display as error "option {bf:digits()} must be a non-negative interger"
		exit
	}

	***********************************
	***** Group numbers and names *****
	***********************************
	
	* Store the names of the groups for use in printing
	forvalues n = 1/`numgroups' {
		local num`n' = `Groups'[`n', 1]
		local group`n'name : label (`by') `num`n''
	}
	
	*********************************
	***** Generate Storage Data *****
	*********************************
	
	* Generate temporary variables which will store results
	tempvar v_rownames v_valnames v_stdiff 
	qui gen str100 `v_rownames' = ""
	qui gen str100 `v_valnames' = ""
	forvalues n = 1/`numgroups' {
		tempvar v_group`n'
		qui gen `v_group`n'' = .
	}
	qui gen `v_stdiff' = .

	***************************
	***** Sample Size (N) *****
	***************************
	
	qui replace `v_rownames' = "Number of Patients, No." in 2
	
	forvalues n = 1/`numgroups' {
		if "`if'" == "" {
			qui count if `by' == `num`n'' `in'
		}
		else {
			qui count `if' & `by' == `num`n'' `in'
		}
		qui replace `v_group`n'' = r(N) in 2
	}
	
	
	* A few temporary matrices to use inside the loop
	tempname B SD Total Freq RowMat 

	tokenize `varlist'
	local i = 1 // Counter of which variable
	local row = 3 // Row for printing
	* Loop over all variables
	while "``i''" != "" {

		**********************************************
		***** Extract and Clean Up Variable Name *****
		**********************************************
		
		local varname "``i''"

		* Extract non-factor version
		local varname_noi = regexr("`varname'", "^i.", "")
		local varlab: var label `varname_noi'

		* Update i. to ibn.
		local varname = regexr("`varname'", "^i.", "ibn.")

		* Macros:
		*  varname = name of variable. Either varname or ibn.varname.
		*  varname_noi = name of variable with any i. removed.
		*  varlab = Variable label for printing.
		
		
		********************************************************
		***** Different paths for Continuous versus Factor *****
		**********************************************

		* A hacky way to check if user passed a categorical variable. If they did,
		* varname will be `ibn.varname`, whereas varname_noi has the ibn. stripped.
		* If they didn't, these are equivalent
		if ("`varname_noi'" == "`varname'") {
			
			********************************
			***** Continuous Variables *****
			********************************
			
			qui mean `varname' `if' `in', over(`by')
			qui replace `v_rownames' = "`varlab'" in `row'
			* Extract mean and sd
			matrix `B' = e(b)
			forvalues n = 1/`numgroups' {
				local mean`n' = `B'[1,`n']
				qui replace `v_group`n'' = `mean`n'' in `row'
			}

			if "`sd'" == "" {
				* This mata command moves e(V) into mata, takes the diagonal, 
				* sqrts each element,  and pops it back into matrix "sd".
				mata: st_matrix("`SD'", sqrt(diagonal(st_matrix("e(V)"))))
				forvalues n = 1/`numgroups' {
					local sd`n' = `SD'[`n',1]
					qui replace `v_group`n'' = `sd`n'' in `=`row'+1'
				}
				if `numgroups' == 2 {
					local standdiff = (`mean1' + `mean2')/sqrt(`sd1'^2 + `sd2'^2)
					qui replace `v_stdiff' = `standdiff' in `row'
				}
			* `row` must increase by 2 due to SD 2nd row
				local row = `row' + 2
			}
			else {
				local row = `row' + 1
			}
		}
		else {
		
			*********************************
			***** Categorical Variables *****
			*********************************
			
			* Generate a table, saving the count and levels.
			qui tab `varname_noi' `by' `if' `in', matcell(`Freq') matrow(`RowMat')
			* Get total by column to find percent later
			mata: st_matrix("`Total'", colsum(st_matrix("`Freq'")))
			forvalues n = 1/`numgroups' {
				local total`n' = `Total'[1,`n']
			}

			qui replace `v_rownames' = "`varlab'" in `row'

			local valuecount = rowsof(`RowMat')
			forvalues vnum = 1/`valuecount' {
				* Looping over each level to produce results
				local val = `RowMat'[`vnum',1]
				local vl : label (`varname_noi') `val'
				qui replace `v_valnames' = "`vl'" in `row'
				
				forvalues n = 1/`numgroups' {
					local freq_val`n' = `Freq'[`vnum',`n']
					local percent_val`n' = `freq_val`n''/`total`n''
					qui replace `v_group`n'' = `percent_val`n'' in `row'
				}

				local row = `row' + 1
        }
		}

		local ++i
	}

	*********************************
	***** Generate Excel Output *****
	*********************************
	
	* Only if passed `using`
	if "`using'" != "" { 
		* Round all numerics to `digits'
		forvalues n = 1/`numgroups' {
			tempvar v_group`n'r
			qui gen `v_group`n'r' = round(`v_group`n'', .1^`digits')
		}
		if `numgroups' == 2 {
			tempvar v_stdiffr
			qui gen `v_stdiffr' = round(`v_stdiff', .1^`digits')
		}
		
		* Write the main data out to excel
		export excel `v_rownames' `v_valnames' `v_group1r'-`v_group`numgroups'r' `v_stdiffr' ///
			using "`using'" in 1/`=`row'-1', `replace'
		
		* Add nice formatting to the file
		putexcel set "`using'", modify
		qui putexcel A1 = ("Variable")
		qui putexcel B1 = ("Value")
		forvalues n = 1/`numgroups' {
			qui putexcel `=word("`c(ALPHA)'", `n'+2)'1 = ("`group`n'name'")
		}
		if `numgroups' == 2 {
			qui putexcel E1 = ("Standard Difference")
		}
		
		* Drop excess variables created during this step
		forvalues n = 1/`numgroups' {
			drop `v_group`n'r'
		}
		if `numgroups' == 2 {
			* Could probably `cap drop` this, but save a few cycles by not bothering
			drop `v_stdiffr'
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

		* For the numeric variables, we'll force them to strings first

		forvalues n = 1/`numgroups' {
			tempvar v_group`n's
			qui tostring `v_group`n'', gen(`v_group`n's') force format("%15.`digits'fc")
		}
		if `numgroups' == 2 {
			tempvar v_stdiffs v_stdifftmp 
			qui tostring `v_stdiff', gen(`v_stdiffs') force format("%15.`digits'fc")
		}
		tempvar inctmp

		* This is a correction to remove trailing 0's if 
		*  the value has 0-2 non-zero decimals (since by
		*  default we're printing 3.
		if `digits' > 0 {
			* If `digits` is 0, we don't need to do this obviously.
			foreach k of numlist `=`digits'-1'/0 {
				* This works by creating new string variables of sharper rounding first...
				forvalues n = 1/`numgroups' {
					tempvar v_group`n'tmp
					qui tostring `v_group`n'', gen(`v_group`n'tmp') force format("%15.`k'fc")
				* ... then, to avoid issues with numeric precision, generating a tmp
				*  variable which basically moves the decimal over the same number of 
				*  places ...
					cap drop `inctmp'
					qui gen `inctmp' = 10^`k'*`v_group`n''
				* ... and if the new variable is an integer (e.g. with k = 0, 1 is 
				*  an integer. With k = 1, 2.3 is an integer [since 10*2.3 = 23])
				*  then it replaces the string with the sharper rounded version.
					qui replace `v_group`n's' = `v_group`n'tmp' if mod(`inctmp',1) == 0
					drop `v_group`n'tmp'
				}
				if `numgroups' == 2 {
					tempvar v_stdifftmp 
					qui tostring `v_stdiff', gen(`v_stdifftmp') force format("%15.`k'fc")
					cap drop `inctmp'
					qui gen `inctmp' = 10^`k'*`v_stdiff'
					qui replace `v_stdiffs' = `v_stdifftmp' if mod(`inctmp',1) == 0
					drop `v_stdifftmp'
				}
				* This whole bit just helps more closely mimic what Excel output
				*  will look like since Excel supports the proper format (up to 3
				*  decimals as needed, as opposed to Stata which only supports an
				*  exact number of decimals [except in `g` format, which may truncate 
				*  even worse just to fit the total width]).
			}
		}
		

		* Replace missing "."'s with blanks
		forvalues n = 1/`numgroups' {
			qui replace `v_group`n's' = "" if `v_group`n'' == .
			qui replace `v_group`n's' = "`group`n'name'" in 1
			drop `v_group`n''
		}
		if `numgroups' == 2 {
			qui replace `v_stdiffs' = "" if `v_stdiff' == .
			qui replace `v_stdiffs' = "Standard Difference" in 1
			drop `v_stdiff'
		}

		* Use a divider variable to separate headers from variables
		tempname v_divider
		qui gen `v_divider' = 0
		qui replace `v_divider' = 1 in 1
		if `numgroups' == 2 {
			list `v_rownames'-`v_stdiffs' ///
					in 1/`=`row'-1', noobs sepby(`v_divider') noheader
		}
		else  {
			list `v_rownames'-`v_group`numgroups's' ///
					in 1/`=`row'-1', noobs sepby(`v_divider') noheader
		}
	}
	
end
