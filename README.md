Markdown
# Olist Brazilian E-Commerce Analytics — End-to-End SQL & Tableau Case Study

[![MySQL 8.0](https://img.shields.io/badge/MySQL-8.0-00758F?style=for-the-badge&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Tableau](https://img.shields.io/badge/Tableau-Public-E97627?style=for-the-badge&logo=tableau&logoColor=white)](https://public.tableau.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

An end-to-end analytics project analyzing ~100k real, anonymized orders (2016–2018) from the [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). 

This project covers relational schema design, pre-constraint data validation, data sanitization, analytical SQL modeling (window functions, CTEs, custom aggregation logic), and executive Tableau dashboards. Built as a core portfolio demonstration during a career transition from customs & logistics operations into data analytics.

> **Interactive Tableau Dashboards:** [View Live on Tableau Public](https://public.tableau.com/app/profile/bartosz.zo.nierowicz/viz/olist_tableau_17909368332890/RegionalDemand?publish=yes)
---

## Executive Summary & Core Insights

| Domain | Key Metric / Pattern | Operational & Business Impact |
| :--- | :--- | :--- |
| **Revenue Concentration** | **Top 15 of 73 Categories** generate 80% of total marketplace GMV (Pareto Class A). | Commercial acquisition, supplier onboarding, and campaign budgets should concentrate on Class A categories (`bed_bath_table`, `health_beauty`, `sports_leisure`). |
| **Seller Geography** | **>70% of merchant supply** originates from São Paulo (`SP`), while demand is distributed across all 27 states. | Long-haul interstate line-hauls lead to delivery delays in northern/northeastern states (`PA`, `AM`, `BA`), highlighting opportunities for decentralized fulfillment hubs outside `SP`. |
| **Fulfillment Latency** | **Payment Approval:** ~0.4 days avg.<br>**Merchant Dispatch:** 2.8 days avg. | Automated platform payment approval is fast; fulfillment bottlenecks occur in seller pick, pack, and carrier handover stages. |
| **Seasonality Patterns** | **Year-normalized indexing** reveals predictable annual spikes (e.g., `watches_gifts` peaking in May for Mother's Day and December for Christmas). | Inventory allocation and freight carrier capacity buffers must ramp up 4–6 weeks prior to known demand shifts. |

---

## Architecture & Data Pipeline

The pipeline processes raw Kaggle CSV files through an ordered series of reproducible SQL scripts in MySQL 8.0:

[Raw CSVs]
│
▼
01_create_database.sql ➔ 02_create_tables.sql
│
▼
03_data_import.sql (LOAD DATA INFILE with NULLIF guards)
│
▼
04_data_import_validation.sql ➔ 05_data_quality_check.sql
│
▼
06_cleaning_data.sql ➔ 07_adding_foreign_keys.sql
│
▼
08_base_views.sql (Central Hub View: vw_sales_analysis)
│
▼
09–13 Domain Scripts ➔ 14_views.sql (Modular Reporting Layer)
│
▼
[Tableau Desktop / Hyper Extracts / Interactive Dashboards]


### Central Hub View Pattern (`vw_sales_analysis`)
All downstream reporting queries read from a central denormalized hub view (`vw_sales_analysis`). This design provides:
1. **Consistent Business Metrics:** Distinct definitions for merchandise sales (`price`) versus total customer outlay (`total_price = price + freight_value`) applied platform-wide.
2. **Prevented Join Fan-Out:** Order reviews are pre-aggregated to the `order_id` grain (`AVG(review_score)`) before joining, preventing duplicate row multiplication on orders with multiple reviews.

---

## Data Quality & Engineering Decisions

* **Composite Primary Key Discovery:** During import validation (`04_data_import_validation.sql`), `order_reviews.review_id` was found to be non-unique across split orders. The schema was updated to use a composite key `PRIMARY KEY (review_id, order_id)`.
* **Malformed CSV Sanitization:** A broken record in `olist_order_reviews_dataset.csv` (row 82,209) contained an unescaped double quote that broke standard ingestion; this was corrected before loading.
* **Chronological Date Auditing:** Discovered instances where `order_delivered_carrier_date < order_approved_at` or estimated delivery preceded purchase. Rather than discarding entire orders and losing revenue data, invalid timestamps were converted to `NULL` to keep financial metrics intact.
* **Empirical Encoding Hypothesis Testing:** Garbled Brazilian city names initially appeared to be a `latin1` vs. `utf8mb4` import issue. A scratch-table re-import using `latin1` confirmed identical text patterns, indicating true spelling variants in the raw source rather than ingestion corruption. As a result, geographic analyses were standardized at the 2-letter state code level (`customer_state`, `seller_state`).
* **Category Translation Referential Integrity:** Missing translations (e.g., `pc_gamer`, `portateis_cozinha...`) and a synthetic `'uncategorized'` placeholder were backfilled before applying foreign key constraints.

---

## Repository Structure

```text
├── sql/
│   ├── 01_create_database.sql         # Database initialization
│   ├── 02_create_tables.sql           # DDL schema definition (9 base tables)
│   ├── 03_data_import.sql             # LOAD DATA INFILE ingestion with NULLIF transforms
│   ├── 04_data_import_validation.sql  # Row counts, PK null & duplicate validation
│   ├── 05_data_quality_check.sql      # Orphan record checks, date chronology, payment checks
│   ├── 06_cleaning_data.sql           # Sanitization: string trimming, date fixes, category backfill
│   ├── 07_adding_foreign_keys.sql     # Foreign key constraint enforcement
│   ├── 08_base_views.sql              # Central hub view (vw_sales_analysis)
│   ├── 09_customer_analysis.sql       # Top customer value, frequency, and regional demand
│   ├── 10_seller_analysis.sql         # Merchant performance, state revenues, Pareto tiering
│   ├── 11_logistics_analysis.sql      # Dispatch timeliness, transit latency, Haversine freight rates
│   ├── 12_product_analysis.sql        # Category & product ABC concentration, top-5 rankings
│   ├── 13_trends.sql                  # MoM revenue growth, 3M moving averages, seasonality index
│   └── 14_views.sql                   # Production DDL view definitions for BI consumption
├── tableau/
│   └── olist_ecommerce_analysis.twbx  # Tableau workbook file (Hyper extract bundled)
└── README.md

Tableau Dashboards Overview
ABC / Pareto Analysis: Dynamic category-level concentration showing cumulative revenue share against an 80% threshold. Clicking a category reveals its Top 5 individual products and category-specific ABC classification.

Logistics & Timeliness: An operational overview pairing high-level KPIs (Lead Time, Dispatch Time, On-Time Delivery Rate, Freight Share) with a synchronized dual-axis chart comparing Payment Approval vs. Dispatch Preparation by seller state, alongside an interstate delivery duration matrix.

Regional Demand: Geographic breakdown of top-selling categories across Brazil with interactive drill-downs into Top 10 customer spending and order frequency per state.

Sellers Performance: Analysis of merchant hubs, state-by-state monthly revenue trends, and top merchant leaderboards.

Trends & Seasonality: Monthly revenue trends paired with a 3-month trailing moving average, month-over-month growth rates, and a year-normalized seasonality index.

Reproduction Guide
Clone this repository:

Bash
git clone [https://github.com/](https://github.com/)<your-username>/olist-brazilian-ecommerce-analytics.git
cd olist-brazilian-ecommerce-analytics
Download the CSVs from the Kaggle Olist Dataset.

Open your MySQL 8.0 client with local_infile=1 enabled.

In sql/03_data_import.sql, update the file paths to point to your local CSV directory.

Run scripts 01 through 14 sequentially.

Open olist_ecommerce_analysis.twbx directly without needing a database connection.