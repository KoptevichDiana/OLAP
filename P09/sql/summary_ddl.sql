CREATE TABLE IF NOT EXISTS olap.sales_by_shop_day (
    sale_date Date,
    shop_id Int32,
    shop_name String,
    city String,
    revenue Decimal(18,2),
    lines_cnt UInt64
) ENGINE = MergeTree
ORDER BY (sale_date, shop_id);
