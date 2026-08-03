{{ iceberg_model_config() }}

SELECT 
    *
FROM {{ ref('stg_fact_booking') }}
QUALIFY ROW_NUMBER() OVER (
        PARTITION BY BOOKING_ID
        ORDER BY SNAPSHOT_DATE DESC
    ) = 1 




