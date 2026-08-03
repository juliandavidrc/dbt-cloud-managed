{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date'
) }}

select    
    unique_id,
    ht.event_date,
    co.country_id,
    tf.traffic_category_id,
    cn.campaign_name_id,
    cm.campaign_medium_id,
    cs.campaign_source_id,        
    ht.cm_lead_type,
    ht.cm_lead_type_name,
    ht.cm_total_form_successes,
    ht.cm_total_number_impressions,
  CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ(6)) AS process_ingestion_date
from {{ ref("stg_fact_ctr") }} ht
    left join {{ ref("dim_time") }} dt
        on ht.event_date = dt.date_day
    left join {{ ref("dim_country_marketing") }} co 
        on ht.country_id = co.country_id
    left join {{ ref("dim_traffic_category") }} tf
        on ht.traffic_category_id = tf.traffic_category_id
    left join {{ ref("dim_campaign_name") }} cn
        on ht.campaign_name_id = cn.campaign_name_id
    left join {{ ref("dim_campaign_medium") }} cm
        on ht.campaign_medium_id = cm.campaign_medium_id
    left join {{ ref("dim_campaign_source") }} cs
        on ht.campaign_source_id = cs.campaign_source_id
{% if is_incremental() %}
WHERE ht.event_date >= DATEADD(day, -3, CURRENT_DATE)
{% endif %}
    