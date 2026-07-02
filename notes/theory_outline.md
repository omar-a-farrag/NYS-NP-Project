# Let's address your final point first: Patient Choice of Hospital.
You correctly identified the main empirical hurdle. Because you are using aggregated CMS data (facility-level and NPI-level tot_benes and tot_srvcs) rather than patient-level microdata (where you track individual Patient John Doe choosing Hospital A over B), you mathematically cannot run a standard individual-level Mixed Logit for demand.

However, you can completely capture patient choice using the Aggregate Demand Framework (Berry 1994 / BLP). Instead of modeling the probability of an individual patient, we model the market share of the facility within its local area as a function of its characteristics (like its MD/NP ratio and HCAHPS scores).

# The Master Plan: Theory to Empirics

## Part 1: The Patient Demand Model (Aggregate Market Shares)
We start by formally defining how patients allocate themselves across facilities based on the labor composition.Let $s_{jt}$ be the market share of facility $j$ in year $t$ (which you can calculate by dividing a facility's tot_benes by the sum of tot_benes for all facilities in that ZIP code/county). We define the mean utility $\delta_{jt}$ of facility $j$ as:

$$\delta_{jt} = \beta_0 + \beta_1 (\text{NP\_Ratio}_{jt}) + \beta_2 (\text{HCAHPS}_{jt}) + \xi_{jt}$$

Following Berry (1994), by taking the natural log of facility $j$'s market share and subtracting the log of the "outside option" share ($s_{0t}$, patients who don't seek care or go elsewhere), we get a perfectly linear equation that you can estimate via OLS or IV:

$$\ln(s_{jt}) - \ln(s_{0t}) = \beta_0 + \beta_1 (\text{NP\_Ratio}_{jt}) + \beta_2 (\text{HCAHPS}_{jt}) + \xi_{jt}$$

The Structural Link: If $\beta_1$ is negative, it proves patients actively avoid facilities that shift away from MDs. If it's positive, it means patients prefer the throughput/access of NP-heavy facilities.

## Part 2: The Provider (Agent) Utility Model
Next, we model the individual provider. This is where your rich sub-group analysis becomes the engine of the structural model.

When provider $k$ treats a patient, they choose a service volume $S_k$ (e.g., partb_srvc_em_99215 vs 99213, or opioid prescribing rates) to maximize their utility:

$$U_k(S_k) = \alpha_k(\text{Ownership}) \cdot \pi(S_k) + \gamma_k(\text{Demographics}) \cdot H(S_k) - C_k(\text{Type}) \cdot S_k^2$$

Here is how your 6 subgroups map directly into the deep parameters of this equation:

1. Profit Weight ($\alpha_k$): Modeled as a function of Hospital Ownership (For-profit docs likely face higher $\alpha_k$ due to RVU targets).

2. Altruism/Practice Style ($\gamma_k$): Modeled as a function of Graduation Decade and Gender. Note: When charting the gender differentials for this parameter, we must ensure the data visualizations explicitly exclude unknown and other categories to maintain a strict focus on the male and female trend lines.

3. Cost of Effort ($C_k$): Modeled as a function of Provider Type (MD vs. NP) and Department.

## Part 3: The Hospital (Principal) Production Function
Knowing how patients react (Part 1) and how providers behave (Part 2), the hospital chooses its target MD/NP ratio. As we discussed, we upgrade the CES to the Translog to allow for flexible substitutability:

$$\ln(Y_{jt}) = \ln(A_{jt}) + \theta_1 \ln(MD_{jt}) + \theta_2 \ln(NP_{jt}) + \frac{1}{2}\theta_3 (\ln MD_{jt})^2 + \frac{1}{2}\theta_4 (\ln NP_{jt})^2 + \theta_5 \ln(MD_{jt})\ln(NP_{jt})$$

Here, the output $Y_{jt}$ can be swapped depending on the setting: hcahps_100_score for quality, or fac_partb_srvc_total for volume.

## Part 4: The Reduced-Form Event Study
Before you estimate those structural parameters ($\beta, \alpha, \gamma, \theta$), you must establish the causal "Stylized Facts" of the 2015 NYS Law.

To estimate how the law changed provider behavior across those subgroups, your primary empirical specification will be a Dynamic Difference-in-Differences (Event Study) framework. For a provider $k$ in facility $j$ at time $t$:

$$Outcome_{kjt} = \sum_{\tau \neq -1} \beta_\tau (\text{NYS}_j \times \text{Year}_{t=\tau}) + \lambda X_{kjt} + \delta_{k} + \gamma_t + \epsilon_{kjt}$$

To rigorously isolate the policy effect from underlying macroeconomic trends or local technological adoption in healthcare, your regression tables should strictly present the models using Tech + Year FE.

# Order of discussion:
## 1. The Reduced Form (Event Study) Goes First
You must establish the causal facts before you build a complex mathematical machine to explain them. If you build the theory first, reviewers will constantly wonder, "Does this even happen in the data?"

In your paper outline, you correctly identified the need for a "Stylized Facts" section. This is exactly where your Event Study belongs. You will introduce the 2015 NYS Nurse Practitioner Modernization Act, explain your empirical strategy, and present the regression tables (using your corrected Tech + Year FE specification).  

By putting the Event Study first, you prove to the reader that the 2015 law definitively shifted hospital staffing and provider behavior. Once they see the undeniable causal effect, you seamlessly transition into the Structural Theory by stating: "To understand the mechanisms driving these reduced-form results, and to simulate counterfactual policies, we now develop a structural model of the healthcare market."

## 2. The Structural Theory (The "Timing of the Game")
When you introduce the structural theory, you should present it expositionally by building the pieces from the bottom up, culminating in the hospital's overarching decision.

- Step 1: Patient Demand (The Market): Start by modeling the patient. You outline how patients experience health shocks and choose a hospital based on its characteristics (HCAHPS scores, MD/NP ratios). This is crucial because it defines the demand curve and the patient volume that the hospital will eventually face.

- Step 2: Provider Utility (The Agent): Next, model what happens once the patient is inside the facility. You will define the provider's utility function, showing how their altruism, cost of effort (based on training), and financial incentives dictate the volume and intensity of services they provide.

- Step 3: Hospital Production (The Principal): This is the grand finale of your theory section. You introduce the Translog production function. The hospital management—fully anticipating how patients will choose facilities (Step 1) and exactly how their providers will behave (Step 2)—chooses the optimal MD/NP ratio to maximize its output subject to its budget constraint.

This specific order prevents you from having to use "forward references" (e.g., "The hospital optimizes this equation, but wait, I haven't told you how patients behave yet..."). It builds the puzzle one logical piece at a time.

