# Phase 2: HCAHPS Unification Methodology

## Overview
Phase 2 integrates CMS Hospital Consumer Assessment of Healthcare Providers and Systems (HCAHPS) data with the Phase 1 Provider and Facility panels. This allows us to observe the structural characteristics and patient satisfaction scores of the acute care hospitals where Medicare providers operate.

## Methodology
1. **Data Sourcing & Alignment:** HCAHPS data from 2007 to 2024 was sourced from CMS. Because CMS data exhibits significant column drift over time, an algorithmic "column sniffer" was deployed in Python to automatically detect and harmonize shifting variable names (e.g., `H_COMP_1_A_P` vs `h_comp_1_a_p`).
2. **Experience Year Lagging:** CMS reports quality metrics with an inherent chronological lag. To accurately correlate physician billing behavior with the environment they operated in, HCAHPS reporting years were lagged by $t-1$ to reflect the actual "Experience Year" (e.g., the 2016 CMS folder maps to 2015 physician behavior).
3. **Network Bifurcation:** The HCAHPS variables were mapped via the 6-digit hospital `CCN`. They were merged via a `1:1` match to create `cms_ultimate_facility_network.dta`, and via a `m:1` match to assign hospital traits to individual physicians in `cms_ultimate_provider_network.dta`.