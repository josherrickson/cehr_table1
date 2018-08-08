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
{synopt :{opt pdi:gits(#)}}number of decimal places to display p-values values; default is 3{p_end}
{synopt :{opt second:arystatposition(string)}}Position of secondary values; one of "None", "Parentheses" (default), "Below"{p_end}
{synopt :{opt nocat:egoricalindent}}suppresses indentation of categorical levels below variable name{p_end}
{synopt :{opt nostddiff}}suppresses display of standardized differences{p_end}
{synopt :{opt pv:als}}reports p-values for significance between groups (when there are two groups){p_end}
{synopt :{opt adjustpv:als}}performs Bonferroni correction on pvalues requetsed via {opt pvals}{p_end}

{syntab:File}
{synopt :{opt rep:lace}}overwrite existing output file{p_end}
{synopt :{opt pr:int}}print output in addition to outputting to a file{p_end}

{syntab:Decorations}
{synopt :{opt sectiondec:oration(string)}}decorations on section headers; one of "None" (default), "Bold", "Border", "Both"{p_end}
{synopt :{opt variabledec:oration(string)}}decorations on variables; one of "None" (default), "Bold", "Border", "Both"{p_end}
{synopt :{opt countl:abel(string)}}printed as variable name for count; default is "Number of patients (No.)"{p_end}
{synoptline}
{p 4 6 2}
{it:anything} may contain factor variables; see {help fvvarlist}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
Generates a table summarizing the requested variables. Each continuous variable in {it:anything} has it's mean and
standard deviation reported at each level of the {varname} from {cmd:by()}. Each binary or categorical variable in {it:anything}
(e.g. those prefaced by {cmd:i.}) reports the count and percent in each category. String variables are not supported; you
can use {it:{help encode}} to convert strings to numeric variables with value labels first. (See {bf:Specifying Variables} below.)

{pstd}
Row and Column names are extracted from the appropriate variable and value labels.

{pstd}
If a {it:filename} is not provided with {cmd:using}, the table is printed to output. If a {it:filename} is provided,
the table are exported to the named Excel file and output is suppressed. To print alongside saving, use the
{cmd:print} option.

{pstd}
If the variable from {cmd:by()} has exactly two levels (in the subset defined by {cmd:if} and/or {cmd:in}, a
standardized difference is printed as well. If it has more than two levels, the standardized difference is
not computed.

{marker specification}{...}
{title:Specifying Variables}

{pstd}
In general, {it:anything} accepts a {varlist}, producing an output table in the same order. It also accepts some advanced options:

{pstd}
{bf:Section headers} are identified by anything which is not a proper variable. You should enclose these in quotes. (Technically only
necessary for multi-word section headers, but best practice for one-word as well.)

{pstd}
The {bf:sample size} can be included by including a special term, {it:_samplesize}. Refer to option {opt countlabel} to specify the label
attached to this.

{pstd}
{bf:Categorical variables} can be identified by a prefix of {it:i.}, then for each level of the category, the number and percent
are displayed.

{pstd}
{bf:Binary variables} can be identified by a prefix of {it:b.}. These should be variables taking on values of only 0 and 1 (and
potentially any missing), where the reported results are the number and percent of rows with a 1 response. Standardized differences
will be reported if the grouping variable has 2 levels.

{pstd}
{bf:Continuous variables} are identified without any prefix, or you can use the prefix {it:c.} for clarity. Means and standard deviations
will be reported for these. Standardized differences will be reported if the grouping variable has 2 levels.

{pstd}
For example,

{phang2}
. cehr_table1 "Main Vars" c.var1 _samplesize  var2 "Other Vars" b.var3 i.var4, by(var5){p_end}

{pstd}
This would produce a table with a two sections, Main Vars and Other Vars. {it:var1} and {it:var2} would be reported as continuous (means and
standard deviations) with the sample size between them. {it:var3} is binary with reported count and percent, and {it:var4} is categorical,
reporting one row per level of {it:var4} with its count and percent.

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
{opt pdigits(#)} controls the amount of rounding for only p-values. The default is 3. For example, 0.0349 would be displayed as 0.035. Ignored if {opt pvals} is not requested.{p_end}

{phang}
{opt secondarystatposition(string)} chooses the location of secondary values. Secondary values are standard deviations
(attached to means) and percentages (attached to counts). The choices are "None", "Parenthese" and "Below".{p_end}

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
indented 5 spaces for clarity. Only used if the using {bf:using} to output an excel file.{p_end}

{phang}
{opt nostddiff} suppresses the calculation and display of standardized differences within continuous variables. This
is ignored if the variable from {bf:by()} has more than two levels as standardized differences are displayed
only when there are two groups.{p_end}

{phang}
{opt pvals} computes and reports p-values comparing the groups. For continuous variables, this is a two-sample t-test
of means; for categorical variables, this is a chi-square test for independence; for binary variables, this is a z-test
for proportions . This is ignored if the variable from {bf:by()} has more than two levels.{p_end}

{phang}
{opt adjustpvals} adjusts the p-values with a Bonferroni correction; multiplying each p-value by the number of p-values reported.
Ignored if {opt pvals} is not specified.{p_end}


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
