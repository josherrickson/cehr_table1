cap program drop cehr_table1
qui do cehr_table1.ado

sysuse auto

andy_table1 i.rep78 headroom trunk , by(foreign)
