-- ============================================================================
-- SCHEMA EVOLUTION EXAMPLE
-- ============================================================================
-- Este archivo muestra cómo manejar evolving schemas en diferentes escenarios

-- ============================================================================
-- ESCENARIO 1: Agregar una nueva columna a una dimensión
-- ============================================================================

-- Antes: stg_dim_campaign_source.sql
{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"
) }}

with table_campaign_source as (
    select distinct
        coalesce(
            traffic_source_source,
            'Unassigned'
        ) as campaign_source
    from {{ source("GA4_silver", "dim_events_flat") }}
)
select
    uuid_string('343eca5c-9666-40f8-9b15-51ecac319fae', campaign_source) as campaign_source_id,
    campaign_source,
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_campaign_source;

-- Después: Agregamos campaign_type y campaign_category
{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"  -- ✨ Maneja el cambio automáticamente
) }}

with table_campaign_source as (
    select distinct
        coalesce(traffic_source_source, 'Unassigned') as campaign_source,
        coalesce(new_campaign_type, 'Unknown') as campaign_type,           -- ✨ NUEVA
        coalesce(new_campaign_category, 'Other') as campaign_category      -- ✨ NUEVA
    from {{ source("GA4_silver", "dim_events_flat") }}
)
select
    uuid_string('343eca5c-9666-40f8-9b15-51ecac319fae', campaign_source) as campaign_source_id,
    campaign_source,
    campaign_type,          -- ✨ NUEVA
    campaign_category,      -- ✨ NUEVA
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_campaign_source;

-- Resultado: Las columnas se agregan automáticamente sin errores
-- dbt run --models stg_dim_campaign_source
-- ✅ Columnas agregadas: campaign_type, campaign_category


-- ============================================================================
-- ESCENARIO 2: Modelo Incremental con Schema Evolution
-- ============================================================================

{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date',
    on_schema_change="sync_all_columns"  -- ✨ También funciona con incremental
) }}

WITH events_base AS (
    SELECT
        unique_id,
        event_date,
        campaign_source,
        -- Nuevas columnas agregadas por GA4
        utm_content,          -- ✨ NUEVA
        utm_term,             -- ✨ NUEVA
        gclid,                -- ✨ NUEVA
        cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
    FROM {{ source("GA4_silver", "dim_events_flat") }}
    {% if is_incremental() %}
    WHERE event_date >= DATEADD(day, -3, CURRENT_DATE)
    {% endif %}
)
SELECT * FROM events_base;

-- Al ejecutar dbt run:
-- 1. Detecta que hay 3 columnas nuevas
-- 2. Agrega las columnas a la tabla Iceberg
-- 3. Las filas existentes tienen NULL en las nuevas columnas
-- 4. Solo procesa los últimos 3 días (incremental)


-- ============================================================================
-- ESCENARIO 3: Diferentes estrategias según el ambiente
-- ============================================================================

-- Para DEV: Permisivo, acepta cambios automáticamente
{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="sync_all_columns"  -- ✅ DEV: flexible
) }}

-- Para PROD: Estricto, falla si hay cambios no esperados
{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="fail" if target.name == 'prod' else "sync_all_columns"
) }}

-- Para STAGING: Solo agrega columnas, no elimina
{{ config_model_iceberg_strategy(
    materialized_type="table",
    on_schema_change="append_new_columns"
) }}


-- ============================================================================
-- ESCENARIO 4: Eliminar columnas obsoletas
-- ============================================================================

-- Antes: Tenías una columna que ya no necesitas
select
    campaign_source_id,
    campaign_source,
    old_deprecated_field,  -- ❌ Ya no existe en la fuente
    process_ingestion_date
from table_campaign_source;

-- Después: Quitas la columna del SELECT
select
    campaign_source_id,
    campaign_source,
    -- old_deprecated_field eliminado
    process_ingestion_date
from table_campaign_source;

-- Con on_schema_change="sync_all_columns":
-- ✅ La columna se ELIMINA automáticamente de la tabla
-- ✅ No necesitas hacer ALTER TABLE DROP COLUMN manual


-- ============================================================================
-- ESCENARIO 5: Cambio de tipo de dato (Requiere intervención manual)
-- ============================================================================

-- IMPORTANTE: on_schema_change NO maneja cambios de tipo de dato automáticamente
-- Ejemplo: campaign_budget era VARCHAR, ahora es DECIMAL

-- Solución 1: Full refresh
-- dbt run --full-refresh --models stg_dim_campaign_source

-- Solución 2: Cast explícito con compatibilidad
select
    campaign_source_id,
    campaign_source,
    TRY_CAST(campaign_budget AS DECIMAL(18,2)) as campaign_budget,  -- ✨ Cast seguro
    process_ingestion_date
from table_campaign_source;

-- Solución 3: Crear una nueva columna temporal
select
    campaign_source_id,
    campaign_source,
    campaign_budget as campaign_budget_old,           -- Mantener viejo
    TRY_CAST(campaign_budget AS DECIMAL(18,2)) as campaign_budget_new,  -- Nuevo
    process_ingestion_date
from table_campaign_source;


-- ============================================================================
-- ESCENARIO 6: Schema Evolution en Fact Tables
-- ============================================================================

{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date',
    on_schema_change="sync_all_columns"
) }}

select
    unique_id,
    event_date,
    country_id,

    -- Métricas originales
    cm_sessions_number,
    cm_active_users,
    cm_new_users,

    -- ✨ NUEVAS MÉTRICAS agregadas por cambios en GA4
    cm_engaged_sessions,           -- Nueva métrica de engagement
    cm_engagement_rate,            -- Nueva métrica de engagement rate
    cm_average_engagement_time,    -- Nueva métrica de tiempo

    process_ingestion_date
from {{ ref("stg_fact_events") }};

-- Beneficios:
-- ✅ Puedes agregar nuevas métricas sin romper queries existentes
-- ✅ Dashboards que usan las métricas viejas siguen funcionando
-- ✅ Nuevos dashboards pueden usar las métricas nuevas


-- ============================================================================
-- TESTING DESPUÉS DE SCHEMA CHANGES
-- ============================================================================

/*
-- 1. Verificar que el modelo se ejecuta sin errores
dbt run --models stg_dim_campaign_source

-- 2. Verificar que las columnas existen
SELECT column_name, data_type, ordinal_position
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'STG_DIM_CAMPAIGN_SOURCE'
ORDER BY ordinal_position;

-- 3. Verificar que los datos se cargaron correctamente
SELECT
    COUNT(*) as total_rows,
    COUNT(campaign_source) as campaign_source_not_null,
    COUNT(campaign_type) as campaign_type_not_null,
    COUNT(campaign_category) as campaign_category_not_null
FROM {{ ref('stg_dim_campaign_source') }};

-- 4. Verificar downstream dependencies
dbt run --models stg_dim_campaign_source+

-- 5. Ejecutar tests
dbt test --models stg_dim_campaign_source
*/


-- ============================================================================
-- ROLLBACK EN CASO DE PROBLEMAS
-- ============================================================================

/*
-- Si algo sale mal, puedes hacer rollback:

-- Opción 1: Full refresh (reconstruye desde cero)
dbt run --full-refresh --models stg_dim_campaign_source

-- Opción 2: Restaurar desde backup (Snowflake Time Travel)
CREATE OR REPLACE TABLE stg_dim_campaign_source
AS SELECT * FROM stg_dim_campaign_source
AT(OFFSET => -3600);  -- 1 hora atrás

-- Opción 3: Drop y recrear
DROP TABLE IF EXISTS stg_dim_campaign_source;
dbt run --models stg_dim_campaign_source
*/


-- ============================================================================
-- BEST PRACTICES SUMMARY
-- ============================================================================

/*
✅ DO:
- Usa sync_all_columns para dimensiones que evolucionan frecuentemente
- Agrega columnas con valores DEFAULT o COALESCE para evitar NULLs masivos
- Documenta cambios de schema en schema.yml y CHANGELOG
- Prueba en DEV antes de aplicar en PROD
- Ejecuta dbt test después de cada schema change
- Propaga cambios a todos los layers (staging → consumption)

❌ DON'T:
- No uses ignore en PROD (puede causar errores silenciosos)
- No cambies tipos de datos sin full-refresh o cast explícito
- No elimines columnas que son usadas por dashboards activos
- No mezcles on_schema_change="fail" con cambios frecuentes
- No olvides actualizar tests de uniqueness/not_null en nuevas columnas

🎯 RECOMMENDED CONFIG por AMBIENTE:
- DEV: on_schema_change="sync_all_columns"      (flexible, permite experimentar)
- STAGING: on_schema_change="sync_all_columns"  (detecta cambios antes de PROD)
- PROD: on_schema_change="sync_all_columns"     (auto-sincroniza, pero monitorea logs)
*/
