# Reestruturação de uploads — subsistema unificado de mídia

Data: 2026-06-22
Repositórios afetados: **PARQUE-BACK** (principal), Flutter (mínimo), PAINEL-PARK (mínimo)

## Problema

Os uploads de imagem estão desorganizados em produção:

- **4 handlers independentes** com convenções diferentes:
  - `upload_handler.go` (genérico) → grava em `uploads/` (raiz), nome `{unix}-{tamanho}.ext`, URL `/api/v1/uploads/...`
  - `review_handler.UploadReviewMedia` → `uploads/reviews/`, nome `review_{n}.jpg`, URL `/uploads/reviews/...`
  - `user_auth_handler.UploadAvatar` → `uploads/avatars/`, URL `/uploads/avatars/...`
  - `evento_handler.AdminUpload` → `uploads/eventos/`, URL `/uploads/eventos/...`
- **83 arquivos** (32 MB) com vários soltos na raiz, sem segmentação por parque.
- **Sem rastreabilidade**: nenhum registro liga arquivo ↔ entidade dona; impossível detectar/limpar órfão.
- **URLs mistas**: a maioria guarda caminho relativo; `denuncia.fotos` (JSON) guarda URL absoluta.
- **`users.avatar_url` é `varchar(255)`** enquanto todas as outras colunas de URL são `varchar(512)`.

## Decisões tomadas (brainstorming)

1. **Manter `varchar(512)`** em todas as colunas de URL. NÃO baixar para 255 (seria regressão: VARCHAR é variável, 512 não custa storage a mais, e a estrutura nova deixa os caminhos mais longos). Alinhar `users.avatar_url` 255 → 512.
2. **Estrutura parque-first** (cada parque numa pasta, subdividido por categoria).
3. **Migrar todos os 83 legados** + reescrever URLs no banco + popular a `media`.
4. **`media` é ledger de rastreio**, NÃO fonte única de verdade. As colunas de URL das entidades continuam mandando na exibição; a `media` só rastreia dono/caminho/tamanho para auditoria e limpeza.
5. **Limpeza de órfãos manual com `--dry-run` por padrão** (sem cron automático).
6. **URLs relativas no banco** (`/uploads/...`); app/admin concatenam a base.
7. **Storage em disco local** (não objeto/S3 por ora).
8. **Upload acontece antes da entidade existir** ("sobe primeiro, vincula depois"). Por isso: o nome do arquivo usa **hash, não `entity_id`** (`review_a3f9c1.webp`); o upload cria a linha `media` com `park_id`+`url`+`entity_type` e `entity_id` NULL; o usecase preenche `entity_id` no save via `MediaService.Link(url, entityType, entityID)`.
9. **Capa de parque novo** (sem `park_id` no upload): vai para `parques/_sem-vinculo/` e é movida para `parques/{id}/capa/` quando o parque é criado.

## Arquitetura

### MediaService (núcleo único)
`internal/application/services/media_service.go` — todos os fluxos de upload delegam a ele.

Responsabilidades:
- Validar: tamanho (5 MB), allowlist de extensão (`.jpg/.jpeg/.png/.webp/.gif`), **MIME sniffing** (lê 512 bytes, compara com a extensão; reaproveitado do `upload_handler.go` atual).
- Resolver o caminho parque-first a partir de `(entityType, entityID, parkID)`.
- Gravar com nome `{tipo}_{entityID}_{hash6}.{ext}` (hash curto evita colisão quando a entidade tem várias fotos, ex.: espaço com até 4 imagens).
- Inserir linha na tabela `media`.
- Retornar a URL relativa.

Assinatura aproximada:
```go
type SaveInput struct {
    EntityType string // park|space|review|evento|denuncia|avatar
    ParkID     *uint  // nil quando desconhecido no upload (capa de parque novo) ou sem parque (avatar)
    File       *multipart.FileHeader
}
// Save valida, resolve o caminho, grava o arquivo e cria a linha media (entity_id NULL).
func (s *MediaService) Save(ctx context.Context, in SaveInput) (url string, err error)

// Link preenche entity_id na linha media correspondente à url (chamado pelo usecase no save da entidade).
func (s *MediaService) Link(ctx context.Context, url, entityType string, entityID uint) error
```

Os 4 handlers viram cascas finas: identificam `(entityType, parkID)` (ambos vindos de campos opcionais do form quando conhecidos) e chamam `MediaService.Save`. Some a duplicação e o prefixo divergente `/api/v1/uploads`. O `entity_id` é ligado depois, no usecase, via `Link`.

### Estrutura de pastas
```
uploads/
  parques/{park_id}/
    capa/        park_{id}_{hash}.{ext}
    espacos/     space_{id}_{hash}.{ext}
    reviews/     review_{id}_{hash}.{ext}
    eventos/     evento_{id}_{hash}.{ext}
    denuncias/   denuncia_{id}_{hash}.{ext}
  parques/_sem-vinculo/ park_{hash}.{ext}        (capa de parque novo; movida na criação)
  usuarios/{user_id}/   avatar_{hash}.{ext}
  eventos-gerais/       evento_{hash}.{ext}        (editorial sem solicitação)
  denuncias-sem-parque/ denuncia_{hash}.{ext}      (park_id NULL)
  _quarantine/          (arquivos sem dono, aguardando conferência manual)
```
Nome do arquivo: `{tipo}_{hash6}.{ext}` (sem `entity_id`, que é desconhecido no upload).

Derivação do `park_id` por entidade:
- park → o próprio id
- space → `spaces.park_id`
- review → `reviews.park_id`
- evento → `eventos.event_request_id` → `event_requests.park_id`; se `event_request_id` for NULL → `eventos-gerais/`
- denuncia → `denuncia.park_id`; se NULL → `denuncias-sem-parque/`
- avatar → sem parque, vai em `usuarios/{user_id}/`

### Tabela `media`
```sql
CREATE TABLE media (
  id          bigint unsigned PK AUTO_INCREMENT,
  entity_type varchar(20)  NOT NULL,
  entity_id   bigint unsigned NOT NULL,
  park_id     bigint unsigned NULL,
  file_path   varchar(512) NOT NULL,   -- caminho relativo (= URL guardada na entidade)
  mime        varchar(30)  NOT NULL,
  size_bytes  bigint       NOT NULL,
  created_at  datetime(3),
  deleted_at  datetime(3)  NULL,
  KEY idx_media_entity (entity_type, entity_id),
  KEY idx_media_park (park_id),
  KEY idx_media_deleted (deleted_at),
  CONSTRAINT fk_media_park FOREIGN KEY (park_id) REFERENCES parks(id)
);
```
Criada via entidade GORM nova + `AutoMigrate`. As colunas de URL das entidades NÃO mudam (a `media` apenas espelha o caminho).

### Migração one-shot
`cmd/migrate-media/main.go` (comando dedicado, NÃO no boot):
1. Backup obrigatório antes: dump do banco + `tar` da pasta `uploads/`.
2. Para cada entidade com URL (`parks.imagem_url`, `spaces.imagem_url`+2/3/4, `reviews.midia_url`, `eventos.banner_url`+`capa_url`, `users.avatar_url`, `denuncia.fotos[]`):
   - mover o arquivo físico para o caminho novo parque-first
   - renomear no padrão novo
   - atualizar a URL na coluna da entidade (relativa)
   - inserir linha na `media`
3. `denuncia.fotos`: converter URL absoluta → relativa.
4. Arquivos sobrando sem dono → `_quarantine/`.
5. Suporta `--dry-run` (só relatório) e `--apply`.

### Limpeza de órfãos
`cmd/cleanup-media/main.go`:
- `--dry-run` por padrão (só relatório); `--apply` executa; backup antes do `--apply`.
- Detecta:
  - **linha-sem-dono**: `media` cujo `entity_id` aponta para entidade deletada/inexistente → soft-delete da linha (`deleted_at`) + remove o arquivo.
  - **arquivo-sem-linha**: arquivo no disco sem `media` correspondente → move para `_quarantine/`.

### Ajuste de schema (ALTER explícito em main.go)
```sql
ALTER TABLE users MODIFY avatar_url varchar(512);
```
(Lembrar da convenção DDL #8: alteração em coluna existente exige ALTER explícito, não basta a struct.)

## Impacto Flutter
- `denuncie_screen.dart`: passar a guardar o caminho **relativo** retornado (hoje monta e guarda absoluto via `ApiConfig.baseUrl.replaceFirst('/api/v1','') + relUrl`). Demais telas concatenam a base ao exibir, como já fazem para reviews/parks.
- Nenhuma mudança nas telas de exibição (URLs continuam relativas como já eram para a maioria).

## Impacto PAINEL-PARK
- Exibição de fotos de denúncia: prefixar a base à URL relativa (antes vinha absoluta pronta).
- Uploads do admin (parque, espaço, evento) continuam recebendo URL relativa; nenhuma mudança de leitura.

## Segurança e reversibilidade
- Backup obrigatório (banco + arquivos) antes da migração e antes de qualquer `--apply`.
- Migração e limpeza rodam `--dry-run` primeiro.
- A execução da migração em produção exige confirmação humana explícita (não roda no boot).
- `_quarantine/` em vez de delete direto para arquivo-sem-dono.

## Fora de escopo (YAGNI)
- Mover storage para objeto/S3.
- Transformar `media` em fonte única (1 entidade → N mídias) e eliminar as colunas `imagem_url2/3/4` do espaço.
- Cron de limpeza automática.

## Critérios de sucesso
- Um único caminho de código para todo upload (MediaService).
- `uploads/` organizado por parque; raiz sem arquivos soltos (legados migrados ou em `_quarantine/`).
- Toda imagem viva tem linha na `media` ligando ao dono.
- `cleanup-media --dry-run` lista órfãos corretamente.
- `users.avatar_url` em `varchar(512)`.
- App e admin continuam exibindo as imagens sem regressão.
