-- З06. SCD2 для справочника товаров dim_goods.
-- Служебные поля:
--   valid_from - с какой даты действует версия
--   valid_to   - по какую дату (у текущей версии 9999-12-31)
--   is_current - TRUE только у актуальной версии

DROP TABLE IF EXISTS dim_goods_scd2;

CREATE TABLE dim_goods_scd2 (
    sku_id        INTEGER NOT NULL,
    item_name     VARCHAR NOT NULL,
    dept          VARCHAR NOT NULL,
    maker         VARCHAR,
    measure_unit  VARCHAR NOT NULL,
    list_price    DECIMAL(10,2) NOT NULL,
    vendor_id     INTEGER,
    valid_from    DATE NOT NULL,
    valid_to      DATE NOT NULL,
    is_current    BOOLEAN NOT NULL
);
