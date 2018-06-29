cap program drop andy_table1
program  andy_table1
	syntax varlist(min=1 fv) [if] [in], BY(varname)
	local numvars: word count `varlist'
	tokenize `varlist'
	
	qui tab `by' `if' `in', matrow(groups)
	local numgroups = rowsof(groups)
	if `numgroups' < 2 {
		di "`by( )` must contain a variable with exactly two levels"
		error 148
	}
	else if `numgroups' > 2 {
		di "`by( )` must contain a variable with exactly two levels"
		error 149
	}

	qui putexcel set "~/Desktop/tmp", replace
	qui putexcel A1 = "Variable"
	qui putexcel A1 = "Value"
	qui putexcel C1 = "Mean Group 1"
	qui putexcel D1 = "SD Group 1"
	qui putexcel E1 = "Mean Group 2"
	qui putexcel F1 = "SD Group 2"
	
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
			qui mean `varname' `if' `in', over(`by')
			qui putexcel A`row' = "`varlab'"
			matrix b = e(b)
			mata: st_matrix("sd", sqrt(diagonal(st_matrix("e(V)"))))
			scalar mean1 = b[1,1]
			scalar sd1 = sd[1,1]
			scalar mean2 = b[1,2]
			scalar sd2 = sd[2,1]
			qui putexcel C`row' = mean1
			qui putexcel D`row' = sd1
			qui putexcel E`row' = mean2
			qui putexcel F`row' = sd2
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

andy_table1 mpg, by(foreign)
