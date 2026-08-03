-- models/test_iceberg_table.sql

{{
  config(
    materialized='incremental',
    table_format='iceberg',
    external_volume='ICEBERG_EXTERNAL_VOLUME',
    database = env_var('DBT_ENVIRONMENT') ~ '_LANDING',
    schema = env_var('DBT_ENVIRONMENT') ~ '_LANDING_DBT_ICEBERG',
    base_location_root='landing/iceberg',
    catalog = 'SNOWFLAKE',
    unique_key='id',
    incremental_strategy="merge"
  )
}}

SELECT
    id,
    name,
    created_at
FROM
    EXT_CUSTOMERS

{% if is_incremental() %}

  WHERE created_at > (SELECT MAX(created_at::TIMESTAMP) FROM {{ this }})

{% endif %}