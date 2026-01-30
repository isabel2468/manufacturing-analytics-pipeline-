-- DIM PRODUCT
INSERT INTO core.dim_product (product_code, product_family, standard_cost, list_price_eur)
SELECT
  TRIM(product_code),
  NULLIF(TRIM(product_family), ''),
  NULLIF(REPLACE(TRIM(standard_cost), ',', '.'), '')::numeric,
  NULLIF(REPLACE(TRIM(list_price_eur), ',', '.'), '')::numeric
FROM raw.products_master
ON CONFLICT (product_code) DO UPDATE SET
  product_family = EXCLUDED.product_family,
  standard_cost  = EXCLUDED.standard_cost,
  list_price_eur = EXCLUDED.list_price_eur;

-- DIM CUSTOMER
INSERT INTO core.dim_customer (customer_id, customer_name, region, country, city, segment, created_at)
SELECT
  TRIM(customer_id),
  NULLIF(TRIM(customer_name), ''),
  COALESCE(
    CASE
      WHEN NULLIF(TRIM(region), '') IS NULL THEN NULL
      WHEN UPPER(TRIM(region)) IN ('EMEA','EU') THEN 'EUROPE'
      WHEN UPPER(TRIM(region)) IN ('AMER', 'AMERICA','NORTH AMERICA', 'LATIN AMERICA','LATAM', 'SA') THEN 'AMERICAS'
      WHEN UPPER(TRIM(region)) IN ('APAC','ASIAPAC') THEN 'ASIA PACIFIC'
      WHEN UPPER(TRIM(region)) LIKE 'LATAM%' THEN 'AMERICAS'
      ELSE UPPER(TRIM(region))
    END,
    'AMERICAS'
  ),

  NULLIF(TRIM(country), ''),
  NULLIF(TRIM(city), ''),
  NULLIF(TRIM(segment), ''),
  CASE
    WHEN TRIM(created_at) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(created_at)::date
    WHEN TRIM(created_at) ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(TRIM(created_at), 'DD.MM.YYYY')
    WHEN TRIM(created_at) ~ '^\d{2}/\d{2}/\d{4}$' THEN
      CASE
        WHEN split_part(TRIM(created_at), '/', 1)::int > 12
          THEN to_date(TRIM(created_at), 'DD/MM/YYYY')
        ELSE to_date(TRIM(created_at), 'MM/DD/YYYY')
      END
    ELSE NULL
  END
FROM raw.customers
ON CONFLICT (customer_id) DO UPDATE SET
  customer_name = EXCLUDED.customer_name,
  region        = EXCLUDED.region,
  country       = EXCLUDED.country,
  city          = EXCLUDED.city,
  segment       = EXCLUDED.segment,
  created_at    = EXCLUDED.created_at;

-- FACT SALES
INSERT INTO core.fact_sales_orders
(order_id, order_date, customer_id, product_code, qty, unit_price, currency, order_status, revenue)
SELECT
  TRIM(order_id),
  CASE
    WHEN TRIM(order_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(order_date)::date
    WHEN TRIM(order_date) ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(TRIM(order_date), 'DD.MM.YYYY')
    WHEN TRIM(order_date) ~ '^\d{2}/\d{2}/\d{4}$' THEN
      CASE
        WHEN split_part(TRIM(order_date), '/', 1)::int > 12
          THEN to_date(TRIM(order_date), 'DD/MM/YYYY')
        ELSE to_date(TRIM(order_date), 'MM/DD/YYYY')
      END
    ELSE NULL
  END,
  TRIM(customer_id),
  TRIM(product),
  NULLIF(TRIM(qty), '')::int,
  NULLIF(REPLACE(TRIM(unit_price), ',', '.'), '')::numeric,
  UPPER(TRIM(currency)),
  NULLIF(TRIM(order_status), ''),
  (NULLIF(TRIM(qty), '')::int * NULLIF(REPLACE(TRIM(unit_price), ',', '.'), '')::numeric)
FROM raw.sales_orders
ON CONFLICT (order_id) DO UPDATE SET
  order_date   = EXCLUDED.order_date,
  customer_id  = EXCLUDED.customer_id,
  product_code = EXCLUDED.product_code,
  qty          = EXCLUDED.qty,
  unit_price   = EXCLUDED.unit_price,
  currency     = EXCLUDED.currency,
  order_status = EXCLUDED.order_status,
  revenue      = EXCLUDED.revenue;

-- FACT PRODUCTION
INSERT INTO core.fact_production_output
(batch_id, production_date, region, plant, product_code, units_produced, units_scrap, scrap_rate)
SELECT
  TRIM(batch_id),
  CASE
    WHEN TRIM(production_date) ~ '^\d{4}-\d{2}-\d{2}$' THEN TRIM(production_date)::date
    WHEN TRIM(production_date) ~ '^\d{2}\.\d{2}\.\d{4}$' THEN to_date(TRIM(production_date), 'DD.MM.YYYY')
    WHEN TRIM(production_date) ~ '^\d{2}/\d{2}/\d{4}$' THEN
      CASE
        WHEN split_part(TRIM(production_date), '/', 1)::int > 12
          THEN to_date(TRIM(production_date), 'DD/MM/YYYY')
        ELSE to_date(TRIM(production_date), 'MM/DD/YYYY')
      END
    ELSE NULL
  END,
 COALESCE(
    CASE
      WHEN NULLIF(TRIM(region), '') IS NULL THEN NULL
      WHEN UPPER(TRIM(region)) IN ('EMEA','EU') THEN 'EUROPE'
      WHEN UPPER(TRIM(region)) IN ('AMER', 'AMERICA','NORTH AMERICA', 'LATIN AMERICA','LATAM', 'SA') THEN 'AMERICAS'
      WHEN UPPER(TRIM(region)) IN ('APAC','ASIAPAC') THEN 'ASIA PACIFIC'
      WHEN UPPER(TRIM(region)) LIKE 'LATAM%' THEN 'AMERICAS'
      ELSE UPPER(TRIM(region))
    END,
    'AMERICAS'
 ),

  NULLIF(TRIM(plant), ''),
  TRIM(product),
  NULLIF(TRIM(units_produced), '')::int,
  NULLIF(TRIM(units_scrap), '')::int,
  CASE
    WHEN NULLIF(TRIM(units_produced), '')::int > 0
      THEN (NULLIF(TRIM(units_scrap), '')::int::numeric / NULLIF(TRIM(units_produced), '')::int::numeric)
    ELSE NULL
  END
FROM raw.production_output
ON CONFLICT (batch_id) DO UPDATE SET
  production_date = EXCLUDED.production_date,
  region          = EXCLUDED.region,
  plant           = EXCLUDED.plant,
  product_code    = EXCLUDED.product_code,
  units_produced  = EXCLUDED.units_produced,
  units_scrap     = EXCLUDED.units_scrap,
  scrap_rate      = EXCLUDED.scrap_rate;
