-- З05. Полная загрузка модели P03 из stg_*.
-- Сначала справочники, затем факты.
INSERT INTO dim_supplier
SELECT supplier_id::INTEGER, supplier_name, supplier_type, city, contract_year::SMALLINT
FROM stg_dim_supplier;

INSERT INTO dim_goods
SELECT sku_id::INTEGER, item_name, dept, maker, measure_unit,
       list_price::DECIMAL(10,2), vendor_id::INTEGER, description,
       NULLIF(kcal, '')::SMALLINT,
       NULLIF(protein_g, '')::DECIMAL(5,1),
       NULLIF(fat_g, '')::DECIMAL(5,1),
       NULLIF(carbs_g, '')::DECIMAL(5,1),
       shelf_life_days::SMALLINT, storage_conditions
FROM stg_dim_goods;

INSERT INTO dim_client
SELECT client_id::INTEGER, client_name, sex, birth_year::SMALLINT,
       home_city, is_loyal = '1', signup_date::DATE
FROM stg_dim_client;

INSERT INTO dim_shop
SELECT shop_id::INTEGER, shop_name, city, address, format,
       area_m2::INTEGER, open_date::DATE
FROM stg_dim_shop;

INSERT INTO dim_calendar
SELECT date_key::DATE, year::SMALLINT, quarter::TINYINT, month::TINYINT, month_name,
       day::TINYINT, weekday::TINYINT, weekday_name,
       is_weekend = '1', is_holiday = '1'
FROM stg_dim_date;

INSERT INTO dim_pay_method
SELECT ROW_NUMBER() OVER (ORDER BY pay_method)::INTEGER, pay_method
FROM (SELECT DISTINCT pay_method
      FROM stg_fact_receipt);

INSERT INTO dim_transport
SELECT transport_id::INTEGER, transport_name, body_type,
       capacity_t::DECIMAL(4,1), is_refrigerated = '1', temp_range
FROM stg_dim_transport;

INSERT INTO dim_writeoff_reason
SELECT reason_id::INTEGER, reason_name, reason_group, is_supplier_fault = '1'
FROM stg_dim_writeoff_reason;

INSERT INTO fact_receipt_line
SELECT r.receipt_line_id::BIGINT, r.sold_at::TIMESTAMP,
       r.client_id::INTEGER, r.sku_id::INTEGER, r.shop_id::INTEGER,
       p.pay_method_id,
       r.qty::DECIMAL(10,1), r.sell_price::DECIMAL(10,2), r.line_total::DECIMAL(12,2)
FROM stg_fact_receipt AS r
JOIN dim_pay_method p ON p.pay_method = r.pay_method;

INSERT INTO fact_supply
SELECT supply_id::BIGINT, shipped_at::TIMESTAMP, delivered_at::TIMESTAMP,
       supplier_id::INTEGER, shop_id::INTEGER, sku_id::INTEGER, transport_id::INTEGER,
       qty::DECIMAL(10,1), purchase_price::DECIMAL(10,2), supply_amount::DECIMAL(12,2),
       expiry_date::DATE
FROM stg_fact_supply;

INSERT INTO fact_writeoff
SELECT writeoff_id::BIGINT, written_off_at::TIMESTAMP,
       shop_id::INTEGER, sku_id::INTEGER, supply_id::BIGINT, reason_id::INTEGER,
       qty::DECIMAL(10,1), cost_amount::DECIMAL(12,2)
FROM stg_fact_writeoff;
