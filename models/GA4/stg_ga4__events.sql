{{
 config(
     materialized = "view",
     database = env_var('DBT_ENVIRONMENT') ~ '_MODELING',
     schema = env_var('DBT_ENVIRONMENT') ~ '_MODELING_GA4'
)}}

with cte_events as (
    select * from {{ source('GA4', 'EVENTS') }}
   
)
select * from cte_events