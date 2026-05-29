## Medicare Provider Anomaly Detection
Tools: SQL · Amazon Athena · AWS S3
Data Sources: CMS Medicare Physician & Other Practitioners (data.cms.gov), CMS Revoked Medicare Providers and Suppliers (data.cms.gov)
Tableau Public Dashboard: https://public.tableau.com/app/profile/gabrielle.epelle/viz/MedicareAnomalyDetection/MedicareAnomalyDetection

# Overview
This project analyzes 9.6 million Medicare billing records across 1.17 million providers to identify anomalous billing patterns that may indicate fraud, waste, or abuse. Providers are scored using z-scores across three metrics and cross-referenced against CMS's list of revoked Medicare providers.

# Dataset
9,660,647 billing records
1,175,281 unique providers
210 specialties
Raw data stored in AWS S3, queried with Amazon Athena

# Methodology
Each provider was aggregated to a single row and scored against peers within their specialty using z-scores across three signals: \
Payment z-score — average Medicare payment per service vs specialty peers \
Services per patient z-score — total services divided by unique patients vs specialty peers \
Services per day z-score — total services divided by unique patient days vs specialty peers \
Providers scoring above 3 standard deviations from their specialty mean on any signal were flagged as anomalies. 

# Key Findings
**1. Anomaly detection flagged a Physical Therapy cluster in California**
Three of the strongest multi-signal anomalies were Physical Therapists in California, 
flagged for extremely high services per patient and per day. This is consistent 
with documented DOJ enforcement actions targeting LA-area physical therapy clinics 
for billing services never provided.

**2. Cross-validation against HHS OIG LEIE**
Of 83,256 excluded entities on the LEIE, 8,608 had valid NPIs. Cross-referencing 
flagged anomalies identified 12 confirmed matches at threshold 3, including:
- A California psychiatrist excluded January 2025 with 49 services per patient 
  (spp z-score: 14.25)
- A New Jersey sports medicine physician excluded June 2025 with 64 services per 
  patient and 40 services per day
- A Montana emergency medicine physician excluded July 2025 with 163,155 total 
  services
- A Texas hematologist excluded in 2015 still appearing in billing data, suggesting 
  an enforcement gap

Of the 12 LEIE matches, exclusion reasons included program-related fraud convictions (1128a1, 5 cases), excessive or unnecessary services (1128b4, 2 cases), kickbacks and prohibited activities (1128a3, 2 cases), and license revocations (1128a4, 2 cases). The presence of 1128b4 exclusions — specifically for excessive billing — directly validates the billing-based anomaly detection approach.
  
# Threshold Analysis

| Threshold | Providers Flagged | LEIE Matches |
|-----------|------------------|--------------|
| 3 | ~hundreds | 12 |
| 2 | 50,638 (4.3%) | 13 |


Lowering the threshold from 3 to 2 increased flagged providers by 50,000+ but 
identified only 1 additional LEIE match, confirming that z-score > 3 minimizes 
false positives while maintaining detection of known bad actors.

# Queries

- 01_exploration.sql — row counts, unique providers, specialty distribution
- 02_anomaly_detection.sql — provider aggregation, z-score calculation, anomaly flagging
- 03_validation.sql — join against revoked providers, threshold analysis

# Limitations

Revocation records and billing data appear to be from different time periods, limiting cross-validation. \
Revocation reasons include compliance and on-site violations not reflected in billing metrics — billing-only anomaly detection cannot catch all fraud types.
High payment z-scores alone are not indicative of fraud — some specialties legitimately bill expensive procedures infrequently.


# Next Steps

Incorporate OIG exclusions list for broader validation
Build a supervised ML model in AWS SageMaker using revoked status as labels
Add procedure-level analysis to flag billing for procedures unusual within a specialty

