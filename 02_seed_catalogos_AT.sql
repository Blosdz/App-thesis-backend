BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'planes_pkey'
      AND conrelid = '"AT".planes'::regclass
  ) THEN
    ALTER TABLE "AT".planes
      ADD CONSTRAINT planes_pkey PRIMARY KEY (id);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'planes_tipos_tesis_precios_pkey'
      AND conrelid = '"AT".planes_tipos_tesis_precios'::regclass
  ) THEN
    ALTER TABLE "AT".planes_tipos_tesis_precios
      ADD CONSTRAINT planes_tipos_tesis_precios_pkey PRIMARY KEY (id);
  END IF;
END $$;

-- Catalogo de ajustes adicionales
WITH seed (
  id,
  codigo,
  nombre,
  tipo_ajuste,
  valor,
  signo,
  automatico,
  requiere_evaluacion,
  descripcion
) AS (
  VALUES
    ('26fc328e-ccbd-4c32-be95-03f959748120', 'nivel_pregrado', 'Ajuste academico Pregrado', 'porcentaje', '0', '+', true, false, 'Pregrado no genera recargo adicional'),
    ('7c3813eb-77fb-4e7c-b442-047e2a1c019f', 'nivel_maestria', 'Ajuste academico Maestria', 'porcentaje', '15', '+', true, false, 'Maestria aplica recargo del 15% sobre el precio base'),
    ('80f91849-2dd4-4c97-ae1d-6659fcfd7b56', 'nivel_especialidad', 'Ajuste academico Especialidad', 'porcentaje', '15', '+', true, false, 'Especialidad aplica recargo del 15% sobre el precio base'),
    ('167304b6-5889-4427-9f43-63a9a8ab95ea', 'nivel_doctorado', 'Ajuste academico Doctorado', 'porcentaje', '20', '+', true, false, 'Doctorado aplica recargo del 20% sobre el precio base'),
    ('ab5bdd10-634a-46cc-a8a4-b34b199f21bd', 'variable_adicional', 'Variable adicional', 'monto_fijo', '1000', '+', true, false, 'Cuando se agrega una variable adicional principal al estudio'),
    ('b5596782-a5f8-4197-870d-d9cec6d3f5e6', 'variable_exogena_simple', 'Variable exogena o de clasificacion simple', 'monto_fijo', '0', '+', true, false, 'No genera costo adicional cuando solo es descriptiva o de clasificacion simple'),
    ('b70ae642-b3e6-44bb-9e8e-f96ef1b13074', 'variable_exogena_analisis_adicional', 'Variable exogena con analisis adicional', 'evaluacion', NULL, '+', false, true, 'Requiere evaluacion por complejidad analitica real'),
    ('f9667ba0-d957-41c3-afbe-6ff8730869c1', 'sin_analisis_estadistico', 'No requiere analisis estadistico', 'monto_fijo', '500', '-', true, false, 'Descuento de S/ 500 cuando no se requiere analisis estadistico'),
    ('ed57f92b-2a4a-4f26-a17d-d9298fcb460b', 'arquitectura_diseno', 'Tesista de Arquitectura o Diseno', 'evaluacion', NULL, '+', false, true, 'Caso especial sujeto a evaluacion particular'),
    ('5416ae63-13ab-454b-a0f9-eb23d141377f', 'correccion_observaciones_adicionales', 'Correccion de observaciones adicionales', 'monto_fijo', '150', '+', false, false, 'Cobro por bloque adicional de observaciones levantadas'),
    ('257cc557-3603-4bac-a53e-80d26945f43a', 'presustentacion_extra', 'Presustentacion adicional', 'monto_fijo', '200', '+', false, false, 'Presustentacion cobrada fuera del beneficio incluido en plan'),
    ('1527a48b-8ca0-4808-a018-365f4b83267e', 'asesoria_externa', 'Asesoria externa dentro del sistema', 'evaluacion', NULL, '+', false, true, 'Asesoria adicional fuera del paquete incluido; puede depender del asesor o tarifa')
),
deleted AS (
  DELETE FROM "AT".ajustes_adicionales_tesis a
  USING seed s
  WHERE a.codigo = s.codigo
  RETURNING 1
)
INSERT INTO "AT".ajustes_adicionales_tesis (
  id,
  codigo,
  nombre,
  tipo_ajuste,
  valor,
  signo,
  automatico,
  requiere_evaluacion,
  descripcion,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.id::uuid,
  s.codigo,
  s.nombre,
  s.tipo_ajuste,
  s.valor::numeric,
  s.signo,
  s.automatico,
  s.requiere_evaluacion,
  s.descripcion,
  true,
  '2026-04-12 07:36:12.921854+00'::timestamptz,
  '2026-04-12 07:36:12.921854+00'::timestamptz
FROM seed s;

-- Soporte para la cotizacion por nivel academico
WITH seed (nivel_academico, tipo_ajuste, valor) AS (
  VALUES
    ('pregrado', 'porcentaje', '0'),
    ('maestria', 'porcentaje', '15'),
    ('especialidad', 'porcentaje', '15'),
    ('doctorado', 'porcentaje', '20')
),
deleted AS (
  DELETE FROM "AT".ajustes_nivel_academico a
  USING seed s
  WHERE a.nivel_academico = s.nivel_academico
  RETURNING 1
)
INSERT INTO "AT".ajustes_nivel_academico (
  nivel_academico,
  tipo_ajuste,
  valor,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.nivel_academico,
  s.tipo_ajuste,
  s.valor::numeric,
  true,
  '2026-04-12 07:36:12.921854+00'::timestamptz,
  '2026-04-12 07:36:12.921854+00'::timestamptz
FROM seed s;

-- Catalogo de beneficios
DELETE FROM "AT".planes_beneficios
WHERE plan_id IN (
  '77561969-ffb8-4823-a20a-fbc9ebc7feb3'::uuid,
  '0eb3868b-cde8-4502-aea5-32b7faa933b0'::uuid,
  '6b9d7f93-9456-4023-883e-470b00781b25'::uuid
)
   OR beneficio_id IN (
  '5d885de1-e1d7-4d63-92ea-ff08461c2055'::uuid,
  'f26c91a2-860a-499d-8735-4257ab04f6bd'::uuid,
  'c72c2b60-fb17-4ecc-bc35-0895d861ac63'::uuid
);

DELETE FROM "AT".planes_tipos_tesis_precios
WHERE plan_id IN (
  '77561969-ffb8-4823-a20a-fbc9ebc7feb3'::uuid,
  '0eb3868b-cde8-4502-aea5-32b7faa933b0'::uuid,
  '6b9d7f93-9456-4023-883e-470b00781b25'::uuid
);

WITH seed (id, codigo, nombre, descripcion, tipo_control) AS (
  VALUES
    ('5d885de1-e1d7-4d63-92ea-ff08461c2055', 'ai_tool', 'Acceso al sistema AI', 'Acceso al sistema AI y sus funcionalidades para el plan de tesis', 'booleano'),
    ('f26c91a2-860a-499d-8735-4257ab04f6bd', 'asesorias_gratis', 'Asesorias gratis', 'Cantidad de asesorias incluidas sin costo adicional', 'contador'),
    ('d46308ca-84d2-471f-a361-54318cc1c779', 'apoyo_defensa', 'Apoyo en defensa y sustentacion', 'Apoyo para preparacion de defensa y sustentacion', 'booleano'),
    ('fca8d591-cd80-4c9d-a878-53eed889fb96', 'seguimiento_constante', 'Seguimiento constante', 'Seguimiento continuo del avance del tesista', 'booleano'),
    ('7911264d-60be-43f0-aad1-242523caae33', 'orientacion_metodologica', 'Orientacion metodologica', 'Orientacion sobre el enfoque metodologico de la tesis', 'booleano'),
    ('2132b8f8-f38f-4e96-908b-cd9d180debda', 'revision_estrategica', 'Revision estrategica del trabajo', 'Revision estrategica del contenido y planteamiento', 'booleano'),
    ('b5df6d32-c089-47e9-8e70-d6b90926a812', 'acompanamiento_metodologico', 'Acompanamiento metodologico cercano', 'Acompanamiento mas cercano durante el desarrollo', 'booleano'),
    ('c72c2b60-fb17-4ecc-bc35-0895d861ac63', 'presustentacion_incluida', 'Presustentacion incluida', 'Incluye una presustentacion dentro del plan', 'contador'),
    ('281e4f5e-f18c-4a46-b31a-a8a45ab316fb', 'revision_borradores', 'Revision progresiva de borradores', 'Revision progresiva de avances y borradores', 'booleano'),
    ('03358eaa-cb1c-41ef-adc9-1e1e5791d770', 'apoyo_resultados_analisis', 'Apoyo de resultados y analisis', 'Apoyo en el analisis e interpretacion de resultados', 'booleano'),
    ('f034327a-cef3-4d43-9cd0-c1dcc57cebc8', 'preparacion_sustentacion', 'Preparacion para la sustentacion', 'Preparacion especifica para la sustentacion final', 'booleano')
),
deleted AS (
  DELETE FROM "AT".beneficios_plan_catalogo b
  USING seed s
  WHERE b.codigo = s.codigo
  RETURNING 1
)
INSERT INTO "AT".beneficios_plan_catalogo (
  id,
  codigo,
  nombre,
  descripcion,
  tipo_control,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.id::uuid,
  s.codigo,
  s.nombre,
  s.descripcion,
  s.tipo_control,
  true,
  '2026-04-12 07:34:35.409461+00'::timestamptz,
  '2026-04-12 07:34:35.409461+00'::timestamptz
FROM seed s;

-- Planes
WITH seed (id, nombre, precio, duracion_dias, caracteristicas) AS (
  VALUES
    ('77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'Esencial', '0.00', 180, '{"descripcion":"Acceso base al sistema AI para desarrollo del plan de tesis","incluye_ai_tool":true,"asesorias_incluidas":0,"presustentaciones_incluidas":0}'),
    ('0eb3868b-cde8-4502-aea5-32b7faa933b0', 'Guiado', '0.00', 180, '{"descripcion":"Plan con acompanamiento metodologico y asesorias incluidas","incluye_ai_tool":true,"asesorias_incluidas":4,"presustentaciones_incluidas":0}'),
    ('6b9d7f93-9456-4023-883e-470b00781b25', 'Integral', '0.00', 180, '{"descripcion":"Plan completo con acompanamiento intensivo, presustentacion y soporte ampliado","incluye_ai_tool":true,"asesorias_incluidas":8,"presustentaciones_incluidas":1}')
)
INSERT INTO "AT".planes (
  id,
  nombre,
  precio,
  duracion_dias,
  caracteristicas,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.id::uuid,
  s.nombre,
  s.precio::numeric,
  s.duracion_dias,
  s.caracteristicas::jsonb,
  true,
  '2026-04-12 07:34:18.588089+00'::timestamptz,
  '2026-04-13 21:15:53.258998+00'::timestamptz
FROM seed s
ON CONFLICT (id) DO UPDATE SET
  nombre = EXCLUDED.nombre,
  precio = EXCLUDED.precio,
  duracion_dias = EXCLUDED.duracion_dias,
  caracteristicas = EXCLUDED.caracteristicas,
  activo = EXCLUDED.activo,
  actualizado_en = EXCLUDED.actualizado_en;

-- Relacion minima entre planes y beneficios para /planes/disponibles
WITH seed (plan_id, beneficio_id, incluido, cantidad, metadata) AS (
  VALUES
    ('77561969-ffb8-4823-a20a-fbc9ebc7feb3', '5d885de1-e1d7-4d63-92ea-ff08461c2055', true, NULL, NULL),
    ('0eb3868b-cde8-4502-aea5-32b7faa933b0', '5d885de1-e1d7-4d63-92ea-ff08461c2055', true, NULL, NULL),
    ('0eb3868b-cde8-4502-aea5-32b7faa933b0', 'f26c91a2-860a-499d-8735-4257ab04f6bd', true, 4, NULL),
    ('6b9d7f93-9456-4023-883e-470b00781b25', '5d885de1-e1d7-4d63-92ea-ff08461c2055', true, NULL, NULL),
    ('6b9d7f93-9456-4023-883e-470b00781b25', 'f26c91a2-860a-499d-8735-4257ab04f6bd', true, 8, NULL),
    ('6b9d7f93-9456-4023-883e-470b00781b25', 'c72c2b60-fb17-4ecc-bc35-0895d861ac63', true, 1, NULL)
),
deleted AS (
  DELETE FROM "AT".planes_beneficios pb
  USING seed s
  WHERE pb.plan_id = s.plan_id::uuid
    AND pb.beneficio_id = s.beneficio_id::uuid
  RETURNING 1
)
INSERT INTO "AT".planes_beneficios (
  plan_id,
  beneficio_id,
  incluido,
  cantidad,
  metadata,
  creado_en,
  actualizado_en
)
SELECT
  s.plan_id::uuid,
  s.beneficio_id::uuid,
  s.incluido,
  s.cantidad,
  s.metadata::jsonb,
  '2026-04-12 07:34:35.409461+00'::timestamptz,
  '2026-04-12 07:34:35.409461+00'::timestamptz
FROM seed s;

-- Tipos de tesis
WITH seed (codigo, nombre, descripcion) AS (
  VALUES
    ('descriptivo', 'Descriptivo', 'Estudio descriptivo'),
    ('correlacional', 'Correlacional', 'Estudio correlacional'),
    ('comparativo', 'Comparativo', 'Estudio comparativo'),
    ('predictivo', 'Predictivo', 'Estudio predictivo'),
    ('explicativo', 'Explicativo', 'Estudio explicativo'),
    ('pre_experimental', 'Pre experimental', 'Diseno pre experimental'),
    ('cuasi_experimental', 'Cuasi experimental', 'Diseno cuasi experimental'),
    ('exploratorio', 'Exploratorio', 'Estudio exploratorio')
),
updated AS (
  UPDATE "AT".tipos_tesis tt
  SET
    nombre = s.nombre,
    descripcion = s.descripcion,
    activo = true,
    actualizado_en = '2026-04-12 07:35:37.165809+00'::timestamptz
  FROM seed s
  WHERE tt.codigo = s.codigo
  RETURNING tt.codigo
)
INSERT INTO "AT".tipos_tesis (
  codigo,
  nombre,
  descripcion,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.codigo,
  s.nombre,
  s.descripcion,
  true,
  '2026-04-12 07:35:37.165809+00'::timestamptz,
  '2026-04-12 07:35:37.165809+00'::timestamptz
FROM seed s
WHERE NOT EXISTS (
  SELECT 1
  FROM "AT".tipos_tesis tt
  WHERE tt.codigo = s.codigo
);

DO $$
BEGIN
  IF to_regclass('"AT".doc_thesis_formats') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM information_schema.columns
       WHERE table_schema = 'AT'
         AND table_name = 'tipos_tesis'
         AND column_name = 'default_doc_thesis_format_id'
     ) THEN
    UPDATE "AT".tipos_tesis AS tt
    SET
      default_doc_thesis_format_id = f.id,
      actualizado_en = now()
    FROM "AT".doc_thesis_formats AS f
    WHERE f.uname = 'apa7'
      AND tt.default_doc_thesis_format_id IS NULL;
  END IF;
END $$;

-- Precios por plan y tipo de tesis
WITH seed (id, plan_id, tipo_tesis_codigo, precio_base) AS (
  VALUES
    ('2ecadebc-797e-4e48-8e4b-cbdcc7379f22', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'descriptivo', '1600.00'),
    ('8f43bf2d-10bc-4a93-aa19-84b6f4855de3', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'descriptivo', '3500.00'),
    ('7b3cf018-7486-4421-acab-9912059ece44', '6b9d7f93-9456-4023-883e-470b00781b25', 'descriptivo', '4000.00'),
    ('810eb9ac-dac2-442c-ab99-d3cf8ac41ed7', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'correlacional', '1800.00'),
    ('45212a9e-803f-44a2-a6ab-860535a979c6', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'correlacional', '3500.00'),
    ('fb1c3ee8-d589-45d5-bdf6-c7995b86a11f', '6b9d7f93-9456-4023-883e-470b00781b25', 'correlacional', '5000.00'),
    ('58823f7a-c6cb-4f44-824c-86b4826c3bd2', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'comparativo', '1800.00'),
    ('67fc3813-d4dd-4d71-a231-8ddab60e16e7', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'comparativo', '3500.00'),
    ('532b0766-e9bb-4bfe-a1a8-1c1312ca5839', '6b9d7f93-9456-4023-883e-470b00781b25', 'comparativo', '5000.00'),
    ('068765b7-9f94-4f9f-b14b-5e5e111bbf80', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'predictivo', '1800.00'),
    ('67e5bb74-d3f8-4feb-a98f-b9fd6f0cbc46', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'predictivo', '3500.00'),
    ('5f59ed1c-bb9a-4385-b9fe-7cabf12ebd29', '6b9d7f93-9456-4023-883e-470b00781b25', 'predictivo', '6000.00'),
    ('952db877-abc9-4142-bb48-3e9f4413cd88', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'explicativo', '2000.00'),
    ('01c47c7b-db23-46c2-9b35-c96e76929a51', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'explicativo', '4000.00'),
    ('6a8d97a8-5c75-421b-86f9-043e09bde5a8', '6b9d7f93-9456-4023-883e-470b00781b25', 'explicativo', '7000.00'),
    ('f622c629-b16f-4d1a-a943-2e7440d43e2b', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'pre_experimental', '2000.00'),
    ('6f3f937a-2bad-4158-b47a-34d28e0e7b7f', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'pre_experimental', '4500.00'),
    ('9a09f6cf-5299-4dde-8f87-5fde019baa72', '6b9d7f93-9456-4023-883e-470b00781b25', 'pre_experimental', '8500.00'),
    ('a8a7cdfa-963b-4811-8a55-be3280dcacad', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'cuasi_experimental', '2200.00'),
    ('64b15721-b4fb-498b-ac4d-9a70c5e1d355', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'cuasi_experimental', '5000.00'),
    ('2ec0e998-a75f-48f6-a72d-55ea67a1c756', '6b9d7f93-9456-4023-883e-470b00781b25', 'cuasi_experimental', '10000.00'),
    ('786e3037-8eb7-4823-9e00-6defc5b3a086', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'exploratorio', '2500.00'),
    ('24951e3a-eeac-44d3-b407-cc64eb46b5cd', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'exploratorio', '5500.00'),
    ('5585a188-6586-4fba-9c90-ba99d0518333', '6b9d7f93-9456-4023-883e-470b00781b25', 'exploratorio', '12000.00')
),
deleted AS (
  DELETE FROM "AT".planes_tipos_tesis_precios ptp
  USING seed s, "AT".tipos_tesis tt
  WHERE ptp.id = s.id::uuid
     OR (
       tt.codigo = s.tipo_tesis_codigo
       AND ptp.plan_id = s.plan_id::uuid
       AND ptp.tipo_tesis_id = tt.id
     )
  RETURNING 1
)
INSERT INTO "AT".planes_tipos_tesis_precios (
  id,
  plan_id,
  tipo_tesis_id,
  precio_base,
  moneda,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.id::uuid,
  s.plan_id::uuid,
  tt.id,
  s.precio_base::numeric,
  'PEN',
  true,
  '2026-04-12 07:35:58.121924+00'::timestamptz,
  '2026-04-12 07:35:58.121924+00'::timestamptz
FROM seed s
JOIN "AT".tipos_tesis tt ON tt.codigo = s.tipo_tesis_codigo
ON CONFLICT (id) DO UPDATE SET
  plan_id = EXCLUDED.plan_id,
  tipo_tesis_id = EXCLUDED.tipo_tesis_id,
  precio_base = EXCLUDED.precio_base,
  moneda = EXCLUDED.moneda,
  activo = EXCLUDED.activo,
  actualizado_en = EXCLUDED.actualizado_en;

-- Universidades
WITH seed (nombre, ubicacion) AS (
  VALUES
    ('Universidad Nacional Tecnologica de Frontera San Ignacio de Loyola', 'Cajamarca/San Ignacio'),
    ('Universidad Interamericana para el Desarrollo', 'Lima/Lima'),
    ('Universidad Jose Carlos Mariategui de Moquegua', 'Moquegua/Mariscal Nieto'),
    ('Universidad Nacional de Musica', 'Lima/Lima'),
    ('Universidad Nacional Daniel Alomia Robles', 'Huanuco/Huanuco'),
    ('Universidad Catolica Los Angeles de Chimbote', 'Ancash/Santa'),
    ('Universidad Politecnica del Peru S.A.', 'Lima/Lima'),
    ('Universidad Privada de Trujillo', 'La Libertad/Trujillo'),
    ('Universidad Peruana del Centro', 'Junin/Huancayo'),
    ('Universidad Nacional Ciro Alegria', 'La Libertad/Sanchez Carrion'),
    ('Universidad Nacional Pedro Ruiz Gallo', 'Lambayeque/Lambayeque'),
    ('Universidad Nacional San Luis Gonzaga', 'Ica/Ica'),
    ('Universidad Autonoma de Ica', 'Ica/Chincha'),
    ('Facultad de Teologia Pontificia y Civil de Lima', 'Lima/Lima'),
    ('Universidad Nacional Federico Villarreal', 'Lima/Lima'),
    ('Universidad Tecnologica de los Andes', 'Apurimac/Abancay'),
    ('Universidad Peruana Los Andes', 'Junin/Huancayo'),
    ('Universidad Nacional Micaela Bastidas de Apurimac', 'Apurimac/Abancay'),
    ('Universidad Nacional Jose Faustino Sanchez Carrion', 'Lima/Huaura'),
    ('Universidad Senor de Sipan', 'Lambayeque/Chiclayo'),
    ('Universidad Nacional del Callao', 'Callao/Prov. Const. del Callao'),
    ('Universidad Nacional de Educacion Enrique Guzman y Valle', 'Lima/Lima'),
    ('Universidad Privada Norbert Wiener', 'Lima/Lima'),
    ('Universidad Nacional de Tumbes', 'Tumbes/Tumbes'),
    ('Universidad Privada San Juan Bautista', 'Lima/Lima'),
    ('Universidad Nacional Amazonica de Madre de Dios', 'Madre de Dios/Tambopata'),
    ('Universidad Nacional Agraria de la Selva', 'Huanuco/Leoncio Prado'),
    ('Universidad Nacional Daniel Alcides Carrion', 'Pasco/Pasco'),
    ('Universidad Nacional Hermilio Valdizan de Huanuco', 'Huanuco/Huanuco'),
    ('Universidad Nacional de Huancavelica', 'Huancavelica/Huancavelica'),
    ('Universidad Nacional Intercultural de Quillabamba', 'Cusco/La Convencion'),
    ('Universidad Tecnologica del Peru', 'Lima/Lima'),
    ('Universidad Privada de Huancayo Franklin Roosevelt', 'Junin/Huancayo'),
    ('Universidad Cesar Vallejo', 'La Libertad/Trujillo'),
    ('Universidad de Huanuco', 'Huanuco/Huanuco'),
    ('Universidad Nacional de Piura', 'Piura/Piura'),
    ('Universidad Nacional de San Antonio Abad del Cusco', 'Cusco/Cusco'),
    ('Universidad Nacional de San Martin', 'San Martin/San Martin'),
    ('Universidad Nacional de Frontera', 'Piura/Sullana'),
    ('Universidad Nacional del Santa', 'Ancash/Santa'),
    ('Universidad Nacional del Centro del Peru', 'Junin/Huancayo'),
    ('Universidad Catolica de Trujillo Benedicto XVI', 'La Libertad/Trujillo'),
    ('Universidad Nacional Autonoma de Tayacaja Daniel Hernandez Morillo', 'Huancavelica/Tayacaja'),
    ('Universidad Nacional de la Amazonia Peruana', 'Loreto/Maynas'),
    ('Universidad Nacional Santiago Antunez de Mayolo', 'Ancash/Huaraz'),
    ('Universidad Nacional Autonoma de Chota', 'Cajamarca/Chota'),
    ('Universidad Le Cordon Bleu S.A.C.', 'Lima/Lima'),
    ('Universidad Nacional de Ucayali', 'Ucayali/Coronel Portillo'),
    ('Universidad Maria Auxiliadora', 'Lima/Lima'),
    ('Universidad Nacional Autonoma Altoandina de Tarma', 'Junin/Tarma'),
    ('Universidad Nacional Intercultural de la Amazonia', 'Ucayali/Coronel Portillo'),
    ('Universidad Nacional de Trujillo', 'La Libertad/Trujillo'),
    ('Universidad Catolica Sedes Sapientiae', 'Lima/Lima'),
    ('Universidad Nacional de Canete', 'Lima/Canete'),
    ('Universidad Nacional de San Agustin de Arequipa', 'Arequipa/Arequipa'),
    ('Universidad Nacional de Juliaca', 'Puno/San Roman'),
    ('Universidad Nacional Intercultural Fabiola Salazar Leguia de Bagua', 'Amazonas/Bagua'),
    ('Universidad Continental', 'Junin/Huancayo'),
    ('Universidad Autonoma del Peru', 'Lima/Lima'),
    ('Universidad Nacional de Cajamarca', 'Cajamarca/Cajamarca'),
    ('Universidad Nacional Autonoma de Alto Amazonas', 'Loreto/Alto Amazonas'),
    ('Universidad Nacional Tecnologica de Lima Sur', 'Lima/Lima'),
    ('Universidad Jaime Bausate y Meza', 'Lima/Lima'),
    ('Universidad Nacional Jorge Basadre Grohmann', 'Tacna/Tacna'),
    ('Universidad Peruana Union', 'Lima/Lima'),
    ('Universidad Nacional de San Cristobal de Huamanga', 'Ayacucho/Huamanga'),
    ('Universidad Nacional de Barranca', 'Lima/Barranca'),
    ('Universidad Cientifica del Sur', 'Lima/Lima'),
    ('Universidad ESAN', 'Lima/Lima'),
    ('Universidad Nacional Mayor de San Marcos', 'Lima/Lima'),
    ('Universidad Privada Antenor Orrego', 'La Libertad/Trujillo'),
    ('Universidad Nacional Intercultural de la Selva Central Juan Santos Atahualpa', 'Junin/Chanchamayo'),
    ('Universidad Catolica Santo Toribio de Mogrovejo', 'Lambayeque/Chiclayo'),
    ('Universidad La Salle', 'Arequipa/Arequipa'),
    ('Universidad Nacional de Jaen', 'Cajamarca/Jaen'),
    ('Universidad Nacional de Moquegua', 'Moquegua/Mariscal Nieto'),
    ('Universidad Catolica de Santa Maria', 'Arequipa/Arequipa'),
    ('Universidad Nacional del Altiplano', 'Puno/Puno'),
    ('Universidad Andina del Cusco', 'Cusco/Cusco'),
    ('Universidad Privada de Tacna', 'Tacna/Tacna'),
    ('Universidad Nacional de Ingenieria', 'Lima/Lima'),
    ('Universidad de Ciencias y Humanidades', 'Lima/Lima'),
    ('Universidad Privada del Norte', 'La Libertad/Trujillo'),
    ('Universidad Catolica San Pablo', 'Arequipa/Arequipa'),
    ('Universidad Marcelino Champagnat', 'Lima/Lima'),
    ('Universidad San Ignacio de Loyola', 'Lima/Lima'),
    ('Universidad Peruana de Ciencias Aplicadas', 'Lima/Lima'),
    ('Universidad Nacional Jose Maria Arguedas', 'Apurimac/Andahuaylas'),
    ('Universidad Nacional Toribio Rodriguez de Mendoza de Amazonas', 'Amazonas/Chachapoyas'),
    ('Universidad de San Martin de Porres', 'Lima/Lima'),
    ('Universidad Antonio Ruiz de Montoya', 'Lima/Lima'),
    ('Universidad Nacional Autonoma de Huanta', 'Ayacucho/Huanta'),
    ('Universidad Nacional Agraria La Molina', 'Lima/Lima'),
    ('Universidad de Piura', 'Piura/Piura'),
    ('Universidad Ricardo Palma', 'Lima/Lima'),
    ('Universidad Femenina del Sagrado Corazon', 'Lima/Lima'),
    ('Universidad de Ciencias y Artes de America Latina', 'Lima/Lima'),
    ('Universidad para el Desarrollo Andino', 'Huancavelica/Angaraes'),
    ('Universidad Peruana Cayetano Heredia', 'Lima/Lima'),
    ('Universidad del Pacifico', 'Lima/Lima')
),
updated AS (
  UPDATE "AT".universidades u
  SET
    ubicacion = s.ubicacion,
    pais = 'Peru',
    actualizado_en = '2026-03-17 23:02:49.397032+00'::timestamptz
  FROM seed s
  WHERE lower(u.nombre) = lower(s.nombre)
  RETURNING u.id
)
INSERT INTO "AT".universidades (
  nombre,
  ubicacion,
  pais,
  creado_en,
  actualizado_en
)
SELECT
  s.nombre,
  s.ubicacion,
  'Peru',
  '2026-03-17 23:02:49.397032+00'::timestamptz,
  '2026-03-17 23:02:49.397032+00'::timestamptz
FROM seed s
WHERE NOT EXISTS (
  SELECT 1
  FROM "AT".universidades u
  WHERE lower(u.nombre) = lower(s.nombre)
);

-- Tipos de sugerencia asesor
WITH seed (codigo, nombre, descripcion) AS (
  VALUES
    ('observacion_general', 'Observacion general', 'Comentario general sobre el avance del documento'),
    ('estructura', 'Estructura', 'Sugerencias sobre la estructura del documento'),
    ('metodologia', 'Metodologia', 'Observaciones sobre el enfoque metodologico'),
    ('referencias', 'Referencias', 'Correcciones o mejoras en citas y bibliografia'),
    ('redaccion', 'Redaccion', 'Mejoras de claridad, estilo y coherencia')
),
updated AS (
  UPDATE "AT".tipos_sugerencia_asesor tsa
  SET
    nombre = s.nombre,
    descripcion = s.descripcion,
    activo = true,
    actualizado_en = now()
  FROM seed s
  WHERE tsa.codigo = s.codigo
  RETURNING tsa.codigo
)
INSERT INTO "AT".tipos_sugerencia_asesor (
  codigo,
  nombre,
  descripcion,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.codigo,
  s.nombre,
  s.descripcion,
  true,
  now(),
  now()
FROM seed s
WHERE NOT EXISTS (
  SELECT 1
  FROM "AT".tipos_sugerencia_asesor tsa
  WHERE tsa.codigo = s.codigo
);

COMMIT;
