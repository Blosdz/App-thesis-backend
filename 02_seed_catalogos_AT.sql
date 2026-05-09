BEGIN;

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
),
deleted AS (
  DELETE FROM "AT".planes p
  USING seed s
  WHERE p.id = s.id::uuid
  RETURNING 1
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
FROM seed s;

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
WITH seed (id, codigo, nombre, descripcion) AS (
  VALUES
    ('ca6947fc-4a1f-4f36-863c-bd2d739bc6bc', 'descriptivo', 'Descriptivo', 'Estudio descriptivo'),
    ('052d730f-3e7e-462a-a7b3-8fb326fe3d98', 'correlacional', 'Correlacional', 'Estudio correlacional'),
    ('836ce8cc-df4a-463e-b617-3f16238d53b7', 'comparativo', 'Comparativo', 'Estudio comparativo'),
    ('245db066-6ed4-4886-ac24-c6b8bccff8ab', 'predictivo', 'Predictivo', 'Estudio predictivo'),
    ('47bbe792-92b4-4f55-bbe5-8c0d2e28edbf', 'explicativo', 'Explicativo', 'Estudio explicativo'),
    ('989e83c2-e4b1-46f2-a6cc-48dcaa79b83b', 'pre_experimental', 'Pre experimental', 'Diseno pre experimental'),
    ('66079348-72f1-4fd7-9747-b1b3382492a1', 'cuasi_experimental', 'Cuasi experimental', 'Diseno cuasi experimental'),
    ('de4d7494-cbe5-44d0-b3df-75fe3248cf4f', 'exploratorio', 'Exploratorio', 'Estudio exploratorio')
),
deleted AS (
  DELETE FROM "AT".tipos_tesis tt
  USING seed s
  WHERE tt.id = s.id::uuid
     OR tt.codigo = s.codigo
  RETURNING 1
)
INSERT INTO "AT".tipos_tesis (
  id,
  codigo,
  nombre,
  descripcion,
  activo,
  creado_en,
  actualizado_en
)
SELECT
  s.id::uuid,
  s.codigo,
  s.nombre,
  s.descripcion,
  true,
  '2026-04-12 07:35:37.165809+00'::timestamptz,
  '2026-04-12 07:35:37.165809+00'::timestamptz
FROM seed s;

-- Precios por plan y tipo de tesis
WITH seed (id, plan_id, tipo_tesis_id, precio_base) AS (
  VALUES
    ('2ecadebc-797e-4e48-8e4b-cbdcc7379f22', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'ca6947fc-4a1f-4f36-863c-bd2d739bc6bc', '1600.00'),
    ('8f43bf2d-10bc-4a93-aa19-84b6f4855de3', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'ca6947fc-4a1f-4f36-863c-bd2d739bc6bc', '3500.00'),
    ('7b3cf018-7486-4421-acab-9912059ece44', '6b9d7f93-9456-4023-883e-470b00781b25', 'ca6947fc-4a1f-4f36-863c-bd2d739bc6bc', '4000.00'),
    ('810eb9ac-dac2-442c-ab99-d3cf8ac41ed7', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', '052d730f-3e7e-462a-a7b3-8fb326fe3d98', '1800.00'),
    ('45212a9e-803f-44a2-a6ab-860535a979c6', '0eb3868b-cde8-4502-aea5-32b7faa933b0', '052d730f-3e7e-462a-a7b3-8fb326fe3d98', '3500.00'),
    ('fb1c3ee8-d589-45d5-bdf6-c7995b86a11f', '6b9d7f93-9456-4023-883e-470b00781b25', '052d730f-3e7e-462a-a7b3-8fb326fe3d98', '5000.00'),
    ('58823f7a-c6cb-4f44-824c-86b4826c3bd2', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', '836ce8cc-df4a-463e-b617-3f16238d53b7', '1800.00'),
    ('67fc3813-d4dd-4d71-a231-8ddab60e16e7', '0eb3868b-cde8-4502-aea5-32b7faa933b0', '836ce8cc-df4a-463e-b617-3f16238d53b7', '3500.00'),
    ('532b0766-e9bb-4bfe-a1a8-1c1312ca5839', '6b9d7f93-9456-4023-883e-470b00781b25', '836ce8cc-df4a-463e-b617-3f16238d53b7', '5000.00'),
    ('068765b7-9f94-4f9f-b14b-5e5e111bbf80', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', '245db066-6ed4-4886-ac24-c6b8bccff8ab', '1800.00'),
    ('67e5bb74-d3f8-4feb-a98f-b9fd6f0cbc46', '0eb3868b-cde8-4502-aea5-32b7faa933b0', '245db066-6ed4-4886-ac24-c6b8bccff8ab', '3500.00'),
    ('5f59ed1c-bb9a-4385-b9fe-7cabf12ebd29', '6b9d7f93-9456-4023-883e-470b00781b25', '245db066-6ed4-4886-ac24-c6b8bccff8ab', '6000.00'),
    ('952db877-abc9-4142-bb48-3e9f4413cd88', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', '47bbe792-92b4-4f55-bbe5-8c0d2e28edbf', '2000.00'),
    ('01c47c7b-db23-46c2-9b35-c96e76929a51', '0eb3868b-cde8-4502-aea5-32b7faa933b0', '47bbe792-92b4-4f55-bbe5-8c0d2e28edbf', '4000.00'),
    ('6a8d97a8-5c75-421b-86f9-043e09bde5a8', '6b9d7f93-9456-4023-883e-470b00781b25', '47bbe792-92b4-4f55-bbe5-8c0d2e28edbf', '7000.00'),
    ('f622c629-b16f-4d1a-a943-2e7440d43e2b', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', '989e83c2-e4b1-46f2-a6cc-48dcaa79b83b', '2000.00'),
    ('6f3f937a-2bad-4158-b47a-34d28e0e7b7f', '0eb3868b-cde8-4502-aea5-32b7faa933b0', '989e83c2-e4b1-46f2-a6cc-48dcaa79b83b', '4500.00'),
    ('9a09f6cf-5299-4dde-8f87-5fde019baa72', '6b9d7f93-9456-4023-883e-470b00781b25', '989e83c2-e4b1-46f2-a6cc-48dcaa79b83b', '8500.00'),
    ('a8a7cdfa-963b-4811-8a55-be3280dcacad', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', '66079348-72f1-4fd7-9747-b1b3382492a1', '2200.00'),
    ('64b15721-b4fb-498b-ac4d-9a70c5e1d355', '0eb3868b-cde8-4502-aea5-32b7faa933b0', '66079348-72f1-4fd7-9747-b1b3382492a1', '5000.00'),
    ('2ec0e998-a75f-48f6-a72d-55ea67a1c756', '6b9d7f93-9456-4023-883e-470b00781b25', '66079348-72f1-4fd7-9747-b1b3382492a1', '10000.00'),
    ('786e3037-8eb7-4823-9e00-6defc5b3a086', '77561969-ffb8-4823-a20a-fbc9ebc7feb3', 'de4d7494-cbe5-44d0-b3df-75fe3248cf4f', '2500.00'),
    ('24951e3a-eeac-44d3-b407-cc64eb46b5cd', '0eb3868b-cde8-4502-aea5-32b7faa933b0', 'de4d7494-cbe5-44d0-b3df-75fe3248cf4f', '5500.00'),
    ('5585a188-6586-4fba-9c90-ba99d0518333', '6b9d7f93-9456-4023-883e-470b00781b25', 'de4d7494-cbe5-44d0-b3df-75fe3248cf4f', '12000.00')
),
deleted AS (
  DELETE FROM "AT".planes_tipos_tesis_precios ptp
  USING seed s
  WHERE ptp.id = s.id::uuid
     OR (ptp.plan_id = s.plan_id::uuid AND ptp.tipo_tesis_id = s.tipo_tesis_id::uuid)
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
  s.tipo_tesis_id::uuid,
  s.precio_base::numeric,
  'PEN',
  true,
  '2026-04-12 07:35:58.121924+00'::timestamptz,
  '2026-04-12 07:35:58.121924+00'::timestamptz
FROM seed s;

-- Universidades
WITH seed (id, nombre, ubicacion) AS (
  VALUES
    ('82322243-d32b-4d93-92f8-fef9ddaff080', 'Universidad Nacional Tecnologica de Frontera San Ignacio de Loyola', 'Cajamarca/San Ignacio'),
    ('58d0d29e-9921-4fa6-b717-6a898f246462', 'Universidad Interamericana para el Desarrollo', 'Lima/Lima'),
    ('e1ce45c4-7536-4a64-9165-b3ed459eae39', 'Universidad Jose Carlos Mariategui de Moquegua', 'Moquegua/Mariscal Nieto'),
    ('ed0d0d5b-db8b-4683-b4a6-16922b8ae8cd', 'Universidad Nacional de Musica', 'Lima/Lima'),
    ('f9e3ed61-a8d2-4898-bf0d-d6bd5abf88f4', 'Universidad Nacional Daniel Alomia Robles', 'Huanuco/Huanuco'),
    ('65cc962a-16df-469e-afd7-3dc995345bcb', 'Universidad Catolica Los Angeles de Chimbote', 'Ancash/Santa'),
    ('2703b7ce-5cb2-4f46-b009-417c80125928', 'Universidad Politecnica del Peru S.A.', 'Lima/Lima'),
    ('78167902-022c-4b31-a4a5-5873312e422a', 'Universidad Privada de Trujillo', 'La Libertad/Trujillo'),
    ('2ea940fd-450e-447b-974c-5c7bec266eaf', 'Universidad Peruana del Centro', 'Junin/Huancayo'),
    ('51a9a457-1557-4243-ae9c-49d203ce17ce', 'Universidad Nacional Ciro Alegria', 'La Libertad/Sanchez Carrion'),
    ('147f580f-5128-451c-8330-5e49ca63cc29', 'Universidad Nacional Pedro Ruiz Gallo', 'Lambayeque/Lambayeque'),
    ('6907f390-4c85-4eac-abc9-98498b4ce316', 'Universidad Nacional San Luis Gonzaga', 'Ica/Ica'),
    ('5fc50c43-0f72-4919-afa1-b800ddc46258', 'Universidad Autonoma de Ica', 'Ica/Chincha'),
    ('3acbd10d-3066-401f-a704-90ffe66deea2', 'Facultad de Teologia Pontificia y Civil de Lima', 'Lima/Lima'),
    ('f6397549-0da3-4a16-9467-0cf62b90075b', 'Universidad Nacional Federico Villarreal', 'Lima/Lima'),
    ('9dae9877-6f93-43f6-81fb-3a05e4bd483e', 'Universidad Tecnologica de los Andes', 'Apurimac/Abancay'),
    ('c8ba6580-a12c-4187-a88d-e7fea68b9990', 'Universidad Peruana Los Andes', 'Junin/Huancayo'),
    ('7739ccd0-4e2a-4e6e-a4f8-568ab300d361', 'Universidad Nacional Micaela Bastidas de Apurimac', 'Apurimac/Abancay'),
    ('0e81cc12-0622-459d-bb5b-c5801efe8237', 'Universidad Nacional Jose Faustino Sanchez Carrion', 'Lima/Huaura'),
    ('91909a2a-4074-4ba9-9c2e-81694ba6c57d', 'Universidad Senor de Sipan', 'Lambayeque/Chiclayo'),
    ('44a86c44-007b-4b5a-b4e8-e3ca9e57db54', 'Universidad Nacional del Callao', 'Callao/Prov. Const. del Callao'),
    ('d2a9af30-1146-4beb-8c6e-40724422d287', 'Universidad Nacional de Educacion Enrique Guzman y Valle', 'Lima/Lima'),
    ('239da9bf-7835-47db-9972-45acc3b9ffea', 'Universidad Privada Norbert Wiener', 'Lima/Lima'),
    ('19d00040-3963-48f2-a1dc-f4a7b744b059', 'Universidad Nacional de Tumbes', 'Tumbes/Tumbes'),
    ('b086279a-d03a-4a04-8e06-4465f283dfa2', 'Universidad Privada San Juan Bautista', 'Lima/Lima'),
    ('e40ed725-8eff-4fba-9ce9-b055fcd4da71', 'Universidad Nacional Amazonica de Madre de Dios', 'Madre de Dios/Tambopata'),
    ('f6e7aee8-8d46-429b-9a55-a504ed173a61', 'Universidad Nacional Agraria de la Selva', 'Huanuco/Leoncio Prado'),
    ('310870dc-3d2a-4415-8638-473055408bad', 'Universidad Nacional Daniel Alcides Carrion', 'Pasco/Pasco'),
    ('2be807b3-c71f-443f-baec-6692a476dd00', 'Universidad Nacional Hermilio Valdizan de Huanuco', 'Huanuco/Huanuco'),
    ('e0e85b1e-ae21-46c5-8b41-f33442a11ea9', 'Universidad Nacional de Huancavelica', 'Huancavelica/Huancavelica'),
    ('09e09841-c5cd-4e83-90cb-52547833f741', 'Universidad Nacional Intercultural de Quillabamba', 'Cusco/La Convencion'),
    ('b0c44c01-40e3-4bb1-9561-e2cd1e1b964f', 'Universidad Tecnologica del Peru', 'Lima/Lima'),
    ('7dddadf3-21d9-4f71-ae5a-c441e91f15cd', 'Universidad Privada de Huancayo Franklin Roosevelt', 'Junin/Huancayo'),
    ('495f66db-2d3c-44ea-9152-0b73b7266c75', 'Universidad Cesar Vallejo', 'La Libertad/Trujillo'),
    ('e6321830-5c34-44e5-97aa-4eb898447fca', 'Universidad de Huanuco', 'Huanuco/Huanuco'),
    ('52861bc7-c599-4d85-8e49-2e3648a9c414', 'Universidad Nacional de Piura', 'Piura/Piura'),
    ('c5891463-d8b0-4115-b485-22b951e2cd64', 'Universidad Nacional de San Antonio Abad del Cusco', 'Cusco/Cusco'),
    ('2200b815-f82e-4c08-8a28-590243a0a9f7', 'Universidad Nacional de San Martin', 'San Martin/San Martin'),
    ('50d1523b-f6a2-4c46-9c44-2b007e5b1085', 'Universidad Nacional de Frontera', 'Piura/Sullana'),
    ('213ae2bc-86f9-4346-af1a-7ed6fe6b0bd5', 'Universidad Nacional del Santa', 'Ancash/Santa'),
    ('4cb8ff14-4396-4d97-b23c-4d42d4891003', 'Universidad Nacional del Centro del Peru', 'Junin/Huancayo'),
    ('8601b4fb-aa72-4989-928c-0f81d9a0781a', 'Universidad Catolica de Trujillo Benedicto XVI', 'La Libertad/Trujillo'),
    ('6bf09acd-5210-40bf-a7a3-c39603d4183f', 'Universidad Nacional Autonoma de Tayacaja Daniel Hernandez Morillo', 'Huancavelica/Tayacaja'),
    ('df6c9431-e5af-4f01-924a-0ccafeabca93', 'Universidad Nacional de la Amazonia Peruana', 'Loreto/Maynas'),
    ('63643459-4b73-4fb4-8ee3-11aaea82838b', 'Universidad Nacional Santiago Antunez de Mayolo', 'Ancash/Huaraz'),
    ('5410e60d-d9f7-4375-85e7-171f248f0c0b', 'Universidad Nacional Autonoma de Chota', 'Cajamarca/Chota'),
    ('749bab79-8a50-447e-ba69-743163f1717b', 'Universidad Le Cordon Bleu S.A.C.', 'Lima/Lima'),
    ('e9164e6f-1ce8-4a76-9369-f9ab6471ed3a', 'Universidad Nacional de Ucayali', 'Ucayali/Coronel Portillo'),
    ('7e0628ad-6cbb-4533-bd7e-37170e8878c2', 'Universidad Maria Auxiliadora', 'Lima/Lima'),
    ('c5895318-6448-4ec1-93f6-ae1f8e71c751', 'Universidad Nacional Autonoma Altoandina de Tarma', 'Junin/Tarma'),
    ('f7e86c20-b7cb-461d-b87b-1fd743c358af', 'Universidad Nacional Intercultural de la Amazonia', 'Ucayali/Coronel Portillo'),
    ('9314f842-0966-4439-9689-6a08bc4c78ba', 'Universidad Nacional de Trujillo', 'La Libertad/Trujillo'),
    ('36728a9a-22d4-494c-be74-ccffd10a0ec2', 'Universidad Catolica Sedes Sapientiae', 'Lima/Lima'),
    ('acb7841e-35ad-47e4-b079-a8136d98b739', 'Universidad Nacional de Canete', 'Lima/Canete'),
    ('6b6fe881-434b-4e5e-babd-d76d423f85b6', 'Universidad Nacional de San Agustin de Arequipa', 'Arequipa/Arequipa'),
    ('d4660db9-26ab-49ee-a5af-0bcb6c699096', 'Universidad Nacional de Juliaca', 'Puno/San Roman'),
    ('0c0af2c9-811a-42d8-967d-b4b878fa558c', 'Universidad Nacional Intercultural Fabiola Salazar Leguia de Bagua', 'Amazonas/Bagua'),
    ('aa291923-ce4d-4f3c-b4e3-5003e5f719c7', 'Universidad Continental', 'Junin/Huancayo'),
    ('624efbd2-df18-4313-9480-0b844a7ebcab', 'Universidad Autonoma del Peru', 'Lima/Lima'),
    ('a5c28436-d9e7-4592-ba68-f092cb57da30', 'Universidad Nacional de Cajamarca', 'Cajamarca/Cajamarca'),
    ('fbbb3140-b3e7-42f4-90ac-e6bc1b4a4e5d', 'Universidad Nacional Autonoma de Alto Amazonas', 'Loreto/Alto Amazonas'),
    ('3704529c-4a30-4fcc-a39b-b297035ec95e', 'Universidad Nacional Tecnologica de Lima Sur', 'Lima/Lima'),
    ('13f0aad7-27f1-4fa7-9d76-b9c5fad2a35a', 'Universidad Jaime Bausate y Meza', 'Lima/Lima'),
    ('101d056c-59f4-411e-95f8-b12d364c6747', 'Universidad Nacional Jorge Basadre Grohmann', 'Tacna/Tacna'),
    ('c988ad50-d7c9-4e24-8d4f-b19ba42aeab5', 'Universidad Peruana Union', 'Lima/Lima'),
    ('eedb86db-adc2-48c8-8d02-7e8761a96ff8', 'Universidad Nacional de San Cristobal de Huamanga', 'Ayacucho/Huamanga'),
    ('aac2ceea-cc64-4718-aceb-2fc5c9d39893', 'Universidad Nacional de Barranca', 'Lima/Barranca'),
    ('30991194-dc28-4809-90bb-aa4fe292ce0d', 'Universidad Cientifica del Sur', 'Lima/Lima'),
    ('cdab098b-a64c-4149-b486-6104e565ab88', 'Universidad ESAN', 'Lima/Lima'),
    ('7a30d696-abd8-4927-af8f-dc14eec073a3', 'Universidad Nacional Mayor de San Marcos', 'Lima/Lima'),
    ('ecb0f452-bd53-41a1-981e-dd8a2b452aa6', 'Universidad Privada Antenor Orrego', 'La Libertad/Trujillo'),
    ('a2412229-0a4e-4540-a63d-d0c8749d3d0f', 'Universidad Nacional Intercultural de la Selva Central Juan Santos Atahualpa', 'Junin/Chanchamayo'),
    ('7d115445-95c1-4009-bc18-fd4d1d47a4fb', 'Universidad Catolica Santo Toribio de Mogrovejo', 'Lambayeque/Chiclayo'),
    ('1e26fb36-60dd-4140-9733-25d7f86f9a9b', 'Universidad La Salle', 'Arequipa/Arequipa'),
    ('c41118f1-5579-49fa-a7fb-508a5ef03808', 'Universidad Nacional de Jaen', 'Cajamarca/Jaen'),
    ('fcf2c83e-3d44-42ff-aeac-b49b30d72b46', 'Universidad Nacional de Moquegua', 'Moquegua/Mariscal Nieto'),
    ('9af8148b-f078-4651-8664-3b767877d533', 'Universidad Catolica de Santa Maria', 'Arequipa/Arequipa'),
    ('17f6952c-959c-4f47-b222-1e26cffc808c', 'Universidad Nacional del Altiplano', 'Puno/Puno'),
    ('5e538f6d-edd5-4206-8d78-c508c4be5391', 'Universidad Andina del Cusco', 'Cusco/Cusco'),
    ('1c5d2dd5-b23a-47c9-9758-b4c196895041', 'Universidad Privada de Tacna', 'Tacna/Tacna'),
    ('f39dde67-c59f-4a03-ae95-5a5063657455', 'Universidad Nacional de Ingenieria', 'Lima/Lima'),
    ('7e671b64-8d33-40a3-bdff-180378ea7118', 'Universidad de Ciencias y Humanidades', 'Lima/Lima'),
    ('af2efd71-2738-4cb3-b10a-1c60b1b9c0be', 'Universidad Privada del Norte', 'La Libertad/Trujillo'),
    ('462f37cb-1664-49fe-bc9c-8c809d9f3411', 'Universidad Catolica San Pablo', 'Arequipa/Arequipa'),
    ('12300e91-bb01-457e-9e35-9c0714911c36', 'Universidad Marcelino Champagnat', 'Lima/Lima'),
    ('76dd61da-ab54-476a-a3f5-e72f8ae41b12', 'Universidad San Ignacio de Loyola', 'Lima/Lima'),
    ('11015eed-d97e-49d8-a081-036451f82b91', 'Universidad Peruana de Ciencias Aplicadas', 'Lima/Lima'),
    ('94d9fbc5-d627-410a-8d35-5968c92e6791', 'Universidad Nacional Jose Maria Arguedas', 'Apurimac/Andahuaylas'),
    ('42fc501a-3ddd-458f-acbc-9e28db463556', 'Universidad Nacional Toribio Rodriguez de Mendoza de Amazonas', 'Amazonas/Chachapoyas'),
    ('225da47b-8440-4be6-a12e-ab9120d28e4c', 'Universidad de San Martin de Porres', 'Lima/Lima'),
    ('05534e04-19da-43cb-827f-ff0978a6dec8', 'Universidad Antonio Ruiz de Montoya', 'Lima/Lima'),
    ('b23579b3-15f4-46a1-8577-96cb7c2bb3f8', 'Universidad Nacional Autonoma de Huanta', 'Ayacucho/Huanta'),
    ('577ad2d0-6bdc-4bec-bd12-13f88b859c1e', 'Universidad Nacional Agraria La Molina', 'Lima/Lima'),
    ('5d4fb3bf-69bc-48ac-975a-60de6954c8f6', 'Universidad de Piura', 'Piura/Piura'),
    ('7e2fc811-1258-40ed-97b9-2d57de5a97d2', 'Universidad Ricardo Palma', 'Lima/Lima'),
    ('edd61a01-0a0f-443b-8a9e-3d084c67b0b5', 'Universidad Femenina del Sagrado Corazon', 'Lima/Lima'),
    ('c1f6680c-af1a-4821-9a93-0c92ddc2ac1f', 'Universidad de Ciencias y Artes de America Latina', 'Lima/Lima'),
    ('5a6f867b-4f31-4fb7-b4c3-721baefa2f55', 'Universidad para el Desarrollo Andino', 'Huancavelica/Angaraes'),
    ('1674748c-4a73-42f1-a3ec-6e91b6cc69ff', 'Universidad Peruana Cayetano Heredia', 'Lima/Lima'),
    ('6d47cd5a-1267-49d3-a667-730efaafb5f2', 'Universidad del Pacifico', 'Lima/Lima')
),
deleted AS (
  DELETE FROM "AT".universidades u
  USING seed s
  WHERE u.id = s.id::uuid
  RETURNING 1
)
INSERT INTO "AT".universidades (
  id,
  nombre,
  ubicacion,
  pais,
  creado_en,
  actualizado_en
)
SELECT
  s.id::uuid,
  s.nombre,
  s.ubicacion,
  'Peru',
  '2026-03-17 23:02:49.397032+00'::timestamptz,
  '2026-03-17 23:02:49.397032+00'::timestamptz
FROM seed s;

COMMIT;
