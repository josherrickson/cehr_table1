cap program drop andy_table1
program  andy_table1
	syntax varlist(min=1 fv) [if] [in], BY(varname) [nosd]
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
	
	
	local num1 = groups[1,1]
	local group1 : label (`by') `num1'
	local num2 = groups[2,1]
	local group2 : label (`by') `num2'
	
	
	qui putexcel set "~/Desktop/tmp", replace
	qui putexcel A1 = "Variable"
	qui putexcel B1 = "Value"
	qui putexcel C1 = "`group1'"
	qui putexcel D1 = "`group2'"
	qui putexcel E1 = "Standard Difference"
	
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
			* Extract mean and sd
			matrix b = e(b)
			scalar mean1 = b[1,1]
			scalar mean2 = b[1,2]
			qui putexcel C`row' = mean1
			qui putexcel D`row' = mean2
			
			if "`sd'" == "" {
				* This mata command moves e(V) into mata, takes the diagonal, sqrts each element,
				*  and pops it back into matrix "sd".
				mata: st_matrix("sd", sqrt(diagonal(st_matrix("e(V)"))))
				scalar sd1 = sd[1,1]
				scalar sd2 = sd[2,1]
				scalar standdiff = (mean1 + mean2)/sqrt(sd1^2 + sd2^2)
				qui putexcel C`=`row'+1' = sd1
				qui putexcel D`=`row'+1' = sd2
				qui putexcel E`row' = standdiff
			* `row` must increase by 2 due to SD 2nd row
				local row = `row' + 2
			}
			else {
				local row = `row' + 1
			}
		}
		else {
			* Categorical variable. Generate a table, saving the count and levels.
			qui tab `varname_noi' `by' `if' `in', matcell(freq) matrow(rowMat)
			* Get total by column to find percent later
			mata: st_matrix("total", colsum(st_matrix("freq")))
			local total1 = total[1,1]
			local total2 = total[1,2]
			
			qui putexcel A`row' = "`varlab'"
			
			local valuecount = rowsof(rowMat)
			forvalues vnum = 1/`valuecount' {
				* Looping over each level to produce results
				local val = rowMat[`vnum',1]
				local vl : label (`varname_noi') `val'

				local freq_val1 = freq[`vnum',1]
				local percent_val1 = `freq_val1'/`total1'
				
				local freq_val2 = freq[`vnum',2]
				local percent_val2 = `freq_val2'/`total2'

				* Macros:
				*  val = The numeric value of the level.
				*  vl = Value label of the `val`.
				*  freq_val = Count of the number of observations at level `val`.
				*  percent_val = Percentage of observations at level `val`.

				qui putexcel B`row'=("`vl'")
				qui putexcel C`row'=(`percent_val1')   
				qui putexcel D`row'=(`percent_val2')   
												
				local row = `row' + 1
        }
		}
			
		local ++i
	}
end

andy_table1 mpg trunk i.rep78, by(foreign)
