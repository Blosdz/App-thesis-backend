import { NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocGeneratorService } from './doc-generator.service';

const user = {
  auth_usuario_id: 'auth-1',
  usuario_id: 'user-1',
  email: 'student@example.com',
  rol: 'estudiante' as const,
  verificado: true,
  email_verificado: true,
};

function makeService(rows: Array<Record<string, unknown>> = [{ ok: 1 }]) {
  const databaseService = {
    query: jest.fn().mockResolvedValue({ rows }),
  };
  const configService = {
    get: jest.fn((_key: string, fallback: unknown) => fallback),
  } as unknown as ConfigService;

  return {
    databaseService,
    service: new DocGeneratorService(configService, databaseService as never),
  };
}

describe('DocGeneratorService', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('validates thesis access before proxying index list', async () => {
    const { databaseService, service } = makeService();
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify([{ title: 'Capítulo I' }]), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await expect(service.listIndex('tesis-1', user)).resolves.toEqual([
      { title: 'Capítulo I' },
    ]);

    expect(databaseService.query).toHaveBeenCalledWith(
      expect.stringContaining('FROM "AT".tesis'),
      ['tesis-1', 'user-1', 'estudiante'],
    );
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8000/theses/tesis-1/sections',
      expect.objectContaining({ method: 'GET' }),
    );
  });

  it('does not proxy when thesis access is denied', async () => {
    const { service } = makeService([]);
    const fetchMock = jest.spyOn(global, 'fetch');

    await expect(service.listIndex('tesis-1', user)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('proxies append text after access validation', async () => {
    const { service } = makeService();
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ content: 'A\n\nB' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await service.appendIndexSectionText('tesis-1', 'section-1', { text: 'B' }, user);

    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8000/theses/tesis-1/sections/section-1/append-text',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({ text: 'B' }),
      }),
    );
  });

  it('proxies index sections with nested subsections', async () => {
    const { service } = makeService();
    const payload = {
      title: 'Capítulo I',
      subtitle: 'Antecedentes',
      level: 1,
      order: 1,
      content: 'Contenido del heading',
      subsections: [
        { title: 'Antecedentes', content: 'Contenido 1.1' },
        { title: 'Marco teórico', content: 'Contenido 1.2' },
      ],
    };
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ id: 'section-1', ...payload }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await expect(
      service.updateIndexSection('tesis-1', 'section-1', payload, user),
    ).resolves.toEqual({ id: 'section-1', ...payload });

    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8000/theses/tesis-1/sections/section-1',
      expect.objectContaining({
        method: 'PATCH',
        body: JSON.stringify(payload),
      }),
    );
  });

  it('validates document ownership before updating raw data', async () => {
    const { databaseService, service } = makeService([{ tesis_id: 'tesis-1' }]);
    jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ document_id: 'doc-1', raw_data: 'Texto' }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );

    await service.updateRawData('doc-1', { raw_data: 'Texto' }, user);

    expect(databaseService.query).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('FROM "AT".documentos_tesis'),
      ['doc-1'],
    );
    expect(databaseService.query).toHaveBeenNthCalledWith(
      2,
      expect.stringContaining('FROM "AT".tesis'),
      ['tesis-1', 'user-1', 'estudiante'],
    );
  });

  it('proxies raw document after document access validation', async () => {
    const { databaseService, service } = makeService([{ tesis_id: 'tesis-1' }]);
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(
        JSON.stringify({
          document_id: 'doc-1',
          raw_data: 'Texto',
          paragraphs: [{ paragraph_index: 0, text: 'Texto' }],
        }),
        {
          status: 200,
          headers: { 'content-type': 'application/json' },
        },
      ),
    );

    await service.getRawDocument('doc-1', user);

    expect(databaseService.query).toHaveBeenNthCalledWith(
      1,
      expect.stringContaining('FROM "AT".documentos_tesis'),
      ['doc-1'],
    );
    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:8000/documents/doc-1/raw-document',
      expect.objectContaining({ method: 'GET' }),
    );
  });

  it('serves generated docm downloads with macro-enabled Word mime fallback', async () => {
    const { service } = makeService([{ tesis_id: 'tesis-1' }]);
    jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response('docm-bytes', {
        status: 200,
        headers: { 'content-type': '' },
      }),
    );

    const file = await service.downloadDocument('tesis-demo.docm', user);

    expect(file.getHeaders().type).toBe(
      'application/vnd.ms-word.document.macroEnabled.12',
    );
  });

  it('proxies in-place citation, heading, and subtitle edits', async () => {
    const { service } = makeService([{ tesis_id: 'tesis-1' }]);
    const fetchMock = jest.spyOn(global, 'fetch').mockImplementation(() =>
      Promise.resolve(
        new Response(JSON.stringify({ document_id: 'doc-1', raw_data: 'Texto' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        }),
      ),
    );

    await service.insertCitation(
      'doc-1',
      { reference_id: 'ref-1', paragraph_index: 0, char_offset: 5 },
      user,
    );
    await service.insertHeading(
      'doc-1',
      { text: 'Capítulo I', paragraph_index: 0, char_offset: 0, level: 1 },
      user,
    );
    await service.insertSubtitle(
      'doc-1',
      {
        text: 'Antecedentes',
        paragraph_index: 0,
        char_offset: 0,
        level: 2,
        mode: 'replace',
      },
      user,
    );

    expect(fetchMock).toHaveBeenNthCalledWith(
      1,
      'http://127.0.0.1:8000/documents/doc-1/citations',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          reference_id: 'ref-1',
          paragraph_index: 0,
          char_offset: 5,
        }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      'http://127.0.0.1:8000/documents/doc-1/headings',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          text: 'Capítulo I',
          paragraph_index: 0,
          char_offset: 0,
          level: 1,
        }),
      }),
    );
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      'http://127.0.0.1:8000/documents/doc-1/subtitles',
      expect.objectContaining({
        method: 'POST',
        body: JSON.stringify({
          text: 'Antecedentes',
          paragraph_index: 0,
          char_offset: 0,
          level: 2,
          mode: 'replace',
        }),
      }),
    );
  });

  it('does not proxy document edits when access is denied', async () => {
    const { service } = makeService([]);
    const fetchMock = jest.spyOn(global, 'fetch');

    await expect(
      service.insertCitation(
        'doc-1',
        { reference_id: 'ref-1', paragraph_index: 0, char_offset: 0 },
        user,
      ),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(fetchMock).not.toHaveBeenCalled();
  });
});
