-- ================================================
-- 03_validation.sql
-- Goal: Cross-reference flagged anomalies against
-- CMS revoked providers list to evaluate detection
-- accuracy at different thresholds
-- ================================================

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

-- All revoked providers with their z-scores
SELECT
  s.*,
  'REVOKED' AS revocation_status,
  r.REVOCATION_RSN,
  r.REVOCATION_EFCTV_DT
FROM scored s
JOIN cms_fraud.revoked_npi rn ON s.Rndrng_NPI = rn.NPI
JOIN cms_fraud.revoked_providers r ON rn.ENRLMT_ID = r.ENRLMT_ID
ORDER BY payment_zscore DESC;

-- Revoked providers caught at threshold 3
-- SELECT
--   s.*,
--   'REVOKED' AS revocation_status,
--   r.REVOCATION_RSN,
--   r.REVOCATION_EFCTV_DT
-- FROM scored s
-- JOIN cms_fraud.revoked_npi rn ON s.Rndrng_NPI = rn.NPI
-- JOIN cms_fraud.revoked_providers r ON rn.ENRLMT_ID = r.ENRLMT_ID
-- WHERE payment_zscore > 3
--    OR spp_zscore > 3
--    OR spd_zscore > 3
-- ORDER BY payment_zscore DESC;

-- Total flagged at threshold 2 (for threshold analysis)
-- SELECT COUNT(*) AS flagged_count
-- FROM scored
-- WHERE payment_zscore > 2
--    OR spp_zscore > 2
--    OR spd_zscore > 2;
