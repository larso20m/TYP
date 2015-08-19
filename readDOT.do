
cd "$data/DOT/data"

*********************************************** GET DOT 1991 data
import excel using DOT1991, firstrow clear
tab date
g new = date != 77
replace data = subinstr(data,"S","",.)
replace data = subinstr(data,"N","",.)
destring data, replace
replace people = subinstr(people,"S","",.)
replace people = subinstr(people,"N","",.)
destring people, replace
replace things = subinstr(things,"S","",.)
replace things = subinstr(things,"N","",.)
destring things, replace
/* first two digits of GOE codes
01 Artistic         05 Mechanical         09 Accommodating
02 Scientific       06 Industrial         10 Humanitarian
03 Plants-Animals   07 Business Detail    11 Leading-Influencing
04 Protective       08 Selling            12 Physical Performing
*/
tostring goe, replace
g goe2 = substr(goe,-6,2)
replace goe2 = substr(goe,-5,1) if goe2 == ""
destring goe2, replace
*g goe2 = substr(goe,1,2)
* Strength “Sedentary, Light, Medium, Heavy, and Very Heavy”
g strengthnum = .
replace strengthnum = 1 if strength == "S"
replace strengthnum = 2 if strength == "L"
replace strengthnum = 3 if strength == "M"
replace strengthnum = 4 if strength == "H"
replace strengthnum = 5 if strength == "V"

global DOTvars data people things date reason math language goe2 strengthnum

save DOT1991, replace

************************************************ get DOT1991- ONET1998 crosswalk
* http://www.xwalkcenter.org/index.php/component/content/article/9-uncategorised/87-o-net-directory
use "$data/ONET/data/net98sas/xwalk", clear
keep if xwalk == "DOT"
ren onetcode onetcode1998
ren xwalkcd dotcode
destring dotcode, replace
save xwalkDOT98, replace

*********************************************** get DOT1991 - ONET2010 crosswalk
* http://www.xwalkcenter.org/index.php/component/content/article/83-onetinfo/109-onetsup
use onetxdot, clear
rename DOTCode dotcode
rename ONETCode onetcode
replace dotcode = subinstr(dotcode,"-","",.)
replace dotcode = subinstr(dotcode,".","",.)
destring dotcode, replace
save xwalkDOT10, replace

use DOT1991, clear
merge 1:m dotcode using xwalkDOT10
keep if _m == 3
drop _m
* now dotcode is unique identifier and we need onetcode to be unique identifier
collapse (mean) $DOTvars, by(onetcode)
ren * *1991
ren onetcode1991 onetcode
ren reason1991 qreason1991
save DOT1991clean, replace

use DOT1991, clear
merge 1:m dotcode using xwalkDOT98
keep if _m == 3
drop _m
* now dotcode is unique identifier and we need onetcode to be unique identifier
collapse (mean) $DOTvars, by(onetcode1998)
ren * *1991
ren onetcode19981991 onetcode
save DOT1991clean98, replace

cd "$data/DOT/data"
use "ICPSR_08942-1980/DS0001/08942-0001-Data.dta", clear
ren *, lower
ren datal data
keep oc80 data people things
ren * *1977
ren oc801977 census1980
save DOT1977clean, replace
