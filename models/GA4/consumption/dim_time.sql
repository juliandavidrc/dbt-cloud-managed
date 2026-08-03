{{ config(
    materialized='incremental',
    table_format='iceberg',
    external_volume='ICEBERG_EXTERNAL_VOLUME',    
    unique_key='date_day',
    on_schema_change='ignore'
) }}

with date_range as (

    -- Generate a series of dates from start_date to today
    select
        dateadd(day, seq4(), '{{ var("start_date", "2020-01-01") }}'::date) as date_day
    from table(generator(rowcount => 10000)) -- adjust rowcount based on expected range

),

final as (

    select
        date_day,

        -- Basic fields
        year(date_day)                          as year,
        month(date_day)                         as month,
        day(date_day)                           as day_of_month,
        dayofweek(date_day)                     as day_of_week,  -- 0=Sunday
        dayname(date_day)                       as day_name,
        monthname(date_day)                     as month_name,

        -- Week & quarter
        week(date_day)                          as week_of_year,
        quarter(date_day)                       as quarter,
        
        -- Flags
        case when dayofweek(date_day) in (0,6) then true else false end as is_weekend,
        case when date_day = current_date() then true else false end     as is_today,
        
        -- Useful formats
        to_char(date_day, 'YYYY-MM-DD')         as date_iso,
        to_char(date_day, 'YYYYMMDD')           as date_key

    from date_range
    where date_day <= current_date()

)

select * from final
