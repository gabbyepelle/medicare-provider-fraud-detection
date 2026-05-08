-- ================================================
-- 01_exploration.sql
-- Goal: Understand the structure and scale
-- of the CMS Medicare billing dataset
-- ================================================

-- Total billing records
SELECT COUNT(*) AS total_rows
FROM cms_fraud.providers;

-- Unique providers
SELECT COUNT(DISTINCT Rndrng_NPI) AS unique_providers
FROM cms_fraud.providers;

-- Unique specialties
SELECT COUNT(DISTINCT Rndrng_Prvdr_Type) AS specialties
FROM cms_fraud.providers;

-- Top 10 specialties by provider count
SELECT
  Rndrng_Prvdr_Type,
  COUNT(DISTINCT Rndrng_NPI) AS provider_count
FROM cms_fraud.providers
GROUP BY Rndrng_Prvdr_Type
ORDER BY provider_count DESC
LIMIT 10;

-- Total revoked providers
SELECT COUNT(*) AS total_revoked
FROM cms_fraud.revoked_providers;

-- How many revoked providers overlap with billing data
SELECT COUNT(*) AS matches
FROM cms_fraud.providers p
JOIN cms_fraud.revoked_npi r
  ON p.Rndrng_NPI = r.NPI;
