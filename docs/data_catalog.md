# Data Catalog for Gold Layer

## Overview

The Gold layer is the business-ready representation of the data warehouse. It combines cleansed CRM and ERP data from the Silver layer into dimension and fact views designed for analytics and reporting.

## Gold Layer Objects

| Object | Object Type | Grain | Purpose |
|---|---|---|---|
| `gold.dim_customers` | Dimension view | One row per CRM customer | Provides customer identity, demographic, and geographic attributes. |
| `gold.dim_products` | Dimension view | One row per current product | Provides current product, category, cost, and product-line attributes. |
| `gold.fact_sales` | Fact view | One row per sales-detail record | Provides transaction dates and sales measures linked to customer and product dimensions. |

## Model Relationships

| Fact View | Foreign Key | Dimension View | Dimension Key | Cardinality |
|---|---|---|---|---|
| `gold.fact_sales` | `customer_key` | `gold.dim_customers` | `customer_key` | Many-to-one |
| `gold.fact_sales` | `product_key` | `gold.dim_products` | `product_key` | Many-to-one |

> **Data type note:** The Gold objects are SQL views. Apart from the surrogate keys created with `ROW_NUMBER()`, their data types are inherited from the corresponding Silver-layer columns. In SQL Server, `ROW_NUMBER()` returns `BIGINT`.

---

## 1. `gold.dim_customers`

**Purpose:** Stores customer details enriched with demographic and geographic data from CRM and ERP sources.

**Grain:** One row per CRM customer.

**Source objects:**

- `silver.crm_cust_info`
- `silver.erp_cust_az12`
- `silver.erp_loc_a101`

| Column Name | Data Type | Key Role | Source or Derivation | Description |
|---|---|---|---|---|
| `customer_key` | `BIGINT` | Surrogate primary key | `ROW_NUMBER() OVER (ORDER BY ci.cst_id)` | Warehouse-generated key that uniquely identifies each customer dimension row. |
| `customer_id` | `INT` | Business/source key | `silver.crm_cust_info.cst_id` | Numerical customer identifier from the CRM system. Used to match sales records to customers. |
| `customer_number` | `NVARCHAR(50)` | Alternate business key | `silver.crm_cust_info.cst_key` | Alphanumeric customer reference used to integrate CRM and ERP customer records. |
| `first_name` | `NVARCHAR(50)` | Attribute | `silver.crm_cust_info.cst_firstname` | Customer's first name. |
| `last_name` | `NVARCHAR(50)` | Attribute | `silver.crm_cust_info.cst_lastname` | Customer's last name or family name. |
| `country` | `NVARCHAR(50)` | Attribute | `silver.erp_loc_a101.cntry` | Customer's country of residence from the ERP location source. |
| `marital_status` | `NVARCHAR(50)` | Attribute | `silver.crm_cust_info.cst_marital_status` | Standardised customer marital-status value. |
| `gender` | `NVARCHAR(50)` | Derived attribute | CRM gender when it is not `N/A`; otherwise ERP gender; defaults to `N/A` | Consolidated customer gender. CRM is treated as the preferred source when it contains a usable value. |
| `birthdate` | `DATE` | Attribute | `silver.erp_cust_az12.bdate` | Customer's date of birth. |
| `create_date` | `DATE` | Lifecycle attribute | `silver.crm_cust_info.cst_create_date` | Date on which the customer record was created in CRM. |

### Integration Rules

- CRM customer information is the base dataset.
- ERP demographic information is joined using the CRM customer key.
- ERP location information is joined using the CRM customer key.
- `LEFT JOIN`s retain CRM customers even when matching ERP information is unavailable.
- CRM is the preferred source for gender unless its value is `N/A`.

---

## 2. `gold.dim_products`

**Purpose:** Provides the current version of each product enriched with ERP category and maintenance information.

**Grain:** One row per current product; historical product versions are excluded.

**Source objects:**

- `silver.crm_prd_info`
- `silver.erp_px_cat_g1v2`

| Column Name | Data Type | Key Role | Source or Derivation | Description |
|---|---|---|---|---|
| `product_key` | `BIGINT` | Surrogate primary key | `ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key)` | Warehouse-generated key that uniquely identifies each current product dimension row. |
| `product_id` | `INT` | Source key | `silver.crm_prd_info.prd_id` | Internal numerical product identifier from CRM. |
| `product_number` | `NVARCHAR(50)` | Business key | `silver.crm_prd_info.prd_key` | Alphanumeric product reference used to match sales transactions to products. |
| `product_name` | `NVARCHAR(50)` | Attribute | `silver.crm_prd_info.prd_nm` | Descriptive product name. |
| `category_id` | `NVARCHAR(50)` | Integration key | `silver.crm_prd_info.cat_id` | Product-category identifier used to integrate CRM product and ERP category data. |
| `category` | `NVARCHAR(50)` | Attribute | `silver.erp_px_cat_g1v2.cat` | High-level product category, such as Bikes or Components. |
| `subcategory` | `NVARCHAR(50)` | Attribute | `silver.erp_px_cat_g1v2.subcat` | Detailed product classification within the broader category. |
| `maintenance` | `NVARCHAR(50)` | Attribute | `silver.erp_px_cat_g1v2.maintenance` | Indicates the maintenance classification or requirement associated with the product category. |
| `product_cost` | `INT` | Measure attribute | `silver.crm_prd_info.prd_cost` | Cost assigned to the product in whole monetary units. |
| `product_line` | `NVARCHAR(50)` | Attribute | `silver.crm_prd_info.prd_line` | Product line or series to which the product belongs. |
| `start_date` | `DATE` | Lifecycle attribute | `silver.crm_prd_info.prd_start_dt` | Date from which the current product record became effective. |

### Integration Rules

- CRM product information is the base dataset.
- ERP category information is joined where the CRM category ID matches the ERP category ID.
- A `LEFT JOIN` retains current CRM products when category details are unavailable.
- Only records where `prd_end_dt IS NULL` are included, representing the current product version.

---

## 3. `gold.fact_sales`

**Purpose:** Stores sales transaction measures and dates, with surrogate keys linking each record to the customer and product dimensions.

**Grain:** One row per record in `silver.crm_sales_details`. An order number may appear more than once when an order contains multiple product lines.

**Source objects:**

- `silver.crm_sales_details`
- `gold.dim_products`
- `gold.dim_customers`

| Column Name | Data Type | Key Role | Source or Derivation | Description |
|---|---|---|---|---|
| `order_number` | `NVARCHAR(50)` | Transaction identifier | `silver.crm_sales_details.sls_ord_num` | Alphanumeric sales order reference. It may repeat across multiple line items. |
| `product_key` | `BIGINT` | Foreign key | Matched through `sls_prd_key = dim_products.product_number` | Links the sales record to `gold.dim_products`. May be null if no product match is found. |
| `customer_key` | `BIGINT` | Foreign key | Matched through `sls_cust_id = dim_customers.customer_id` | Links the sales record to `gold.dim_customers`. May be null if no customer match is found. |
| `order_date` | `DATE` | Date | `silver.crm_sales_details.sls_order_dt` | Date on which the order was placed. |
| `shipping_date` | `DATE` | Date | `silver.crm_sales_details.sls_ship_dt` | Date on which the order was shipped. |
| `due_date` | `DATE` | Date | `silver.crm_sales_details.sls_due_dt` | Date by which the order was due. |
| `sales_amount` | `INT` | Measure | `silver.crm_sales_details.sls_sales` | Total sales value recorded for the transaction line in whole monetary units. |
| `quantity` | `INT` | Measure | `silver.crm_sales_details.sls_quantity` | Number of product units recorded for the transaction line. |
| `price` | `INT` | Measure | `silver.crm_sales_details.sls_price` | Unit price recorded for the product in whole monetary units. |

### Integration Rules

- CRM sales details form the base dataset.
- `product_key` is retrieved by matching the source product key to the product dimension's business key.
- `customer_key` is retrieved by matching the source customer ID to the customer dimension's business key.
- `LEFT JOIN`s retain sales records even when a corresponding customer or product cannot be found.
- The view performs no aggregation; measures remain at the source sales-detail grain.

