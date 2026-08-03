# Schema Evolution Implementation Checklist

## ✅ Completado

### 1. Macro Actualizado
- [x] Actualizado `macros/config_model_iceberg_strategy.sql`
- [x] Agregado parámetro `on_schema_change="sync_all_columns"` (default)
- [x] Soporte para modelos incrementales y tables
- [x] Compatibilidad con Iceberg tables

### 2. Modelos Staging (Gold - Modeling)
- [x] `models/GA4/modeling/stg_dim_campaign_source.sql`
- [x] `models/GA4/modeling/stg_dim_campaign_medium.sql`
- [x] `models/GA4/modeling/stg_dim_campaign_name.sql`
- [x] `models/GA4/modeling/stg_dim_traffic_category.sql`
- [x] `models/GA4/modeling/stg_dim_country_marketing.sql`

### 3. Modelos Consumption (Gold - Consumption)
- [x] `models/GA4/consumption/dim_campaign_source.sql`
- [x] `models/GA4/consumption/dim_campaign_medium.sql`
- [x] `models/GA4/consumption/dim_campaign_name.sql`
- [x] `models/GA4/consumption/dim_traffic_category.sql`
- [x] `models/GA4/consumption/dim_country_marketing.sql`

### 4. Documentación Creada
- [x] `SCHEMA_EVOLUTION.md` - Documentación completa
- [x] `examples/schema_evolution_example.sql` - Ejemplos prácticos
- [x] `SCHEMA_EVOLUTION_SUMMARY.txt` - Resumen visual
- [x] `SCHEMA_EVOLUTION_CHECKLIST.md` - Este archivo

---

## 🔄 Próximos Pasos Recomendados

### 1. Testing en DEV
- [ ] Ejecutar `dbt run --models stg_dim_campaign_source` en DEV
- [ ] Verificar logs para confirmar que schema evolution funciona
- [ ] Probar agregar una columna nueva a un modelo
- [ ] Verificar que la columna se agrega sin errores

### 2. Aplicar a Otros Modelos

#### Fact Tables
- [ ] `models/GA4/modeling/stg_fact_events.sql`
- [ ] `models/GA4/modeling/stg_fact_ctr.sql`
- [ ] `models/GA4/modeling/stg_fact_website_toppage.sql`
- [ ] `models/GA4/consumption/fact_events.sql`
- [ ] `models/GA4/consumption/fact_ctr.sql`
- [ ] `models/GA4/consumption/fact_website_toppage.sql`

#### Silver Layer
- [ ] `models/GA4/dim_flattened_events.sql`
- [ ] `models/GA4/stg_ga4__events.sql` (ya es view, evaluar si necesita)

#### Otros Dominios
- [ ] Modelos en `models/CRM/`
- [ ] Modelos en `models/TS/`
- [ ] Modelos en `models/Chat_History/`

### 3. Configuración por Ambiente
- [ ] Crear variables de ambiente para `on_schema_change`
- [ ] Configurar estrategia estricta en PROD si es necesario
- [ ] Documentar la estrategia elegida por ambiente

**Ejemplo de configuración por ambiente:**

```yaml
# dbt_project.yml
models:
  your_project:
    GA4:
      modeling:
        +on_schema_change: "{{ 'fail' if target.name == 'prod' else 'sync_all_columns' }}"
      consumption:
        +on_schema_change: "sync_all_columns"
```

### 4. Tests y Validación
- [ ] Crear tests de schema en `models/GA4/schema.yml`
- [ ] Agregar tests de uniqueness para IDs
- [ ] Agregar tests de not_null para columnas críticas
- [ ] Crear tests de relationships entre dimensiones y facts

**Ejemplo:**

```yaml
# models/GA4/schema.yml
version: 2

models:
  - name: stg_dim_campaign_source
    description: "Staging dimension for campaign sources with schema evolution support"
    config:
      on_schema_change: sync_all_columns
    columns:
      - name: campaign_source_id
        description: "Unique identifier for campaign source"
        tests:
          - unique
          - not_null
      - name: campaign_source
        description: "Campaign source name"
        tests:
          - not_null
```

### 5. Monitoreo y Alertas
- [ ] Configurar alertas para schema changes en PROD
- [ ] Crear dashboard para monitorear evolución de schemas
- [ ] Documentar proceso de rollback en caso de problemas
- [ ] Configurar notificaciones en Slack/Email para schema changes

### 6. Capacitación del Equipo
- [ ] Compartir documentación con el equipo
- [ ] Realizar sesión de training sobre schema evolution
- [ ] Documentar casos de uso comunes
- [ ] Crear runbook para troubleshooting

---

## 📊 Testing Checklist

### Pre-deployment
- [ ] Ejecutar `dbt compile` para verificar sintaxis
- [ ] Ejecutar `dbt run --models stg_dim_*` en DEV
- [ ] Verificar que no hay errores de compilación
- [ ] Revisar logs de dbt para warnings

### Smoke Tests
```bash
# 1. Verificar que los modelos compilan
dbt compile --models stg_dim_campaign_source

# 2. Ejecutar un modelo individual
dbt run --models stg_dim_campaign_source

# 3. Verificar schema en Snowflake
SHOW COLUMNS IN TABLE {ENV}_MODELING.{ENV}_MODELING_GA4.STG_DIM_CAMPAIGN_SOURCE;

# 4. Contar filas
SELECT COUNT(*) FROM {ENV}_MODELING.{ENV}_MODELING_GA4.STG_DIM_CAMPAIGN_SOURCE;

# 5. Verificar que no hay NULLs en columnas críticas
SELECT
    COUNT(*) as total_rows,
    COUNT(campaign_source_id) as campaign_source_id_not_null,
    COUNT(campaign_source) as campaign_source_not_null
FROM {ENV}_MODELING.{ENV}_MODELING_GA4.STG_DIM_CAMPAIGN_SOURCE;

# 6. Ejecutar downstream dependencies
dbt run --models stg_dim_campaign_source+

# 7. Ejecutar tests
dbt test --models stg_dim_campaign_source
```

### Integration Tests
- [ ] Verificar que fact tables siguen funcionando con las nuevas dimensiones
- [ ] Verificar que dashboards de BI siguen funcionando
- [ ] Verificar que queries de usuarios no rompen
- [ ] Realizar full regression test

---

## 🚨 Troubleshooting Checklist

### Si un modelo falla con schema change

**Error común:**
```
Database Error in model stg_dim_campaign_source
  column "new_column" does not exist
```

**Solución:**
```bash
# 1. Full refresh del modelo
dbt run --full-refresh --models stg_dim_campaign_source

# 2. Si persiste, drop y recrear
# En Snowflake:
DROP TABLE IF EXISTS {ENV}_MODELING.{ENV}_MODELING_GA4.STG_DIM_CAMPAIGN_SOURCE;

# En dbt:
dbt run --models stg_dim_campaign_source
```

### Si la columna no se agrega automáticamente

**Verificar:**
```bash
# 1. Verificar que on_schema_change está configurado
dbt run --models stg_dim_campaign_source --debug

# 2. Buscar en logs:
# "Schema changed, applying on_schema_change=sync_all_columns"

# 3. Verificar configuración del modelo
cat models/GA4/modeling/stg_dim_campaign_source.sql | grep on_schema_change
```

### Si hay problemas con tipos de datos

**Limitación conocida:**
`on_schema_change` NO maneja cambios de tipo de dato.

**Solución:**
```sql
-- Opción 1: Cast explícito con compatibilidad backward
SELECT
    campaign_source_id,
    TRY_CAST(campaign_budget AS DECIMAL(18,2)) as campaign_budget
FROM table_campaign_source

-- Opción 2: Full refresh
dbt run --full-refresh --models stg_dim_campaign_source

-- Opción 3: Crear columna temporal durante transición
SELECT
    campaign_source_id,
    campaign_budget as campaign_budget_old,
    TRY_CAST(campaign_budget AS DECIMAL(18,2)) as campaign_budget_new
FROM table_campaign_source
```

---

## 📝 Documentation Updates Needed

### Internal Docs
- [ ] Actualizar wiki interno con guía de schema evolution
- [ ] Documentar proceso de add/remove columnas
- [ ] Crear guía de troubleshooting
- [ ] Documentar rollback procedures

### Schema.yml Updates
- [ ] Agregar `on_schema_change` a la configuración de modelos
- [ ] Documentar columnas nuevas cuando se agregan
- [ ] Actualizar tests para nuevas columnas

### Confluence/Wiki
- [ ] Crear página "Schema Evolution Best Practices"
- [ ] Documentar casos de uso reales
- [ ] Agregar FAQs

---

## 🎯 Success Criteria

Schema evolution está correctamente implementado cuando:

1. ✅ **Agregar columnas**: Puedes agregar una columna a un modelo y ejecutar `dbt run` sin errores, y la columna aparece en la tabla.

2. ✅ **Eliminar columnas**: Puedes remover una columna del SELECT y ejecutar `dbt run`, y la columna se elimina de la tabla.

3. ✅ **Sin downtime**: Los dashboards y queries existentes siguen funcionando durante schema changes.

4. ✅ **Propagación automática**: Los cambios se propagan desde staging → consumption sin intervención manual.

5. ✅ **Rollback funcional**: Puedes hacer rollback con `--full-refresh` si algo sale mal.

6. ✅ **Testing**: Los tests de dbt pasan después de schema changes.

7. ✅ **Documentación**: El equipo entiende cómo usar schema evolution y cuándo aplicarlo.

---

## 🔐 Security & Compliance

- [ ] Verificar que nuevas columnas no contienen PII sin encriptar
- [ ] Validar que schema changes no afectan políticas de data masking
- [ ] Documentar cambios en audit logs
- [ ] Verificar compliance con GDPR/regulaciones de datos

---

## 📅 Rollout Timeline (Sugerido)

### Semana 1: Setup y Testing
- [x] Implementar macro y actualizar modelos
- [x] Crear documentación
- [ ] Testing en DEV
- [ ] Smoke tests

### Semana 2: Staging Deployment
- [ ] Desplegar a STAGING
- [ ] Ejecutar integration tests
- [ ] Capacitar al equipo
- [ ] Documentar casos edge

### Semana 3: Production Rollout
- [ ] Deploy gradual a PROD (por dominio)
- [ ] Monitoreo intensivo
- [ ] Validación con stakeholders
- [ ] Documentar lessons learned

### Semana 4: Optimización
- [ ] Aplicar a todos los modelos restantes
- [ ] Refinamiento de configuración
- [ ] Actualizar runbooks
- [ ] Retrospectiva con el equipo

---

## 🎉 Next Steps After Completion

1. **Monitoring Dashboard**: Crear dashboard para visualizar schema changes over time
2. **Automation**: Automatizar notificaciones de schema changes vía Slack
3. **CI/CD Integration**: Integrar validación de schema en CI/CD pipeline
4. **Data Quality**: Implementar data quality checks para nuevas columnas
5. **Performance**: Monitorear performance impact de schema changes

---

## 📞 Support & Questions

Si tienes preguntas o encuentras issues:

1. Revisar `SCHEMA_EVOLUTION.md` para documentación completa
2. Revisar `examples/schema_evolution_example.sql` para ejemplos
3. Consultar logs de dbt con `--debug` flag
4. Contactar al equipo de data engineering

---

**Última actualización:** 2026-08-03
**Versión:** 1.0
**Autor:** Data Engineering Team
