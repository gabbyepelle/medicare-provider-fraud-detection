-- ================================================
-- 02_anomaly_detection.sql
-- Goal: Aggregate providers, calculate z-scores
-- across three fraud signals, flag anomalies
-- ================================================

-- Step 1: Aggregate to one row per provider
-- Step 2: Calculate specialty-level averages and std deviations
-- Step 3: Score each provider against their specialty peers
-- Step 4: Flag providers > 3 standard deviations above peers

WITH provider_summary AS (
  SELECT
    Rndrng_NPI,
    Rndrng_Prvdr_Last_Org_Name,
    Rndrng_Prvdr_First_Name,
    Rndrng_Prvdr_Type,
    Rndrng_Prvdr_State_Abrvtn,
    COUNT(DISTINCT HCPCS_Cd) AS unique_procedures,
    SUM(CAST(Tot_Srvcs AS DOUBLE)) AS total_services,
    SUM(CAST(Tot_Benes AS DOUBLE)) AS total_patients,
    SUM(CAST(Tot_Bene_Day_Srvcs AS DOUBLE)) AS total_patient_days,
    AVG(CAST(Avg_Mdcr_Pymt_Amt AS DOUBLE)) AS avg_payment,
    AVG(CAST(Avg_Sbmtd_Chrg AS DOUBLE)) AS avg_submitted_charge,
    ROUND(SUM(CAST(Tot_Srvcs AS DOUBLE)) /
      NULLIF(SUM(CAST(Tot_Benes AS DOUBLE)), 0), 2) AS services_per_patient,
    ROUND(SUM(CAST(Tot_Srvcs AS DOUBLE)) /
      NULLIF(SUM(CAST(Tot_Bene_Day_Srvcs AS DOUBLE)), 0), 2) AS services_per_day
  FROM cms_fraud.providers
  GROUP BY
    Rndrng_NPI,
    Rndrng_Prvdr_Last_Org_Name,
    Rndrng_Prvdr_First_Name,
    Rndrng_Prvdr_Type,
    Rndrng_Prvdr_State_Abrvtn
),

specialty_stats AS (
  SELECT
    Rndrng_Prvdr_Type,
    AVG(avg_payment) AS mean_payment,
    STDDEV(avg_payment) AS std_payment,
    AVG(services_per_patient) AS mean_spp,
    STDDEV(services_per_patient) AS std_spp,
    AVG(services_per_day) AS mean_spd,
    STDDEV(services_per_day) AS std_spd
  FROM provider_summary
  GROUP BY Rndrng_Prvdr_Type
),

scored AS (
  SELECT
    p.*,
    ROUND((p.avg_payment - s.mean_payment) /
      NULLIF(s.std_payment, 0), 2) AS payment_zscore,
    ROUND((p.services_per_patient - s.mean_spp) /
      NULLIF(s.std_spp, 0), 2) AS spp_zscore,
    ROUND((p.services_per_day - s.mean_spd) /
      NULLIF(s.std_spd, 0), 2) AS spd_zscore
  FROM provider_summary p
  JOIN specialty_stats s
    ON p.Rndrng_Prvdr_Type = s.Rndrng_Prvdr_Type
)

SELECT *
FROM scored
WHERE payment_zscore > 3
   OR spp_zscore > 3
   OR spd_zscore > 3
ORDER BY payment_zscore DESC
LIMIT 100;
