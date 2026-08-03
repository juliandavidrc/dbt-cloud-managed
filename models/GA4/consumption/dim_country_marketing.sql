{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"
) }}

select
    *
from {{ ref("stg_dim_country_marketing") }}
