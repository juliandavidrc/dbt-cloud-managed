{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"
) }}

with
    table_campaign_source as (
        select distinct
            coalesce(
                traffic_source_source,
                collected_traffic_source_manual_source,
                session_traffic_source_last_click_manual_campaign_source,
                session_traffic_source_last_click_cross_channel_campaign_source,
                'Unassigned'
            ) as campaign_source
        from {{ source("GA4_silver", "dim_events_flat") }}
    )
select
    uuid_string(
        '343eca5c-9666-40f8-9b15-51ecac319fae', campaign_source
    ) as campaign_source_id,
    campaign_source,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_campaign_source
