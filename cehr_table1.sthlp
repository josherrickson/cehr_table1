{smcl}
{* *! version 0.0.1 06jul2018}{...}
{findalias asfradohelp}{...}
{vieweralsosee "" "--"}{...}
{vieweralsosee "[R] help" "help help"}{...}
{viewerjumpto "Syntax" "fencode##syntax"}{...}
{viewerjumpto "Description" "fencode##description"}{...}
{viewerjumpto "Options" "regress##options"}{...}
{viewerjumpto "Examples" "fencode##examples"}{...}

{p2colset 1 16 18 2}{...}
{p2col:{bf:cehr_table1} {hline 2}}Produces a Table 1 for CEHR manuscripts{p_end}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:cehr_table1} {varlist} {ifin} [{cmd:using} {it:{help filename}}], {cmd:by}({varname}) [{it:options}]


{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Display}
{synopt :{opt nosd}}suppress display of standard errors and standardized differences{p_end}
{synopt :{opt di:gits(#)}}number of decimal places to display; default is 3.{p_end}

{syntab:File}
{synopt :{opt rep:lace}}overwrite existing output file{p_end}
{synopt :{opt pr:int}}print output in addition to outputting to a file{p_end}
{synoptline}
{p 4 6 2}
{it:varlist} may contain factor variables;; see {help fvvarlist}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
Generates a table summarizing the requested variables. Each continuous variable in {varlist} has it's mean and
standard deviation reported at each level of the {varname} from {cmd:by()}. Each categorical variable in {varlist}
(e.g. those prefaced by {cmd:i.}) report the percent in each category. String variables are not supported; you
can use {it:{help encode}} to convert strings to numeric variables with value labels first.

{pstd}
Row and Column names are extracted from the appropriate variable and value labels.

{pstd}
If a {filename} is not provided with {cmd:using}, the table is printed to output. If a {filename} is provided,
the table are exported to the named Excel file and output is suppressed. To print alongside saving, use the
{cmd:print} option.

{pstd}
If the variable from {cmd:by()} has exactly two levels (in the subset defined by {cmd:if} and/or {cmd:in}, a
standardized difference is printed as well. If it has more than two levels, the standardized difference is
not computed.


{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{stata sysuse auto:. sysuse auto}{p_end}

{pstd}Basic table, printed to output{p_end}
{phang2}{stata cehr_table1 mpg price i.rep78, by(foreign):. cehr_table1 mpg price i.rep78, by(foreign)}{p_end}

{pstd}Decrease the amount of rounding{p_end}
{phang2}{stata cehr_table1 mpg price i.rep78, by(foreign) digits(5):. cehr_table1 mpg price i.rep78, by(foreign) digits(5)}{p_end}

{pstd}On a subset of the data, save to an excel file{p_end}
{phang2}{stata cehr_table1 mpg price i.rep78 if headroom < 4 using "mytable.xlsx", by(foreign) digits(5):. cehr_table1 mpg price i.rep78 if headroom < 4 using "mytable.xlsx", by(foreign) digits(5)}{p_end}

{pstd}As above, but print the output as well as saving to the file{p_end}
{phang2}{stata cehr_table1 mpg price i.rep78 if headroom < 4 using "mytable.xlsx" replace print, by(foreign) digits(5):. cehr_table1 mpg price i.rep78 if headroom < 4 using "mytable.xlsx", by(foreign) digits(5) replace print}{p_end}
