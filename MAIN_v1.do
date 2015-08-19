* MAIN FILE

clear all
set more off
global home "/Users/Miriam/Box Sync/TYPlocal"
global data "$home/data"
global do "$home/do"

* toggle level of occupation aggregation, 22, 94, 439
global agg 439

* clean DOT characteristics files
do "$do/readDOT"

* clean ONET characteristics files
do "$do/readONET"

* clean Census/ACS
* calculate sexratios and wage gaps by occupation-year-state, and clean data, sample selections
do "$do/readACS"


* combine ONET characteristics files
* collapse onet codes into broader categories, weighting variables as necessary
*cd $home
*do MergeONET2_v2

* Put all occupation characteristics into occ1990 codes
cd $home
*do MergeONET3 // includes 1980 DOT in 1980 census codes from ICPSR
do MergeONET4 // for the change over time ONET and DOT data, 
** including regressions on sex ratio

/*
********** ACS 2012 analysis
* cleans ACS data, saves matlab files by sex and education level
cd $home
do ACS2
* makes data files with occupation level data from census, eg. wage, sexratio, usual hours
cd $home
do ACSchar
* cleans ONET file for matlab and merges with ACS occupation level data, saves files
cd $home
do ONETmatlab
* run logit regressions, output to latex
cd $home
do Descriptives
*/



* make regression ready files at occupation-year-state level and run regressions
*cd $home
*do ACS_matlab2
* fixed effect regressions
*do shares_regressions

* Individual level census wage regressions
cd $home
do Census_ind_regressions

