{smcl}
{* 30jan2019}{...}
{hi:help hexplot}
{hline}

{title:Title}

{pstd}{hi:hexplot} {hline 2} Command to create hexagon plots


{title:Syntax}

{pstd}
    Syntax 1: Hex plot from variables

{p 8 15 2}
    {cmd:hexplot} [{it:z}] {it:y} {it:x} {ifin} {weight}
    [{cmd:,}
    {help hexplot##opts:{it:options}}
    ]

{pmore}
    where {cmd:i.}{it:varname} is allowed for {it:y} and {it:x}

{pstd}
    Syntax 2: Hex plot from Mata matrix

{p 8 15 2}
    {cmd:hexplot} {opt m:ata(M)}
    [{cmd:,}
    {help hexplot##opts:{it:options}}
    ]

{pstd}
    Syntax 3: Hex plot from Stata matrix

{p 8 15 2}
    {cmd:hexplot} {it:matrix} [{cmd:,}
    {help hexplot##opts:{it:options}}
    ]

{marker opts}{...}
{synoptset 22}{...}
{synopthdr:options}
{synoptline}
{synopt :{opt vert:ical}}arrange hexagons vertically (the default)
    {p_end}
{synopt :{opt hor:izontal}}arrange hexagons horizontally
    {p_end}
{synopt :{opt right}}start with a right shift (the default)
    {p_end}
{synopt :{opt left}}start with a left shift
    {p_end}
{synopt :{opt even}}use even number of columns (the default)
    {p_end}
{synopt :{opt odd}}use odd number of columns
    {p_end}
{synopt :{helpb heatplot##heatopts:{it:heatplot_options}}}Syntax 1, Syntax 2, or
    Syntax 3 options of {helpb heatplot}, except {cmd:scatter()} and {cmd:hexagon()}
    {p_end}
{synoptline}

{pstd}
    {cmd:fweight}s, {cmd:aweight}s, {cmd:iweight}s, and {cmd:pweight}s are allowed with Syntax 1; see help {help weight}.


{title:Description}

{pstd}
    {cmd:hexplot} creates hexagon plots. It is implemented as a wrapper for
    {helpb heatplot}. {cmd:hexplot} is equivalent to {cmd:heatplot} with option
    {cmd:hexagon}.


{title:Options}

{phang}
    {opt vertical} arranges the hexagons vertically; this is the default.

{phang}
    {opt horizontal} arranges the hexagons horizontally. Only one of {cmd:vertical}
    and {cmd:horizontal} is allowed.

{phang}
    {opt right} starts with a right-shifted hexagon row (the default).

{phang}
    {opt left} starts with a left-shifted hexagon row. Only one of {cmd:right}
    and {cmd:left} is allowed.

{phang}
    {opt even} uses an even number of hexagon columns (the default).

{phang}
    {opt odd} uses an odd number of hexagon columns. Only one of {cmd:even}
    and {cmd:odd} is allowed. By default, each
    x-axis bin (or y-axis bin if {cmd:horizontal} has been specified) contains a
    double column of hexagons. To use a single column for the last bin and thus have
    an odd overall number of columns, specify {cmd:odd}.

{phang}
    {it:heatplot_options} are {helpb heatplot} options allowed in Syntax 1, 2, or
    3, respectively. Not allowed are options {cmd:scatter()} and {cmd:hexagon()}.


{title:Examples}

    . {stata drawnorm y x, n(10000) corr(1 .5 1) cstorage(lower) clear}
    . {stata hexplot y x}
    . {stata hexplot y x, horizontal}
    . {stata hexplot y x, size recenter}
{p 4 8 2}
    . {stata hexplot y x, statistic(count) cuts(@min(5)@max) colors(dimgray black) keylabels(, range(1))}

    . {stata sysuse auto, clear}
{p 4 8 2}
    . {stata hexplot price weight mpg, colors(plasma, intensity(.6)) p(lc(black) lalign(center)) legend(off) values(format(%9.0f)) aspectratio(1)}


{title:Author}

{pstd}
    Ben Jann, University of Bern, ben.jann@soz.unibe.ch

{pstd}
    Thanks for citing this software as follows:

{pmore}
    Jann, B. (2019). heatplot: Stata module to create heat plots and hexagon plots. Available from
    {browse "http://ideas.repec.org/c/boc/bocode/s458595.html"}.


{title:Also see}

{psee}
    Online:  help for {helpb heatplot}, {helpb colorpalette},
    {helpb twoway contour}
