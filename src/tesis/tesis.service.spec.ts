import { BadRequestException, NotFoundException } from '@nestjs/common';
import { TesisService } from './tesis.service';

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
  const localStorageService = {
    saveFile: jest.fn().mockResolvedValue({
      relativePath: 'tesis/tesis-1/caratula/caratula.docx',
      absolutePath: '/tmp/caratula.docx',
      publicUrl: 'http://localhost:3000/storage/tesis/tesis-1/caratula/caratula.docx',
      originalName: 'caratula.docx',
      mimeType: docxMime,
      size: 4,
    }),
  };

  return {
    databaseService,
    localStorageService,
    service: new TesisService(
      databaseService as never,
      {} as never,
      {} as never,
      {} as never,
      localStorageService as never,
    ),
  };
}

describe('TesisService document format and cover upload', () => {
  it('updates thesis document format when the format is active', async () => {
    const { databaseService, service } = makeService([
      [
        {
          id: 'format-1',
          uname: 'vancouver',
          name: 'Vancouver',
          citation_type: 'numeric',
        },
      ],
      [{ id: 'tesis-1', estudiante_id: user.usuario_id, metadata: {} }],
    ]);

    await expect(
      service.actualizarFormatoDoc(user, 'tesis-1', {
        docThesisFormat: 'Vancouver',
      }),
    ).resolves.toMatchObject({
      ok: true,
      data: {
        id: 'tesis-1',
        doc_thesis_format: 'vancouver',
        doc_thesis_format_name: 'Vancouver',
        citation_type: 'numeric',
      },
    });

    expect(databaseService.query).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('FROM "AT".doc_thesis_formats'),
      ['vancouver'],
    );
    expect(databaseService.query).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('doc_thesis_format_id'),
      ['tesis-1', 'student-1', 'format-1', 'vancouver', 'numeric', 'estudiante'],
    );
  });

  it('rejects inactive or unknown thesis document formats', async () => {
    const { databaseService, service } = makeService([[]]);

    await expect(
      service.actualizarFormatoDoc(user, 'tesis-1', {
        docThesisFormat: 'desconocido',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(databaseService.query).toHaveBeenCalledTimes(1);
  });

  it('rejects format updates when the thesis is not accessible', async () => {
    const { service } = makeService([
      [
        {
          id: 'format-1',
          uname: 'apa7',
          name: 'APA 7',
          citation_type: 'author_year',
        },
      ],
      [],
    ]);

    await expect(
      service.actualizarFormatoDoc(user, 'tesis-1', {
        docThesisFormat: 'apa7',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('accepts DOCX files as cover documents', async () => {
    const { databaseService, localStorageService, service } = makeService([
      [{ id: 'tesis-1', estudiante_id: user.usuario_id }],
      [{ metadata: { cover_docx_original_name: 'caratula.docx' } }],
    ]);

    await expect(
      service.subirCaratula(user, 'tesis-1', makeFile('caratula.docx', docxMime)),
    ).resolves.toMatchObject({
      ok: true,
      data: {
        cover_docx_original_name: 'caratula.docx',
        cover_docx_url:
          'http://localhost:3000/storage/tesis/tesis-1/caratula/caratula.docx',
      },
    });

    expect(localStorageService.saveFile).toHaveBeenCalledWith(
      expect.objectContaining({ originalname: 'caratula.docx' }),
      { directory: 'tesis/tesis-1/caratula', fileNamePrefix: 'caratula' },
    );
    expect(databaseService.query).toHaveBeenLastCalledWith(
      expect.stringContaining('RETURNING metadata'),
      [
        'tesis-1',
        expect.objectContaining({
          cover_docx_original_name: 'caratula.docx',
        }),
      ],
    );
  });

  it('accepts PDF files as cover documents', async () => {
    const { databaseService, localStorageService, service } = makeService([
      [{ id: 'tesis-1', estudiante_id: user.usuario_id }],
      [{ metadata: { cover_docx_original_name: 'caratula.pdf' } }],
    ]);
    localStorageService.saveFile.mockResolvedValueOnce({
      relativePath: 'tesis/tesis-1/caratula/caratula.pdf',
      absolutePath: '/tmp/caratula.pdf',
      publicUrl: 'http://localhost:3000/storage/tesis/tesis-1/caratula/caratula.pdf',
      originalName: 'caratula.pdf',
      mimeType: pdfMime,
      size: 4,
    });

    await expect(
      service.subirCaratula(user, 'tesis-1', makeFile('caratula.pdf', pdfMime)),
    ).resolves.toMatchObject({
      ok: true,
      data: {
        cover_docx_original_name: 'caratula.pdf',
        cover_docx_mime_type: pdfMime,
        cover_docx_url:
          'http://localhost:3000/storage/tesis/tesis-1/caratula/caratula.pdf',
      },
    });

    expect(localStorageService.saveFile).toHaveBeenCalledWith(
      expect.objectContaining({ originalname: 'caratula.pdf' }),
      { directory: 'tesis/tesis-1/caratula', fileNamePrefix: 'caratula' },
    );
    expect(databaseService.query).toHaveBeenLastCalledWith(
      expect.stringContaining('RETURNING metadata'),
      [
        'tesis-1',
        expect.objectContaining({
          cover_docx_original_name: 'caratula.pdf',
          cover_docx_mime_type: pdfMime,
        }),
      ],
    );
  });

  it('rejects image cover uploads', async () => {
    const { localStorageService, service } = makeService();

    await expect(
      service.subirCaratula(user, 'tesis-1', makeFile('caratula.png', 'image/png')),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(localStorageService.saveFile).not.toHaveBeenCalled();
  });
});
