{{ iceberg_model_config() }}

WITH unique_destinations AS (
SELECT 
    DISTINCT(REGIONNAME) AS DESTINATION_NAME, 
    md5_binary(REGIONNAME) AS DESTINATION_ID
    FROM {{ source('TS', 'BOOKED_SERVICE_DETAILS') }}
    WHERE REGIONNAME IS NOT NULL
)

SELECT 
    DESTINATION_ID,
    DESTINATION_NAME
    FROM unique_destinations