{{ config_model_iceberg_strategy() }}

with
    table_country as (
        select distinct
            geo_country as country_name,            
            geo_sub_continent as sub_continent,
            geo_continent as continent        
        from {{ source("GA4_silver", "dim_events_flat") }}
    )
select
    uuid_string('e90fa283-e222-4794-9281-7c18ea80fefa', country_name) as country_id,
    country_name,    
    sub_continent,
    continent,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_country
