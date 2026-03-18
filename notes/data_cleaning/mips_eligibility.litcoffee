# Methodological Overview: The Merit-based Incentive Payment System (MIPS)

## 1. What is MIPS?
The Merit-based Incentive Payment System (MIPS) is the primary track of the Quality Payment Program (QPP), established by the Medicare Access and CHIP Reauthorization Act of 2015 (MACRA). MIPS consolidates legacy programs (PQRS, Value Modifier, and the Medicare EHR Incentive Program) into a single overarching system. 

It calculates a composite performance score (0-100) based on four performance categories:
* **Quality** (clinical outcomes and care processes)
* **Cost** (resource use, risk-adjusted)
* **Promoting Interoperability (PI)** (meaningful use of certified EHR technology)
* **Improvement Activities (IA)** (care coordination, patient engagement, and safety)

The MIPS Final Score dictates a positive, negative, or neutral payment adjustment applied to the clinician's Medicare Part B allowed charges two years after the performance period (e.g., 2022 performance dictates 2024 payments).

## 2. Who is Eligible? (MIPS Eligible Clinicians)
MIPS applies specifically to clinicians who bill Medicare Part B for professional services. The definition of a "MIPS Eligible Clinician" has expanded since 2017. 

**Core Clinicians (Eligible since 2017):**
* Physicians (MD, DO, DDS, DDM, DPM, OD)
* Osteopathic Practitioners
* Chiropractors
* Physician Assistants (PAs)
* Nurse Practitioners (NPs)
* Clinical Nurse Specialists (CNSs)
* Certified Registered Nurse Anesthetists (CRNAs)

**Expanded Clinicians (Added over subsequent years):**
* Physical Therapists & Occupational Therapists
* Qualified Speech-Language Pathologists & Audiologists
* Clinical Psychologists
* Registered Dietitians / Nutrition Professionals
* Clinical Social Workers
* Certified Nurse-Midwives

## 3. Exemption Criteria (Who is Excluded from MIPS)
Understanding who is excluded is critical for framing the bounds of empirical analysis. A significant portion of Medicare-enrolled providers are legally exempt from MIPS reporting and payment adjustments.

**A. The Low Volume Threshold (LVT)**
Clinicians or groups are exempt if they fall below **any one** of the following three LVT criteria during the determination period:
1.  Bill less than or equal to $90,000 in Medicare Part B allowed charges.
2.  Provide care for 200 or fewer Part B-enrolled Medicare beneficiaries.
3.  Provide 200 or fewer covered professional services under the Physician Fee Schedule (PFS).
*(Note: Clinicians who exceed some but not all LVT criteria may "opt-in," but are not mandated to participate).*

**B. Advanced APM Participants (Qualifying APM Participants - QPs)**
Clinicians who receive a significant portion of their payments or see a significant portion of their patients through an Advanced Alternative Payment Model (e.g., specific tracks of the Medicare Shared Savings Program ACOs) are completely exempt from MIPS. They are evaluated under the APM framework instead.

**C. Newly Enrolled in Medicare**
Clinicians who enroll in Medicare for the very first time during the performance year are exempt from MIPS for that initial year.

## 4. Empirical Implications and Limitations
When utilizing MIPS data for empirical analysis, researchers must acknowledge the following selection biases and structural limitations:

1.  **Selection Bias of the LVT:** The MIPS dataset inherently truncates low-volume, part-time, or rural clinicians who do not meet the strict LVT criteria. The data represents a higher-volume, systematically distinct subset of the Medicare workforce. 
2.  **The "Advanced APM" Blind Spot:** High-performing, highly integrated networks (like leading ACOs) often graduate into Advanced APMs. Consequently, some of the highest-quality or most cost-efficient providers may vanish from the MIPS dataset, creating potential downward bias in observed market-level quality.
3.  **Facility-Based Scoring Confounding:** For facility-based clinicians (e.g., hospitalists, anesthesiologists, ER physicians who furnish >75% of covered services in inpatient/ER settings), CMS may automatically adopt the hospital's Value-Based Purchasing (VBP) score as the clinician's MIPS Quality and Cost scores. Individual clinical quality cannot be cleanly disentangled from hospital structural quality for these specific providers.
4.  **Extreme and Uncontrollable Circumstances (EUC):** During the COVID-19 Public Health Emergency (particularly impacting performance years 2020-2022), CMS approved widespread EUC exception applications. This led to massive, non-random attrition in the panel data, as clinicians could request category reweighting to zero to avoid penalties.