cls
cd "/Users/josh/repositories/contracts/cehr_table1"
cap program drop cehr_table1 string_better_round
qui do cehr_table1.ado

sysuse auto, clear
gen big = weight > 3000
label var big "Heavy cars (%)"

cehr_table1  "Size of car" _samplesize c.headroom trunk b.big "Engine characteristics" i.rep78 mpg , ///
	by(foreign) secondary(parentheses)  adjustpv pvals
cehr_table1 "Size of car" _samplesize headroom trunk b.big "Engine characteristics" i.rep78 mpg ///
  using "~/Desktop/tmp1.xlsx", ///
    by(foreign) replace sectiondec("both") variabledec("border") pvals adjustpvals print


cehr_table1 headroom i.rep78 i.foreign trunk, by(rep78)
cehr_table1 headroom i.rep78 i.foreign trunk using "~/Desktop/tmp2.xlsx", by(rep78) replace
