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
{cmdab:cehr_table1} {anything} {ifin} [{cmd:using} {it:{help filename}}], {cmd:by}({varname}) [{it:options}]


{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Display}
{synopt :{opt di:gits(#)}}number of decimal places to display numeric values; default is 3{p_end}
{synopt :{opt perdi:gits(#)}}number of decimal places to display percent values; default is 1{p_end}
{synopt :{opt second:arystatposition(string)}}Position of secondary values; one of "None", "Parentheses" (default), "Below"{p_end}
{synopt :{opt nocat:egoricalindent}}suppresses indentation of categorical levels below variable name{p_end}

{syntab:File}
{synopt :{opt rep:lace}}overwrite existing output file{p_end}
{synopt :{opt pr:int}}print output in addition to outputting to a file{p_end}

{syntab:Decorations}
{synopt :{opt sectiondec:oration(string)}}decorations on section headers; one of "None" (default), "Bold", "Border", "Both"{p_end}
{synopt :{opt variabledec:oration(string)}}decorations on variables; one of "None" (default), "Bold", "Border", "Both"{p_end}
{synopt :{opt countl:abel(string)}}printed as variable name for count; default is "Number of patients (No.)"{p_end}
{synoptline}
{p 4 6 2}
{it:anything} may contain factor variables;; see {help fvvarlist}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
Generates a table summarizing the requested variables. Each continuous variable in {it:anything} has it's mean and
standard deviation reported at each level of the {varname} from {cmd:by()}. Each categorical variable in {it:anything}
(e.g. those prefaced by {cmd:i.}) report the percent in each category. String variables are not supported; you
can use {it:{help encode}} to convert strings to numeric variables with value labels first.

{pstd}
Row and Column names are extracted from the appropriate variable and value labels. Section names can be passed as strings
into {it:anything}. To include a row for the sample size in each group, include {it:_samplesize}. For example,

{phang2}
. cehr_table1 "Main vars" _samplesize var1 var2 "Other vars" var3 var4, by(var5){p_end}

{pstd}
If a {it:filename} is not provided with {cmd:using}, the table is printed to output. If a {it:filename} is provided,
the table are exported to the named Excel file and output is suppressed. To print alongside saving, use the
{cmd:print} option.

{pstd}
If the variable from {cmd:by()} has exactly two levels (in the subset defined by {cmd:if} and/or {cmd:in}, a
standardized difference is printed as well. If it has more than two levels, the standardized difference is
not computed.


{marker options}{...}
{title:Options}

{dlgtab:Display}
{phang}
{opt digits(#)} controls the amount of rounding that takes places and defines the number of decimal places to display
numeric values. The default is 3. For example, 7.338185 would be displayed as 7.338.{p_end}

{phang}
{opt perdigits(#)} controls the amount of rounding for only percentages. The default is 1. For example, .7349,
representing just shy of 75%, would be displayed as 73.5%.{p_end}

{phang}
{opt secondarystatposition(string)} chooses the location of secondary values. Secondary values are standard deviations
(attached to means) and percentages (attached to percents). The choices are "None", "Parenthese" and "Below".{p_end}

{pmore2}
{opt secondarystatposition("None")} suppresses these secondary stats completely.{p_end}

{pmore2}
{opt secondarystatposition("Parentheses")} affixes the secondary values after the primary values, wrapped in parentheses.
For example, "3.243 (1.221)".{p_end}

{pmore2}
{opt secondarystatposition("Below")} places the secondary values in the cell below the primary values, wrapped in
parentheses.{p_end}

{phang}
{opt nocategoricalindent} suppresses the identation of categorical values below their header; by default the values are
indented 5 spaces for clarity.{p_end}

{dlgtab:File}
{phang}
{opt replace} overwrites any existing output Excel file specified in {bf:using}.{p_end}

{phang}
{opt print} produces a table in the Stata output if it would otherwise not be printed because a file was passed
via {bf:using}. No effect if {bf:using} is not specified.{p_end}

{dlgtab:Decorations}

{phang}
{opt countlabel(string)} allows a custom label on the count row, overriding the default "Number of patients (No.)"{p_end}

{phang}
These two decoration options operate identically; on different rows of the data. {opt sectiondecoration} operates
on sections, as defined by quoted strings in {it:anything}; {opt variabledecoration} operates on each variable name (as
opposed to levels of a categorical variable).{p_end}

{pmore}The default for each is "None"; meaning no additional decoration is applied.{p_end}

{pmore}Passing "Bold" decorates the chosen cells with bold font.

{pmore}Passing "Border" adds a border underlining the chosen cells and all other cells in the same row.

{pmore}Passing "Both" applies both "Bold" and "Border".


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
{phang2}{stata cehr_table1 mpg price i.rep78 if headroom < 4 using "mytable.xlsx", by(foreign) digits(5) replace print:. cehr_table1 mpg price i.rep78 if headroom < 4 using "mytable.xlsx", by(foreign) digits(5) replace print}{p_end}

{pstd}A different table but with some decorations{p_end}
{phang2}{stata cehr_table1 "Car Size" weight headroom "Engine Characteristics" mpg i.rep78 using "mytable.xlsx", by(foreign) replace variabledecoration("Bold") sectiondecoration("Both"):. cehr_table1 "Car Size" weight headroom "Engine Characteristics" mpg i.rep78 using "mytable.xlsx", by(foreign) replace ///}{p_end}

{phang3}{stata cehr_table1 "Car Size" weight headroom "Engine Characteristics" mpg i.rep78 using "mytable.xlsx", by(foreign) replace variabledecoration("Bold") sectiondecoration("Both"):variabledecoration("Bold") sectiondecoration("Both")}{p_end}
