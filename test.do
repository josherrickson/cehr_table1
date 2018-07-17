cls
cd "/Users/josh/repositories/contracts/cehr_table1"
cap program drop cehr_table1 string_better_round
qui do cehr_table1.ado

sysuse auto, clear
*replace headroom = 3.3
gen big = weight > 3000

// cehr_table1 "Size of car" headroom trunk big "Engine characteristics"  mpg , by(foreign) secondary(below)
cehr_table1 "Size of car" headroom trunk big "Engine characteristics" i.rep78 mpg ///
	using "~/Desktop/tmp1.xlsx", ///
		by(foreign) replace sectiondec("both") variabledec("border") countdec("bold")


cehr_table1 headroom i.rep78 i.foreign trunk, by(rep78)
cehr_table1 headroom i.rep78 i.foreign trunk using "~/Desktop/tmp2.xlsx", by(rep78) replace

