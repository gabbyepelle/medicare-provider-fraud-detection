# Medicare Provider Fraud Detection
Tools: SQL · Amazon Athena · AWS S3
Data Sources: CMS Medicare Physician & Other Practitioners (data.cms.gov), CMS Revoked Medicare Providers and Suppliers (data.cms.gov) \
Tableau Public Dashboard: https://public.tableau.com/app/profile/gabrielle.epelle/viz/MedicareAnomalyDetection/MedicareAnomalyDetection

## Overview

This project builds a two-stage Medicare provider fraud detection pipeline 
using CMS billing data, cloud infrastructure, and machine learning.

**Stage 1** uses SQL anomaly detection in Amazon Athena to flag providers 
whose billing patterns deviate significantly from specialty peers, scoring 
1.17 million providers across three signals using z-scores.

**Stage 2** trains a logistic regression model using confirmed fraud labels 
from the HHS OIG List of Excluded Individuals and Entities (LEIE), following 
the random undersampling methodology from academic fraud detection research.

Flagged anomalies are cross-referenced against both the CMS Revoked Medicare 
Providers list and the full LEIE to validate detection accuracy. The project 
identifies real excluded providers in the billing data, including several 
excluded in 2024-2025 for excessive billing and program-related fraud.

**Stack:** AWS S3 · Amazon Athena · Python · scikit-learn · Tableau

## Dataset
9,660,647 billing records
1,175,281 unique providers
210 specialties
Raw data stored in AWS S3, queried with Amazon Athena

## Methodology

### Stage 1: SQL Anomaly Detection (Amazon Athena)
Providers were aggregated from 9.6M billing records to one row per provider 
and scored using z-scores across three signals vs specialty peers:
- **Payment z-score** — average Medicare payment per service
- **Services per patient z-score** — total services divided by unique patients
- **Services per day z-score** — total services divided by unique patient days

Providers scoring above 3 standard deviations from their specialty mean on 
any signal were flagged as anomalies.

### Stage 2: Supervised Learning (Python + scikit-learn)
A logistic regression model was trained using LEIE exclusion status as labels, 
following the random undersampling (RUS) methodology from academic fraud 
detection research. Four class ratios (50:50, 65:35, 75:25, 80:20) were tested 
across 10 runs each to ensure stability.

| Class Ratio | Mean F1 | Std F1 | Mean AUC | Std AUC |
|-------------|---------|--------|----------|---------|
| 50:50 | 0.588 | 0.036 | 0.672 | 0.024 |
| 65:35 | 0.229 | 0.045 | 0.665 | 0.019 |
| 75:25 | 0.135 | 0.031 | 0.661 | 0.012 |
| 80:20 | 0.107 | 0.024 | 0.655 | 0.011 |

**Feature importance** showed `spp_zscore` as the strongest predictor 
(coefficient: 0.417), independently validating the anomaly detection approach.


## Key Findings
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

## Threshold Analysis

| Threshold | Providers Flagged | LEIE Matches |
|-----------|------------------|--------------|
| 3 | ~hundreds | 12 |
| 2 | 50,638 (4.3%) | 13 |


Lowering the threshold from 3 to 2 increased flagged providers by 50,000+ but 
identified only 1 additional LEIE match, confirming that z-score > 3 minimizes 
false positives while maintaining detection of known bad actors.

## Logistic Regression Validates Anomaly Detection Signals
The supervised model achieved a mean AUC of 0.672 at a 50:50 class ratio which is  
meaningfully above the 0.5 random baseline. Feature importance analysis 
confirmed `spp_zscore` as the strongest predictor of LEIE exclusion 
(coefficient: 0.417), independently validating that services per patient 
relative to specialty peers is the most meaningful fraud signal.
  

## Queries

- 01_exploration.sql — row counts, unique providers, specialty distribution
- 02_anomaly_detection.sql — provider aggregation, z-score calculation, anomaly flagging
- 03_validation.sql — join against revoked providers, threshold analysis

## Limitations

- Only 198 confirmed LEIE matches limits supervised learning performance
- Labels reflect exclusion status at time of LEIE download, not necessarily 
  during the billing period
- Logistic regression assumes linear relationships while ensemble methods like 
  Random Forest may capture non-linear patterns better

## Next Steps

- Train a Random Forest or Gradient Boosting model for comparison
- Incorporate IQR-based anomaly scores as additional features
- Expand labeled dataset using historical LEIE snapshots
