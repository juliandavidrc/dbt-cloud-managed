{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'event_date', 'data_type': 'date'},
    unique_key=['event_date','unique_id','user_pseudo_id']
) }}

WITH stg_flattened_events AS (

    SELECT
        t.event_date,
        t.unique_id,
        t.user_pseudo_id,
        ep.value:key::string       AS key,
        ep.value:value:int_value::string   AS int_val,
        ep.value:value:string_value::string AS str_val
    FROM {{ source("GA4_silver", "dim_events_flat") }} t,
         LATERAL FLATTEN(INPUT => PARSE_JSON(t.event_params)) ep
    {% if is_incremental() %}
    WHERE event_date >= DATEADD(day, -3, CURRENT_DATE)
    {% endif %}
),

stg_metrics_sessions AS (

    SELECT
        event_date,
        unique_id,
        user_pseudo_id,
        MAX(CASE WHEN key = 'ga_session_id' THEN int_val END)     AS cm_session_id,
        MAX(CASE WHEN key = 'session_engaged' THEN str_val END)   AS cm_session_engaged
    FROM stg_flattened_events
    GROUP BY event_date, unique_id, user_pseudo_id
)

SELECT *, cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
FROM stg_metrics_sessions
