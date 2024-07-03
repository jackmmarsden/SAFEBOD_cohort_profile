// Project: Defining SAFEBOD cohorts
// Created: 15/01/2024
// Created by: Jack Marsden
// Last edited: 27/05/2024
// Last edited by: Jack Marsden


* Set directories
global usyd_path "\\shared.sydney.edu.au\research-data"
global safebod_path "${usyd_path}\PRJ-SAFEBOD\3. Data Management\3.5 Datasets_Relinkage 2022\Formatted data"
global anzdata_path "${safebod_path}\ANZDATA_ANZOD"
global anziptr_path "${safebod_path}\ANZIPTR"
global antlu_path "${safebod_path}\ANTLU"
global anzcotr_path "${safebod_path}\CPR"
global organmatch_path "${safebod_path}\OrganMatchDetails"
global orchard_path "${safebod_path}\ORCHARD"
global apdc_path "${safebod_path}\APDC"
global mortality_path "${safebod_path}\Mortality"
global concordance_path "${safebod_path}\Donor_Recipient_Concordance"
global output_path "${usyd_path}\PRJ-SAFEBOD\4. Statistical Analysis\Jack M\Safebod cohort definition"
global eddc_path "${safebod_path}\EDDC"
global summary_path "${usyd_path}\PRJ-SAFEBOD\3. Data Management\3.5 Datasets_Relinkage 2022\Summary datasets"

*** FIND PPNS TO BE EXCLUDED ***

use "${mortality_path}\rbdm_deaths_sensitive.dta", clear
keep ppn DEATH_DATE
duplicates drop
duplicates tag ppn, gen(dup)
snapshot erase _all
snapshot save
keep if dup == 0
save "${output_path}\deaths_one_per_ppn.dta", replace
snapshot restore 1
keep if dup == 1
gen reason = "Duplicate death dates"
save "${output_path}\excluded.dta", replace

** APDC records following death

use "${output_path}\deaths_one_per_ppn.dta", clear
merge 1:m ppn using "${apdc_path}\apdc_main.dta"
keep if _merge == 3
keep if episode_start_date > DEATH_DATE
gen diff = episode_start_date - DEATH_DATE
bysort ppn: gen count = _N
drop if count == 1 & diff < 5
drop if inlist(ppn, "00000003126179", "00000005443724")
gen reason = "APDC records following death"
keep ppn reason
duplicates drop
append using "${output_path}\excluded.dta", force
drop DEATH_DATE
duplicates drop
save "${output_path}\excluded.dta", replace

** EDDC records following death

merge 1:1 ppn using "${output_path}\deaths_one_per_ppn.dta"
keep if _merge == 2
drop _merge
merge 1:m ppn using "${eddc_path}\prj_2017_27_2_ed_sensitive"
keep if _merge == 3
keep if arrival_date > DEATH_DATE
gen diff = arrival_date - DEATH_DATE
bysort ppn: gen count = _N
drop if count == 1 & diff < 5
drop reason
gen reason = "EDDC records following death"
keep ppn reason
duplicates drop
append using "${output_path}\excluded.dta", force
save "${output_path}\excluded.dta", replace

** No health records

merge 1:1 ppn using "${summary_path}\ppn_list.dta"
keep if _merge == 2
drop _merge
gen health = apdc + ccr + eddc + hiv + codurf + rbdm + ncims_labtests + ncims_ncres + ncims_tb + ncims_vaccination
keep if health == 0
keep ppn
append using "${output_path}\excluded.dta", force
duplicates drop
save "${output_path}\excluded.dta", replace
*/
*** CREATE RECIPIENT PPN LIST ***

** Kidney 
/*
use "${anzdata_path}\42952 AnzdataTransplants.dta", clear
keep if inlist(donorsourcecode, 100, .)
keep ppn transplantdate
rename transplantdate deceased_kidney_transplant_date
sort ppn deceased_kidney_transplant_date
bysort ppn: gen graftno = _n
reshape wide deceased_kidney_transplant_date, j(graftno) i(ppn)
gen organ = "kidney"
save "${output_path}\deceased_kidney_recipients.dta", replace

use "${anzdata_path}\42952 AnzdataTransplants.dta", clear
drop if inlist(donorsourcecode, 100, .)
keep ppn transplantdate
rename transplantdate living_kidney_transplant_date
sort ppn living_kidney_transplant_date
bysort ppn: gen graftno = _n
reshape wide living_kidney_transplant_date, j(graftno) i(ppn)
gen organ = "single_kidney"
save "${output_path}\living_kidney_recipients.dta", replace

** Pancreas

use "${anziptr_path}\anziptr_content.dta", clear
keep ppn transplant_date
rename transplant_date pancreas_transplant_date
sort ppn pancreas_transplant_date
bysort ppn: gen graftno = _n
reshape wide pancreas_transplant_date, j(graftno) i(ppn)
gen organ = "pancreas"
save "${output_path}\pancreas_recipients.dta", replace

** Lung

use "${anzcotr_path}\cpr_data.dta", clear
rename PPN ppn
keep if strpos(TransplantType, "Lung") != 0
gen received = 1
replace received = 2 if strpos(TransplantType, ",") != 0 & strpos(TransplantType, "Single") == 0
drop TransplantType
rename Operation_Date lung_transplant_date
sort ppn lung_transplant_date
gen organ = "double_lung" if received == 2
replace organ = "single_lung" if received == 1
bysort ppn organ: gen graftno = _n
reshape wide lung_transplant_date, j(graftno) i(ppn organ)
drop received
save "${output_path}\lung_recipients.dta", replace

** Heart
use "${anzcotr_path}\cpr_data.dta", clear
rename PPN ppn
keep if strpos(TransplantType, "Heart") != 0
drop TransplantType
rename Operation_Date heart_transplant_date
sort ppn heart_transplant_date
bysort ppn: gen graftno = _n
reshape wide heart_transplant_date, j(graftno) i(ppn)
gen organ = "heart"
save "${output_path}\heart_recipients.dta", replace

** Liver
use "${antlu_path}\antlu_recip.dta", clear
tostring ppn_recip, gen(rppn)
gen ppn = string(real(rppn), "%014.0f")
gen transplant_date=dofC(transplantdate)
format transplant_date %td
replace transplantdate=transplant_date+1
save "${output_path}\antlu_recip_tidy.dta", replace
keep ppn transplant_date grafttype
gen organ = "whole_liver" if grafttype == "Whole Liver"
replace organ = "split_liver" if organ == ""
drop grafttype
sort ppn transplant_date
bysort ppn organ: gen graftno = _n
rename transplant_date liver_transplant_date
reshape wide liver_transplant_date, j(graftno) i(ppn organ)
save "${output_path}\liver_recipients.dta", replace

** Combined recipient list
foreach i in liver heart lung pancreas living_kidney deceased_kidney {
    append using "${output_path}\\`i'_recipients.dta", force
	drop *transplant*
	gen `i' = 0
	replace `i' = 1 if organ == "`i'"
}

drop liver lung deceased_kidney living_kidney

foreach i in whole_liver kidney single_kidney split_liver single_lung double_lung {
    gen `i' = 0
	replace `i' = 1 if organ == "`i'"
}

duplicates drop
drop organ

foreach i in whole_liver split_liver single_lung heart double_lung pancreas kidney single_kidney {
    replace `i' = 0 if `i' == .
	bysort ppn: egen max_`i' = max(`i')
	replace `i' = max_`i'
	drop max_`i'
}

duplicates drop
drop if ppn == ""

rename ppn recipient_ppn
save "${output_path}\recipients.dta", replace

*** CREATE DONOR PPN LIST ***

** Kidney

use "${anzdata_path}\42952 AnzodDonors.dta", clear
keep if kidneydonorcode == "Y"
keep ppn donor_date
rename donor_date deceased_kidney_donation_date
merge 1:m ppn using "${anzdata_path}\42952 AnzodDestination.dta"
keep if _merge == 3 & inlist(organcode, 10, 11, 12, 13)
decode organcode, gen(organ)
keep ppn deceased_kidney_donation_date organ
save "${output_path}\deceased_kidney_donors.dta", replace

use "${anzdata_path}\42952 LKDonorDetails.dta", clear
keep ppn donationdate
rename donationdate living_kidney_donation_date
gen organ = "single_kidney"
save "${output_path}\living_kidney_donors.dta", replace

** Pancreas


use "${anzdata_path}\42952 AnzodDonors.dta", clear
keep if pancreasdonorcode == "Y"
keep ppn donor_date
rename donor_date pancreas_donation_date
gen organ = "pancreas"
merge 1:m ppn using "${anzdata_path}\42952 AnzodDestination.dta", keepusing(organcode)
keep if _merge == 3
keep if organcode == 50
drop organcode
save "${output_path}\pancreas_donors.dta", replace

** Lung

use "${anzdata_path}\42952 AnzodDonors.dta", clear
keep if lungdonorcode == "Y"
keep ppn donor_date
rename donor_date lung_donation_date
merge 1:m ppn using "${anzdata_path}\42952 AnzodDestination.dta"
keep if _merge == 3 & inlist(organcode, 40, 41, 42, 36, 35)
decode organcode, gen(organ)
keep ppn lung_donation_date organ
replace organ = "double_lung" if organ == "Double Lung"
replace organ = "single_lung" if inlist(organ, "Right Lung", "Left Lung") 
save "${output_path}\lung_donors.dta", replace

** Heart

use "${anzdata_path}\42952 AnzodDonors.dta", clear
keep if heartdonorcode == "Y"
keep ppn donor_date
rename donor_date heart_donation_date
gen organ = "heart"
save "${output_path}\heart_donors.dta", replace

** Liver

use "${anzdata_path}\42952 AnzodDonors.dta", clear
keep if liverdonorcode == "Y"
keep ppn donor_date
rename donor_date liver_donation_date
merge 1:m ppn using "${anzdata_path}\42952 AnzodDestination.dta"
keep if _merge == 3 & inlist(organcode, 20, 21, 22)
decode organcode, gen(organ)
replace organ = "whole_liver" if organ == "Liver"
replace organ = "split_liver" if organ != "whole_liver"
keep ppn liver_donation_date organ
save "${output_path}\liver_donors.dta", replace

** Combined

foreach i in liver heart lung pancreas living_kidney deceased_kidney {
    append using "${output_path}\\`i'_donors.dta", force
	drop *donation*
	gen `i' = 0
	replace `i' = 1 if organ == "`i'"
}

rename liver whole_liver
replace whole_liver = 1 if organ == "Liver"
gen split_liver = 0
replace split_liver = 1 if inlist(organ, "Split Liver (L)", "Split Liver (R)")

rename lung double_lung
replace double_lung = 1 if organ == "Double Lung"
gen single_lung = 0
replace single_lung = 1 if inlist(organ, "Right Lung", "Left Lung")

rename living_kidney single_kidney
replace single_kidney = 1 if inlist(organ, "Left Kidney", "Right Kidney", "Single kidney")
rename deceased_kidney double_kidney
replace double_kidney = 1 if organ == "Double/En-bloc Kidney"


duplicates drop
drop organ

foreach i in whole_liver split_liver heart double_lung single_lung pancreas single_kidney double_kidney {
    replace `i' = 0 if `i' == .
	bysort ppn: egen max_`i' = max(`i')
	replace `i' = max_`i'
	drop max_`i'
}

duplicates drop
drop if ppn == ""

rename ppn donor_ppn
save "${output_path}\donors.dta", replace

*/

*** MATCH DONORS AND RECIPIENTS ***




*** Generate initial datasets of total potential matches

foreach i in liver heart lung pancreas living_kidney deceased_kidney {
    use "${output_path}\\`i'_recipients.dta", clear
	rename ppn PPNID_Recipient
	merge m:m PPNID_Recipient using "${concordance_path}\Donor_Recipient_Concordance.dta"
	snapshot erase _all
	snapshot save
	keep if _merge == 1
	rename organ recipient_organ
	drop _merge
	save "${output_path}\\`i'_recipients_unmatched.dta", replace
	snapshot restore 1
	keep if _merge == 3
	drop _merge
	rename organ recipient_organ
	save "${output_path}\\`i'_recipients_matched.dta", replace 
	snapshot restore 1
	drop if _merge == 2
	drop _merge
	keep PPNID_Recipient PPNID_Donor
	duplicates drop
	save "${output_path}\\`i'_recipients_matched_and_unmatched.dta", replace
    use "${output_path}\\`i'_donors.dta", clear
	rename ppn PPNID_Donor
	merge m:m PPNID_Donor using "${output_path}\\`i'_recipients_matched_and_unmatched.dta"
	keep if _merge == 1
	drop _merge
	save "${output_path}\\`i'_donors_unmatched.dta", replace
	use "${output_path}\\`i'_donors.dta", clear
	rename ppn PPNID_Donor
	merge m:m PPNID_Donor using "${output_path}\\`i'_recipients_matched.dta"
	keep if _merge == 3
	drop _merge
	save "${output_path}\\`i'_matched.dta", replace
}

*** Reshape and trim for heart/lung/pancreas pairs

foreach i in heart lung pancreas {
    use "${output_path}\\`i'_matched.dta", clear
	gen potential_match = 0
	forvalues j = 1/2 {
	    replace potential_match = 1 if abs(`i'_donation_date - `i'_transplant_date`j')<3
	}
	bysort PPNID_Donor: egen potential_donor_match = max(potential_match)
	bysort PPNID_Recipient: egen potential_recipient_match = max(potential_match)
	snapshot erase _all
	snapshot save
	keep if potential_donor_match == 0
	keep PPNID_Donor *donation* organ
	append using "${output_path}\\`i'_donors_unmatched.dta", force
	save "${output_path}\\`i'_donors_unmatched.dta", replace
	snapshot restore 1
	keep if potential_recipient_match == 0
	keep PPNID_Recipient *transplant*
	append using "${output_path}\\`i'_recipients_unmatched.dta", force
	save "${output_path}\\`i'_recipients_unmatched.dta", replace
	duplicates drop
	snapshot restore 1
	keep if potential_match == 1
	drop potential* 
	drop if organ != recipient_organ
	drop recipient_organ
	duplicates drop
	reshape long `i'_transplant_date, i(PPNID_Donor PPNID_Recipient organ) j(seq)
	drop if `i'_transplant_date == .
	drop if abs(`i'_donation_date - `i'_transplant_date)>3
	drop seq
	save "${output_path}\\`i'_matched.dta", replace
}

*** Cull to real LK pairs

foreach i in living_kidney {
    use "${output_path}\\`i'_matched.dta", clear
	gen potential_match = 0
	forvalues j = 1/3 {
	    replace potential_match = 1 if abs(`i'_donation_date - `i'_transplant_date`j')<3
	}
	bysort PPNID_Donor: egen potential_donor_match = max(potential_match)
	bysort PPNID_Recipient: egen potential_recipient_match = max(potential_match)
	snapshot erase _all
	snapshot save
	keep if potential_donor_match == 0
	keep PPNID_Donor *donation* organ
	append using "${output_path}\\`i'_donors_unmatched.dta", force
	save "${output_path}\\`i'_donors_unmatched.dta", replace
	snapshot restore 1
	keep if potential_recipient_match == 0
	keep PPNID_Recipient *transplant* *organ
	append using "${output_path}\\`i'_recipients_unmatched.dta", force
	save "${output_path}\\`i'_recipients_unmatched.dta", replace
	duplicates drop
	snapshot restore 1
	keep if potential_match == 1
	drop potential*
	duplicates drop 
	reshape long `i'_transplant_date, i(PPNID_Donor PPNID_Recipient recipient_organ) j(seq)
	drop if `i'_transplant_date == .
	drop if abs(`i'_donation_date - `i'_transplant_date)>3
	drop seq
	replace organ = "single_kidney"
	save "${output_path}\\`i'_matched.dta", replace
}

*** Cull to real DK pairs


foreach i in deceased_kidney {
    use "${output_path}\\`i'_matched.dta", clear
	gen potential_match = 0
	forvalues j = 1/4 {
	    replace potential_match = 1 if abs(`i'_donation_date - `i'_transplant_date`j')<3
	}
	bysort PPNID_Donor: egen potential_donor_match = max(potential_match)
	bysort PPNID_Recipient: egen potential_recipient_match = max(potential_match)
	snapshot erase _all
	snapshot save
	keep if potential_donor_match == 0
	keep PPNID_Donor *donation* organ
	append using "${output_path}\\`i'_donors_unmatched.dta", force
	save "${output_path}\\`i'_donors_unmatched.dta", replace
	snapshot restore 1
	keep if potential_recipient_match == 0
	keep PPNID_Recipient *transplant*
	append using "${output_path}\\`i'_recipients_unmatched.dta", force
	save "${output_path}\\`i'_recipients_unmatched.dta", replace
	duplicates drop
	snapshot restore 1
	keep if potential_match == 1
	drop potential*
	duplicates drop
	reshape long `i'_transplant_date, i(PPNID_Donor PPNID_Recipient organ) j(seq)
	drop if `i'_transplant_date == .
	drop if abs(`i'_donation_date - `i'_transplant_date)>3
	save "${output_path}\\`i'_matched.dta", replace
	rename PPNID_Donor DONOR_PPN
	rename PPNID_Recipient Recipient_PPN
	merge m:m DONOR_PPN Recipient_PPN using "${organmatch_path}\\prj2017272_organmatch_details_v3.dta", keepusing(Transplanted)
	drop if _merge == 2
	drop if inlist(Transplanted, "0", "NULL")
	gen gap = abs(`i'_donation_date - `i'_transplant_date)
	rename DONOR_PPN PPNID_Donor
	rename Recipient_PPN PPNID_Recipient
	bysort PPNID_Donor: egen closest = min(gap)
	sort PPNID_Donor gap
	drop seq
	by PPNID_Donor: gen seq = _n
	sort PPNID_Donor seq
	by PPNID_Donor: gen lag = gap - gap[_n-1]
	by PPNID_Donor: replace lag = abs(gap - gap[2]) if seq > 2
	drop if lag > 0 & seq > 2
	drop if lag > 0 & lag != . & organ == "Double/En-bloc Kidney"
	drop seq lag
	duplicates drop
	replace organ = "single_kidney" if organ != "Double/En-bloc Kidney"
	replace organ = "double_kidney" if organ == "Double/En-bloc Kidney"
	save "${output_path}\\`i'_matched.dta", replace
}

*** Ensure only one pair per donor for appropriate organs

foreach i in heart living_kidney pancreas {
    use "${output_path}\\`i'_matched.dta", clear
	gen gap = abs(`i'_donation_date - `i'_transplant_date)
	bysort PPNID_Donor: egen closest = min(gap)
	keep if gap == closest
	drop gap closest
	save "${output_path}\\`i'_matched.dta", replace
}

*** Manually fix pancreas dataset duplicates
duplicates drop
save "${output_path}\\pancreas_matched.dta", replace

*** Manually fix heart dataset duplicates
use "${output_path}\\heart_matched.dta", clear
rename PPNID_Donor DONOR_PPN
rename PPNID_Recipient Recipient_PPN
merge m:m DONOR_PPN Recipient_PPN using "${organmatch_path}\\prj2017272_organmatch_details_v3.dta", keepusing(Transplanted)
drop if _merge == 2
*** Donor-recipient 00000002578816	00000002716946 was an organmatch
*** but not a transplanted match
use "${output_path}\\heart_matched.dta", clear
drop if PPNID_Donor == "00000002578816" & PPNID_Recipient == "00000002716946"
save "${output_path}\\heart_matched.dta", replace

*** Finalise pairs for lung transplants


foreach i in lung {
    use "${output_path}\\`i'_matched.dta", clear
	gen gap = abs(`i'_donation_date - `i'_transplant_date)
	bysort PPNID_Donor: egen closest = min(gap)
	sort PPNID_Donor gap
	by PPNID_Donor: gen seq = _n
	sort PPNID_Donor seq
	by PPNID_Donor: gen lag = gap - gap[_n-1]
	by PPNID_Donor: replace lag = abs(gap - gap[2]) if seq > 2
	drop if lag > 0 & seq > 2
	drop if lag > 0 & lag != . & organ == "double_lung"
	save "${output_path}\\`i'_matched.dta", replace
}

*** manually remove incorrect pairs in lung dataset
use "${output_path}\\lung_matched.dta", clear
rename PPNID_Donor DONOR_PPN
rename PPNID_Recipient Recipient_PPN
merge m:m DONOR_PPN Recipient_PPN using "${organmatch_path}\\prj2017272_organmatch_details_v3.dta", keepusing(Transplanted)
drop if _merge == 2

use "${output_path}\\lung_matched.dta", clear
drop if PPNID_Donor == "00000002379678" & PPNID_Recipient == "00000004790417"
drop if PPNID_Donor == "00000002882455" & PPNID_Recipient == "00000006619051"
drop gap closest seq lag
save "${output_path}\\lung_matched.dta", replace

*** Finalise pairs for liver transplants


foreach i in liver {
     use "${output_path}\\`i'_matched.dta", clear
	 replace organ = "split_liver" if organ != "Liver"
	 replace organ = "whole_liver" if organ == "Liver"
	 drop if organ != recipient_organ
	 drop recipient_organ
	 duplicates drop
	 reshape long `i'_transplant_date, i(PPNID_Donor PPNID_Recipient organ) j(seq)
	 drop seq
	 duplicates drop
	 drop if `i'_transplant_date == .
	drop if abs(`i'_donation_date - `i'_transplant_date)>3
	drop if PPNID_Donor == "00000000506070" & liver_transplant_date == mdy(6, 18, 2017)
	drop if PPNID_Donor == "00000002217087" & liver_transplant_date == mdy(7, 19, 2012)
	drop if PPNID_Donor == "00000004985745" & liver_transplant_date == mdy(11, 5, 2019)
	drop if PPNID_Donor == "00000006101951" & liver_transplant_date == mdy(1, 29, 2012)
	drop if PPNID_Donor == "00000006547105" & liver_transplant_date == mdy(6, 20, 2017)
	drop if PPNID_Donor == "00000011123862" & liver_transplant_date == mdy(1, 31, 2012)
	save "${output_path}\\`i'_matched.dta", replace
}

*/

*** ADD UNMATCHED OBSERVATIONS ***


foreach i in pancreas living_kidney deceased_kidney  heart liver lung {
    use "${output_path}\\`i'_recipients.dta", clear
	duplicates drop
	drop if ppn == ""
	rename ppn PPNID_Recipient
	rename organ recipient_organ
	reshape long `i'_transplant_date, i(PPNID_Recipient recipient_organ) j(seq)
	drop if `i'_transplant_date == .
	drop seq
	append using "${output_path}\\`i'_donors.dta", force
	rename ppn PPNID_Donor
	gen can_be_dropped = 1
	append using "${output_path}\\`i'_matched.dta", force
	duplicates tag PPNID_Donor, gen(donor)
	duplicates tag PPNID_Recipient `i'_transplant_date, gen(receipt)
	gen tempvar = "`i'"
	drop if donor > 0 & donor < 10 & can_be_dropped == 1 & (inlist(organ, "heart", "double_lung", "Double/En-bloc Kidney", "pancreas", "Liver") | tempvar=="living_kidney")
	drop if donor > 1 & donor < 10 & can_be_dropped == 1 & inlist(organ, "Left Kidney", "Right Kidney", "single_kidney", "single_lung")
	drop if receipt > 0 & PPNID_Donor == ""
	keep PPNID_Recipient recipient_organ `i'_transplant_date PPNID_Donor `i'_donation_date organ
	gen donor_unknown = 0
	gen recip_unknown = 0
	replace donor_unknown = 1 if PPNID_Donor == ""
	replace recip_unknown = 1 if PPNID_Recipient == ""
	save "${output_path}\\`i'_transplants.dta", replace
	}
	


*** DETERMINE NSW RESIDENCE OF DONORS/RECIPIENTS IN PAIRS ***

snapshot erase _all
use "${apdc_path}\apdc_main.dta", clear
snapshot save


*** Recipients

foreach i in living_kidney deceased_kidney heart lung {
    snapshot restore 1
	keep ppn STATE_OF_RESIDENCE_RECODE episode_start_date episode_end_date
	rename ppn PPNID_Recipient
	merge m:m PPNID_Recipient using "${output_path}\\`i'_transplants.dta"
	drop if _merge == 1
	gen NSW = 0
	gen instance = 0
	replace instance = 1 if inrange(`i'_transplant_date, episode_start_date, episode_end_date)
	replace NSW = 1 if instance == 1 & STATE_OF_RESIDENCE_RECODE == 1 & PPNID_Recipient !=""
	gen closeness = abs(episode_start_date - `i'_transplant_date)
	bysort PPNID_Recipient `i'_transplant_date: egen closest = min(closeness)
	replace NSW = 1 if closeness == closest & STATE_OF_RESIDENCE_RECODE == 1 & PPNID_Recipient !=""
	bysort PPNID_Recipient `i'_transplant_date: egen NSW_recip = max(NSW)
	keep PPNID_Recipient `i'_transplant_date PPNID_Donor `i'_donation_date organ recipient_organ *unknown NSW_recip
	duplicates drop
	save "${output_path}\\`i'_transplants.dta", replace
} 

foreach i in pancreas {
	use "${anziptr_path}\anziptr_content.dta", clear
	keep ppn transplant_date patient_state
	rename ppn PPNID_Recipient
	rename transplant_date `i'_transplant_date
	drop if PPNID_Recipient == ""
	duplicates drop
	merge 1:m PPNID_Recipient `i'_transplant_date using "${output_path}\\`i'_transplants.dta", nogen
	gen NSW_recip = 0
	replace NSW_recip = 1 if patient_state == 1
	drop patient_state
	save "${output_path}\\`i'_transplants.dta", replace
}

*** All liver recipients were NSW resident

foreach i in liver {
	use "${output_path}\\`i'_transplants.dta", clear
	gen NSW_recip = 0
	replace NSW_recip = 1 if PPNID_Recipient != ""
	save "${output_path}\\`i'_transplants.dta", replace
}

*** Donors

foreach i in heart lung pancreas liver deceased_kidney {
	use "${output_path}\\`i'_transplants.dta", clear
	rename PPNID_Donor ppn
	merge m:1 ppn using "${anzdata_path}\42952 AnzodDonors.dta", keepusing(postcode)
	drop if _merge == 2
	drop _merge
	gen NSW_donor = 0
	replace NSW_donor = 1 if postcode < 2900 & postcode != . & postcode > 1999
	replace NSW_donor = 0 if inlist(postcode, 2600, 2601, 2602, 2603, 2604, 2605, 2606, 2609, 2610, 2611, 2612, 2614, 2615, 2616)
	save "${output_path}\\`i'_transplants.dta", replace
	snapshot restore 1
	keep ppn STATE_OF_RESIDENCE_RECODE episode_start_date episode_end_date
	merge m:m ppn using "${output_path}\\`i'_transplants.dta"
	drop if _merge == 1
	gen NSW = 0
	gen instance = 0
	replace instance = 1 if inrange(`i'_donation_date, episode_start_date, episode_end_date)
	replace NSW = 1 if instance == 1 & STATE_OF_RESIDENCE_RECODE == 1 & ppn !=""
	gen closeness = abs(episode_start_date - `i'_transplant_date)
	bysort ppn: egen closest = min(closeness)
	replace NSW = 1 if closeness == closest & STATE_OF_RESIDENCE_RECODE == 1 & ppn !=""
	bysort ppn: egen NSW_donor1 = max(NSW)
	replace NSW_donor = NSW_donor1 if postcode == .
	keep PPNID_Recipient `i'_transplant_date ppn `i'_donation_date organ recipient_organ *unknown NSW_recip NSW_donor
	duplicates drop
	rename ppn PPNID_Donor
	save "${output_path}\\`i'_transplants.dta", replace
}
 

foreach i in living_kidney {
	use "${output_path}\\`i'_transplants.dta", clear
	rename PPNID_Donor ppn
	merge m:1 ppn using "${anzdata_path}\42952 LKDonorDetails.dta", keepusing(donorpostcode) nogen
	gen NSW_donor = 0
	replace NSW_donor = 1 if donorpostcode < 2900 & donorpostcode != . & donorpostcode > 1999
	replace NSW_donor = 0 if inlist(donorpostcode, 2600, 2601, 2602, 2603, 2604, 2605, 2606, 2609, 2610, 2611, 2612, 2614, 2615, 2616)
	save "${output_path}\\`i'_transplants.dta", replace
	snapshot restore 1
	keep ppn STATE_OF_RESIDENCE_RECODE episode_start_date episode_end_date
	merge m:m ppn using "${output_path}\\`i'_transplants.dta"
	drop if _merge == 1
	gen NSW = 0
	gen instance = 0
	replace instance = 1 if inrange(`i'_donation_date, episode_start_date, episode_end_date)
	replace NSW = 1 if instance == 1 & STATE_OF_RESIDENCE_RECODE == 1 & ppn !=""
	gen closeness = abs(episode_start_date - `i'_transplant_date)
	bysort ppn: egen closest = min(closeness)
	replace NSW = 1 if closeness == closest & STATE_OF_RESIDENCE_RECODE == 1 & ppn !=""
	bysort ppn: egen NSW_donor1 = max(NSW)
	replace NSW_donor = NSW_donor1 if donorpostcode == .
	keep PPNID_Recipient `i'_transplant_date ppn `i'_donation_date organ recipient_organ *unknown NSW_recip NSW_donor
	duplicates drop
	rename ppn PPNID_Donor
	save "${output_path}\\`i'_transplants.dta", replace
}


*** APPEND ALL TRANSPLANT DATASETS TO MAKE A MASTER SET ***

foreach i in heart lung pancreas liver deceased_kidney living_kidney {
	use "${output_path}\\`i'_transplants.dta", clear
	rename `i'_transplant_date transplant_date
	rename `i'_donation_date donation_date
	replace organ = recipient_organ if organ == ""
	drop recipient_organ
	save "${output_path}\\`i'_transplants.dta", replace
}

gen donor_type = "Living"

foreach i in heart lung pancreas liver deceased_kidney {
	append using "${output_path}\\`i'_transplants.dta", force
}

replace donor_type = "Deceased" if donor_type == ""

replace organ = "split_liver" if inlist(organ, "Split Liver (L)", "Split Liver (R)")
replace organ = "single_kidney" if inlist(organ, "Right Kidney", "Left Kidney")
replace organ = "whole_liver" if organ == "Liver"
replace organ = "double_kidney" if organ == "Double/En-bloc Kidney"

*** Attach to excluded dataset

rename PPNID_Donor ppn
merge m:1 ppn using "${output_path}\excluded.dta", keepusing(reason) gen(donor)
drop if donor==2
rename ppn donor_ppn
gen donor_excluded = 0
replace donor_excluded = 1 if reason == "Duplicate death dates"
replace donor_excluded = 2 if reason == "APDC records following death"
replace donor_excluded = 3 if reason == "EDDC records following death"
replace donor_excluded = 4 if reason == "" & donor == 3 & NSW_donor == 1

drop donor reason

rename PPNID_Recipient ppn
merge m:1 ppn using "${output_path}\excluded.dta", keepusing(reason) gen(recip)
drop if recip==2
rename ppn recipient_ppn
gen recip_excluded = 0
replace recip_excluded = 1 if reason == "Duplicate death dates"
replace recip_excluded = 2 if reason == "APDC records following death"
replace recip_excluded = 3 if reason == "EDDC records following death"
replace recip_excluded = 4 if reason == "" & recip == 3 & NSW_recip == 1

drop recip reason

label define exclusionlabel ///
	0 "Validly linked" ///
	1 "Duplicate death dates" ///
	2 "APDC records following death" ///
	3 "EDDC records following death" ///
	4 "No health records for NSW resident" ///
	, replace
	
label values donor_excluded exclusionlabel
label values recip_excluded exclusionlabel

replace recip_excluded = . if recip_unknown == 1
replace donor_excluded = . if donor_unknown == 1

drop *unknown

gen transplantdate = transplant_date if transplant_date == donation_date
replace transplantdate = transplant_date if donation_date == .
replace transplantdate = donation_date if transplant_date == .

replace transplantdate = transplant_date if inlist(organ, "single_kidney", "double_kidney", "pancreas", "split_liver", "whole_liver") & transplantdate == .
replace transplantdate = donation_date if inlist(organ, "heart", "single_lung", "double_lung") & transplantdate == .

format transplantdate %td

drop *_date

lab var NSW_donor "Was the donor NSW resident at time of donation?"
lab var NSW_recip "Was the recipient NSW resident at time of transplant?"
lab var donor_excluded "Was the donor a valid linkage?"
lab var recip_excluded "Was the recipient a valid linkage?"
lab var organ "Organ transplanted"
lab var donor_ppn "PPN of Donor"
lab var recipient_ppn "PPN of Recipient"
lab var transplantdate "Date of transplant"
lab var donor_type "Donor living or deceased"

label define nswlabel ///
	0 "Non-NSW resident" ///
	1 "NSW resident" ///
	, replace
	
label values NSW_recip nswlabel
label values NSW_donor nswlabel

order donor_ppn recipient_ppn donor_type organ transplantdate NSW_donor NSW_recip donor_excluded recip_excluded

save "${output_path}\\master_transplants.dta", replace

*** Amend for living liver recipients

use "${output_path}\\master_transplants.dta", clear
snapshot erase _all
drop if recipient_ppn != "" & donor_type == "Deceased" & inlist(organ, "split_liver", "whole_liver")
snapshot save 
use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & donor_type == "Deceased" & inlist(organ, "split_liver", "whole_liver")
distinct recipient_ppn
rename recipient_ppn ppn
rename transplantdate transplant_date
drop donor_type
merge 1:1 ppn transplant_date using "${output_path}\antlu_recip_tidy.dta", keepusing(donor_type) nogen
rename ppn recipient_ppn
rename transplant_date transplantdate
save "${output_path}\\liver_transplants_living_tagged.dta", replace
snapshot restore 1
append using "${output_path}\\liver_transplants_living_tagged.dta"

*** Add donors for domino transplants
replace donor_ppn = "00000005968661" if recipient_ppn == "00000008679513" & organ == "whole_liver"
replace NSW_donor = 1 if recipient_ppn == "00000008679513" & organ == "whole_liver"
replace donor_excluded = 0 if recipient_ppn == "00000008679513" & organ == "whole_liver"
replace donor_ppn = "00000003440661" if recipient_ppn == "00000007303894" & organ == "whole_liver"
replace NSW_donor = 1 if recipient_ppn == "00000007303894" & organ == "whole_liver"
replace donor_excluded = 0 if recipient_ppn == "00000007303894" & organ == "whole_liver"

*** Missing states for non-matches outside of time window

replace NSW_donor = . if inlist(organ, "split_liver", "whole_liver") & donor_type == "Living" & NSW_donor == 0

gen year = yofd(transplantdate)

replace NSW_donor = . if donor_type == "Living" & inlist(organ, "single_kidney", "double_kidney") & (year < 2004 | year > 2019) & donor_ppn == ""

replace NSW_recip = . if donor_type == "Deceased" & inlist(organ, "single_kidney", "double_kidney") & (year < 2000 | year > 2019) & recipient_ppn == ""

drop year

save "${output_path}\\master_transplants.dta", replace

*** NUMBERS FOR FLOWCHART ***	

** LK donors

use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn != "" & donor_type == "Living" & organ == 6
count
drop if donor_excluded != 0
count
drop if NSW_donor != 1
count
drop if NSW_recip != 1
count
drop if recip_excluded != 0
count

save "${output_path}\\living_kidney_donations_included.dta", replace

** deceased kidney donors (plus total donors)

use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn != "" & donor_type == "Deceased" & inlist(organ, 1, 6)
distinct donor_ppn
drop if donor_excluded != 0
distinct donor_ppn
gen year = yofd(transplantdate)
drop if year > 2019
distinct donor_ppn
drop if NSW_donor != 1
distinct donor_ppn
drop if NSW_recip != 1
distinct donor_ppn
drop if recip_excluded != 0
distinct donor_ppn
save "${output_path}\\deceased_kidney_donations_included.dta", replace

append using "${output_path}\\living_kidney_donations_included.dta", force
distinct donor_ppn
save "${output_path}\\total_kidney_donations_included.dta", replace

**** Count of included donors donating outside NSW
use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn!= "" & donor_type == "Deceased" & inlist(organ, 1, 6) &  donor_excluded == 0 & NSW_donor == 1 & recip_excluded == 0
gen year = yofd(transplantdate)
drop if year > 2019
bysort donor_ppn: egen ever_donated_in_nsw = max(NSW_recip)
drop if ever_donated_in_nsw == 0
count if NSW_recip == 0

** Liver donors

use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn != "" & inlist(organ, 8, 9)
distinct donor_ppn
drop if donor_excluded != 0
distinct donor_ppn
keep if NSW_donor == 1
distinct donor_ppn
drop if NSW_recip != 1
distinct donor_ppn
drop if recip_excluded != 0
distinct donor_ppn
save "${output_path}\\liver_donations_included.dta", replace

**** Count of included donors donating outside NSW
use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn!= "" & donor_type == "Deceased" & inlist(organ, 8, 9) &  donor_excluded == 0 & NSW_donor == 1 & recip_excluded == 0
bysort donor_ppn: egen ever_donated_in_nsw = max(NSW_recip)
drop if ever_donated_in_nsw == 0
count if NSW_recip == 0

** Lung donors

use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn != "" & inlist(organ, 2, 7)
distinct donor_ppn
drop if donor_excluded != 0
distinct donor_ppn
keep if NSW_donor == 1
distinct donor_ppn
drop if NSW_recip != 1
distinct donor_ppn
drop if recip_excluded != 0
distinct donor_ppn
save "${output_path}\\lung_donations_included.dta", replace

**** Count of included donors donating outside NSW
use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn!= "" & donor_type == "Deceased" & inlist(organ, 2, 7) &  donor_excluded == 0 & NSW_donor == 1 & recip_excluded == 0
bysort donor_ppn: egen ever_donated_in_nsw = max(NSW_recip)
drop if ever_donated_in_nsw == 0
count if NSW_recip == 0

** Heart donors

use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn != "" & inlist(organ, 3)
distinct donor_ppn
drop if donor_excluded != 0
distinct donor_ppn
keep if NSW_donor == 1
distinct donor_ppn
drop if NSW_recip != 1
distinct donor_ppn
drop if recip_excluded != 0
distinct donor_ppn
save "${output_path}\\heart_donations_included.dta", replace

** Pancreas donors

use "${output_path}\\master_transplants.dta", clear
keep if donor_ppn != "" & inlist(organ, 5)
distinct donor_ppn
drop if donor_excluded != 0
distinct donor_ppn
keep if NSW_donor == 1
distinct donor_ppn
drop if NSW_recip != 1
distinct donor_ppn
drop if recip_excluded != 0
distinct donor_ppn
save "${output_path}\\pancreas_donations_included.dta", replace

** LK recipients

use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & donor_type == "Living" & organ == 6
distinct recipient_ppn
drop if recip_excluded != 0
distinct recipient_ppn
gen year = yofd(transplantdate)
keep if inrange(year, 2004, 2019) | donor_ppn != ""
distinct recipient_ppn
keep if NSW_recip == 1
distinct recipient_ppn
drop if NSW_donor != 1
distinct recipient_ppn
drop if donor_excluded != 0
distinct recipient_ppn

** Deceased kidney recipients

use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & donor_type == "Deceased" & inlist(organ, 1, 6)
distinct recipient_ppn
drop if recip_excluded != 0
distinct recipient_ppn
gen year = yofd(transplantdate)
keep if inrange(year, 2000, 2019) | donor_ppn != ""
distinct recipient_ppn
keep if NSW_recip == 1
distinct recipient_ppn
drop if NSW_donor != 1
distinct recipient_ppn
drop if donor_excluded != 0
distinct recipient_ppn

** Liver recipients

use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & inlist(organ, 8, 9)
distinct recipient_ppn
drop if donor_type == "Living" & donor_ppn == ""
distinct recipient_ppn
drop if recip_excluded != 0
distinct recipient_ppn
keep if NSW_recip == 1
distinct recipient_ppn
drop if NSW_donor != 1
distinct recipient_ppn
drop if donor_excluded != 0
distinct recipient_ppn

** Lung recipients

use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & inlist(organ, 2, 7)
distinct recipient_ppn
drop if recip_excluded != 0
distinct recipient_ppn
keep if NSW_recip == 1
distinct recipient_ppn
drop if NSW_donor != 1
distinct recipient_ppn
drop if donor_excluded != 0
distinct recipient_ppn

** Heart recipients

use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & inlist(organ, 3)
drop if recipient_ppn == "00000006619051" & donor_ppn == "00000002882455"
distinct recipient_ppn
drop if recip_excluded != 0
distinct recipient_ppn
keep if NSW_recip == 1
distinct recipient_ppn
drop if NSW_donor != 1
distinct recipient_ppn
drop if donor_excluded != 0
distinct recipient_ppn

** Pancreas recipients

use "${output_path}\\master_transplants.dta", clear
keep if recipient_ppn != "" & inlist(organ, 5)
distinct recipient_ppn
drop if recip_excluded != 0
distinct recipient_ppn
keep if NSW_recip == 1
distinct recipient_ppn
drop if NSW_donor != 1
distinct recipient_ppn
drop if donor_excluded != 0
distinct recipient_ppn

*** Repeat recipients

foreach i in total_kidney living_kidney deceased_kidney liver lung heart pancreas {
	use "${output_path}\\`i'_donations_included.dta", clear
	duplicates tag recipient_ppn, gen(d)
	di "`i'"
	tab d
}


****

use "${output_path}\\master_transplants.dta", clear
drop if recipient_ppn == "00000006619051" & donor_ppn == "00000002882455" & organ == 3
save "${output_path}\\master_transplants.dta", replace

encode organ, gen(organ1)
drop organ
rename organ1 organ

gen organcat = 0
	replace organcat = 1 if inlist(organ, 1, 6)
	replace organcat = 2 if inlist(organ, 8, 9)
	replace organcat = 3 if inlist(organ, 2, 7)
	replace organcat = 4 if organ == 3
	replace organcat = 5 if organ == 5
	
label define organlabel ///
	1 "Kidney" ///      
	2 "Liver" ///
	3 "Lung" ///
	4 "Heart" ///
	5 "Pancreas" ///
	, replace

label values organcat organlabel

gen recorgan = 0
replace recorgan = organ if recipient_ppn != ""

gen donorgan = 0
replace donorgan = organ if donor_ppn != ""

sort recipient_ppn recorgan donor_ppn donorgan

drop recorgan donorgan

save "${output_path}\\master_transplants.dta", replace
keep if NSW_donor == 1 & NSW_recip == 1 & donor_excluded == 0 & recip_excluded == 0
drop NSW* *excluded
save "${output_path}\\donor_recipient_pairs.dta", replace

*** Prepare data for sankey plot

use "${output_path}\\master_transplants.dta", clear
keep if (recip_excluded == 0 | recip_excluded == .) & (donor_excluded == 0 | donor_excluded == .)
drop if donor_type == "Living" & organcat == 1
drop if NSW_donor == 0 & NSW_recip == 0
drop if NSW_donor == . | NSW_recip == .
gen location = "NSW" if NSW_donor == 1
replace location = "Interstate" if NSW_donor == 0
gen destination = "NSW" if NSW_recip == 1
replace destination = "Interstate" if NSW_recip == 0

gen organcount = 0
replace organcount = 0.5 if organ == 8
replace organcount = 2 if inlist(organ, 1, 2)
replace organcount = 1 if organcount == 0



gen path = location+destination
decode organcat, gen(organname)
drop organ
rename organname organ
replace organ = "Kidney" if organ == ""
gen alluvium = organ + path
bysort alluvium: egen freq = sum(organcount)

keep organ path freq location destination alluvium
duplicates drop

expand 2, generate(time1)
gen time = 1
replace time = 2 if time1 == 1
drop time1

gen border = "#000000"


set obs 34

replace organ = "Gap" if organ == ""
replace path = "NSWNSW" if organ == "Gap"
replace freq = 150 if freq == .
replace border = "#FFFFFF" if border == ""
replace alluvium = "Gap1" in 31
replace alluvium = "Gap2" in 32
replace alluvium = "Gap3" in 33
replace alluvium = "Gap4" in 34

replace location = destination if time == 2
replace location = "NSW" if location == ""

gen stratum = 1 if organ == "Kidney" & location == "NSW"
replace stratum = 11 if organ == "Kidney" & location == "Interstate"
replace stratum = 2 if organ == "Lung" & location == "NSW"
replace stratum = 21 if organ == "Lung" & location == "Interstate"
replace stratum = 3 if organ == "Liver" & location == "NSW"
replace stratum = 31 if organ == "Liver" & location == "Interstate"
replace stratum = 4 if organ == "Heart" & location == "NSW"
replace stratum = 41 if organ == "Heart" & location == "Interstate"
replace stratum = 5 if organ == "Pancreas" & location == "NSW"
replace stratum = 51 if organ == "Pancreas" & location == "Interstate"
replace stratum = 12 in 31
replace stratum = 22 in 32
replace stratum = 32 in 33
replace stratum = 42 in 34

expand 2 if organ == "Gap", generate(time1)
replace time = 1 if time1 == 0 & organ == "Gap"
replace time = 2 if time1 == 1 & organ == "Gap"
drop time1

gen lab = location
replace lab = "" if organ == "Gap"
bysort organ location time: egen freqlab = sum(freq)
tostring freqlab, gen(freqstring)
replace lab = lab + " (" + freqstring + ")" if lab != ""

save "${output_path}\\sankey_data.dta", replace

*** Prepare table 1 data ***

use "${output_path}\\donor_recipient_pairs.dta", clear

*** Deceased donors

** Merge with ANZOD for most categories

keep if donor_type == "Deceased"
keep donor_ppn transplantdate
rename donor_ppn ppn
duplicates drop ppn, force
merge m:1 ppn using "${anzdata_path}\42952 AnzodDonors.dta", keep(match) nogen keepusing(weight height donor_age gendercode ethnicorigincode bloodgroupcode deathcategorycode heartbeatingcode)
gen bmi=(weight/(height/100)^2)
drop weight height
gen agecat=""
replace agecat="0-17" if donor_age<18
replace agecat="18-44" if donor_age<45 & agecat==""
replace agecat="45-64" if donor_age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop agecat
gen bmicat=""
replace bmicat="Underweight" if bmi<18.5
replace bmicat="Normal" if bmi<25 & bmicat==""
replace bmicat="Overweight" if bmi<30 & bmicat==""
replace bmicat="Obese" if bmicat==""
encode bmicat, gen(bmi_cat)
drop bmicat

** Merge with APDC for country of birth

merge m:m ppn using "${apdc_path}\apdc_main.dta", keepusing(COUNTRY_OF_BIRTH_SACC)
drop if _merge==2
gen country_of_birth="Australia" if COUNTRY_OF_BIRTH_SACC=="1101" | COUNTRY_OF_BIRTH_SACC=="036"
replace country_of_birth="Unknown" if inlist(COUNTRY_OF_BIRTH_SACC, "0000","0001","0002","0003","")
replace country_of_birth="Other" if country_of_birth==""
drop COUNTRY_OF_BIRTH_SACC
duplicates drop
duplicates tag ppn transplantdate, gen(dup)
drop if dup>0 & country_of_birth=="Other"
drop dup
duplicates tag ppn transplantdate, gen(dup)
drop if dup>0 & country_of_birth=="Australia"
drop dup
drop _merge
gen type="Deceased"

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\deceased_donors_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\deceased_donors_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\deceased_donors_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(donor_age)
egen lowq_age = pctile(donor_age), p(25)
egen highq_age = pctile(donor_age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

encode gendercode, gen(sex)
egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(ethnicorigincode), val(1102 1103 1104)
egen ethnicity_white = anycount(ethnicorigincode), val(10 1101 1202 2000 3000 3103 3205 8100)
egen ethnicity_unknown = anycount(ethnicorigincode), val(0 1)
gen ethnicity_other = 1 if ethnicity_aboriginal == 0 & ethnicity_white == 0 & ethnicity_unknown == 0
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)
egen white_ethnicity = sum(ethnicity_white)
egen unknown_ethnicity = sum(ethnicity_unknown)
egen other_ethnicity = sum(ethnicity_other)
gen ethnicity = 0 if inlist(ethnicorigincode, 1102, 1103, 1104)
replace ethnicity = 1 if inlist(ethnicorigincode, 10, 1101, 1202, 2000, 3000, 3103, 3205, 8100)
replace ethnicity = 2 if inlist(ethnicorigincode, 0, 1)
replace ethnicity = 3 if ethnicity == .

replace deathcategorycode = 7 if deathcategorycode == .
forvalues i = 1/7 {
	egen deathcat`i' = anycount(deathcategorycode), val(`i')
}
egen intracranial = sum(deathcat1)
egen traumaticbrain = sum(deathcat2)
egen cerebralinf = sum(deathcat3)
egen cerebralhyp = sum(deathcat4)
egen othernonneuro = sum(deathcat5)
egen nonneuro = sum(deathcat6)
egen unknown_death = sum(deathcat7)

replace bloodgroupcode = "A" if inlist(bloodgroupcode, "A1", "A2")
replace bloodgroupcode = "AB" if inlist(bloodgroupcode, "A1B", "A2B")
encode bloodgroupcode, gen(bloodgroup_code)
forvalues i = 1/4 {
	egen bloodgroup`i' = anycount(bloodgroup_code), val(`i')
}
egen a_bloodgroup = sum(bloodgroup1)
egen ab_bloodgroup = sum(bloodgroup2)
egen b_bloodgroup = sum(bloodgroup3)
egen o_bloodgroup = sum(bloodgroup4)

egen median_bmi = median(bmi)
egen lowq_bmi = pctile(bmi), p(25)
egen highq_bmi = pctile(bmi), p(75)
forvalues i = 1/4 {
	egen bmi`i' = anycount(bmi_cat), val(`i')
}
egen underweight_bmi = sum(bmi4)
egen normal_bmi = sum(bmi1)
egen overweight_bmi = sum(bmi3)
egen obese_bmi = sum(bmi2)

encode country_of_birth, generate(countryofbirth)
forvalues i = 1/3 {
	egen country`i' = anycount(countryofbirth), val(`i')
}
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

gen donation1 = 1 if heartbeatingcode == "Yes"
gen donation2 = 1 if heartbeatingcode == "No"
egen dbd = sum(donation1)
egen dcd = sum(donation2)

save "${output_path}\deceased_donors_data_linkage_`j'.dta", replace


keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity white_ethnicity other_ethnicity unknown_ethnicity australia_birth other_birth unknown_birth median_bmi highq_bmi lowq_bmi underweight_bmi normal_bmi overweight_bmi obese_bmi a_bloodgroup ab_bloodgroup b_bloodgroup o_bloodgroup intracranial cerebralinf cerebralhyp nonneuro othernonneuro unknown_death traumaticbrain dbd dcd
duplicates drop
xpose, clear varname

order _varname

save "${output_path}\\deceased_donor_table_`j'.dta", replace
}


*** Living donors

use "${output_path}\\donor_recipient_pairs.dta", clear

keep if donor_type == "Living" & organcat == 1
keep donor_ppn transplantdate
rename donor_ppn ppn
duplicates drop

*** Merge with LK donor details for most variables

merge 1:1 ppn using "${anzdata_path}\42952 LKDonorDetails.dta", keep(match) nogen keepusing(ethnicity1code gendercode dateofbirth donationdate height weight)
gen donor_age = trunc((donationdate - dateofbirth)/365.25)
drop dateofbirth donationdate
gen bmi=(weight/(height/100)^2)
drop weight height

gen agecat=""
replace agecat="0-17" if donor_age<18
replace agecat="18-44" if donor_age<45 & agecat==""
replace agecat="45-64" if donor_age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop agecat
gen bmicat=""
replace bmicat="Underweight" if bmi<18.5
replace bmicat="Normal" if bmi<25 & bmicat==""
replace bmicat="Overweight" if bmi<30 & bmicat==""
replace bmicat="Obese" if bmicat==""
encode bmicat, gen(bmi_cat)
drop bmicat


*** Merge with APDC for country of birth

merge 1:m ppn using "${apdc_path}\apdc_main.dta", keepusing(COUNTRY_OF_BIRTH_SACC)
drop if _merge==2
gen country_of_birth="Australia" if COUNTRY_OF_BIRTH_SACC=="1101" | COUNTRY_OF_BIRTH_SACC=="036"
replace country_of_birth="Unknown" if inlist(COUNTRY_OF_BIRTH_SACC, "0000","0001","0002","0003","")
replace country_of_birth="Other" if country_of_birth==""
drop COUNTRY_OF_BIRTH_SACC
duplicates drop
duplicates tag ppn, gen(dup)
drop if dup>0 & country_of_birth=="Other"
drop dup
duplicates tag ppn, gen(dup)
drop if dup>0 & country_of_birth=="Australia"
drop dup
drop _merge

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\living_donors_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\living_donors_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\living_donors_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(donor_age)
egen lowq_age = pctile(donor_age), p(25)
egen highq_age = pctile(donor_age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

encode gendercode, gen(sex)
egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(ethnicity1code), val(1102 1103 1104)
egen ethnicity_white = anycount(ethnicity1code), val(10 1101 1202 2000 3000 3103 3205 8100)
egen ethnicity_unknown = anycount(ethnicity1code), val(0 1)
gen ethnicity_other = 1 if ethnicity_aboriginal == 0 & ethnicity_white == 0 & ethnicity_unknown == 0
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)
egen white_ethnicity = sum(ethnicity_white)
egen unknown_ethnicity = sum(ethnicity_unknown)
egen other_ethnicity = sum(ethnicity_other)
gen ethnicity = 0 if inlist(ethnicity1code, 1102, 1103, 1104)
replace ethnicity = 1 if inlist(ethnicity1code, 10, 1101, 1202, 2000, 3000, 3103, 3205, 8100)
replace ethnicity = 2 if inlist(ethnicity1code, 0, 1)
replace ethnicity = 3 if ethnicity == .

egen median_bmi = median(bmi)
egen lowq_bmi = pctile(bmi), p(25)
egen highq_bmi = pctile(bmi), p(75)
forvalues i = 1/4 {
	egen bmi`i' = anycount(bmi_cat), val(`i')
}
egen underweight_bmi = sum(bmi4)
egen normal_bmi = sum(bmi1)
egen overweight_bmi = sum(bmi3)
egen obese_bmi = sum(bmi2)

encode country_of_birth, generate(countryofbirth)
forvalues i = 1/3 {
	egen country`i' = anycount(countryofbirth), val(`i')
}
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

save "${output_path}\living_donors_data_linkage_`j'.dta", replace

keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity white_ethnicity other_ethnicity unknown_ethnicity australia_birth other_birth unknown_birth median_bmi highq_bmi lowq_bmi underweight_bmi normal_bmi overweight_bmi obese_bmi
duplicates drop
xpose, clear varname

order _varname

save "${output_path}\\living_donor_table_`j'.dta", replace
}


*** Potential donors

use "${orchard_path}\orchard_content.dta", clear
merge m:m ppn using "${output_path}\excluded.dta", keep(master) nogen
keep ppn sex logdate birthdate causeofdeath

merge m:1 ppn using "${output_path}\safebod_ppn_postcode_orchard.dta", nogen keep(master match)
destring postcode, replace force
drop if (postcode >= 2900 & postcode!=.) | inlist(postcode, 2600, 2601, 2602, 2603, 2604, 2605, 2606, 2609, 2610, 2611, 2612, 2614, 2615, 2616) | postcode<=1999
drop if state=="ACT"
drop if country!="Australia" & country!=""

merge m:m ppn using "${apdc_path}\apdc_main.dta", keep(master match) keepusing(STATE_OF_RESIDENCE_RECODE episode_end_date COUNTRY_OF_BIRTH_SACC INDIGENOUS_STATUS birth_date)
gen daydiff = abs(logdate-episode_end_date)
bysort ppn logdate: egen mindaydiff = min(daydiff)
keep if mindaydiff == daydiff
bysort ppn logdate: egen state1 = max(STATE_OF_RESIDENCE)
drop if (state1 == 0 | state1 > 1) & postcode == . & state == ""
drop episode_end_date STATE_OF_RESIDENCE
bysort ppn logdate: egen indig = min(INDIGENOUS)
drop if INDIGENOUS != indig
duplicates drop

gen country_of_birth="Australia" if COUNTRY_OF_BIRTH_SACC=="1101" | COUNTRY_OF_BIRTH_SACC=="036"
replace country_of_birth="Unknown" if inlist(COUNTRY_OF_BIRTH_SACC, "0000","0001","0002","0003","")
replace country_of_birth="Other" if country_of_birth==""
drop COUNTRY_OF_BIRTH_SACC
duplicates drop
duplicates tag ppn logdate, gen(dup)
drop if dup>0 & country_of_birth=="Other"
drop dup
duplicates tag ppn logdate, gen(dup)
drop if dup>0 & country_of_birth=="Australia"
drop dup
drop _merge

bysort ppn (logdate): gen seq = _n
bysort ppn (logdate): egen finalseq = max(seq)
keep if seq == finalseq
drop seq finalseq

replace birthdate = birth_date if birthdate == .
gen age=trunc((logdate-birthdate)/365)

drop if age < 0

keep ppn logdate sex causeofdeath INDIGENOUS_STATUS country_of_birth birthdate age

rename age donor_age

gen agecat=""
replace agecat="0-17" if donor_age<18
replace agecat="18-44" if donor_age<45 & agecat==""
replace agecat="45-64" if donor_age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop agecat

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\potential_donors_data_linkage_two.dta", replace
drop linkage
keep if logdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\potential_donors_data_linkage_one.dta", replace

foreach j in one two {
	
	use "${output_path}\potential_donors_data_linkage_`j'.dta", clear
	gen total = _N


egen median_age = median(donor_age)
egen lowq_age = pctile(donor_age), p(25)
egen highq_age = pctile(donor_age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(INDIGENOUS), val(1 2 3 5)
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)

encode country_of_birth, generate(countryofbirth)
forvalues i = 1/3 {
	egen country`i' = anycount(countryofbirth), val(`i')
}
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

merge 1:m logdate birthdate using "W:\PRJ-ORCHARD\3. Data Management\ORCHARD Database\Snapshots\Previous Versions\orchard_20170725.dta", keep(master match) keepusing(otdscauseofdeath) nogen

duplicates drop

replace causeofdeath = 1 if inlist(otdscauseofdeath, 13)
replace causeofdeath = 2 if inlist(otdscauseofdeath, 12)
replace causeofdeath = 3 if inlist(otdscauseofdeath, 10, 11)
replace causeofdeath = 4 if inrange(otdscauseofdeath, 16, 21)
replace causeofdeath = 5 if inlist(otdscauseofdeath, 14, 15)
replace causeofdeath = 6 if inrange(otdscauseofdeath, 1, 9)

replace causeofdeath = 2 if causeofdeath == 100
replace causeofdeath = 4 if causeofdeath == 101
replace causeofdeath = 5 if causeofdeath == 102
replace causeofdeath = 6 if causeofdeath == 103
replace causeofdeath = 7 if causeofdeath == 90
replace causeofdeath = 8 if inlist(causeofdeath, 99, .)
forvalues i = 1/8 {
egen cause`i' = anycount(causeofdeath), val(`i')
}
egen cerebralhyp = sum(cause1)
egen cerebralinf = sum(cause2)
egen intracranial = sum(cause3)
egen nonneuro = sum(cause4)
egen othernonneuro = sum(cause5)
egen traumaticbrain = sum(cause6)
egen didnotdie = sum(cause7)
egen unknown_death = sum(cause8)

save "${output_path}\potential_donors_data_linkage_`j'.dta", replace

keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity australia_birth other_birth unknown_birth cerebralhyp cerebralinf intracranial nonneuro othernonneuro traumaticbrain didnotdie unknown_death
duplicates drop

xpose, clear varname

order _varname

save "${output_path}\\potential_donor_table_`j'.dta", replace

}

*** Kidney recipients

use "${output_path}\\donor_recipient_pairs.dta", clear

keep if organcat == 1

keep recipient_ppn transplantdate

rename recipient_ppn ppn

duplicates drop

*** Merge with anzdata for most variables

merge m:m ppn using "${anzdata_path}\42952 AnzdataPatients.dta", keep(match) nogen keepusing(dateofbirth gendercode birthcountrycode ethnicity1code primaryrenaldiseasecode height weight)

gen age = trunc((transplantdate-dateofbirth)/365.25)
drop dateofbirth
gen bmi=(weight/(height/100)^2)
drop weight height
gen agecat=""
replace agecat="0-17" if age<18
replace agecat="18-44" if age<45 & agecat==""
replace agecat="45-64" if age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop agecat
gen bmicat=""
replace bmicat="Underweight" if bmi<18.5
replace bmicat="Normal" if bmi<25 & bmicat==""
replace bmicat="Overweight" if bmi<30 & bmicat==""
replace bmicat="Obese" if bmicat==""
encode bmicat, gen(bmi_cat)

gen renaldisease=.
replace renaldisease=1 if primaryrenaldiseasecode==0
replace renaldisease=2 if primaryrenaldiseasecode==1
replace renaldisease=3 if inrange(primaryrenaldiseasecode, 100, 182)
replace renaldisease=3 if inrange(primaryrenaldiseasecode, 190, 199)
replace renaldisease=4 if primaryrenaldiseasecode==302
replace renaldisease=5 if inrange(primaryrenaldiseasecode, 400, 499)
replace renaldisease=6 if primaryrenaldiseasecode==500
replace renaldisease=7 if inrange(primaryrenaldiseasecode, 800, 899)
replace renaldisease = 1 if renaldisease== .

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\kidney_recip_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\kidney_recip_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\kidney_recip_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(age)
egen lowq_age = pctile(age), p(25)
egen highq_age = pctile(age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

encode gendercode, gen(sex)
egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(ethnicity1code), val(1102 1103 1104)
egen ethnicity_white = anycount(ethnicity1code), val(10 1101 1202 2000 3000 3103 3205 8100)
egen ethnicity_unknown = anycount(ethnicity1code), val(0 1)
gen ethnicity_other = 1 if ethnicity_aboriginal == 0 & ethnicity_white == 0 & ethnicity_unknown == 0
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)
egen white_ethnicity = sum(ethnicity_white)
egen unknown_ethnicity = sum(ethnicity_unknown)
egen other_ethnicity = sum(ethnicity_other)
gen ethnicity = 0 if inlist(ethnicity1code, 1102, 1103, 1104)
replace ethnicity = 1 if inlist(ethnicity1code, 10, 1101, 1202, 2000, 3000, 3103, 3205, 8100)
replace ethnicity = 2 if inlist(ethnicity1code, 0, 1)
replace ethnicity = 3 if ethnicity == .

egen median_bmi = median(bmi)
egen lowq_bmi = pctile(bmi), p(25)
egen highq_bmi = pctile(bmi), p(75)
forvalues i = 1/4 {
	egen bmi`i' = anycount(bmi_cat), val(`i')
}
egen underweight_bmi = sum(bmi4)
egen normal_bmi = sum(bmi1)
egen overweight_bmi = sum(bmi3)
egen obese_bmi = sum(bmi2)

replace birthcountrycode = 1 if birthcountrycode == 10
replace birthcountrycode = 3 if inlist(birthcountrycode, 999, .)
replace birthcountrycode = 2 if birthcountrycode > 3
forvalues i = 1/3 {
	egen country`i' = anycount(birthcountrycode), val(`i')
}
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

forvalues i = 1/7 {
	egen renal`i' = anycount(renaldisease), val(`i')
}
egen glomerular = sum(renal3)
egen hypertension = sum(renal4)
egen polycystic = sum(renal5)
egen refluxneph = sum(renal6)
egen diabetes = sum(renal7)
egen otherrenal = sum(renal1)
egen unknownrenal = sum(renal2)

save "${output_path}\kidney_recip_data_linkage_`j'.dta", replace


keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity white_ethnicity other_ethnicity unknown_ethnicity australia_birth other_birth unknown_birth glomerular hypertension polycystic refluxneph diabetes otherrenal unknownrenal median_bmi lowq_bmi highq_bmi underweight_bmi normal_bmi overweight_bmi obese_bmi
duplicates drop
xpose, clear varname
order _varname

save "${output_path}\\kidney_recip_table_`j'.dta", replace
}


*** Liver recipients

use "${output_path}\\donor_recipient_pairs.dta", clear

keep if organcat == 2

keep recipient_ppn transplantdate

*** Gain most variables from ANTLU

rename recipient_ppn ppn
merge m:m ppn using "${output_path}\antlu_recip_tidy.dta", keep(match) keepusing(birthdate birthcountry gender bloodgroup diagnosis1) nogen
gen birth_date=dofC(birthdate)
format birth_date %td
drop birthdate
duplicates drop

gen age = trunc((transplantdate-birth_date)/365.25)
gen agecat=""
replace agecat="0-17" if age<18
replace agecat="18-44" if age<45 & agecat==""
replace agecat="45-64" if age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)

*** merge with APDC for indigenous status

merge m:m ppn using "${apdc_path}\apdc_main.dta", keep(master match) keepusing(INDIGENOUS_STATUS) nogen
bysort ppn transplantdate: gen entries = _N
gen aboriginal_any = 1 if inlist(INDIGENOUS_STATUS, 1, 2, 3, 5)
replace aboriginal_any = 0 if aboriginal_any == .
bysort ppn transplantdate: egen indig = sum(aboriginal_any)
gen aboriginal_status = 0
replace aboriginal_status = 1 if entries < 3 & indig == 1
replace aboriginal_status = 1 if entries > 2 & indig > 1
keep ppn transplantdate birthcountry gender bloodgroup diagnosis1 age agecat age_category aboriginal_status
duplicates drop

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\liver_recip_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\liver_recip_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\liver_recip_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(age)
egen lowq_age = pctile(age), p(25)
egen highq_age = pctile(age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

encode gender, gen(sex)
egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen aboriginal_ethnicity = sum(aboriginal_status)


gen country = "AUSTRALIA" if birthcountry == "AUSTRALIA"
replace country = "UNKNOWN" if birthcountry == "UNKNOWN"
replace country = "OTHER" if country == ""
gen country1 = 1 if birthcountry == "AUSTRALIA"
gen country3 = 1 if birthcountry == "UNKNOWN"
gen country2 = 1 if country1 == . & country3 == .
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

gen liverdisease = .
replace liverdisease = 1 if diagnosis1 == "HCV"
replace liverdisease = 2 if diagnosis1 == "HCC"
replace liverdisease = 3 if diagnosis1 == "Alcoholic cirrhosis"
replace liverdisease = 4 if diagnosis1 == "Cirrhosis - Non Alcoholic Fatty Liver (NAFLD or NASH)"
replace liverdisease = 5 if diagnosis1 == "Primary sclerosing cholangitis"
replace liverdisease = 6 if diagnosis1 == "HBV"
replace liverdisease = 1 if diagnosis1 == "HBV, HCV"
replace liverdisease = 7 if liverdisease == .

forvalues i = 1/7 {
	egen liver`i' = anycount(liverdisease), val(`i')
}
egen hcv = sum(liver1)
egen hcc = sum(liver2)
egen cirrhosis = sum(liver3)
egen nafld = sum(liver4)
egen cholangitis = sum(liver5)
egen hbv = sum(liver6)
egen otherliver = sum(liver7)

encode bloodgroup, gen(bloodgroup_code)
forvalues i = 1/4 {
	egen bloodgroup`i' = anycount(bloodgroup_code), val(`i')
}
egen a_bloodgroup = sum(bloodgroup1)
egen ab_bloodgroup = sum(bloodgroup2)
egen b_bloodgroup = sum(bloodgroup3)
egen o_bloodgroup = sum(bloodgroup4)

save "${output_path}\liver_recip_data_linkage_`j'.dta", replace

keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity australia_birth other_birth unknown_birth hcv hcc cirrhosis nafld cholangitis hbv otherliver o_bloodgroup a_bloodgroup b_bloodgroup ab_bloodgroup
duplicates drop
xpose, clear varname
order _varname

save "${output_path}\\liver_recip_table_`j'.dta", replace
}


*** Pancreas recipients

use "${output_path}\\donor_recipient_pairs.dta", clear

keep if organcat == 5

keep recipient_ppn transplantdate

*** Gain most variables from ANZIPTR

rename recipient_ppn ppn
merge m:m ppn using "${anziptr_path}\anziptr_content.dta", keep(match) nogen keepusing(patient_birthdate patient_ethnicity patient_country patient_bloodgroup)
duplicates drop

gen age = trunc((transplantdate-patient_birthdate)/365.25)
gen agecat=""
replace agecat="0-17" if age<18
replace agecat="18-44" if age<45 & agecat==""
replace agecat="45-64" if age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)

** Merge with APDC for sex

merge m:m ppn using "${apdc_path}\apdc_main.dta", keep(master match) keepusing(SEX) nogen

gen male = 1 if SEX == 1
gen female = 1 if SEX == 2
bysort ppn: egen malecount = sum(male)
bysort ppn: egen femcount = sum(female)

gen gender = "Male" if malecount > femcount
replace gender = "Female" if malecount < femcount

drop SEX male* fem*
duplicates drop

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\panc_recip_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\panc_recip_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\panc_recip_data_linkage_`j'.dta", clear
	drop if patient_ethnicity == .
	gen total = _N

egen median_age = median(age)
egen lowq_age = pctile(age), p(25)
egen highq_age = pctile(age), p(75)
egen age_1 = anycount(age_category), val(0)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(1)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(2)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(3)
egen age_65_plus = sum(age_4)

encode gender, gen(sex)
egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(patient_ethnicity), val(2 3 4)
egen ethnicity_white = anycount(patient_ethnicity), val(1 6 16 17 18 19 34)
egen ethnicity_unknown = anycount(patient_ethnicity), val(99)
replace ethnicity_unknown = 1 if patient_ethnicity == .
gen ethnicity_other = 1 if ethnicity_aboriginal == 0 & ethnicity_white == 0 & ethnicity_unknown == 0
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)
egen white_ethnicity = sum(ethnicity_white)
egen unknown_ethnicity = sum(ethnicity_unknown)
egen other_ethnicity = sum(ethnicity_other)
gen ethnicity = 0 if inlist(patient_ethnicity, 2, 3, 4)
replace ethnicity = 1 if inlist(patient_ethnicity, 1, 6, 16, 17, 18. 19, 34)
replace ethnicity = 3 if inlist(patient_ethnicity, 99, .)
replace ethnicity = 2 if ethnicity == .


gen country1 = 1 if patient_country == 1
gen country3 = 1 if patient_country == 99
gen country2 = 1 if country1 == . & country3 == .
gen country = 1 if patient_country == 1
replace country = 2 if patient_country == 99
replace country = 3 if country == .
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

forvalues i = 1/4 {
	egen bloodgroup`i' = anycount(patient_bloodgroup), val(`i')
}
egen o_bloodgroup = sum(bloodgroup1)
egen a_bloodgroup = sum(bloodgroup2)
egen b_bloodgroup = sum(bloodgroup3)
egen ab_bloodgroup = sum(bloodgroup4)

save "${output_path}\panc_recip_data_linkage_`j'.dta", replace

keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity white_ethnicity other_ethnicity unknown_ethnicity australia_birth other_birth unknown_birth o_bloodgroup a_bloodgroup b_bloodgroup ab_bloodgroup
duplicates drop
xpose, clear varname
order _varname


save "${output_path}\\pancreas_recip_table_`j'.dta", replace

}

*** Lung recipients

use "${output_path}\\donor_recipient_pairs.dta", clear

keep if organcat == 3

keep recipient_ppn transplantdate

*** Gain variables from APDC

rename recipient_ppn ppn
merge m:m ppn using "${apdc_path}\apdc_main.dta", keep(match master) nogen keepusing(SEX birth_date INDIGENOUS_STATUS COUNTRY_OF_BIRTH_SACC)
duplicates drop

bysort ppn SEX: gen obs = _N
bysort ppn: egen maxobs = max(obs)
keep if obs == maxobs
drop obs maxobs

bysort ppn birth_date: gen obs = _N
bysort ppn: egen maxobs = max(obs)
keep if obs == maxobs
drop obs maxobs

duplicates tag ppn, gen(dup)
gen indig_report=1 if INDIGENOUS_STATUS!=4 & INDIGENOUS_STATUS!=9 & INDIGENOUS_STATUS!=8
bysort ppn: egen total_indig_report=total(indig_report)
gen indig=1 if total_indig_report>1
replace indig=1 if total_indig_report==1 & dup<3
replace indig=0 if indig==.
drop INDIGENOUS_STATUS dup indig_report total_indig_report
duplicates drop

gen birthcountry="Australia" if COUNTRY_OF_BIRTH_SACC=="1101" | COUNTRY_OF_BIRTH_SACC=="036"
replace birthcountry="Unknown" if inlist(COUNTRY_OF_BIRTH_SACC, "0000","0001","0002","0003","")
replace birthcountry="Other" if birthcountry==""
drop COUNTRY_OF_BIRTH_SACC
gen countrycode = 0
replace countrycode = 1 if birthcountry == "Australia"
replace countrycode = 2 if birthcountry != "Australia" & birthcountry != "Unknown"
bysort ppn: egen countrycodemax = max(countrycode)
keep if countrycode == countrycodemax
drop birthcountry
drop countrycodemax
duplicates drop

gen age = trunc((transplantdate-birth_date)/365.25)
gen agecat=""
replace agecat="0-17" if age<18
replace agecat="18-44" if age<45 & agecat==""
replace agecat="45-64" if age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop birth_date
duplicates drop

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\lung_recip_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\lung_recip_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\lung_recip_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(age)
egen lowq_age = pctile(age), p(25)
egen highq_age = pctile(age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

egen sex_female = anymatch(SEX), val(2)
egen sex_male = anymatch(SEX), val(1)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(indig), val(1)
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)


gen country1 = 1 if countrycode == 1
gen country3 = 1 if countrycode == 0
gen country2 = 1 if country1 == . & country3 == .
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3) 

save "${output_path}\lung_recip_data_linkage_`j'.dta", replace

keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity australia_birth other_birth unknown_birth
duplicates drop
xpose, clear varname
order _varname

save "${output_path}\\lung_recip_table_`j'.dta", replace

}

*** Heart recipients

use "${output_path}\\donor_recipient_pairs.dta", clear

keep if organcat == 4

keep recipient_ppn transplantdate

*** Gain variables from APDC

rename recipient_ppn ppn
merge m:m ppn using "${apdc_path}\apdc_main.dta", keep(match master) nogen keepusing(SEX birth_date INDIGENOUS_STATUS COUNTRY_OF_BIRTH_SACC)
duplicates drop

bysort ppn SEX: gen obs = _N
bysort ppn: egen maxobs = max(obs)
keep if obs == maxobs
drop obs maxobs

bysort ppn birth_date: gen obs = _N
bysort ppn: egen maxobs = max(obs)
keep if obs == maxobs
drop obs maxobs

duplicates tag ppn, gen(dup)
gen indig_report=1 if INDIGENOUS_STATUS!=4 & INDIGENOUS_STATUS!=9 & INDIGENOUS_STATUS!=8
bysort ppn: egen total_indig_report=total(indig_report)
gen indig=1 if total_indig_report>1
replace indig=1 if total_indig_report==1 & dup<3
replace indig=0 if indig==.
drop INDIGENOUS_STATUS dup indig_report total_indig_report
duplicates drop

gen birthcountry="Australia" if COUNTRY_OF_BIRTH_SACC=="1101" | COUNTRY_OF_BIRTH_SACC=="036"
replace birthcountry="Unknown" if inlist(COUNTRY_OF_BIRTH_SACC, "0000","0001","0002","0003","")
replace birthcountry="Other" if birthcountry==""
drop COUNTRY_OF_BIRTH_SACC
gen countrycode = 0
replace countrycode = 1 if birthcountry == "Australia"
replace countrycode = 2 if birthcountry != "Australia" & birthcountry != "Unknown"
bysort ppn: egen countrycodemax = max(countrycode)
keep if countrycode == countrycodemax
drop birthcountry
drop countrycodemax
duplicates drop

gen age = trunc((transplantdate-birth_date)/365.25)
gen agecat=""
replace agecat="0-17" if age<18
replace agecat="18-44" if age<45 & agecat==""
replace agecat="45-64" if age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop birth_date
duplicates drop

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\heart_recip_data_linkage_two.dta", replace
drop linkage
keep if transplantdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\heart_recip_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\heart_recip_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(age)
egen lowq_age = pctile(age), p(25)
egen highq_age = pctile(age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

egen sex_female = anymatch(SEX), val(2)
egen sex_male = anymatch(SEX), val(1)
egen male = sum(sex_male)
egen female = sum(sex_female)

egen ethnicity_aboriginal = anycount(indig), val(1)
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)


gen country1 = 1 if countrycode == 1
gen country3 = 1 if countrycode == 0
gen country2 = 1 if country1 == . & country3 == .
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

save "${output_path}\heart_recip_data_linkage_`j'.dta", replace

keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity australia_birth other_birth unknown_birth
duplicates drop
xpose, clear varname
order _varname
save "${output_path}\\heart_recip_table_`j'.dta", replace

}

*** Waitlisted ppns
use "${anzdata_path}\42952 OMStatusHistory", clear
bysort ppn: gen enddate = waitdate[_n+1]
replace enddate = 21913 if enddate == .
format enddate %td
keep if waitstatus == 2
keep ppn *date
duplicates drop
merge m:m ppn using "${output_path}\excluded.dta", keep(master) nogen

** Find NSW residents in waitlist

*** Using organmatch
rename ppn Recipient_PPN
merge m:m Recipient_PPN using "${organmatch_path}\prj2017272_organmatch_details_v3", keep(match master) keepusing(RECIPIENT_RES_STATE) nogen
gen nsw_flag = 0
replace nsw_flag = 1 if RECIPIENT_RES == "NSW"
bysort Recipient_PPN: egen nsw_res = max(nsw_flag)
rename Recipient_PPN ppn
keep ppn nsw_res *date
duplicates drop

*** Using anzdata
merge m:1 ppn using "${anzdata_path}\42952 AnzdataPatients", keep(match) nogen keepusing(initialparentcentrestate currentparentcentrestate)
replace nsw_res = 1 if inlist(2, initialparentcentrestate, currentparentcentrestate)
keep ppn nsw_res *date

*** Using APDC
merge m:m ppn using "${apdc_path}\apdc_main.dta", keepusing(STATE_OF_RESIDENCE episode_start_date) keep(match master) nogen
duplicates drop
replace nsw_res = 1 if STATE_OF_RESIDENCE == 1 & inrange(episode_start_date, waitdate, enddate)
keep ppn nsw_res
duplicates drop
bysort ppn: egen nsw_resident = max(nsw_res)
keep ppn nsw_resident
duplicates drop
keep if nsw_resident == 1
keep ppn
save "${output_path}\waitlist_nsw", replace

*** Table 1 for this cohort (variables from anzdata)
merge 1:m ppn using "${anzdata_path}\42952 OMStatusHistory", keep(match) keepusing(waitdate waitstatus) nogen
keep if waitstatus == 2
bysort ppn (waitdate): gen seq = _n
keep if seq == 1
keep ppn waitdate
save "${output_path}\waitlist_nsw", replace
merge 1:1 ppn using "${anzdata_path}\42952 AnzdataPatients", keep(match) nogen keepusing(dateofbirth gendercode birthcountrycode ethnicity1code primaryrenaldiseasecode height weight)

gen age = trunc((waitdate-dateofbirth)/365.25)
drop dateofbirth
gen bmi=(weight/(height/100)^2)
drop weight height
gen agecat=""
replace agecat="0-17" if age<18
replace agecat="18-44" if age<45 & agecat==""
replace agecat="45-64" if age<65 & agecat==""
replace agecat="65+" if agecat==""
encode agecat, gen(age_category)
drop agecat
gen bmicat=""
replace bmicat="Underweight" if bmi<18.5
replace bmicat="Normal" if bmi<25 & bmicat==""
replace bmicat="Overweight" if bmi<30 & bmicat==""
replace bmicat="Obese" if bmicat==""
encode bmicat, gen(bmi_cat)
drop bmicat

gen renaldisease=.
replace renaldisease=1 if primaryrenaldiseasecode==0
replace renaldisease=2 if primaryrenaldiseasecode==1
replace renaldisease=3 if inrange(primaryrenaldiseasecode, 100, 182)
replace renaldisease=3 if inrange(primaryrenaldiseasecode, 190, 199)
replace renaldisease=4 if primaryrenaldiseasecode==302
replace renaldisease=5 if inrange(primaryrenaldiseasecode, 400, 499)
replace renaldisease=6 if primaryrenaldiseasecode==500
replace renaldisease=7 if inrange(primaryrenaldiseasecode, 800, 899)
replace renaldisease = 1 if renaldisease== .

** Make summary stats then transpose dataset

gen linkage = 2
save "${output_path}\waitlist_recip_data_linkage_two.dta", replace
drop linkage
keep if waitdate<mdy(1,1,2016)
gen linkage = 1
save "${output_path}\waitlist_recip_data_linkage_one.dta", replace

foreach j in one two {
	use "${output_path}\waitlist_recip_data_linkage_`j'.dta", clear
	gen total = _N

egen median_age = median(age)
egen lowq_age = pctile(age), p(25)
egen highq_age = pctile(age), p(75)
egen age_1 = anycount(age_category), val(1)
egen age_0_17 = sum(age_1)
egen age_2 = anycount(age_category), val(2)
egen age_18_44 = sum(age_2)
egen age_3 = anycount(age_category), val(3)
egen age_45_64 = sum(age_3)
egen age_4 = anycount(age_category), val(4)
egen age_65_plus = sum(age_4)

encode gendercode, gen(sex)
egen sex_female = anymatch(sex), val(1)
egen sex_male = anymatch(sex), val(2)
egen male = sum(sex_male)
egen female = sum(sex_female)


gen ethnicity = 0 if inlist(ethnicity1code, 1102, 1103, 1104)
replace ethnicity = 1 if inlist(ethnicity1code, 10, 1101, 1202, 2000, 3000, 3103, 3205, 8100)
replace ethnicity = 2 if inlist(ethnicity1code, 0, 1)
replace ethnicity = 3 if ethnicity == .
egen ethnicity_aboriginal = anycount(ethnicity1code), val(1102 1103 1104)
egen ethnicity_white = anycount(ethnicity1code), val(10 1101 1202 2000 3000 3103 3205 8100)
egen ethnicity_unknown = anycount(ethnicity1code), val(0 1)
gen ethnicity_other = 1 if ethnicity_aboriginal == 0 & ethnicity_white == 0 & ethnicity_unknown == 0
egen aboriginal_ethnicity = sum(ethnicity_aboriginal)
egen white_ethnicity = sum(ethnicity_white)
egen unknown_ethnicity = sum(ethnicity_unknown)
egen other_ethnicity = sum(ethnicity_other)

egen median_bmi = median(bmi)
egen lowq_bmi = pctile(bmi), p(25)
egen highq_bmi = pctile(bmi), p(75) 
forvalues i = 1/4 {
	egen bmi`i' = anycount(bmi_cat), val(`i')
}
egen underweight_bmi = sum(bmi4)
egen normal_bmi = sum(bmi1)
egen overweight_bmi = sum(bmi3)
egen obese_bmi = sum(bmi2)

replace birthcountrycode = 1 if birthcountrycode == 10
replace birthcountrycode = 3 if inlist(birthcountrycode, 999, .)
replace birthcountrycode = 2 if birthcountrycode > 3
forvalues i = 1/3 {
	egen country`i' = anycount(birthcountrycode), val(`i')
}
egen australia_birth = sum(country1)
egen other_birth = sum(country2)
egen unknown_birth = sum(country3)

forvalues i = 1/7 {
	egen renal`i' = anycount(renaldisease), val(`i')
}
egen glomerular = sum(renal3)
egen hypertension = sum(renal4)
egen polycystic = sum(renal5)
egen refluxneph = sum(renal6)
egen diabetes = sum(renal7)
egen otherrenal = sum(renal1)
egen unknownrenal = sum(renal2)

save "${output_path}\waitlist_recip_data_linkage_`j'.dta", replace


keep total median_age lowq_age highq_age age_0_17 age_18_44 age_45_64 age_65_plus female aboriginal_ethnicity white_ethnicity other_ethnicity unknown_ethnicity australia_birth other_birth unknown_birth glomerular hypertension polycystic refluxneph diabetes otherrenal unknownrenal median_bmi lowq_bmi highq_bmi underweight_bmi normal_bmi overweight_bmi obese_bmi
duplicates drop
xpose, clear varname
order _varname

save "${output_path}\\kidney_waitlist_table_`j'.dta", replace

}

*** Create files to compare demographics to those in 
*** previous linkage

foreach i in kidney liver panc heart lung waitlist {
	use "${output_path}\\`i'_recip_data_linkage_one.dta", clear
	append using "${output_path}\\`i'_recip_data_linkage_two.dta", force
	save "${output_path}\\`i'_recip_data_comparison.dta", replace
}

foreach i in living deceased potential {
	use "${output_path}\\`i'_donors_data_linkage_one.dta", clear
	append using "${output_path}\\`i'_donors_data_linkage_two.dta", force
	save "${output_path}\\`i'_donors_data_comparison.dta", replace
}

use "${output_path}\\kidney_recip_data_comparison.dta", clear
ttest age, by(linkage)
tab gendercode linkage, chi2
tab birthcountrycode linkage if birthcountrycode != 3, chi2
tab ethnicity linkage if ethnicity != 2, chi2
ttest bmi, by(linkage)
tab renaldisease linkage, chi2

use "${output_path}\\liver_recip_data_comparison.dta", clear
ttest age, by(linkage)
tab gender linkage, chi2
tab country linkage if country != "UNKNOWN", chi2
tab liverdisease linkage, chi2
tab bloodgroup_code linkage, chi2
tab aboriginal_status linkage, chi2

use "${output_path}\\lung_recip_data_comparison.dta", clear
ttest age, by(linkage)
tab SEX linkage, chi2
tab countrycode linkage, chi2
tab ethnicity_aboriginal linkage, chi2

use "${output_path}\\heart_recip_data_comparison.dta", clear
ttest age, by(linkage)
tab SEX linkage, chi2
tab countrycode linkage, chi2
tab ethnicity_aboriginal linkage, chi2

use "${output_path}\\panc_recip_data_comparison.dta", clear
ttest age, by(linkage)
tab gender linkage, chi2
tab ethnicity linkage, chi2
tab patient_bloodgroup linkage, chi2
tab country linkage, chi2

use "${output_path}\\deceased_donors_data_comparison.dta", clear
ttest donor_age, by(linkage)
tab gendercode linkage, chi2
ttest bmi, by(linkage)
tab ethnicity linkage, chi2
tab countryofbirth linkage if countryofbirth != 3, chi2
tab deathcategorycode linkage if deathcategorycode != 7, chi2
tab bloodgroupcode linkage, chi2
tab heartbeatingcode linkage, chi2

use "${output_path}\\living_donors_data_comparison.dta", clear
ttest donor_age, by(linkage)
tab gendercode linkage, chi2
ttest bmi, by(linkage)
tab ethnicity linkage if ethnicity != 2, chi2
tab countryofbirth linkage if countryofbirth != 3, chi2

use "${output_path}\\potential_donors_data_comparison.dta", clear
ttest donor_age, by(linkage)
tab ethnicity_aboriginal linkage, chi2
tab countryofbirth linkage if countryofbirth != 3, chi2
tab sex linkage if sex != 99, chi2
tab causeofdeath linkage if causeofdeath != 8, chi2

* Find follow up times

** Recipients

use "${output_path}\donor_recipient_pairs.dta", clear
keep recipient_ppn transplantdate
sort recipient_ppn transplantdate
by recipient_ppn: gen obs = _n
keep if obs == 1
drop obs

gen studyend = td(31dec2020)
format studyend %td

rename recipient_ppn ppn

merge 1:m ppn using "${mortality_path}\rbdm_deaths_sensitive.dta", keepusing(DEATH_DATE) keep(master match) nogen
duplicates drop

gen end = DEATH_DATE
replace end = studyend if end == .
format end %td
keep ppn transplantdate end

gen years_follow_up = round((end-transplantdate)/365.25)

summ years_follow_up, d

** LK donors

use "${output_path}\donor_recipient_pairs.dta", clear
keep if donor_type == "Living" & organ == 6
keep donor_ppn transplantdate
rename donor_ppn ppn
gen studyend = td(31dec2020)
format studyend %td

merge 1:m ppn using "${mortality_path}\rbdm_deaths_sensitive.dta", keepusing(DEATH_DATE) keep(master match) nogen
duplicates drop

gen end = DEATH_DATE
replace end = studyend if end == .
format end %td
keep ppn transplantdate end

gen years_follow_up = round((end-transplantdate)/365.25)

summ years_follow_up, d

** Waitlisted

use "${output_path}\waitlist_nsw", clear
gen studyend = td(31dec2020)
format studyend %td

merge 1:m ppn using "${mortality_path}\rbdm_deaths_sensitive.dta", keepusing(DEATH_DATE) keep(master match) nogen
duplicates drop

gen end = DEATH_DATE
replace end = studyend if end == .
format end %td
keep ppn waitdate end

gen years_follow_up = round((end-waitdate)/365.25)

summ years_follow_up, d

*** NUMBERS IN BOTH POTENTIAL DONORS & ACTUAL DONORS

use "${output_path}\potential_donors_data_linkage_two.dta", clear
keep ppn 
duplicates drop
rename ppn donor_ppn

merge 1:m donor_ppn using "${output_path}\donor_recipient_pairs.dta", keep(match) nogen

keep donor_ppn

duplicates drop

*** NUMBERS IN BOTH KIDNEY WAITLIST & KIDNEY RECIPIENT

use "${output_path}\waitlist_nsw", clear
keep ppn
rename ppn recipient_ppn

merge 1:m recipient_ppn using "${output_path}\donor_recipient_pairs.dta", keep(match) nogen

keep recipient_ppn

duplicates drop

*** NUMBER OF RECIPIENTS AND DONORS
use "${output_path}\donor_recipient_pairs.dta", clear
keep recipient_ppn
duplicates drop

use "${output_path}\donor_recipient_pairs.dta", clear
keep donor_ppn
duplicates drop

use "${output_path}\donor_recipient_pairs.dta", clear
keep recipient_ppn donor_ppn
stack recipient_ppn donor_ppn, into(ppn)
drop _stack
duplicates drop

*** TOTAL PARTICIPANTS
append using "${output_path}\waitlist_nsw", force
append using "${output_path}\potential_donors_data_linkage_two.dta", force
keep ppn
duplicates drop

*** Numbers for supplementary figures (flowcharts for waitlist & potential
*** donors)
use "${anzdata_path}\42952 OMStatusHistory", clear
distinct ppn
keep ppn waitstatus
duplicates drop
merge m:1 ppn using "${output_path}\excluded.dta", keep(master) nogen
keep if waitstatus == 2
keep ppn
duplicates drop
count
use "${output_path}\waitlist_nsw", clear
distinct ppn

use "${orchard_path}\orchard_content.dta", clear
merge m:1 ppn using "${output_path}\excluded.dta", keep(master) nogen
use "${output_path}\potential_donors_data_linkage_two.dta", clear