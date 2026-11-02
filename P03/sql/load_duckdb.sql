INSERT INTO dim_supplier
SELECT supplier_id::INTEGER, supplier_name, supplier_type, city, contract_year::SMALLINT
FROM read_csv('data/raw/dim_supplier.csv', header = true, all_varchar = true);

INSERT INTO dim_goods
SELECT sku_id::INTEGER, item_name, dept, maker, measure_unit,
       list_price::DECIMAL(10,2), vendor_id::INTEGER, description,
       NULLIF(kcal, '')::SMALLINT,
       NULLIF(protein_g, '')::DECIMAL(5,1),
       NULLIF(fat_g, '')::DECIMAL(5,1),
       NULLIF(carbs_g, '')::DECIMAL(5,1),
       shelf_life_days::SMALLINT, storage_conditions
FROM read_csv('data/raw/dim_goods.csv', header = true, all_varchar = true);

INSERT INTO dim_client
SELECT client_id::INTEGER, client_name, sex, birth_year::SMALLINT,
       home_city, is_loyal = '1', signup_date::DATE
FROM read_csv('data/raw/dim_client.csv', header = true, all_varchar = true);

INSERT INTO dim_shop
SELECT shop_id::INTEGER, shop_name, city, address, format,
       area_m2::INTEGER, open_date::DATE
FROM read_csv('data/raw/dim_shop.csv', header = true, all_varchar = true);

INSERT INTO dim_calendar
SELECT date_key::DATE, year::SMALLINT, quarter::TINYINT, month::TINYINT, month_name,
       day::TINYINT, weekday::TINYINT, weekday_name,
       is_weekend = '1', is_holiday = '1'
FROM read_csv('data/raw/dim_date.csv', header = true, all_varchar = true);

INSERT INTO dim_pay_method
SELECT ROW_NUMBER() OVER (ORDER BY pay_method)::INTEGER, pay_method
FROM (SELECT DISTINCT pay_method
      FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true));

INSERT INTO dim_transport
SELECT transport_id::INTEGER, transport_name, body_type,
       capacity_t::DECIMAL(4,1), is_refrigerated = '1', temp_range
FROM read_csv('data/raw/dim_transport.csv', header = true, all_varchar = true);

INSERT INTO dim_writeoff_reason
SELECT reason_id::INTEGER, reason_name, reason_group, is_supplier_fault = '1'
FROM read_csv('data/raw/dim_writeoff_reason.csv', header = true, all_varchar = true);

INSERT INTO fact_receipt_line
SELECT r.receipt_line_id::BIGINT, r.sold_at::TIMESTAMP,
       r.client_id::INTEGER, r.sku_id::INTEGER, r.shop_id::INTEGER,
       p.pay_method_id,
       r.qty::DECIMAL(10,1), r.sell_price::DECIMAL(10,2), r.line_total::DECIMAL(12,2)
FROM read_csv('data/raw/fact_receipt.csv', header = true, all_varchar = true) AS r
JOIN dim_pay_method p ON p.pay_method = r.pay_method;

INSERT INTO fact_supply
SELECT supply_id::BIGINT, shipped_at::TIMESTAMP, delivered_at::TIMESTAMP,
       supplier_id::INTEGER, shop_id::INTEGER, sku_id::INTEGER, transport_id::INTEGER,
       qty::DECIMAL(10,1), purchase_price::DECIMAL(10,2), supply_amount::DECIMAL(12,2),
       expiry_date::DATE
FROM read_csv('data/raw/fact_supply.csv', header = true, all_varchar = true);

INSERT INTO fact_writeoff
SELECT writeoff_id::BIGINT, written_off_at::TIMESTAMP,
       shop_id::INTEGER, sku_id::INTEGER, supply_id::BIGINT, reason_id::INTEGER,
       qty::DECIMAL(10,1), cost_amount::DECIMAL(12,2)
FROM read_csv('data/raw/fact_writeoff.csv', header = true, all_varchar = true);
