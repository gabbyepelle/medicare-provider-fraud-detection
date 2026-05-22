# Medicare Provider Anomaly Detection
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
Each provider was aggregated to a single row and scored against peers within their specialty using z-scores across three signals:
Payment z-score — average Medicare payment per service vs specialty peers
Services per patient z-score — total services divided by unique patients vs specialty peers
Services per day z-score — total services divided by unique patient days vs specialty peers
Providers scoring above 3 standard deviations from their specialty mean on any signal were flagged as anomalies.

# Key Findings
1. Three of the strongest multi-signal anomalies were Physical Therapists in California, flagged for extremely high services per patient and per day. This is consistent with documented enforcement actions by the DOJ, including a $15M fraud scheme involving LA-area physical therapy clinics billing for services never provided.
2. Cross-validation against revoked providers
Of 7,456 revoked Medicare providers, 4 overlapped with the billing dataset. At a z-score threshold of 3, one was caught — Aafiyah Solutions Inc (IL), flagged for high services per patient (z-score 4.71) and services per day (z-score 5.50), and subsequently revoked for on-site review violations and failure to report.

## Threshold Analysis

| Threshold | Providers Flagged | Revoked Providers Caught |
|-----------|------------------|--------------------------|
| 3 | ~hundreds | 1 of 4 (25%) |
| 2 | 50,638 (4.3%) | 1 of 4 (25%) |

Lowering the threshold to 2 increased noise significantly without improving detection of known bad actors, suggesting z-score > 3 is the more useful operational threshold.

## Limitations

Revocation records and billing data appear to be from different time periods, limiting cross-validation
Revocation reasons include compliance and on-site violations not reflected in billing metrics — billing-only anomaly detection cannot catch all fraud types
High payment z-scores alone are not indicative of fraud — some specialties legitimately bill expensive procedures infrequently

# Queries

01_exploration.sql — row counts, unique providers, specialty distribution
02_anomaly_detection.sql — provider aggregation, z-score calculation, anomaly flagging
03_validation.sql — join against revoked providers, threshold analysis

# Next Steps

Incorporate OIG exclusions list for broader validation
Build a supervised ML model in AWS SageMaker using revoked status as labels
Add procedure-level analysis to flag billing for procedures unusual within a specialty

