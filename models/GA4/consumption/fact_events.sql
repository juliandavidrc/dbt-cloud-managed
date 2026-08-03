{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date'
) }}

select
    -- ht.TRAFFIC_CATEGORY, 
    -- ht.CAMPAIGN_NAME,
    -- ht.CAMPAIGN_MEDIUM,
    -- ht.CAMPAIGN_SOURCE,
    -- co.country_name    
    UUID_STRING('b990a346-fe48-4dd3-8af1-7a0eceee4220', ' - ' || ht.event_date || 
                                                        ' - ' || co.country_id || 
                                                        ' - ' || tf.traffic_category_id || 
                                                        ' - ' || cn.campaign_name_id || 
                                                        ' - ' || cm.campaign_medium_id || 
                                                        ' - ' || cs.campaign_source_id) as unique_id,
    ht.event_date,
    co.country_id,
    tf.traffic_category_id,
    cn.campaign_name_id,
    cm.campaign_medium_id,
    cs.campaign_source_id,    
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date,
    count(ht.sessions_number) as cm_sessions_number,
    count(distinct ht.active_users) as cm_active_users,
    count(distinct ht.new_users) as cm_new_users,
    count(distinct ht.form_completion) as cm_form_completion,
    count(distinct ht.subscription_users) as cm_subscription_users,
    count(distinct ht.lead_passes) as cm_lead_passes,
    count(distinct ht.user_pseudo_id) as cm_total_users,
    count(
        distinct
        case
            when
                (
                    cs.campaign_source ilike '%influencer%'
                    and tf.traffic_category not in ('organic')
                )
            then ht.lead_passes
            else null
        end
    ) as cm_influencers_lead_passes,
    div0(
        datediff(second, min(ht.event_timestamp), max(ht.event_timestamp)),
        count(concat(ht.user_pseudo_id, ht.ga_session_id))
    ) as cm_average_session_duration,
    div0(
        count(distinct ht.user_pseudo_id || ht.cm_session_id) - count(
            distinct case
                when ht.cm_session_engaged = '1'
                then ht.user_pseudo_id || ht.cm_session_id
            end
        ),
        count(distinct ht.user_pseudo_id || ht.cm_session_id)
    ) as cm_web_bounce_rate

from {{ ref("stg_fact_events") }} ht
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
group by
    ht.event_date,
    co.country_id,
    tf.traffic_category_id,
    cn.campaign_name_id,
    cm.campaign_medium_id,
    cs.campaign_source_id
    