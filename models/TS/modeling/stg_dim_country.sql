{{ iceberg_model_config() }}
WITH unique_countries AS (
SELECT 
    DISTINCT(COUNTRYID::INT) AS COUNTRY_ID,
    COUNTRYNAME AS COUNTRY_NAME

    FROM {{ source('TS', 'BOOKED_PASSENGERS') }}
    WHERE COUNTRYNAME IS NOT NULL
)

SELECT 
    COUNTRY_ID,
    COUNTRY_NAME
    FROM unique_countries