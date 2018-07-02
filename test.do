cap program drop cehr_table1
qui do cehr_table1.ado

sysuse auto, clear

cehr_table1 headroom i.rep78 i.foreign trunk using ~/Desktop/tmp.xlsx, by(foreign)
