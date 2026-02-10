# Combining CMS, HCAHPS, and MIPS

## Three Stages
### 1) Combine CMS Sets: By Provider, By Provider and Service, and By Part D --> separately by individual and facility
### 2) Combine HCAHPS across years --> by facility
### 3) Combine MIPS --> by individual and facility

## Combining CMS
### 1) Make 5 percent smaples for each data set
### 2) Append then merge:
#### A) merge by individual
#### B) aggregate, then merge by facility
### 3) Things to be cognizant of:
##### - Changes through time in variable names

### 4) Merging:
#### A) Create a diagnostic "script zero"
##### - Test all code on 5 percent samples for quickest debugging
##### - Use flags for: user(paths), 5pct sample
#### B) Create log files
#### C) Use facility names files to match gender of providers for early years 

## Other data I have:
### 1) Hospital infections (2017-present)
### 2) Provider of services (2011-2025) - demographic info of providers and facility and types of services provided

## Departments across time:
### 1) Some, like hospitalist, don't exist through all years
#### A) Because of this and because I restricted the departments when I downloaded the CSVs originally, people like Dr. Ardalan, who was under "Internal Medicine" in 2013 but switched to be under "Hospitalist" in later years, is not included in later years. 