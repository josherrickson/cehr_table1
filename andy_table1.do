cap program drop andy_table1
program  andy_table1
	syntax varlist(min=2 fv) [if] [in], BY(varname)
	local numvars: word count `varlist'
	tokenize `varlist'
	
	qui levelsof `by'
	if `r(r)' < 2 {
		di "`by( )` must contain a variable with exactly two levels"
		error 148
	}
	else if `r(r)' > 2 {
		di "`by( )` must contain a variable with exactly two levels"
		error 149
	}
	
	qui putexcel set "~/Desktop/tmp", replace
	qui putexcel A1 = "Variable"
	qui putexcel A1 = "Value"
	qui putexcel C1 = "Mean"
	qui putexcel D1 = "SD/Percent"
	
	local i = 1
	local row = 2
	* Loop over all variables
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
			qui summ `varname' `if' `in'
			qui putexcel A`row' = "`varlab'"
			qui putexcel C`row' = `r(mean)'
			qui putexcel D`row' = `r(sd)'
			local ++row
		}
		else {
			* Categorical variable. Generate a table, saving the count and levels.
			qui tab `varname_noi' `if' `in', matcell(freq) matrow(rowMat)
			local total = r(N)

			qui putexcel A`row' = "`varlab'"
			
			local valuecount = rowsof(rowMat)
			forvalues vnum = 1/`valuecount' {
				* Looping over each level to produce results
							local val = rowMat[`vnum',1]
							local vl : label (`varname_noi') `val'

							local freq_val = freq[`vnum',1]

							local percent_val = `freq_val'/`total'*100

							* Macros:
							*  val = The numeric value of the level.
							*  vl = Value label of the `val`.
							*  freq_val = Count of the number of observations at level `val`.
							*  percent_val = Percentage of observations at level `val`.

							qui putexcel B`row'=("`vl'")
							qui putexcel C`row'=(`freq_val') 
							qui putexcel D`row'=(`percent_val')   
															
							local row = `row' + 1
        }
		}
			
		local ++i
	}
end

andy_table1 mpg i.foreign weight i.rep78, by(rep78)
