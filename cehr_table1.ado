program define cehr_table1
	syntax varlist(min=1 fv) [if] [in] [using/], BY(varname) [nosd replace print] 
	
	
	* Define all temporary objects
	*		Variable names to store results
	tempvar v_rownames v_valnames v_group1 v_group2 v_stdiff 
	*		Matrices 
	tempname B SD Total Freq RowMat Groups
	
	* Ensure that the treatment variable has exactly 2 levels
	qui tab `by' `if' `in', matrow(`Groups')
	local numgroups = rowsof(`Groups')
	if `numgroups' != 2 {
		if "`if'" != "" | "`in'" != "" {
			di "`by( )` must contain a variable with exactly two levels in the subgroup"
		}
		else {
			di "`by( )` must contain a variable with exactly two levels"
		}
		if `numgroups' < 2 {
			error 148
		}
		else {
			error 149
		}
	}

	local num1 = `Groups'[1,1]
	local group1name : label (`by') `num1'
	local num2 = `Groups'[2,1]
	local group2name : label (`by') `num2'

	* Generate temporary variables which will store results
	qui gen str100 `v_rownames' = ""
	qui gen str100 `v_valnames' = ""
	qui gen `v_group1' = .
	qui gen `v_group2' = .
	qui gen `v_stdiff' = .
	

	local i = 1
	local row = 2
	* Loop over all variables
	tokenize `varlist'
	while "``i''" != "" {

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

		* A hacky way to check if user passed a categorical variable. If they did,
		* varname will be `ibn.varname`, whereas varname_noi has the ibn. stripped.
		* If they didn't, these are equivalent
		if ("`varname_noi'" == "`varname'") {
			qui mean `varname' `if' `in', over(`by')
			qui replace `v_rownames' = "`varlab'" in `row'
			* Extract mean and sd
			matrix `B' = e(b)
			local mean1 = `B'[1,1]
			local mean2 = `B'[1,2]
			qui replace `v_group1' = `mean1' in `row'
			qui replace `v_group2' = `mean2' in `row'

			if "`sd'" == "" {
				* This mata command moves e(V) into mata, takes the diagonal, sqrts each element,
				*  and pops it back into matrix "sd".
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
			* Categorical variable. Generate a table, saving the count and levels.
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
		
	if "`using'" == "" | ("`using'" != "" & "`print'" == "print") {
		list `v_rownames' `v_valnames' `v_group1' `v_group2' `v_stdiff' in 1/`=`row'-1'
	}
	
	if "`using'" != "" { 
	
		export excel `v_rownames' `v_valnames' `v_group1' `v_group2' `v_stdiff' using "`using'" in 1/`=`row'-1', `replace'
		
		putexcel set "`using'", modify
		qui putexcel A1 = "Variable"
		qui putexcel B1 = "Value"
		qui putexcel C1 = "`group1name'"
		qui putexcel D1 = "`group2name'"
		qui putexcel E1 = "Standard Difference"
	}	
	
	
end
