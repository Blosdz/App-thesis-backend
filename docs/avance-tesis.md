# Plan: cómo determinar el "avance de tesis"

## El problema

Hoy no existe una definición real de avance. Lo que se muestra es una heurística
pobre (`documentos_recientes * 12.5%` en el dashboard del estudiante). La tabla
"Mis Estudiantes" del asesor necesita una columna **Avance** que sea creíble, y la
pregunta de fondo es: **¿quién define el avance y cómo?**

Respuesta corta: **lo define el asesor**, sobre una estructura de **fases
ordenadas** (primero problemática, luego marco teórico, etc.), y el sistema le da
señales automáticas como sugerencia — no como verdad.

---

## Modelo propuesto: fases ponderadas, autoridad del asesor

Una tesis = lista ordenada de **fases**. Cada fase tiene un **peso** (suman 100),
un **estado** y un **progreso interno** opcional.

### Plantilla por defecto (editable por universidad)

| # | Fase (`clave`) | Peso | Señal automática sugerida |
|---|---|---|---|
| 1 | Planteamiento del problema (`planteamiento`) — problemática, objetivos, justificación, hipótesis | 10 | secciones "Introducción/Planteamiento" con contenido |
| 2 | Marco teórico (`marco_teorico`) | 15 | secciones de marco teórico redactadas + nº de referencias |
| 3 | Marco metodológico (`metodologia`) | 15 | sección metodología redactada; variables/instrumentos definidos |
| 4 | Trabajo de campo / recolección (`campo`) | 15 | (manual — o integración con COLMENA: respuestas de formulario) |
| 5 | Resultados y análisis (`resultados`) | 15 | sección resultados redactada; artefactos/gráficos de COLMENA |
| 6 | Discusión y conclusiones (`conclusiones`) | 10 | secciones discusión + conclusiones redactadas |
| 7 | Redacción final y formato (`redaccion`) | 5 | `documentos_tesis` subido y con formato aplicado |
| 8 | Revisión del asesor (`revision`) | 5 | ratio de `sugerencias` verificadas vs pendientes |
| 9 | Dictamen / jurado (`dictamen`) | 5 | `tesis.estado = 'revision'` → en curso; aprobado → completo |
| 10 | Sustentación (`sustentacion`) | 5 | reunión `tipo_reunion='presustentacion'` completada |

> Los pesos y la lista son configurables. Universidades distintas pueden tener
> fases distintas (p. ej. tesis de arquitectura). Se reutiliza el patrón de
> `modulos_lista` (plantilla por `universidad_id`) → `modulos_tesis` (instancia
> por tesis) que **ya existe en el esquema pero está sin usar**.

### Estados de fase

`pendiente` → `en_progreso` → `completado`, más `observado` (el asesor la devolvió).

### Fórmula del avance total

```
avance_total = Σ ( peso_fase * progreso_fase / 100 )
```

Versión simple sin `progreso` interno (checklist binario con media fase):

```
avance_total = Σ peso(fases completadas) + 0.5 * Σ peso(fases en_progreso)
```

### La etiqueta "Estado" (el pill de la tabla)

Se deriva, no se guarda aparte:

- relación `pendiente` → **"Pendiente aceptación"**
- sin tesis → **"Sin tesis vinculada"**
- primera fase no completada → **"Fase N: <título>"** (p. ej. "Fase 3: Metodología")
- `tesis.estado='revision'` → **"En revisión"**
- avance = 100 o `tesis.estado='completado'` → **"Listo para sustentar"**

---

## Quién hace qué

- **Asesor (fuente de verdad):** en la ficha del estudiante (`/advisor/students/:id`)
  ve las fases, marca cada una `en_progreso` / `completado` / `observado`, ajusta
  el `progreso` interno si quiere granularidad. Cada cambio queda con
  `definido_por` + timestamp. Es el mismo gesto que ya soporta
  `PATCH /modulos/:moduloId { estado, progreso, observacion }`.
- **Sistema (sugerencia):** calcula el % automático por fase con las señales de la
  tabla y lo muestra al lado del valor del asesor ("automático: 62% · tú: 50%").
  El asesor decide si lo adopta. Nunca sobrescribe lo que el asesor fijó.
- **Estudiante:** ve el avance en su workspace (solo lectura); entiende qué fase
  falta y por qué.

---

## Esquema

Opción A — reutilizar `modulos_lista` / `modulos_tesis` (mínimo cambio):
- Sembrar `modulos_lista` con la plantilla de fases (una fila por universidad, o
  una global con `universidad_id IS NULL`).
- Añadir `peso numeric(5,2)` y `clave varchar(40)` a `modulos_lista`/`modulos_tesis`
  (hoy el peso no existe → el avance es media simple de `progreso`).
- Al crear una tesis (o al primer acceso del asesor), instanciar `modulos_tesis`
  desde la plantilla de su universidad.
- Vista `vw_avance_tesis (tesis_id, avance_pct, fase_actual, fases_completadas, fases_total)`.

Opción B — tabla dedicada `fases_tesis` (más limpia, más trabajo):

```sql
CREATE TABLE "AT".fases_tesis (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tesis_id      uuid NOT NULL REFERENCES "AT".tesis(id) ON DELETE CASCADE,
  clave         varchar(40) NOT NULL,
  titulo        text NOT NULL,
  orden         int NOT NULL,
  peso          numeric(5,2) NOT NULL DEFAULT 0,
  estado        varchar(20) NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente','en_progreso','completado','observado')),
  progreso      int NOT NULL DEFAULT 0 CHECK (progreso BETWEEN 0 AND 100),
  observacion   text,
  definido_por  uuid REFERENCES "AT".usuarios(id),
  actualizado_en timestamptz NOT NULL DEFAULT now(),
  creado_en     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tesis_id, clave)
);
```

Recomendación: **Opción A** para no multiplicar tablas — `modulos_tesis` ya tiene
`estado` + `progreso` + endpoint de update; solo falta `peso`, `clave` y el seed.

---

## API a añadir

- `GET  /tesis/:tesisId/avance` → `{ avance_pct, fuente, fases: [...] }`
- `POST /tesis/:tesisId/avance/instanciar` → crea las fases desde la plantilla (idempotente)
- `PATCH /tesis/:tesisId/fases/:clave` → `{ estado?, progreso?, observacion? }` (solo asesor de esa tesis / admin)
- El listado de estudiantes del asesor ya devuelve `avance_pct` (ver "transición").

---

## Transición (ya implementado)

Mientras no exista el seed de fases, `GET /asesores/estudiantes` y
`/asesores/estudiantes/:id` devuelven `avance_pct` + `avance_fuente` calculados así
(en `asesores.service.ts::buildEstudianteAsesorSql`):

1. si hay filas en `modulos_tesis` → media de `progreso` (`fuente = 'modulos'`)
2. si no, si hay `tesis_sections` nivel 1 → % de secciones con contenido > 40 chars (`fuente = 'contenido'`)
3. si no → `NULL` → la UI muestra "Sin registro"

La UI ("Mis Estudiantes") ya pinta la barra con esto y muestra la fuente en el
tooltip. Al implementar el modelo de fases, el paso 1 pasa a usar el peso y la UI
no cambia.

---

## Orden de implementación sugerido

1. **(hecho)** columna Avance transicional en el listado + rediseño de la página.
2. Añadir `peso` + `clave` a `modulos_lista`/`modulos_tesis` + seed de la plantilla global.
3. Instanciar fases al crear tesis (`tesis.service`) + endpoint `instanciar` para las existentes.
4. `PATCH /tesis/:id/fases/:clave` + UI de fases en `/advisor/students/:id` (ficha).
5. Panel de fases en el workspace del estudiante (solo lectura).
6. Señales automáticas por fase (job o cálculo on-read) mostradas como sugerencia.
7. Sustituir la heurística `documentos * 12.5%` del dashboard del estudiante por `vw_avance_tesis`.
