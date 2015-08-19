* regress occupation shares of ages 20-30 on occupation sex ratios of ages 30-60

set more off, perm
clear all

********************** CAN RUN CODE WITH EITHER OCC1990 (400 occs) or occ6 (6 occs)
* by toggling:
global whichocc occ1990

global ageoff = 30

cd "$data/ACA/data"
use usa_00009.dta, clear
rename OCC1990 occ1990

************ calculate share
* share is for group making the decision, eg. age <30
* occ90 is consistent across all years

/* Many users will want to further aggregate categories into the broad occupational 
categories implicit in the 1990 scheme: Managerial and Professional (000-200); 
Technical, Sales, and Administrative (201-400); Service (401-470); 
Farming, Forestry, and Fishing (471-500); Precision Production, Craft, and Repairers (501-700); 
Operatives and Laborers (701-900); Non-occupational responses (900-999).
*/
* unemployed, unknown, and military
recode occ1990 (0=.) (900/999=.)
g occ6 = occ1990
recode occ6 (0=.) (001/200=1)  (201/400=2)  (401/470=3) (471/500=4) (501/700=5)  (701/900=6)

la def occ 0 "Unemployed" 1 "Managerial and Professional" 2 "Technical, Sales, and Administrative" /*
*/ 3 "Service" 4 "Farming, Forestry, and Fishing" 5 "Precision Production, Craft, and Repairers" /*
*/ 6 "Operatives and Laborers"
la val occ6 occ


* Make broad industry categories
replace IND1990 = . if IND1990 == 992
g ind15 = IND1990
recode ind15 (0=.) (10/32=1) (40/50=2) (60=3) (100/392=4) (400/472=5) (500/571=6) /*
*/ (580/691=7) (700/712=8) (721/760=9) (761/791=10) (800/810=11) (812/893=12) /*
*/ (900/932=13) (940/960=14)

la def ind 1 "Agriculture, Forestry and Fisheries" 2 "Mining" 3 "Construction" 4 "Manufacturing" /*
*/ 5 "Transportation, Communications, and other public utilities" 6 "Wholesale Trade" 7 "Retail Trade" 8 "Finance, Insurance, and Real Estate" /*
*/ 9 "Business and Repaire Service" 10 "Personal Services" 11 "Entertainment and Recreation Services" 12 "Professional and Related Services" /*
*/ 13 "Public Administration" 14 "Active Duty Military"
la val ind15 ind

************* DROP FOR NOW UNTIL INCLUDE HOME SECTOR
drop if occ6 == .

*** Drop if number of workers in occupatoin ever drops below 30
* noobs is indicator of occupation has < 30 observations in that year
egen o90 = group(occ1990)
foreach year in 1980 1990 2000 2012 {
g noobs`year' = 0
forval x=1/386 {
count if o90 == `x' & year == `year'
if r(N) < 30 {
replace noobs`year' = noobs`year' + 1 if o90 == `x'
}
}
}
egen under30 = rowmax(noobs*)
count if under30 > 0
* 3.36 of sample
preserve
byso $whichocc: keep if _n == 1
tab under30
* 58 occupations missing at least one year, 328 not missing at all
restore
******* Sample restrictions*****************************************************
keep if inrange(age,18,64)== 1
* get rid of students 
drop if school == 2

* get rid of puerto rico, groups, overseas, and unknown
drop if inlist(stateicp,83,96,97,99) == 1

g sexratio = sex
recode sexratio (1=0) (2=1)
recode incwage (999999=.)
recode uhrswork (0=.)
g rawincwage = incwage
* inflation adjust, 2010 dollars using http://www.bls.gov/data/inflation_calculator.htm
g inflation = .
replace inflation = 7.37 if year == 1960
replace inflation = 5.62 if year == 1970
replace inflation = 2.65 if year == 1980
replace inflation = 1.67 if year == 1990
replace inflation = 1.27 if year == 2000 
replace inflation = 0.95 if year == 2012 

replace incwage = incwage*inflation
g wage = incwage/(uhrswork*50)
drop if wage < 2 | wage > 100 & wage != .

g logwage = log(wage)
g logincwage = log(incwage)

* clean education
g ed = educd
replace ed = . if ed == 1
recode ed (2/61=1)
recode ed (62/64 = 2)
recode ed (65/80=3)
recode ed 81= 4
recode ed 101 = 5
recode ed 114=7
recode ed 115=6
recode ed 116=8
la def ed1 1 "less than HS" 2 "HS" 3 "some college" 4 "associates" 5 "Bachelor" 6 "Professional" 7 "Master" 8 "Doctorate"
la val ed ed1 
ren ed ed8

recode educ 0 = .

* clean marital status
g marstd = marst
recode marst (2=1) (3/6=0)
la def mar 0 "unmarried" 1 "married"
la val marst mar

* clean industry
recode IND1990 (999=.) (0=.)

g yrsch = . // potential experience = age-schooling-5 as in Addison Ozturk
replace yrsch = 0 if educ == 0
replace yrsch = 5 if educ == 1
replace yrsch = 7.5 if educ == 2
replace yrsch = 10 if educ == 3
replace yrsch = 11 if educ == 4
replace yrsch = 12 if educ == 5
replace yrsch = 13 if educ == 6
replace yrsch = 14 if educ == 7
replace yrsch = 15 if educ == 8
replace yrsch = 16 if educ == 9
replace yrsch = 17 if educ == 10
replace yrsch = 18 if educ == 11
g potexp = age - yrsch - 5
g potexp2 = potexp^2
g agesquare = age^2
g black = race == 2
g white = race == 1
g hisp = inrange(hispan,1,4)
g fulltime = uhrswork > 34 & uhrswork != .

recode region (11/13=1) (21/23=2) (31/34=3) (41/43=4) (91/99=.)
la def region 1 "Northeast" 2 "Midwest" 3 "South" 4 "West"
la val region region

recode metro (0=.) (1=0) (2/4=1)
la def metro 0 "non metro" 1 "metro area"
la val metro metro
la var metro "Indicator of Metro Area"

* make child under 5 and over 5 in household dummies using age of oldest and youngest child <18
recode eldch (99=.)
recode yngch (99=.)
g under5 = 0
replace under5 = 1 if eldch < 5 & eldch != .
replace under5 = 1 if yngch < 5 & yngch != .
g over5 = 0
replace over5 = 1 if eldch > 5 & eldch != . & eldch < 18
replace over5 = 1 if yngch > 5 & yngch != . & yngch <18

la var yrsch "Years of Schooling"
la var potexp "Years of Potential Experience"
la var age "Age"
la var black "Indicator of Black"
la var hisp "Indicator of Hispanic"
la var white "Indicator of White"
la var fulltime "Indicator Works >35hrs"
la var marst "Indicator of Married"
la var under5 "Indicator of Children <5"
la var over5 "Indicator of Children >5"


save usa00009new, replace
cd $home\ACS
use usa00009new, clear


program calc_shares
syntax, invar(name)
keep if age <= $ageoff
contract $whichocc [fw=perwt], percent(percent) freq(freq)
g share`invar' = percent/100
drop percent freq
end

* males
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00009new.dta, clear
keep if sex == 1 & year == `num'
calc_shares, invar(male)
tempfile sharemale`num'_$whichocc
g year = `num'
save "`sharemale`num'_$whichocc'", replace
}
use "`sharemale1960_$whichocc'", replace
foreach num of numlist 1970 1980 1990 2000 2012 {
append using "`sharemale`num'_$whichocc'"
}
save sharemale_young_$whichocc, replace
* females
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00009new.dta, clear
keep if sex == 2 & year == `num'
calc_shares, invar(female)
tempfile sharefemale`num'_$whichocc
g year = `num'
save "`sharefemale`num'_$whichocc'", replace
}

use "`sharefemale1960_$whichocc'", replace
foreach num of numlist 1970 1980 1990 2000 2012 {
append using "`sharefemale`num'_$whichocc'"
}
save sharefemale_young_$whichocc, replace


************ MY SPEC: regress young gen wages on old gen sexratio
************ calculate sex ratios >30 and <30
use usa00009new, clear
preserve
keep if age < $ageoff
collapse (mean) sexratio [fw=perwt], by($whichocc year)
ren sexratio sexratio_young
save "sexratio_young_$whichocc", replace
restore, preserve
collapse (mean) sexratio [fw=perwt], by($whichocc year stateicp)
ren sexratio sexratio_young
save "sexratio_young_states_$whichocc", replace
restore
preserve
keep if age > $ageoff
collapse (mean) sexratio [fw=perwt], by($whichocc year)
ren sexratio sexratio_old
save "sexratio_old_$whichocc", replace
restore, preserve
collapse (mean) sexratio [fw=perwt], by($whichocc year stateicp)
ren sexratio sexratio_old
save "sexratio_old_states_$whichocc", replace
restore
************ calculate mean male and female log wages <30
preserve
keep if age < $ageoff
collapse (mean) logwage [fw=perwt], by($whichocc year sex)
ren logwage logwage_young
save "logwage_young_$whichocc", replace
restore, preserve
collapse (mean) logwage [fw=perwt], by($whichocc year stateicp sex)
ren logwage logwage_young
save "logwage_young_states_$whichocc", replace
restore

************* ALT SPEC: regress all wages on all sexratios
use usa00009new, clear
preserve
collapse (mean) sexratio [fw=perwt], by($whichocc year)
save "sexratio_$whichocc", replace
restore, preserve
collapse (mean) sexratio [fw=perwt], by($whichocc year stateicp)
save "sexratio_states_$whichocc", replace
restore
************ calculate mean male and female log wages
preserve
collapse (mean) logwage [fw=perwt], by($whichocc year sex)
save "logwage_$whichocc", replace
restore, preserve
collapse (mean) logwage [fw=perwt], by($whichocc year stateicp sex)
save "logwage_states_$whichocc", replace
restore
*/
************ get mean raw wage and incwage by year for summary stats
use usa00009new, clear
preserve
collapse (mean) wage [fw=perwt], by($whichocc year sex)
save "wage_$whichocc", replace
restore, preserve
collapse (mean) incwage [fw=perwt], by($whichocc year sex)
save "incwage_$whichocc", replace
restore

cd $home\ACS
use "wage_$whichocc", clear
keep if year >1970
reshape wide wage, i($whichocc year) j(sex)
rename wage1 wagemale
rename wage2 wagefemale
save wage_$whichocc, replace


/*

* 1 is female
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if age > $ageoff & year == `num'
collapse (mean) sexratio [fw=perwt], by($whichocc)
tempfile sexratio`num'_$whichocc
save "`sexratio`num'_$whichocc'", replace
}

************ calculate male wage
* 1 is female
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if sex == 1 & year == `num'
collapse (mean) incwage [fw=perwt], by($whichocc)
rename incwage incwagemale
tempfile incwagemale`num'_$whichocc
save "`incwagemale`num'_$whichocc'", replace
}

************ calculate female wage
* 1 is female
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if sex == 2 & year == `num'
collapse (mean) incwage [fw=perwt], by($whichocc)
rename incwage incwagefemale
tempfile incwagefemale`num'_$whichocc
save "`incwagefemale`num'_$whichocc'", replace
}



************** make data set
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use "`sexratio`num'_$whichocc'", clear
g year = `num'
merge 1:1 $whichocc using "`sharemale`num'_$whichocc'"
drop _merge
merge 1:1 $whichocc using "`sharefemale`num'_$whichocc'"
drop _merge
merge 1:1 $whichocc using "`incwagemale`num'_$whichocc'"
drop _merge
merge 1:1 $whichocc using "`incwagefemale`num'_$whichocc'"
drop _merge
tempfile census_occ_`num'_$whichocc
save "`census_occ_`num'_$whichocc'", replace
}

use census_occ_1960_$whichocc
foreach num of numlist 1970 1980 1990 2000 2012 {
append using "`census_occ_`num'_$whichocc'"
}

replace sharemale = 0 if sharemale == .
replace sharefemale = 0 if sharefemale == .

drop if occ6 == .
save census_occ_$whichocc, replace


*********************************************************************
* Do same also by state (define as labor market)
*********************************************************************
use usa00007new.dta, clear

* males
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if sex == 1 & year == `num'
forval x = 1/99 {
preserve
g check1 = stateicp ==`x'
egen check2 = mean(check1)
if check2 != 0 {
keep if stateicp ==`x'
calc_shares, invar(male)
rename sharemale sharemale`num'state`x'
save sharemale`num'state`x'_$whichocc, replace
}
restore
}
}

* females
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if sex == 2 & year == `num'
forval x = 1/99 {
preserve
g check1 = stateicp ==`x'
egen check2 = mean(check1)
if check2 != 0 {
keep if stateicp ==`x'
calc_shares, invar(female)
rename sharefemale sharefemale`num'state`x'
save sharefemale`num'state`x'_$whichocc, replace
}
restore
}
}

************ calculate sex ratios
* 1 is female
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if age > $ageoff & year == `num'
forval x = 1/99 {
preserve
g check1 = stateicp ==`x'
egen check2 = mean(check1)
if check2 != 0 {
keep if stateicp ==`x'
collapse (mean) sexratio [fw=perwt], by($whichocc)
rename sexratio sexratio`num'state`x'
save sexratio`num'state`x'_$whichocc, replace
}
restore
}
}

************ calculate wages MALES
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if age > $ageoff & year == `num' & sex == 1
forval x = 1/99 {
preserve
g check1 = stateicp ==`x'
egen check2 = mean(check1)
if check2 != 0 {
keep if stateicp ==`x'
collapse (mean) incwage [fw=perwt], by($whichocc)
rename incwage incwagemale`num'state`x'
save incwagemale`num'state`x'_$whichocc, replace
}
restore
}
}


************ calculate wages FEMALES
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use usa00007new.dta, clear
keep if age > $ageoff & year == `num' & sex == 2
forval x = 1/99 {
preserve
g check1 = stateicp ==`x'
egen check2 = mean(check1)
if check2 != 0 {
keep if stateicp ==`x'
collapse (mean) incwage [fw=perwt], by($whichocc)
rename incwage incwagefemale`num'state`x'
save incwagefemale`num'state`x'_$whichocc, replace
}
restore
}
}



************** make data set for matlab
foreach num of numlist 1960 1970 1980 1990 2000 2012 {
use sexratio`num'_$whichocc, clear
merge 1:1 $whichocc using sharemale`num'_$whichocc
drop _merge
merge 1:1 $whichocc using sharefemale`num'_$whichocc
drop _merge
forval x = 1/99 {
capture confirm file "sexratio`num'state`x'_$whichocc.dta"
if _rc != 601 {
merge 1:1 $whichocc using sexratio`num'state`x'_$whichocc
drop _merge
merge 1:1 $whichocc using sharemale`num'state`x'_$whichocc
drop _merge
merge 1:1 $whichocc using sharefemale`num'state`x'_$whichocc
drop _merge
merge 1:1 $whichocc using incwagemale`num'state`x'_$whichocc
drop _merge
merge 1:1 $whichocc using incwagefemale`num'state`x'_$whichocc
drop _merge
}
else if _rc==601 {
display "can't find file sexratio`num'state`x'"
}
}
save census_occ_`num'_states_$whichocc, replace
}






use census_occ_1960_$whichocc
foreach num of numlist 1970 1980 1990 2000 2012 {
append using census_occ_`num'_states_$whichocc
}

replace sharemale = 0 if sharemale == .
replace sharefemale = 0 if sharefemale == .

save census_occ_states_$whichocc, replace

if !_rc {
display "asdf"
}

if _rc==601 {
display "asdf"
}
