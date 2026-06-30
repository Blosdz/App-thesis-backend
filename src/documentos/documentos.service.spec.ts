import { DocumentosService } from './documentos.service';

const user = {
  auth_usuario_id: 'auth-1',
  usuario_id: 'student-1',
  email: 'student@example.com',
  rol: 'estudiante' as const,
  verificado: true,
  email_verificado: true,
};

const docxMime =
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const pdfMime = 'application/pdf';

function makeFile(
  originalname: string,
  mimetype: string,
): Express.Multer.File {
  return {
    originalname,
    mimetype,
    buffer: Buffer.from('demo'),
    size: 4,
  } as Express.Multer.File;
}

function makeService(queryRows: Array<Array<Record<string, unknown>>> = []) {
  const databaseService = {
    query: jest.fn().mockImplementation(() =>
      Promise.resolve({ rows: queryRows.shift() ?? [] }),
    ),
  };
  const googleService = {
    getDriveUser: jest.fn().mockResolvedValue({ emailAddress: 'drive@test.dev' }),
    uploadFileToDrive: jest.fn().mockResolvedValue({
      id: 'drive-file-1',
      webViewLink: 'https://drive.test/file',
      mimeType: docxMime,
    }),
    normalizeName: jest.fn((value: string, fallback: string) =>
      (value || fallback).toLowerCase().replace(/[^a-z0-9]+/g, '-'),
    ),
  };
  const localStorageService = {
    saveFile: jest.fn().mockResolvedValue({
      relativePath: 'tesis/tesis-1/avances/avance-v1.docx',
      absolutePath: '/tmp/storage/tesis/tesis-1/avances/avance-v1.docx',
      publicUrl: 'http://localhost:3000/storage/tesis/tesis-1/avances/avance-v1.docx',
      originalName: 'avance.docx',
      mimeType: docxMime,
      size: 4,
    }),
  };
  const configService = {
    get: jest.fn((_key: string, fallback: unknown) => fallback),
  };

  return {
    databaseService,
    googleService,
    localStorageService,
    configService,
    service: new DocumentosService(
      databaseService as never,
      googleService as never,
      localStorageService as never,
      configService as never,
    ),
  };
}

describe('DocumentosService thesis uploads', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('stores a local editable copy for Word thesis progress uploads', async () => {
    const { databaseService, localStorageService, service } = makeService([
      [
        {
          id: 'tesis-1',
          estudiante_id: user.usuario_id,
          titulo: 'Demo Tesis',
          carpeta_drive_id: 'folder-1',
        },
      ],
      [],
      [
        {
          id: 'doc-1',
          nombre_archivo: 'avance.docx',
          ruta_storage: '/tmp/storage/tesis/tesis-1/avances/avance-v1.docx',
        },
      ],
    ]);
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          document_id: 'doc-1',
          tesis_id: 'tesis-1',
          title: 'Demo Tesis',
          raw_data: 'Demo Tesis\n\nCapítulo I\n\nTexto',
          raw_data_json: {
            document_id: 'doc-1',
            title: 'Demo Tesis',
            sections: [
              {
                heading: 'Capítulo I',
                level: 1,
                content: 'Texto',
                order_index: 1,
                parent_order_index: null,
                source_paragraphs: [0, 1],
                manual_override: false,
              },
            ],
            references: [
              {
                type: 'book',
                authors: [{ last_name: 'Hernández', first_name: 'Roberto' }],
                year: 2014,
                title: 'Metodología de la investigación',
                raw_text: 'Hernández, R. (2014). Metodología de la investigación.',
                style: 'APA7',
                source: 'metadata',
                confidence: 0.9,
              },
            ],
            paragraphs: [],
            metadata: {},
            raw_data: 'Demo Tesis\n\nCapítulo I\n\nTexto',
          },
          processing_status: 'processed',
          processing_error: null,
          sections: [
            {
              id: 'section-1',
              heading: 'Capítulo I',
              level: 1,
              content: 'Texto',
              order_index: 1,
              parent_section_id: null,
              source_paragraphs: [0, 1],
              manual_override: false,
              version: 1,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              deleted_at: null,
            },
          ],
          references: [
            {
              id: 'ref-1',
              type: 'book',
              authors: [{ last_name: 'Hernández', first_name: 'Roberto' }],
              year: 2014,
              title: 'Metodología de la investigación',
              raw_text: 'Hernández, R. (2014). Metodología de la investigación.',
              style: 'APA7',
              source: 'metadata',
              confidence: 0.9,
              version: 1,
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              deleted_at: null,
            },
          ],
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      ),
    );

    await expect(
      service.subirArchivo(user, 'tesis-1', makeFile('avance.docx', docxMime), {
        modo: 'tesis',
      }),
    ).resolves.toMatchObject({
      ok: true,
      data: {
        id: 'doc-1',
        ruta_storage: '/tmp/storage/tesis/tesis-1/avances/avance-v1.docx',
        processing_status: 'processed',
        raw_data_json: expect.any(Object),
        reference_extraction: {
          ok: true,
          extracted_count: 1,
          created_count: 1,
          skipped_count: 0,
          references: [
            {
              title: 'Metodología de la investigación',
              source: 'metadata',
              status: 'created',
            },
          ],
        },
        outline_extraction: {
          ok: true,
          extracted_count: 1,
          created_count: 1,
          sections: [
            {
              title: 'Capítulo I',
              source: 'heading',
              status: 'created',
              subtitles: [],
            },
          ],
        },
      },
    });

    expect(localStorageService.saveFile).toHaveBeenCalledWith(
      expect.objectContaining({ originalname: 'avance.docx' }),
      { directory: 'tesis/tesis-1/avances', fileNamePrefix: 'avance-v1' },
    );
    expect(databaseService.query).toHaveBeenLastCalledWith(
      expect.stringContaining('ruta_storage'),
      expect.arrayContaining(['/tmp/storage/tesis/tesis-1/avances/avance-v1.docx']),
    );
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8000/documents/doc-1/process',
      { method: 'POST' },
    );
  });

  it('does not store a local editable copy for PDF thesis progress uploads', async () => {
    const { databaseService, googleService, localStorageService, service } =
      makeService([
        [
          {
            id: 'tesis-1',
            estudiante_id: user.usuario_id,
            titulo: 'Demo Tesis',
            carpeta_drive_id: 'folder-1',
          },
        ],
        [],
        [
          {
            id: 'doc-1',
            nombre_archivo: 'avance.pdf',
            ruta_storage: null,
          },
        ],
      ]);
    googleService.uploadFileToDrive.mockResolvedValueOnce({
      id: 'drive-file-1',
      webViewLink: 'https://drive.test/file',
      mimeType: pdfMime,
    });
    const fetchMock = jest.spyOn(global, 'fetch');

    await service.subirArchivo(user, 'tesis-1', makeFile('avance.pdf', pdfMime), {
      modo: 'tesis',
    });

    expect(localStorageService.saveFile).not.toHaveBeenCalled();
    expect(fetchMock).not.toHaveBeenCalled();
    expect(databaseService.query).toHaveBeenLastCalledWith(
      expect.stringContaining('ruta_storage'),
      expect.arrayContaining([null, pdfMime, 4]),
    );
  });
});
