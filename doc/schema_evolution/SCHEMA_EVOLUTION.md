# Schema Evolution Strategy

## 📋 Overview

Este proyecto implementa **schema evolution** para manejar cambios automáticos en la estructura de las tablas cuando el schema fuente cambia.

## 🔧 Configuración Implementada

### Macro `config_model_iceberg_strategy`

Ubicación: [`macros/config_model_iceberg_strategy.sql`](macros/config_model_iceberg_strategy.sql)

```sql
{% macro config_model_iceberg_strategy(
    materialized_type="table",
    unique_key=None,
    incremental_strategy=None,
    partition_by=None,
    full_refresh=None,
    on_schema_change="sync_all_columns"
) %}
```

**Nuevo parámetro:** `on_schema_change="sync_all_columns"` (default)

---

## 🎯 Opciones de `on_schema_change`

| Opción | Comportamiento | Cuándo usar |
|--------|----------------|-------------|
| **`sync_all_columns`** | Agrega nuevas columnas y elimina columnas que ya no existen | ✅ **Recomendado** - Mantiene el schema sincronizado automáticamente |
| **`append_new_columns`** | Solo agrega nuevas columnas, NO elimina columnas obsoletas | Cuando necesitas mantener columnas legacy |
| **`fail`** | Falla el build si detecta cambios en el schema | Para ambientes de producción estrictos |
| **`ignore`** | Ignora cambios de schema, puede causar errores | No recomendado |

---

## 📁 Modelos Actualizados

### **Gold Layer - Modeling (Staging Dimensions)**

Todos con `on_schema_change="sync_all_columns"`:

- [`models/GA4/modeling/stg_dim_campaign_source.sql`](models/GA4/modeling/stg_dim_campaign_source.sql)
- [`models/GA4/modeling/stg_dim_campaign_medium.sql`](models/GA4/modeling/stg_dim_campaign_medium.sql)
- [`models/GA4/modeling/stg_dim_campaign_name.sql`](models/GA4/modeling/stg_dim_campaign_name.sql)
- [`models/GA4/modeling/stg_dim_traffic_category.sql`](models/GA4/modeling/stg_dim_traffic_category.sql)
- [`models/GA4/modeling/stg_dim_country_marketing.sql`](models/GA4/modeling/stg_dim_country_marketing.sql)

### **Gold Layer - Consumption (Dimensions)**

Todos con `on_schema_change="sync_all_columns"`:

- [`models/GA4/consumption/dim_campaign_source.sql`](models/GA4/consumption/dim_campaign_source.sql)
- [`models/GA4/consumption/dim_campaign_medium.sql`](models/GA4/consumption/dim_campaign_medium.sql)
- [`models/GA4/consumption/dim_campaign_name.sql`](models/GA4/consumption/dim_campaign_name.sql)
- [`models/GA4/consumption/dim_traffic_category.sql`](models/GA4/consumption/dim_traffic_category.sql)
- [`models/GA4/consumption/dim_country_marketing.sql`](models/GA4/consumption/dim_country_marketing.sql)

---

## 🔄 Ejemplo de Schema Evolution en Acción

### Escenario: GA4 agrega una nueva columna

**Situación:**
Google Analytics 4 agrega un nuevo campo `campaign_group` a los eventos.

**Paso 1: Antes del cambio**
```sql
-- stg_dim_campaign_source.sql
select
    campaign_source_id,
    campaign_source,
    process_ingestion_date
from table_campaign_source
```

**Paso 2: Actualizar el modelo**
```sql
-- stg_dim_campaign_source.sql
with table_campaign_source as (
    select distinct
        coalesce(traffic_source_source, 'Unassigned') as campaign_source,
        coalesce(new_campaign_group_field, 'Unknown') as campaign_group  -- ✨ Nueva columna
    from {{ source("GA4_silver", "dim_events_flat") }}
)
select
    uuid_string('343eca5c-9666-40f8-9b15-51ecac319fae', campaign_source) as campaign_source_id,
    campaign_source,
    campaign_group,  -- ✨ Nueva columna
    cast(current_timestamp() as timestamp_ntz(6)) as process_ingestion_date
from table_campaign_source
```

**Paso 3: Ejecutar dbt**
```bash
dbt run --models stg_dim_campaign_source
```

**Resultado con `on_schema_change="sync_all_columns"`:**
✅ La columna `campaign_group` se **agrega automáticamente** a la tabla Iceberg
✅ Las filas existentes tendrán `NULL` en la nueva columna
✅ **No es necesario hacer ALTER TABLE manual**

---

## ⚠️ Consideraciones Importantes

### 1. **Schema Changes y Downstream Dependencies**

Cuando agregas una nueva columna a una dimensión staging, asegúrate de propagarla a consumption:

```sql
-- ❌ MALO: consumption no verá la nueva columna
-- dim_campaign_source.sql (consumption)
select * from {{ ref("stg_dim_campaign_source") }}
```

```sql
-- ✅ BUENO: Especifica todas las columnas explícitamente
-- dim_campaign_source.sql (consumption)
select
    campaign_source_id,
    campaign_source,
    campaign_group,  -- nueva columna
    process_ingestion_date
from {{ ref("stg_dim_campaign_source") }}
```

### 2. **Incremental Models**

El parámetro `on_schema_change` también funciona con modelos incrementales:

```sql
{{ config_model_iceberg_strategy(
    materialized_type="incremental",
    unique_key="unique_id",
    incremental_strategy="merge",
    partition_by='event_date',
    on_schema_change="sync_all_columns"  -- ✅ También aquí
) }}
```

### 3. **Testing After Schema Changes**

Después de un schema change, ejecuta:

```bash
# Test completo
dbt test

# Test específico de un modelo
dbt test --models stg_dim_campaign_source

# Full refresh si hay problemas
dbt run --full-refresh --models stg_dim_campaign_source
```

---

## 🚀 Best Practices

### ✅ DO

- Usa `sync_all_columns` para dimensiones que cambian frecuentemente
- Documenta cambios de schema en el `schema.yml`
- Ejecuta `dbt test` después de schema changes
- Propaga cambios de schema a todos los layers (staging → consumption)

### ❌ DON'T

- No uses `ignore` en producción (puede romper pipelines silenciosamente)
- No mezcles `sync_all_columns` con `select *` sin validación
- No olvides actualizar tests y documentación cuando cambies el schema

---

## 📊 Monitoreo de Schema Changes

### Ver cambios de schema en logs

```bash
dbt run --models stg_dim_campaign_source --debug
```

Busca en los logs:
```
Schema changed, applying on_schema_change=sync_all_columns
Added columns: ['campaign_group']
Removed columns: []
```

### Query para verificar columnas en Snowflake

```sql
-- Ver columnas actuales de una tabla
SHOW COLUMNS IN TABLE {ENV}_MODELING.{ENV}_MODELING_GA4.STG_DIM_CAMPAIGN_SOURCE;

-- Comparar schemas entre staging y consumption
SELECT column_name, data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name IN ('STG_DIM_CAMPAIGN_SOURCE', 'DIM_CAMPAIGN_SOURCE')
ORDER BY table_name, ordinal_position;
```

---

## 🔗 Referencias

- [dbt docs: on_schema_change](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/configuring-incremental-models#what-if-the-columns-of-my-incremental-model-change)
- [Iceberg Schema Evolution](https://iceberg.apache.org/docs/latest/evolution/)
- [Snowflake Iceberg Tables](https://docs.snowflake.com/en/user-guide/tables-iceberg)

---

## 📝 Changelog

### 2026-08-03
- ✅ Implementado `on_schema_change="sync_all_columns"` en todas las dimensiones GA4
- ✅ Actualizado macro `config_model_iceberg_strategy` con soporte para schema evolution
- ✅ Aplicado a 10 modelos (5 staging + 5 consumption)
