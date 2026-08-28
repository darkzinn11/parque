# Storage de mídia content-addressed (com dedup + checksum) — Design

Data: 2026-06-22
Repositórios: **PARQUE-BACK** (principal), Flutter, PAINEL-PARK
Status: aprovado no brainstorming, aguardando review da spec

## Relação com a spec anterior

Revisa o layout de storage da spec `2026-06-22-media-uploads-restructure-design.md` (parque-first). Motivo: o engenheiro sênior apontou que pastas organizadas por parque degradam quando uma pasta passa de ~255–1.000 arquivos, e recomendou **storage por hash do conteúdo (content-addressed) + checksum para dedup**, com o **hash calculado no cliente** (não no backend, para não pesar sob carga).

**O que é reaproveitado:** o conceito de um índice no banco que liga arquivo ↔ entidade (a tabela `media`). **O que muda:** o disco deixa de ser organizado por parque e passa a ser organizado por hash; surge uma tabela `blobs` (arquivo físico único por conteúdo) e a `media` vira a camada de referência/índice. A função de resolução de caminho parque-first (`ResolveDir`) e os ajustes de migração/handlers da spec anterior são substituídos.

## Decisões (brainstorming)

1. **Content-addressed puro**: o caminho do arquivo deriva só do conteúdo (hash), não do parque. É a única forma de habilitar dedup (parque no caminho duplicaria o mesmo conteúdo entre parques).
2. **SHA-256** (não md5/sha1): em storage por conteúdo, colisão = sobrescrita = perda de dado.
3. **Sharding por hash**: `uploads/blobs/<aa>/<bb>/<hash>.<ext>` (fanout 2+2 = 65.536 pastas folha). Nenhuma pasta estoura o limite, funciona em qualquer filesystem.
4. **Dedup com ref-counting**: tabela `blobs` (1 por conteúdo) + tabela `media` (N referências). Só apaga o arquivo físico quando nenhuma entidade ativa o referencia.
5. **Hash calculado no cliente** (Flutter + painel): o hot path do backend não re-hasheia.
6. **Verificação assíncrona**: worker em background re-hasheia fora do hot path, marca/quarentena divergências. Honra "não pesar o backend ao vivo" e fecha o buraco de integridade.
7. **"Achar por parque"** deixa de ser papel do filesystem e passa a ser query no banco (`media.park_id`).

## Arquitetura

### Layout de storage
```
uploads/
  blobs/<aa>/<bb>/<sha256hex>.<ext>   ex.: uploads/blobs/a3/f9/a3f9c1...e8.webp
  _quarantine/                         blobs com verificação divergente
```
- `<aa>` = 1º e 2º hex char do hash; `<bb>` = 3º e 4º. Resto do hash = nome do arquivo.
- `<ext>` derivada do MIME validado (serve para o Content-Type ao servir estático).
- **Escrita atômica**: grava em `uploads/blobs/<aa>/<bb>/.tmp-<rand>` e faz `os.Rename` para o nome final — dois uploads concorrentes do mesmo conteúdo não se corrompem.

### Schema
```sql
CREATE TABLE blobs (
  hash       CHAR(64) PRIMARY KEY,          -- sha256 hex
  ext        VARCHAR(8),
  mime       VARCHAR(30),
  size_bytes BIGINT,
  ref_count  INT NOT NULL DEFAULT 0,        -- cache; a verdade é COUNT(media ativas)
  verified   VARCHAR(10) NOT NULL DEFAULT 'pending', -- pending|ok|mismatch
  created_at DATETIME(3),
  updated_at DATETIME(3)
);

CREATE TABLE media (
  id          BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  entity_type VARCHAR(20),                  -- park|space|review|evento|denuncia|avatar
  entity_id   BIGINT UNSIGNED NULL,         -- NULL no upload; preenchido no save (Link)
  park_id     BIGINT UNSIGNED NULL,         -- índice "achar por parque"
  blob_hash   CHAR(64) NOT NULL,            -- FK -> blobs.hash
  created_at  DATETIME(3),
  deleted_at  DATETIME(3) NULL,             -- soft-delete
  KEY idx_media_entity (entity_type, entity_id),
  KEY idx_media_park (park_id),
  KEY idx_media_blob (blob_hash),
  KEY idx_media_deleted (deleted_at),
  CONSTRAINT fk_media_blob FOREIGN KEY (blob_hash) REFERENCES blobs(hash)
);
```
As colunas de URL das entidades (`reviews.midia_url`, `spaces.imagem_url`, etc.) continuam sendo a fonte de verdade da exibição e passam a guardar a URL do blob (`/uploads/blobs/aa/bb/hash.ext`).

### Fluxo de upload (hot path leve)
1. **Cliente** lê o arquivo, calcula o SHA-256, e envia: `file`, `checksum` (hex), `ext`/mime, `entity_type`, `park_id` (opcional).
2. **Backend** (sem re-hashear):
   - valida tamanho + extensão + MIME sniff (barato, só o header — não o arquivo todo);
   - normaliza/valida o formato do `checksum` (64 hex);
   - se já existe `blobs[hash]` → **dedup hit**: não grava o arquivo;
   - senão → grava os bytes recebidos atomicamente em `uploads/blobs/<aa>/<bb>/<hash>.<ext>` e cria `blobs` (`verified='pending'`);
   - retorna a URL do blob + o hash. (A linha `media` com `entity_id` é criada/ligada no save da entidade, como hoje — `MediaService.Link`.)
3. **Worker assíncrono** (contínuo, fora do hot path): pega blobs `verified='pending'`, re-hasheia o arquivo gravado; se bate → `ok`; se não bate → `mismatch` + move para `_quarantine` e marca as `media` que apontam para ele. Deve rodar com baixa latência (segundos/minutos), não só de madrugada, para encurtar a janela de poisoning (ver Segurança).

### Dedup + ref-counting + GC
- `media` é a fonte de verdade das referências. Um blob é **deletável** quando **nenhuma `media` ativa (não soft-deletada)** aponta para ele.
- `blobs.ref_count` é um cache; o job de GC (evolução do `cleanup-media`) recalcula a verdade via `COUNT(media WHERE blob_hash=? AND deleted_at IS NULL)`.
- Deletar entidade → soft-delete das `media` correspondentes. GC depois deleta o arquivo físico + linha `blobs` dos blobs com 0 referências ativas.
- **Regra de ouro (bug nº1 de dedup):** nunca apagar um blob com referência ativa — uma review e uma denúncia podem compartilhar o mesmo arquivo.
- **Período de carência:** o GC só considera blobs `created_at` mais antigo que uma janela (ex.: 24h). Isso protege o blob recém-enviado mas ainda **não ligado** a uma entidade (o `Link` ocorre no save, depois do upload) de ser apagado por ter 0 referências momentaneamente. Blobs antigos sem nenhuma `media` (upload abandonado) são limpos após a carência.

### Migração (offline, pode ser pesada)
Comando dedicado, `--dry-run` por padrão, backup obrigatório antes:
1. Para cada coluna de URL das entidades, localiza o arquivo legado.
2. Calcula o SHA-256 (offline — sem tráfego ao vivo, custo OK).
3. Se o blob já existe → dedup (não copia); senão move/copia para `uploads/blobs/<aa>/<bb>/<hash>.<ext>` e cria `blobs` (`verified='ok'`, já que foi hasheado aqui).
4. Cria a linha `media` (entity_type, entity_id, park_id, blob_hash) e atualiza a coluna de URL da entidade para a URL do blob.
5. Arquivos sem dono → `_quarantine`.

### Cliente: cálculo do hash
- **Flutter**: pacote `crypto` (`sha256.convert(bytes)`), envia `checksum` no `MultipartRequest`.
- **Painel (JS)**: `crypto.subtle.digest('SHA-256', buffer)` → hex.

## Segurança
- Endpoint público de denúncia continua sem auth + rate-limited; `entity_type` fixado no servidor (já feito).
- **Confiança no hash do cliente**: o hot path confia; a verificação assíncrona re-hasheia e quarentena divergências.
- **Vetor de poisoning (residual, documentado):** um cliente malicioso pode subir bytes maliciosos declarando o hash de um arquivo-alvo ainda inexistente; um upload legítimo posterior do alvo daria dedup hit e receberia o blob malicioso. **Mitigação:** o worker de verificação roda com baixa latência e marca `mismatch` → quarentena, bounded e detectável. Risco aceito sob a restrição "não hashear no hot path".
- Overwrite por dedup é seguro: se o hash já existe, o backend NÃO regrava — não dá para sobrescrever um blob existente.

## Fora de escopo (YAGNI)
- Storage em objeto/S3 (continua disco local).
- Dedup perceptual (mesma imagem re-codificada tem bytes diferentes → hashes diferentes; dedup é byte-exato, e tudo bem).
- CDN / URLs assinadas.

## Critérios de sucesso
- Nenhuma pasta de uploads excede algumas dezenas/centenas de arquivos, em qualquer volume.
- Conteúdo idêntico é gravado uma única vez no disco (dedup), com referências múltiplas rastreadas.
- Deletar uma entidade nunca remove arquivo ainda referenciado por outra.
- Hot path de upload não re-hasheia; verificação acontece em background.
- "Todas as mídias do parque X" sai por query em `media.park_id`.
- App e painel calculam e enviam o SHA-256; exibição sem regressão.
