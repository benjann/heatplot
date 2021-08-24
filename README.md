# heatplot
Stata module to create heat plots and hexagon plots

`heatplot` creates heat plots from variables or matrices. One
example of a heat plot is a two-dimensional histogram in which the
frequencies of combinations of binned Y and X are displayed as
rectangular (or hexagonal) fields using a color gradient. Another example
is a plot of a trivariate distribution where the color gradient is used to
visualize the (average) value of Z within bins of Y and
X. Yet another example is a plot that displays the contents of a matrix,
say, a correlation matrix or a spacial weights matrix, using a color
gradient.

To install `heatplot` from the SSC Archive, type

    . ssc install heatplot, replace

in Stata. The `palettes` package and, in Stata 14.2 or newer,
the `colrspace` package are required. To install these packages, type

    . ssc install palettes, replace
    . ssc install colrspace, replace

Furthermore, the `fast` option of `heatplot` of requires the `gtools` package. To 
install `gtools`, type

    . ssc install gtools, replace
    . gtools, upgrade

---

Installation from GitHub:

    . net install heatplot, replace from(https://raw.githubusercontent.com/benjann/heatplot/master/)

---

Main changes:

    24aug2021
    - improved checks for required packages and corresponding error messages

    20jul2021
    - values(label(exp)) can now be string in syntax 1; the statistic() suboption
      will be set to -first- in this case

    19jul2021
    - new [x|y]bcuts() option to cut x and y at arbitrary values (not allowed with
      hexagon)
    - option values() has been revised; new label() suboption can be used to select
      a secondary variable or matrix for the values; new transform() suboption
      transforms the values; other suboptions have been renamed
    - size(exp) is now also allowed in syntax 2 and 3, where exp is the name of a
      (mata) matrix; size() now has a statistic() suboption to set the type of
      aggregation; observations for which exp is missing are no longer excluded
      from the estimation sample
    - new -normalize- option normalizes the plotted results by dividing by the size
      of the corresponding color field
    - if [x|y]discrete is specified together with hexagon, a color field is now printed
      at each unique value (similar the behavior without option hexagon)
    - shapes of clipped hexagons were not always correct; this is fixed
    - option generate failed in syntax 2 and 3 if the current dataset was empty
      (unless -nopreserve- was specified); this is fixed
    - other than stated in the documentation, palette -hcl, viridis- was used as the 
      default palette in Stata 14.2 or newer instead of palette -viridis-; this is fixed

    13oct2020
    - option colors() did not work with color specifications that included
      quotes; this is fixed
    
    07sep2019
    - new ramp() option
    - new equations() option in syntax 3
    - heatplot could break if there were only very few observations; this is fixed
    
    21jun2019
    - a note is now displayed if there are observations outside the binning range of y and x
    - binning of x and y was erroneous at the edges if subobtion tight was specified and
      the requested binning range was smaller than the data range; this is fixed
    - undocumented idgenerate() option to store bin IDs (to confirm binning)
    
    31may2019
    - added -fast- option to use fast commands from -gtools- (-gcollapse- instead of 
      official -collapse- for aggregation; -gegen- functions to handle categorical 
      variables instead of -bysort-)
    - added faster code to write Mata matrix to data if full matrix is used
    
    25may2019
    - there was a bug in how the intervals were computed if cuts() was specified
      and did not contain @min or @max and the specified minimum cut was larger than 
      min of data or specified maximum cut wqs smaller than max of data

    20may2019
    - option -srange()- added
