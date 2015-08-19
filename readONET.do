cd "$data/ONET/data/net19sas"

*-------------------------------------------------------------------------------
* VERSION 19 ONET
*-------------------------------------------------------------------------------
* FILES TO READ IN: abilities, activities, anchors, context, contxcat, contmodl, 
* education, interests, knowledge, skills, styles, STEM
use abilities, clear
append using activities
append using anchors
append using context
append using contxcat
append using contmodl
append using education
append using interests
append using knowledge
replace Element_Name = "Mathematics_kn" if Element_Name == "Mathematics"
append using skills
append using styles

* make sure all variables were updated after 2000
g year = substr(Date,4,7)
destring year, replace
egen minyear = min(year)
su minyear
local old = r(min) // make note if data has not been updated since 1998 release
if `old' < 2000 {
g oldflag = year < `old'
stop
}
* everything is updated 2002 or later!


keep O_NET_SOC_Code Element_Name Scale_ID Data_Value year Category
rename O_NET_SOC_Code onetcode
drop if onetcode == ""
drop if Category == "n/a"
destring Category, replace
g value = Category*Data_Value
byso onetcode Element_Name: g sumval = sum(value)
byso onetcode Element_Name: egen maxval = max(sumval)
replace maxval = maxval/100
keep if Category == 1 | Category == .

replace Element_Name = Scale_ID + Element_Name if Scale_ID == "IM"
replace Element_Name = Scale_ID + Element_Name if Scale_ID == "LV"
replace Element_Name = "LV" + Element_Name if Scale_ID == "LC" // level of competition is also on 7 point scale like LV

preserve
byso Element_Name: keep if _n == 1
save onet_done_tomerge, replace // to check what variables are consistent across 1998 and 2013
restore
save onet_done, replace



*-------------------------------------------------------------------------------
* VERSION 1.0 1998 ONET
*-------------------------------------------------------------------------------
* want to predict data people things date reason math language goe2 strengthnum in DOT1991
cd "$data/ONET/data/net98sas"
import excel using RENAME_all, clear
drop C
g todrop = strpos(B,"-") if strpos(B,"-") > 0
replace todrop = 100 if todrop == .
replace B = substr(B, 1,todrop)
drop todrop
g BB = reverse(B)
replace BB = substr(BB, 2, .)
drop B
g B = reverse(BB)
drop BB
replace B = rtrim(B)
g Scale_ID = substr(A,4,2)
keep if inlist(Scale_ID,"LV","IM","LC")==1
g Element_Name = Scale_ID+B
replace Element_Name = "LV" + B if Scale_ID == "LC"
rename A VAR_NAME
duplicates tag VAR_NAME, g(blah)
byso VAR_NAME: drop if blah>0 & _n == 1
drop blah
merge 1:m VAR_NAME using means
keep if _m == 3
drop if Element_Name == ""
keep VAR_NAME Element_Name onetcode value
* mathematics knowledge and skills variables have same names
replace Element_Name = "IMMathematics_kn" if Element_Name == "IMMathematics" & strpos(VAR_NAME,"K")==1
replace Element_Name = "LVMathematics_kn" if Element_Name == "LVMathematics" & strpos(VAR_NAME,"K")==1
*replace Element_Name = Element_Name + "_kw" if strpos(VAR_NAME,"K")==1
isid onetcode Element_Name
save onet_done98, replace


byso Element_Name: keep if _n == 1
merge 1:1 Element_Name using "$data/ONET/data/net19sas/onet_done_tomerge"
keep if _m == 3
keep Element_Name
save match98, replace // this is list of variables measured consistently in 1998 and 2013 with consistent names

***** now reshape the data using only the match variables: 1998
use onet_done98, clear
merge m:1 Element_Name using match98
keep if _m == 3
drop _m
replace Element_Name = subinstr(Element_Name, " ", "_", .)
replace Element_Name = subinstr(Element_Name, ",", "_", .)
drop VAR_NAME
ren value v
replace Element_Name = substr(Element_Name, 1, 30)
reshape wide v, i(onetcode) j(Element_Name) string
ren v* *
g year = 1998
save onet_clean98, replace

***** now reshape the data using only the match variables: 2013
cd "$data/ONET/data/net19sas"
use onet_done, clear
merge m:1 Element_Name using "$data/ONET/data/net98sas/match98"
keep if _m == 3
drop _m
replace Element_Name = subinstr(Element_Name, " ", "_", .)
replace Element_Name = subinstr(Element_Name, ",", "_", .)
keep onetcode Element_Name Data_Value
ren Data_Value v
replace Element_Name = substr(Element_Name, 1, 30)
reshape wide v, i(onetcode) j(Element_Name) string
ren v* *
g year = 2013
save onet_clean13, replace
append using "$data/ONET/data/net98sas/onet_clean98" // now have file with 1998 and 2013 files stacked vertically
merge 1:1 onetcode using "$data/DOT/data/DOT1991clean98"  // merge in DOT data to 1998 data
keep if _m == 3 | year == 2013
drop _m
cd "$data/DOT/data"
rename * r*
rename ronetcode onetcode
rename r*1991 *1991
rename ryear year
rename reason1991 qreason1991
save regfile_onet_DOT, replace


** predice 2013 values of DOT variables
use  regfile_onet_DOT, clear
foreach var in data people things qreason math language goe2 strengthnum {
qui reg `var'1991 r*
disp("`var'")
disp(e(r2))
predict `var'2013
su `var'*
}
keep if year == 2013
** bring in 1991 data on RHS of 2013 data
merge 1:1 onetcode using DOT1991clean, update
keep if _m == 4
drop _m
save onet_DOT, replace

** bring in 1998 data on RHS of 2013 data
use "$data/ONET/data/net98sas/onet_clean98", clear
ren onetcode onetcode1998
merge 1:m onetcode1998 using xwalkDOT98
keep if _m == 3
drop _m onetcode1998 xwalk
ren * i*
ren idotcode dotcode
collapse (mean) i*, by(dotcode)
ren i* *

merge 1:m dotcode using xwalkDOT10
keep if _m == 3
drop _m dotcode DOTTitle ONETTitle
ren * i*
ren ionetcode onetcode
collapse (mean) i*, by(onetcode)
ren i* *9
merge 1:1 onetcode using onet_DOT
keep if _m == 3
drop _m
ren r* *2
merge 1:m onetcode using xwalkDOT10
keep if _m ==3
 drop _m
 order *, alpha


*** DONE!
ren *2013 *2
ren *1991 *9

save onet_DOT_all, replace

** examine
/*
cap program drop lookvar
program lookvar
args var cut
br `var'* *Title  if abs(`var'2-`var'9) > `cut' & `var'2 != . & `var'9 !=.
end

sort ONETTitle
lookvar math 1

lookvar data 1
lookvar  IMAnalyzing_Data_or_Information 1

lookvar strengthnum 1
lookvar IMDynamic_Strength 1

lookvar people 1
lookvar IMAssisting_and_Caring_for_Othe 1

lookvar IMInteracting_With_Computers 1
*/

* collapse by onetcode


* Get rid of detail by taking off digits
* description of structure in soc_structure2010.xls

g occsoc = onetcode
if $agg == 22 {
* 2 digits "Major Group" = 22 occupations
replace occsoc = substr(occsoc, 1, length(occsoc) - 8)
replace occsoc = subinstr(occsoc, "-", "", .)
}
else if $agg == 94 {
* 3 digits "Minor Group" = 94 occupations
replace occsoc = substr(occsoc, 1, length(occsoc) - 6)
replace occsoc = subinstr(occsoc, "-", "", .)
}
else if $agg == 439 {
* 5 digits "Broad Group" = 439 occupations
replace occsoc = substr(occsoc, 1, length(occsoc) - 4)
replace occsoc = subinstr(occsoc, "-", "", .)
}

drop if occsoc == ""
drop onetcode ONETTitle DOTTitle

ren * c*
ren coccsoc occsoc
collapse (mean) c* , by(occsoc)
ren c* *

*replace STEM = 0 if STEM == .

g match = occsoc
destring match, replace
save onet_tomerge$agg, replace


*** get crosswalk for occsoc codes censored with XX in ACS data
* ACS has agreggated and replaced detail with X, problem for 439 or greater!
cd "$data/ACS/data"
import excel using ACSoccsoccodes, clear sheet("Sheet3")
rename A occsoc
tostring B, g(match2)
tostring C, g(match3)
tostring D, g(match4)
tostring E, g(match5)
drop B C D E F G
foreach var of varlist * {
if $agg == 439 {
replace `var' = substr(`var', 1, length(`var') - 1)
}
destring `var', replace
}
byso occsoc: drop if occsoc == "51511" & _n ==1
reshape long match, i(occsoc) j(thing)
drop thing
drop if match == .
save occsocXX$agg, replace

cd "$data/DOT/data"
merge m:1 match using onet_tomerge$agg
drop _m match
ren * c*
ren coccsoc occsoc
collapse (mean) c* , by(occsoc)
ren c* *
* round categories that were weighted
*replace edreq = round(edreq)
*replace STEM = round(STEM)

save onet_tomerge3_$agg, replace  // file with onetcode






/*
reshape wide Data_Value year, i(onetcode Element_Name) j(Scale_ID) string
rename Data_ValueIM IM
rename Data_ValueLV LV
replace Element_Name = subinstr(Element_Name, " ", "_", .)
replace Element_Name = subinstr(Element_Name, "-", "_", .)
replace Element_Name = substr(Element_Name, 1, 15)
reshape wide IM LV, i(onetcode) j(Element_Name) string
drop yearIM
ren yearLV yearab // both are same
g year = 2013
save abilities_done, replace


use context, clear
makeyear
keep O_NET_SOC_Code Element_Name Data_Value Category year
rename O_NET_SOC_Code onetcode
* parse down for now
*keep if Element_Name == "Contact With Others" | Element_Name == "Level of Competition" | Element_Name == "Time Pressure" 

drop if Category == "n/a"
*replace Category = ".n" if Category == "n/a"
destring Category, replace
* data values are percent choosing 1-5 on Likert scale. take weighted average as value
g value = Category*Data_Value
byso onetcode Element_Name: g sumval = sum(value)
byso onetcode Element_Name: egen maxval = max(sumval)
replace maxval = maxval/100
keep if Category == 1
keep onetcode year Element_Name maxval

replace Element_Name = subinstr(Element_Name, " ", "_", .)
replace Element_Name = subinstr(Element_Name, "-", "_", .)
replace Element_Name = subinstr(Element_Name, ",", "_", .)
replace Element_Name = subinstr(Element_Name, "'", "_", .)
replace Element_Name = subinstr(Element_Name, "___", "_", .)
replace Element_Name = subinstr(Element_Name, "__", "_", .)
replace Element_Name = substr(Element_Name, 1, 20)

rename Element_Name context
rename maxval freq
drop if context == "Exposed_to_Hazardous"
reshape wide freq, i(onetcode) j(context) string
ren freq* *
rename year yearcon
g year = 2013
save context_done, replace

/*
rename Data_Value p
replace Category  = "na" if Category == "n/a"
replace Category  = "I" if Category == "1"
replace Category  = "II" if Category == "2"
replace Category  = "III" if Category == "3"
replace Category  = "IV" if Category == "4"
replace Category  = "V" if Category == "5"
reshape wide p, i(onetcode Element_Name) j(Category) string
replace Element_Name = subinstr(Element_Name, " ", "_", .)
replace Element_Name = subinstr(Element_Name, "-", "_", .)
replace Element_Name = subinstr(Element_Name, ",", "_", .)
replace Element_Name = subinstr(Element_Name, "'", "_", .)
replace Element_Name = substr(Element_Name, 5, 20)
*/


use education, clear
makeyear
keep O_NET_SOC_Code Element_Name Data_Value Category year
rename O_NET_SOC_Code onetcode
* drop training and experience for now
keep if Element_Name == "Required Level of Education"
destring Category, replace
g value = Category*Data_Value
byso onetcode Element_Name: g sumval = sum(value)
byso onetcode Element_Name: egen maxval = max(sumval)
replace maxval = maxval/100
rename maxval educ
g education = round(educ)
keep if Category == 1
keep onetcode educ* year

* recode to match ACS categories
g edreq = education
recode edreq 3 = 2
recode edreq 4 = 3
recode edreq 5 = 4
recode edreq 6 = 5
recode edreq 7 = 6
recode edreq 8 = 7
recode edreq 9 = 7
recode edreq 10 = 6
recode edreq (11 = 8) (12=8)
la def ed 1 "less than HS" 2 "HS" 3 "some college" 4 "associates" 5 "Bachelor" 6 "Professional" 7 "Master" 8 "Doctorate"
la val edreq ed 

ren year yeared
g year = 2013
save education_done, replace


**** Indicator of STEM discipline (and category if desired)
import excel using All_STEM_Disciplines, clear sheet("Sheet1")
rename A onetcode
drop B C
g STEM = 1
save STEM, replace


**** Get date last updated
import excel using Updated_Data, sheet("Sheet1") clear firstrow
save onet_update_date, replace






forval x=0/9 {
replace B = subinstr(B,"`x'","",.)
}
replace B = subinstr(B,".","",.)
replace B = subinstr(B, " ", "_", .)
replace B = subinstr(B, "-", "_", .)
replace B = subinstr(B, ",", "_", .)
replace B = subinstr(B, "'", "_", .)
replace B = subinstr(B, "___", "_", .)
replace B = subinstr(B, "__", "_", .)
replace B = substr(B, 1, 20)
g prefix = "LV" if strpos(A,"LV")>0
replace prefix = "IM" if strpos(A,"IM")>0
g var = prefix+B
drop B prefix
rename A VAR_NAME
duplicates tag VAR_NAME, g(blah)
byso VAR_NAME: drop if blah>0 & _n == 1
drop blah
save rename_all, replace

cd $home/ONET/net98sas
* work context
use means, clear
merge m:1 VAR_NAME using rename_all
keep if _m == 3 
drop _m
reshape wide value, i(onetcode) j(var)

/*


*** make RENAME files, to rename all 1998 variables to match 2013 names
import excel using RENAME_A, clear
drop if strpos(A,"IM")>0
g BB = reverse(B)
replace BB = subinstr(BB,"_","",1)
drop B
g B = reverse(BB)
drop BB
g thing = "LV"
g newthing = thing + B
replace newthing = substr(newthing, 1, 17)
keep A newthing
save RENAME_A, replace

import excel using RENAME_W, clear
forval x=0/9 {
replace B = subinstr(B,"`x'","",.)
}
replace B = subinstr(B,".","",.)
replace B = subinstr(B, " ", "_", .)
replace B = subinstr(B, "-", "_", .)
replace B = subinstr(B, ",", "_", .)
replace B = subinstr(B, "'", "_", .)
replace B = subinstr(B, "___", "_", .)
replace B = subinstr(B, "__", "_", .)
replace B = substr(B, 1, 20)
save RENAME_W, replace

******************************* GET 1998 DATA
cd $home/ONET/net98sas
* work context
use means_wc, clear
use means_gw, clear
do $home/rename_onet98_W
g year = 1998
save means_wc_done, replace

* abilities, predict reason math language
use means_ab, clear
do $home\rename_onet98
keep onetcode LV*
g year = 1998
append using $home\ONET\abilities_done

* Interests: I

* task categories/ general tasks= G (taskrating


save means_ab_done, replace

merge 1:m onetcode1998 using $home\DOT\DOT1991clean98
ren onetcode1998 onetcode
reg math IMMathematical_Re LVMathematical_Re
reg math *1998

*********
use means, clear



