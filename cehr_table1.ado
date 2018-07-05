program define cehr_table1

	******************
	***** Syntax *****
	******************
	
	syntax varlist(min=1 fv) [if] [in] [using/], BY(varname) [nosd replace print digits(integer 3)] 
	
	************************
	***** Input checks *****
	************************
	
	* Ensure that the treatment variable has exactly 2 levels
	tempname Groups
	qui tab `by' `if' `in', matrow(`Groups')
	local numgroups = rowsof(`Groups')
	if `numgroups' != 2 {
		if "`if'" != "" | "`in'" != "" {
			display as error "option {bf:by()} must contain a variable with exactly two levels in the subgroup"
		}
		else {
			display as error "option {bf:by()} must contain a variable with exactly two levels"
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
	local num1 = `Groups'[1,1]
	local group1name : label (`by') `num1'
	local num2 = `Groups'[2,1]
	local group2name : label (`by') `num2'

	*********************************
	***** Generate Storage Data *****
	*********************************
	
	* Generate temporary variables which will store results
	tempvar v_rownames v_valnames v_group1 v_group2 v_stdiff 
	qui gen str100 `v_rownames' = ""
	qui gen str100 `v_valnames' = ""
	qui gen `v_group1' = .
	qui gen `v_group2' = .
	qui gen `v_stdiff' = .

	***************************
	***** Sample Size (N) *****
	***************************
	
	qui replace `v_rownames' = "Number of Patients, No." in 2
	* Group 1
	if "`if'" == "" {
		qui count if `by' == `num1' `in'
	}
	else {
		qui count `if' & `by' == `num1' `in'
	}
	qui replace `v_group1' = r(N) in 2
	* Group 2
	if "`if'" == "" {
		qui count if `by' == `num2' `in'
	}
	else {
		qui count `if' & `by' == `num2' `in'
	}
	qui replace `v_group2' = r(N) in 2
	
	
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
			local mean1 = `B'[1,1]
			local mean2 = `B'[1,2]
			qui replace `v_group1' = `mean1' in `row'
			qui replace `v_group2' = `mean2' in `row'

			if "`sd'" == "" {
				* This mata command moves e(V) into mata, takes the diagonal, 
				* sqrts each element,  and pops it back into matrix "sd".
				mata: st_matrix("`SD'", sqrt(diagonal(st_matrix("e(V)"))))
				local sd1 = `SD'[1,1]
				local sd2 = `SD'[2,1]
				local standdiff = (`mean1' + `mean2')/sqrt(`sd1'^2 + `sd2'^2)
				qui replace `v_group1' = `sd1' in `=`row'+1'
				qui replace `v_group2' = `sd2' in `=`row'+1'
				qui replace `v_stdiff' = `standdiff' in `row'
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
			local total1 = `Total'[1,1]
			local total2 = `Total'[1,2]

			qui replace `v_rownames' = "`varlab'" in `row'

			local valuecount = rowsof(`RowMat')
			forvalues vnum = 1/`valuecount' {
				* Looping over each level to produce results
				local val = `RowMat'[`vnum',1]
				local vl : label (`varname_noi') `val'

				local freq_val1 = `Freq'[`vnum',1]
				local percent_val1 = `freq_val1'/`total1'

				local freq_val2 = `Freq'[`vnum',2]
				local percent_val2 = `freq_val2'/`total2'

				* Macros:
				*  val = The numeric value of the level.
				*  vl = Value label of the `val`.
				*  freq_val = Count of the number of observations at level `val`.
				*  percent_val = Percentage of observations at level `val`.

				qui replace `v_valnames' = "`vl'" in `row'
				qui replace `v_group1' = `percent_val1' in `row'
				qui replace `v_group2' = `percent_val2' in `row'

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
		tempvar v_group1s v_group2s v_stdiffs v_group1r v_group2r v_stdiffr
		qui tostring `v_group1' `v_group2' `v_stdiff', ///
			gen(`v_group1r' `v_group2r' `v_stdiffr') force format("%15.`digits'fc")
		qui destring `v_group1r' `v_group2r' `v_stdiffr', replace
	
		export excel `v_rownames' `v_valnames' `v_group1r' `v_group2r' `v_stdiffr' ///
			using "`using'" in 1/`=`row'-1', `replace'
		
		putexcel set "`using'", modify
		qui putexcel A1 = ("Variable")
		qui putexcel B1 = ("Value")
		qui putexcel C1 = ("`group1name'")
		qui putexcel D1 = ("`group2name'")
		qui putexcel E1 = ("Standard Difference")
		putexcel A2:A`row', nformat(0.###) // NOT WORKING
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
		tempvar v_group1s v_group2s v_stdiffs
		qui tostring `v_group1' `v_group2' `v_stdiff', ///
			gen(`v_group1s' `v_group2s' `v_stdiffs') force format("%15.`digits'fc")

		* This is a correction to remove trailing 0's if 
		*  the value has 0-2 non-zero decimals (since by
		*  default we're printing 3.
		if `digits' > 0 {
			* If `digits` is 0, we don't need to do this obviously.
			foreach k of numlist `=`digits'-1'/0 {
				* This works by creating new string variables of sharper rounding first...
				tempvar  v_group1tmp v_group2tmp v_stdifftmp inctmp
				cap drop `v_group1tmp' `v_group2tmp' `v_stdifftmp'
				qui tostring `v_group1' `v_group2' `v_stdiff', ///
					gen(`v_group1tmp' `v_group2tmp' `v_stdifftmp') force format("%15.`k'fc")
				* ... then, to avoid issues with numeric precision, generating a tmp
				*  variable which basically moves the decimal over the same number of 
				*  places ...
				cap drop `inctmp'
				qui gen `inctmp' = 10^`k'*`v_group1'
				* ... and if the new variable is an integer (e.g. with k = 0, 1 is 
				*  an integer. With k = 1, 2.3 is an integer [since 10*2.3 = 23])
				*  then it replaces the string with the sharper rounded version.
				qui replace `v_group1s' = `v_group1tmp' if mod(`inctmp',1) == 0
				cap drop `inctmp'
				qui gen `inctmp' = 10^`k'*`v_group2'
				qui replace `v_group2s' = `v_group2tmp' if mod(`inctmp',1) == 0
				cap drop `inctmp'
				qui gen `inctmp' = 10^`k'*`v_stdiff'
				qui replace `v_stdiffs' = `v_stdifftmp' if mod(`inctmp',1) == 0
				* This whole bit just helps more closely mimic what Excel output
				*  will look like since Excel supports the proper format (up to 3
				*  decimals as needed, as opposed to Stata which only supports an
				*  exact number of decimals [except in `g` format, which may truncate 
				*  even worse just to fit the total width]).
			}
		}

		* Replace missing "."'s with blanks
		qui replace `v_group1s' = "" if `v_group1' == .
		qui replace `v_group2s' = "" if `v_group2' == .
		qui replace `v_stdiffs' = "" if `v_stdiff' == .

		qui replace `v_group1s' = "`group1name'" in 1
		qui replace `v_group2s' = "`group2name'" in 1
		qui replace `v_stdiffs' = "Standard Difference" in 1

		* Use a divider variable to separate headers from variables
		tempname v_divider
		qui gen `v_divider' = 0
		qui replace `v_divider' = 1 in 1
		list `v_rownames' `v_valnames' `v_group1s' `v_group2s' `v_stdiffs' ///
				in 1/`=`row'-1', noobs sepby(`v_divider') noheader
	}
	
end
