cd "/Users/josh/repositories/contracts/cehr_table1"
cap program drop cehr_table1
qui do cehr_table1.ado

sysuse auto, clear
*replace headroom = 3.3

cehr_table1 headroom i.rep78 i.foreign trunk, by(foreign)
cehr_table1 headroom i.rep78 i.foreign trunk using "~/Desktop/tmp.xlsx", by(foreign) replace

