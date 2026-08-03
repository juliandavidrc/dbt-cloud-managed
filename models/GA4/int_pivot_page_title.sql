{{
  config(
    materialized = "incremental", 
    table_format = "iceberg",
    external_volume = "ICEBERG_EXTERNAL_VOLUME",
    database = env_var('DBT_ENVIRONMENT') ~ '_MODELING',
    schema = env_var('DBT_ENVIRONMENT') ~ '_MODELING_GA4'
  )
}}

-- CTE: new_data is always needed
with new_data as (
    select distinct
        trim(page_title) as page_title
    from {{ ref('dim_flattened_events') }}
    where length(trim(page_title)) > 0
)

{% if is_incremental() %}

-- CTE: existing_data only used in incremental runs
, existing_data as (
    select distinct
        trim(page_title) as page_title
    from {{ this }}
)

, deduplicated as (
    select
        uuid_string() as unique_id,
        n.page_title,
        --''::string as page_title_english,
        --''::string as page_title_spanish,
        --snowflake.cortex.translate(n.page_title,'ar','en') as page_title_english,
        --snowflake.cortex.translate(n.page_title,'ar','es') as page_title_spanish,
        case 
            when UNICODE(SUBSTRING(n.page_title, 1, 1)) BETWEEN 1536 AND 1791 then snowflake.cortex.translate(n.page_title, 'ar', 'en')
            else ''::string
        end as page_title_english,
        ''::string as page_title_spanish,
        case 
            when UNICODE(SUBSTRING(n.page_title, 1, 1)) BETWEEN 1536 AND 1791 then 'Translated'
            else ''::string
        end as status        
        --'Translated'::string as status
    from new_data n
    left join existing_data e
        on n.page_title = e.page_title
    where e.page_title is null
)

select *
from deduplicated

{% else %}

select
    uuid_string() as unique_id,
    page_title,
    --''::string as page_title_english,
    --''::string as page_title_spanish,
    --snowflake.cortex.translate(page_title,'ar','en') as page_title_english,
    --snowflake.cortex.translate(page_title,'ar','es') as page_title_spanish,
    case 
        when UNICODE(SUBSTRING(page_title, 1, 1)) BETWEEN 1536 AND 1791 then snowflake.cortex.translate(page_title, 'ar', 'en')
        else ''::string
    end as page_title_english,
    ''::string as page_title_spanish,
    case 
        when UNICODE(SUBSTRING(page_title, 1, 1)) BETWEEN 1536 AND 1791 then 'Translated'
        else ''::string
    end as status        
    --'Translated'::string as status
from new_data

{% endif %}