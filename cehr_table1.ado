program define cehr_table1
	preserve

	******************
	***** Syntax *****
	******************
	
	syntax anything [if] [in] [using/],  ///
		BY(varname)                                 ///
		[	REPlace 																	///
			SECONDarystatposition(string)							///
			PRint 																		///
			DIgits(integer 2) 												///
			PERDIgits(integer 1)											///
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
	
	* Ensure `secondarypos` is proper
	if "`secondarystatposition'" == "" {
		local secondarystatposition "parentheses"
	}
	if !inlist("`secondarystatposition'", "below", "Below", "Parentheses", "parentheses", "none", "None") {
		display as error `"option {bf:{ul:seconda}rystatposition()} must contain either "none", "parentheses" or "below""'
		exit
	}
	local second = strlower(substr("`secondarystatposition'", 1, 5))

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
		tempvar v_mean`n' v_secondary`n'
		qui gen `v_mean`n'' = .
		if "`second'" != "below" {
			* If we're using "below" for the secondary, no need for `v_secondary'
			qui gen `v_secondary`n'' = .
		}
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
		qui replace `v_mean`n'' = r(N) in 2
	}
	
	
	* A few temporary matrices to use inside the loop
	tempname B SD Total Count RowMat 

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
			
		* Check if we have a variable name. If not, we've got a section header.
		capture confirm variable `varname_noi'
		if !_rc {
		
			* Extract variable label, warning as needed if not provided.
			local varlab: var label `varname_noi'
			if "`varlab'" == "" {
				display as error "Variable {bf:`varname_noi'} does not have a label, falling back to variable name."
				local varlab "`varname'"
			}

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
					qui replace `v_mean`n'' = `mean`n'' in `row'
				}

				* This mata command moves e(V) into mata, takes the diagonal, 
				* sqrts each element, multiplyes by sqrt(n) to move from SE to SD,
				* and pops it back into matrix "sd".
				mata: st_matrix("`SD'", sqrt(diagonal(st_matrix("e(V)")))*sqrt(st_numscalar("e(N)")))
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
				if `numgroups' == 2 {
					local standdiff = (`mean1' + `mean2')/sqrt(`sd1'^2 + `sd2'^2)
					qui replace `v_stdiff' = `standdiff' in `row'
				}
				if "`second'" == "below" {
					* Skipping down an extra row to account for SD
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
				qui tab `varname_noi' `by' `if' `in', matcell(`Count') matrow(`RowMat')
				* Get total by column to find percent later
				mata: st_matrix("`Total'", colsum(st_matrix("`Count'")))
				forvalues n = 1/`numgroups' {
					local total`n' = `Total'[1,`n']
				}

				qui replace `v_rownames' = "`varlab'" in `row'
				local row = `row' + 1

				local valuecount = rowsof(`RowMat')
				forvalues vnum = 1/`valuecount' {
					* Looping over each level to produce results
					local val = `RowMat'[`vnum',1]
					local vl : label (`varname_noi') `val'
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
		}
		else {
			qui replace `v_rownames' = "__sec__`varname'" in `row'
			local row = `row' + 1
		}

		local ++i
	}
	
	****************************
	***** Restructure Data *****
	****************************
	
	
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
	if `numgroups' == 2 {
		string_better_round `v_stdiff', digits(`digits')
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
		
		if `numgroups' == 2 {
			qui replace `v_stdiff' = "" if `v_stdiff' == "."
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
		if `numgroups' == 2 {
			qui replace `v_stdiff' = "" if `v_stdiff' == "."
		}
	}
	
	

	*********************************
	***** Generate Excel Output *****
	*********************************
	
	* Only if passed `using`
	if "`using'" != "" { 
		
		* Merge variable & value names with indenting
		tempvar v_rownamestmp
		qui gen `v_rownamestmp' = `v_rownames'
		qui replace `v_rownamestmp' = "     " + `v_valnames' if `v_valnames' != ""
		
		* Write the main data out to excel
		export excel `v_rownamestmp' `v_mean1'-`v_mean`numgroups'' `v_stdiff' ///
			using "`using'" in 1/`=`row'-1', `replace'
		
		* Add nice formatting to the file
		putexcel set "`using'", modify
		qui putexcel A1 = ("Variable")
		forvalues n = 1/`numgroups' {
			qui putexcel `=word(c(ALPHA), `=`n'+1')'1 = "`group`n'name'"
		}
		if `numgroups' == 2 {
			* Don't need to worry about any other place for this; only used with 2 groups
			qui putexcel D1 = ("Standard Difference")
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
		if `numgroups' == 2 {
			qui replace `v_stdiff' = "Standard Difference" in 1
		}

		replace `v_rownames' = upper(regexr(`v_rownames', "^__sec__", "")) ///
			if regexm(`v_rownames', "^__sec__") == 1
		
		* Use a divider variable to separate headers from variables
		tempname v_divider
		qui gen `v_divider' = 0
		qui replace `v_divider' = 1 in 1
		if `numgroups' == 2 {
			list `v_rownames'-`v_stdiff' ///
					in 1/`=`row'-1', noobs sepby(`v_divider') noheader
		}
		else  {
			list `v_rownames'-`v_group`numgroupss' ///
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
