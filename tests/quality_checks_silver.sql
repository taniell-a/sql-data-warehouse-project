/*
===============================================================================
Quality Checks 
===============================================================================
Scripts Purpose: 
	This script performs various quality checks for data consistency, accuracy, 
	and standardisation across the 'silver' schema. It includes checks for: 
	- Null or duplicate primary keys. 
	- Unwanted spaces in string fields. 
	- Data standardisation and consistency. 
	- Invalid dates ranges and orders. 
	- Data consistency between related fields. 

Usage Notes:
	- Run these checks after data loading silver layer. 
	- Investigate and resolve any discrepancies found during the checks. 
===============================================================================
*/

-- ===============================================================================
-- Checking 'silver.crm_cust_info'
-- ===============================================================================
--Check For Nulls or Duplicates in PK
--Expectation: No Result 
SELECT
cst_id,
COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT (*) >1 OR cst_id IS NULL

--Check for unwanted spaces - firstname
--Expectation: No Results
SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != LTRIM(RTRIM(cst_firstname))

--Check for unwanted spaces - lastname
--Expectation: No Results
SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != LTRIM(RTRIM(cst_lastname))

--Data Standardisation & Consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

SELECT * FROM silver.crm_cust_info
-- ===============================================================================

-- ===============================================================================
-- Checking 'silver.crm_prd_info'
-- ===============================================================================

--Check For Nulls or Duplicates in PK
--Expectation: No Result

SELECT 
prd_id,
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT (*) > 1 OR prd_id IS NULL 

--Check for unwanted spaces 
--Expectation: No Result 
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm!=LTRIM(RTRIM(prd_nm))

--Check for Nulls or Negative Numbers 
--Expectation: No Results
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

--Data Standardisation & Consistency
SELECT DISTINCT prd_line
FROM silver.crm_prd_info

--Check for invalid date orders
SELECT *
FROM silver.crm_prd_info 
WHERE prd_end_dt < prd_start_dt

SELECT *
FROM silver.crm_prd_info 

-- ===============================================================================
-- Checking 'silver.crm_sales_details'
-- ===============================================================================
--Check for Invalid Dates 
SELECT 
NULLIF(sls_due_dt,0)
FROM silver.crm_sales_details
WHERE sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 
OR sls_due_dt > 20200101
OR sls_due_dt < 19000101

--Check for Invalid Date Orders
SELECT
*
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

--Check data consistency: Between Sales, Quantity and Price 
-->> Sales = Quantity * Price 
-->> Values must not be NULL, zero, or negative.

SELECT DISTINCT
sls_sales,
sls_quantity,
sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

SELECT * FROM silver.crm_sales_details

-- ===============================================================================
-- Checking 'silver.erp_cust_az12'
-- ===============================================================================
--identify out-of-range dates
SELECT DISTINCT
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE()

--Data standardisation & consistency 
SELECT DISTINCT 
gen, 
CASE 
	WHEN UPPER(LTRIM(RTRIM(gen))) IN ('F', 'FEMALE') THEN 'Female'
	WHEN UPPER(LTRIM(RTRIM(gen))) IN ('M', 'MALE') THEN 'Male'
	ELSE 'N/A'
END AS gen
FROM silver.erp_cust_az12

SELECT * FROM silver.erp_cust_az12

-- ===============================================================================
-- Checking 'silver.erp_loc_a101'
-- ===============================================================================
--data standardisation and consistency
SELECT DISTINCT
cntry AS old_cntry,
CASE 
	WHEN LTRIM(RTRIM(cntry)) = 'DE' THEN 'Germany'
	WHEN LTRIM(RTRIM(cntry)) IN ('US', 'USA') THEN 'United States'
	WHEN LTRIM(RTRIM(cntry)) = '' OR cntry IS NULL THEN 'N/A'
	ELSE LTRIM(RTRIM(cntry))
END AS cntry
FROM siver.erp_loc_a101
ORDER BY cntry

SELECT DISTINCT cntry
FROM
silver.erp_loc_a101
ORDER BY cntry

SELECT * FROM silver.erp_loc_a101

-- ===============================================================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ===============================================================================
--Check for unwanted spaces 
SELECT * FROM bronze.erp_px_cat_g1v2
	WHERE cat != LTRIM(RTRIM(cat)) 
		OR subcat != LTRIM(RTRIM(subcat)) 
		OR maintenance!= LTRIM(RTRIM(maintenance))
--Data Standardisations & consistency 
SELECT DISTINCT 
cat 
FROM silver.erp_px_cat_g1v2

SELECT DISTINCT 
subcat 
FROM silver.erp_px_cat_g1v2

SELECT DISTINCT 
maintenance 
FROM silver.erp_px_cat_g1v2

