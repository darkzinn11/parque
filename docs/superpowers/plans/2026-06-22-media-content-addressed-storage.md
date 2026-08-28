# Storage de mídia content-addressed — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development ou superpowers:executing-plans para implementar tarefa-a-tarefa. Steps usam checkbox (`- [ ]`).

**Goal:** Trocar o storage de uploads por um modelo content-addressed (arquivo nomeado/foldered pelo SHA-256 do conteúdo), com dedup, ref-counting, hash calculado no cliente e verificação de integridade assíncrona.

**Architecture:** O disco guarda blobs em `uploads/blobs/<aa>/<bb>/<hash>.<ext>` (escrita atômica). Uma tabela `blobs` representa o arquivo físico único por conteúdo; uma tabela `media` liga entidades a blobs (com `park_id` para query). O cliente calcula o SHA-256; o hot path do backend não re-hasheia; um worker assíncrono verifica integridade. GC apaga blob só quando nenhuma `media` ativa o referencia.

**Tech Stack:** Go, Gin, GORM (MySQL 8); Flutter (`crypto`); React/TS (`crypto.subtle`).

## Global Constraints

- Repo backend: `/Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK`. Module: `github.com/darkzinn11/parque/back/go-api`.
- **Branch:** criar `feat/media-content-addressed` a partir de `feat/media-uploads-restructure` (herda infra que sobrevive: validação de upload, delegação dos handlers ao MediaService, wiring de cliente, ALTER avatar_url). As tarefas refatoram a camada de storage de parque-first → content-addressed. (O layout parque-first nunca foi deployado em produção.)
- **A produção tem só a estrutura de uploads ANTIGA** (`uploads/<ts>-<size>.jpg`, `uploads/reviews/`, `uploads/avatars/`, `uploads/eventos/`). A migração tem que mirar ESSA estrutura, não a parque-first.
- Hash = **SHA-256 hex (64 chars)**. Sharding: 2+2 chars → `blobs/<aa>/<bb>/<hash>.<ext>`.
- Hot path do upload **não re-hasheia**; valida só tamanho/ext/MIME-sniff (header) + formato do checksum.
- Escrita de arquivo **atômica**: temp + `os.Rename`.
- Dedup: nunca apagar blob com `media` ativa apontando; GC com **período de carência 24h**.
- Cliente calcula o hash; avatar é **redimensionado no cliente** (não no backend — senão os bytes salvos divergem do hash enviado).
- Comandos de migração/GC: `--dry-run` por padrão; backup antes de `--apply`; nunca rodar `--apply` em produção sem confirmação humana.
- Sem testes no repo além dos de `internal/application/services`. TDD só onde há lógica pura (resolução de caminho, validação). Resto: `go build`/`vet` + verificação manual.

---

### Task 1: Entidade `Blob` + revisão da entidade `Media` + AutoMigrate

**Files:**
- Create: `internal/domain/entities/blob.go`
- Modify: `internal/domain/entities/media.go`
- Modify: `cmd/api/main.go` (AutoMigrate)

**Interfaces:**
- Produces: `entities.Blob{Hash string; Ext string; Mime string; SizeBytes int64; RefCount int; Verified string; CreatedAt, UpdatedAt time.Time}` (Hash é PK). `entities.Media{ID uint; EntityType string; EntityID *uint; ParkID *uint; BlobHash string; CreatedAt time.Time; DeletedAt gorm.DeletedAt}`.

- [ ] **Step 1: Criar `blob.go`**
```go
package entities

import "time"

// Blob é o arquivo físico, único por conteúdo (content-addressed).
type Blob struct {
	Hash      string    `json:"hash" gorm:"primaryKey;size:64"` // sha256 hex
	Ext       string    `json:"ext" gorm:"size:8"`
	Mime      string    `json:"mime" gorm:"size:30"`
	SizeBytes int64     `json:"size_bytes"`
	RefCount  int       `json:"ref_count" gorm:"default:0"`        // cache; verdade = COUNT(media ativas)
	Verified  string    `json:"verified" gorm:"size:10;default:'pending'"` // pending|ok|mismatch
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
```

- [ ] **Step 2: Revisar `media.go`** — trocar `FilePath` por `BlobHash`:
```go
package entities

import (
	"time"

	"gorm.io/gorm"
)

// Media liga uma entidade (review, denuncia, etc.) a um Blob físico.
type Media struct {
	ID         uint           `json:"id" gorm:"primaryKey"`
	EntityType string         `json:"entity_type" gorm:"size:20;index:idx_media_entity,priority:1"`
	EntityID   *uint          `json:"entity_id" gorm:"index:idx_media_entity,priority:2"`
	ParkID     *uint          `json:"park_id" gorm:"index"`
	BlobHash   string         `json:"blob_hash" gorm:"size:64;index"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
}
```

- [ ] **Step 3: AutoMigrate** — em `cmd/api/main.go`, adicionar `&entities.Blob{},` ANTES de `&entities.Media{}` na lista do `db.AutoMigrate(...)` (blobs primeiro porque media referencia blobs).

- [ ] **Step 4: Build** — `cd /Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK && go build ./...` → sem erros.

- [ ] **Step 5: Commit**
```bash
git add internal/domain/entities/blob.go internal/domain/entities/media.go cmd/api/main.go
git commit -m "feat(media): entidade Blob + media referencia blob_hash (content-addressed)"
```

---

### Task 2: Resolução de caminho por hash (lógica pura, TDD)

**Files:**
- Modify: `internal/application/services/media_path.go` (substitui ResolveDir)
- Modify: `internal/application/services/media_path_test.go`

**Interfaces:**
- Produces: `func BlobRelDir(hash string) (string, error)` → `"blobs/aa/bb"`; `func BlobFilename(hash, ext string) string` → `"<hash>.<ext>"`; `func BlobURL(hash, ext string) string` → `"/uploads/blobs/aa/bb/<hash>.<ext>"`; `func ValidateHash(hash string) error` (64 hex).

- [ ] **Step 1: Teste que falha** — substituir o conteúdo de `media_path_test.go`:
```go
package services

import "testing"

func TestValidateHash(t *testing.T) {
	ok := "a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9"
	if err := ValidateHash(ok); err != nil {
		t.Errorf("hash válido recusado: %v", err)
	}
	for _, bad := range []string{"", "xyz", "A3F9", ok + "00", "g" + ok[1:]} {
		if err := ValidateHash(bad); err == nil {
			t.Errorf("hash inválido aceito: %q", bad)
		}
	}
}

func TestBlobRelDir(t *testing.T) {
	h := "a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9"
	got, err := BlobRelDir(h)
	if err != nil || got != "blobs/a3/f9" {
		t.Errorf("BlobRelDir = %q, err=%v", got, err)
	}
}

func TestBlobURL(t *testing.T) {
	h := "a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9c1d2e8b4a3f9"
	if got := BlobURL(h, ".webp"); got != "/uploads/blobs/a3/f9/"+h+".webp" {
		t.Errorf("BlobURL = %q", got)
	}
}
```

- [ ] **Step 2: Rodar e ver falhar** — `go test ./internal/application/services/ -run 'Hash|BlobRelDir|BlobURL' -v` → FAIL (undefined).

- [ ] **Step 3: Implementar** — substituir o conteúdo de `media_path.go` (remove ResolveDir/categorySubdir/Entity*-dir logic; mantém só o que segue):
```go
package services

import (
	"fmt"
	"regexp"
)

// Constantes de tipo de entidade (usadas em media.entity_type).
const (
	EntityPark     = "park"
	EntitySpace    = "space"
	EntityReview   = "review"
	EntityEvento   = "evento"
	EntityDenuncia = "denuncia"
	EntityAvatar   = "avatar"
)

var hashRe = regexp.MustCompile(`^[0-9a-f]{64}$`)

// ValidateHash garante que é um SHA-256 hex minúsculo de 64 chars.
func ValidateHash(hash string) error {
	if !hashRe.MatchString(hash) {
		return fmt.Errorf("checksum inválido: esperado sha256 hex de 64 chars")
	}
	return nil
}

// BlobRelDir retorna o diretório relativo do blob (fanout 2+2).
func BlobRelDir(hash string) (string, error) {
	if err := ValidateHash(hash); err != nil {
		return "", err
	}
	return fmt.Sprintf("blobs/%s/%s", hash[0:2], hash[2:4]), nil
}

func BlobFilename(hash, ext string) string { return hash + ext }

func BlobURL(hash, ext string) string {
	return fmt.Sprintf("/uploads/blobs/%s/%s/%s%s", hash[0:2], hash[2:4], hash, ext)
}
```

- [ ] **Step 4: Rodar e ver passar** — `go test ./internal/application/services/ -run 'Hash|BlobRelDir|BlobURL' -v` → PASS. (Os testes antigos de `ResolveDir` foram removidos no Step 1; `ValidateUpload` continua intacto.)

- [ ] **Step 5: Commit**
```bash
git add internal/application/services/media_path.go internal/application/services/media_path_test.go
git commit -m "feat(media): resolução de caminho content-addressed (hash fanout) + testes"
```

---

### Task 3: Repositórios `blobs` e `media`

**Files:**
- Create: `internal/domain/repositories/blob_repository.go`
- Create: `internal/infrastructure/persistence/mysql_blob_repository.go`
- Modify: `internal/domain/repositories/media_repository.go`
- Modify: `internal/infrastructure/persistence/mysql_media_repository.go`

**Interfaces:**
- Produces: `BlobRepository{ GetByHash(ctx,hash)(*Blob,error); Create(ctx,*Blob)error; SetVerified(ctx,hash,status string)error; ListByVerified(ctx,status string,limit int)([]Blob,error); DeletableHashes(ctx,graceCutoff time.Time)([]string,error); DeleteByHash(ctx,hash)error }`. `MediaRepository{ Create(ctx,*Media)error; LinkByBlob(ctx,blobHash,entityType string,entityID uint)error; ActiveCountByBlob(ctx,hash string)(int64,error); ListAll(ctx)([]Media,error); SoftDeleteByID(ctx,id uint)error }`.

- [ ] **Step 1: Interface blob** — `internal/domain/repositories/blob_repository.go`:
```go
package repositories

import (
	"context"
	"time"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type BlobRepository interface {
	GetByHash(ctx context.Context, hash string) (*entities.Blob, error) // (nil,nil) se não existe
	Create(ctx context.Context, b *entities.Blob) error
	SetVerified(ctx context.Context, hash, status string) error
	ListByVerified(ctx context.Context, status string, limit int) ([]entities.Blob, error)
	DeletableHashes(ctx context.Context, graceCutoff time.Time) ([]string, error) // 0 media ativas e created_at < cutoff
	DeleteByHash(ctx context.Context, hash string) error
}
```

- [ ] **Step 2: Impl blob** — `internal/infrastructure/persistence/mysql_blob_repository.go`:
```go
package persistence

import (
	"context"
	"errors"
	"time"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlBlobRepository struct{ db *gorm.DB }

func NewMySQLBlobRepository(db *gorm.DB) repositories.BlobRepository {
	return &mysqlBlobRepository{db: db}
}

func (r *mysqlBlobRepository) GetByHash(ctx context.Context, hash string) (*entities.Blob, error) {
	var b entities.Blob
	err := r.db.WithContext(ctx).First(&b, "hash = ?", hash).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *mysqlBlobRepository) Create(ctx context.Context, b *entities.Blob) error {
	return r.db.WithContext(ctx).Create(b).Error
}

func (r *mysqlBlobRepository) SetVerified(ctx context.Context, hash, status string) error {
	return r.db.WithContext(ctx).Model(&entities.Blob{}).Where("hash = ?", hash).Update("verified", status).Error
}

func (r *mysqlBlobRepository) ListByVerified(ctx context.Context, status string, limit int) ([]entities.Blob, error) {
	var bs []entities.Blob
	q := r.db.WithContext(ctx).Where("verified = ?", status)
	if limit > 0 {
		q = q.Limit(limit)
	}
	return bs, q.Find(&bs).Error
}

// DeletableHashes: blobs sem nenhuma media ativa e mais antigos que o cutoff (carência).
func (r *mysqlBlobRepository) DeletableHashes(ctx context.Context, graceCutoff time.Time) ([]string, error) {
	var hashes []string
	err := r.db.WithContext(ctx).
		Model(&entities.Blob{}).
		Where("created_at < ?", graceCutoff).
		Where("hash NOT IN (?)",
			r.db.Model(&entities.Media{}).Select("blob_hash").Where("deleted_at IS NULL")).
		Pluck("hash", &hashes).Error
	return hashes, err
}

func (r *mysqlBlobRepository) DeleteByHash(ctx context.Context, hash string) error {
	return r.db.WithContext(ctx).Delete(&entities.Blob{}, "hash = ?", hash).Error
}
```

- [ ] **Step 3: Revisar media repo** — `internal/domain/repositories/media_repository.go` e a impl `mysql_media_repository.go`: trocar a assinatura para usar `BlobHash`. Interface:
```go
package repositories

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type MediaRepository interface {
	Create(ctx context.Context, m *entities.Media) error
	LinkByBlob(ctx context.Context, blobHash, entityType string, entityID uint) error
	ActiveCountByBlob(ctx context.Context, hash string) (int64, error)
	ListAll(ctx context.Context) ([]entities.Media, error)
	SoftDeleteByID(ctx context.Context, id uint) error
}
```
Impl `mysql_media_repository.go`:
```go
package persistence

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlMediaRepository struct{ db *gorm.DB }

func NewMySQLMediaRepository(db *gorm.DB) repositories.MediaRepository {
	return &mysqlMediaRepository{db: db}
}

func (r *mysqlMediaRepository) Create(ctx context.Context, m *entities.Media) error {
	return r.db.WithContext(ctx).Create(m).Error
}

// LinkByBlob preenche entity_id na linha media (entity_id NULL) daquele blob/tipo.
func (r *mysqlMediaRepository) LinkByBlob(ctx context.Context, blobHash, entityType string, entityID uint) error {
	return r.db.WithContext(ctx).Model(&entities.Media{}).
		Where("blob_hash = ? AND entity_type = ? AND entity_id IS NULL", blobHash, entityType).
		Update("entity_id", entityID).Error
}

func (r *mysqlMediaRepository) ActiveCountByBlob(ctx context.Context, hash string) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Model(&entities.Media{}).Where("blob_hash = ?", hash).Count(&n).Error
	return n, err
}

func (r *mysqlMediaRepository) ListAll(ctx context.Context) ([]entities.Media, error) {
	var ms []entities.Media
	return ms, r.db.WithContext(ctx).Find(&ms).Error
}

func (r *mysqlMediaRepository) SoftDeleteByID(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&entities.Media{}, id).Error
}
```

- [ ] **Step 4: Build** — `go build ./...` (vai quebrar no MediaService/handlers que usam a API antiga; isso é resolvido nas Tasks 4-5; se quiser commitar isolado, comente temporariamente os usos — preferível avançar para a Task 4 antes de commitar).

- [ ] **Step 5: Commit** (após Task 4 compilar) — incluído no commit da Task 4.

---

### Task 4: `MediaService.Save` content-addressed + dedup (sem resize no backend)

**Files:**
- Modify: `internal/application/services/media_service.go`
- Delete: `internal/application/services/media_image.go` (resize sai do backend)
- Modify: `cmd/api/main.go` (instanciar blobRepo + injetar no service)

**Interfaces:**
- Consumes: `BlobRepository`, `MediaRepository`, `ValidateUpload`, `ValidateHash`, `BlobRelDir/BlobFilename/BlobURL`.
- Produces: `MediaService.Save(ctx, SaveInput) (url string, err error)` com `SaveInput{EntityType string; ParkID *uint; Checksum string; File *multipart.FileHeader}`; `MediaService.Link(ctx, blobHash, entityType string, entityID uint) error`.

- [ ] **Step 1: Reescrever `media_service.go`**:
```go
package services

import (
	"context"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"os"
	"path/filepath"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
)

type MediaService struct {
	blobs   repositories.BlobRepository
	media   repositories.MediaRepository
	baseDir string // "uploads"
}

func NewMediaService(blobs repositories.BlobRepository, media repositories.MediaRepository, baseDir string) *MediaService {
	return &MediaService{blobs: blobs, media: media, baseDir: baseDir}
}

type SaveInput struct {
	EntityType string
	ParkID     *uint
	Checksum   string // sha256 hex calculado no cliente
	File       *multipart.FileHeader
}

// Save valida (sem re-hashear), deduplica por hash, grava atomicamente se novo,
// registra blob (pending) e cria linha media (entity_id NULL). Retorna a URL do blob.
func (s *MediaService) Save(ctx context.Context, in SaveInput) (string, error) {
	if err := ValidateHash(in.Checksum); err != nil {
		return "", err
	}
	// validação barata (header), não lê o arquivo todo
	src, err := in.File.Open()
	if err != nil {
		return "", fmt.Errorf("falha ao abrir arquivo: %w", err)
	}
	head := make([]byte, 512)
	n, _ := src.Read(head)
	src.Close()
	ext, mime, err := ValidateUpload(in.File.Filename, in.File.Size, head[:n])
	if err != nil {
		return "", err
	}

	url := BlobURL(in.Checksum, ext)

	existing, err := s.blobs.GetByHash(ctx, in.Checksum)
	if err != nil {
		return "", err
	}
	if existing == nil {
		// blob novo: grava atomicamente
		relDir, _ := BlobRelDir(in.Checksum)
		absDir := filepath.Join(s.baseDir, relDir)
		if err := os.MkdirAll(absDir, 0755); err != nil {
			return "", fmt.Errorf("mkdir: %w", err)
		}
		absPath := filepath.Join(absDir, BlobFilename(in.Checksum, ext))
		if err := saveAtomic(in.File, absPath); err != nil {
			return "", fmt.Errorf("gravar: %w", err)
		}
		blob := &entities.Blob{Hash: in.Checksum, Ext: ext, Mime: mime, SizeBytes: in.File.Size, Verified: "pending"}
		if err := s.blobs.Create(ctx, blob); err != nil {
			log.Printf("media: blob.Create falhou %s: %v", in.Checksum, err)
		}
	}
	// cria a linha media (entity_id NULL; ligada no save da entidade via Link)
	m := &entities.Media{EntityType: in.EntityType, ParkID: in.ParkID, BlobHash: in.Checksum}
	if err := s.media.Create(ctx, m); err != nil {
		log.Printf("media: media.Create falhou %s: %v", in.Checksum, err)
	}
	return url, nil
}

func (s *MediaService) Link(ctx context.Context, blobHash, entityType string, entityID uint) error {
	if blobHash == "" {
		return nil
	}
	return s.media.LinkByBlob(ctx, blobHash, entityType, entityID)
}

// saveAtomic grava o multipart num temp e renomeia (escrita atômica).
func saveAtomic(fh *multipart.FileHeader, dst string) error {
	src, err := fh.Open()
	if err != nil {
		return err
	}
	defer src.Close()
	tmp, err := os.CreateTemp(filepath.Dir(dst), ".tmp-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	if _, err := io.Copy(tmp, src); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	tmp.Close()
	return os.Rename(tmpName, dst)
}
```
> Nota: `Link` agora recebe `blobHash` (o checksum), não a URL. Os usecases (Task 7) passam o hash. Como a URL guardada na entidade é `BlobURL(hash,ext)`, derive o hash dela quando necessário, ou guarde o hash retornado pelo upload.

- [ ] **Step 2: Deletar `media_image.go`** — `git rm internal/application/services/media_image.go` (resize do avatar passa para o Flutter — Task 10).

- [ ] **Step 3: Wiring `main.go`** — junto dos repos: `blobRepo := persistence.NewMySQLBlobRepository(db)`; `mediaRepo := persistence.NewMySQLMediaRepository(db)`; e `mediaService := services.NewMediaService(blobRepo, mediaRepo, "uploads")`.

- [ ] **Step 4: Build + test** — `go build ./...` e `go test ./internal/application/services/...` (pode ainda quebrar nos handlers; resolve na Task 5 — avançar antes de commitar).

- [ ] **Step 5: Commit** (junto com Task 5).

---

### Task 5: Handlers passam `checksum` (sem resize no backend)

**Files:**
- Modify: `internal/infrastructure/http/handlers/upload_handler.go`, `review_handler.go`, `user_auth_handler.go`, `evento_handler.go`
- Modify: `cmd/api/main.go` (call sites dos construtores, se mudaram)

**Interfaces:**
- Consumes: `MediaService.Save(SaveInput{..., Checksum})`.

- [ ] **Step 1:** Em cada handler de upload, ler `checksum := c.PostForm("checksum")` e passar em `SaveInput`. Remover qualquer chamada/branch de resize (avatar): `UploadAvatar` agora só faz `Save` com `EntityType: services.EntityAvatar` + `Checksum` e depois `UpdateAvatar(url)` + `Link(checksum, EntityAvatar, userID)`. `UploadDenuncia` mantém entity_type fixo + checksum. Review exige `park_id` + `checksum`. Evento idem. Manter o mapeamento de status `uploadErrorStatus` (413/415) e os sentinelas.

- [ ] **Step 2:** Atualizar call sites dos construtores em `main.go` se a assinatura mudou (passar `mediaService`).

- [ ] **Step 3: Build + vet** — `go build ./... && go vet ./...` → sem erros.

- [ ] **Step 4: Commit**
```bash
git add internal/ cmd/api/main.go
git commit -m "feat(media): Save content-addressed + dedup; handlers enviam checksum; resize sai do backend"
```

---

### Task 6: Worker de verificação assíncrona

**Files:**
- Create: `internal/infrastructure/jobs/media_verifier.go`
- Modify: `cmd/api/main.go` (iniciar o worker em goroutine no boot)

**Interfaces:**
- Consumes: `BlobRepository.ListByVerified("pending",N)`, `SetVerified`; lê arquivo de `uploads/blobs/...`.

- [ ] **Step 1: Implementar o verifier** — `internal/infrastructure/jobs/media_verifier.go`: função `RunMediaVerifier(ctx, blobRepo, baseDir, interval)` que num loop (ticker) pega blobs `pending` (lote pequeno, ex. 20), re-hasheia o arquivo (`sha256` streaming via `io.Copy` para não estourar memória), compara com `blob.Hash`; se bate → `SetVerified ok`; se não → `SetVerified mismatch` + move o arquivo para `uploads/_quarantine/`. Intervalo curto (ex. 30s) para encurtar a janela de poisoning, lote pequeno para não pesar. Usar `Date`/`time` injetado via parâmetro (não chamar relógio dentro de teste).

- [ ] **Step 2: Iniciar no boot** — em `main.go`, após o wiring: `go jobs.RunMediaVerifier(context.Background(), blobRepo, "uploads", 30*time.Second)`.

- [ ] **Step 3: Build** — `go build ./...` → sem erros.

- [ ] **Step 4: Commit**
```bash
git add internal/infrastructure/jobs/media_verifier.go cmd/api/main.go
git commit -m "feat(media): worker assíncrono de verificação de integridade (re-hash off hot path)"
```

---

### Task 7: Usecases ligam media→blob no save

**Files:**
- Modify: usecases de review/space/denuncia/evento/park (`internal/application/usecases/*.go`)
- Modify: `cmd/api/main.go` (injetar service onde faltar)

**Interfaces:**
- Consumes: `MediaService.Link(ctx, blobHash, entityType string, entityID uint)`.

- [ ] **Step 1:** Em cada create/update que grava URL de imagem, derivar o `blobHash` da URL salva (a URL é `/uploads/blobs/<aa>/<bb>/<hash>.<ext>` → o hash é o basename sem extensão) e chamar `_ = uc.media.Link(ctx, hash, services.Entity..., id)` APÓS o ID existir. Para denúncia, iterar `Fotos`. Não há mais `MoveToPark` (sem parque no caminho) — remover esse método e a lógica de `_sem-vinculo`.

- [ ] **Step 2: Build** — `go build ./...` → sem erros.

- [ ] **Step 3: Commit**
```bash
git add internal/application/usecases/ internal/application/services/ cmd/api/main.go
git commit -m "feat(media): usecases ligam media->blob no save (entity_id)"
```

---

### Task 8: Comando de migração (legados → blobs)

**Files:**
- Rewrite: `cmd/migrate-media/main.go`

**Interfaces:** conecta no DB (envs DB_*), lê `uploads/` legado.

- [ ] **Step 1: Reescrever** — para cada coluna de URL das entidades (parks.imagem_url; spaces.imagem_url+2/3/4; reviews.midia_url; eventos.capa_url+banner_url; users.avatar_url; denuncia.fotos[]):
  - localizar o arquivo legado (strip de `/api/v1/uploads/` e `/uploads/`, prefixar `uploads/`);
  - **hashear (SHA-256 streaming)** — offline, custo OK;
  - se `blobs[hash]` não existe → mover/copiar para `uploads/blobs/<aa>/<bb>/<hash>.<ext>` (atômico) e criar `blobs` (`verified='ok'`); se existe → dedup (não copia);
  - criar `media` (entity_type, entity_id, park_id, blob_hash) e atualizar a coluna de URL da entidade para `BlobURL(hash,ext)`;
  - dedup de origem duplicada: mapa `origem→hash` para não re-hashear/re-mover o mesmo arquivo.
  - `--dry-run` padrão; `--apply` com checagem de erro de DB + rollback de arquivo (padrão da versão anterior); órfãos → `_quarantine`.

- [ ] **Step 2: Build** — `go build ./cmd/migrate-media && go build ./...` → sem erros.

- [ ] **Step 3: Commit**
```bash
git add cmd/migrate-media/main.go
git commit -m "feat(migrate-media): migra legados para blobs content-addressed (dry-run padrão)"
```

---

### Task 9: GC (cleanup) por ref-count + carência

**Files:**
- Rewrite: `cmd/cleanup-media/main.go`

- [ ] **Step 1: Reescrever** — `--apply` (default dry-run), backup avisado:
  - **Blobs deletáveis**: `blobRepo.DeletableHashes(cutoff = agora - 24h)` (0 media ativas E created_at < cutoff). Para cada: `os.Remove` do arquivo (`BlobRelDir`+`BlobFilename`) + `blobRepo.DeleteByHash`.
  - **Arquivo-sem-blob**: percorre `uploads/blobs/` (pula `_quarantine`); arquivo cujo basename(sem ext) não existe em `blobs` → quarentena (nome único em colisão). Cruza também: se o hash aparece em alguma `media` mas o blob sumiu, logar inconsistência em vez de quarentenar.
  - Checa erro de toda query; conservador (na dúvida, não apaga).

- [ ] **Step 2: Build** — `go build ./cmd/cleanup-media && go build ./...` → sem erros.

- [ ] **Step 3: Commit**
```bash
git add cmd/cleanup-media/main.go
git commit -m "feat(cleanup-media): GC de blobs por ref-count + carência 24h (dry-run padrão)"
```

---

### Task 10: Cliente calcula SHA-256 (Flutter + painel) + resize de avatar no Flutter

**Files:**
- Modify: `lib/data/repositories/go_reviews_repository.dart` (uploadMedia envia checksum)
- Modify: `lib/screens/denuncie_screen.dart` (upload envia checksum)
- Modify: tela/serviço de avatar no Flutter (resize 300x300 + checksum)
- Modify: PAINEL-PARK uploads (parque/espaço/evento) — calcular checksum (SubtleCrypto) e enviar

- [ ] **Step 1: Flutter — helper de checksum** — usar o pacote `crypto` (já provável no projeto; senão adicionar em `pubspec.yaml`). Função util: lê os bytes do arquivo, `sha256.convert(bytes).toString()`.
- [ ] **Step 2: Flutter — review/denúncia/avatar** — antes do upload, calcular o checksum e adicionar `request.fields['checksum']`. Avatar: redimensionar para 300x300 (ex.: `image` package ou `flutter_image_compress`) ANTES de hashear, e enviar os bytes redimensionados + o hash deles.
- [ ] **Step 3: Painel** — onde sobe imagem de parque/espaço/evento, calcular `crypto.subtle.digest('SHA-256', buffer)` → hex e enviar `checksum` no form, com `entity_type`/`park_id` quando aplicável.
- [ ] **Step 4: Verificar** — `flutter analyze` (0 erros novos) e build do painel (`tsc --noEmit`).
- [ ] **Step 5: Commit (Flutter)** — só os arquivos Flutter; painel salvo localmente (não está no git).

---

## Checkpoint de produção (NÃO automatizar)
1. Backup do banco + `tar` de `uploads/` no VPS.
2. Deploy do backend (cria `blobs`/`media`, inicia o worker).
3. Deploy do app/painel que calculam o checksum (sem app novo, uploads novos chegam sem checksum → handler rejeita; coordenar).
4. `migrate-media --dry-run` → revisar → confirmação humana → `--apply`.
5. `cleanup-media --dry-run` para conferir.

## Self-review (cobertura da spec)
- content-addressed + sharding → Task 2; escrita atômica → Task 4 (`saveAtomic`).
- blobs+media + ref-count → Tasks 1, 3; dedup → Task 4; GC + carência → Task 9.
- hash no cliente + resize avatar no cliente → Task 10; hot path sem re-hash → Task 4.
- verificação assíncrona + quarentena → Task 6.
- achar por parque (media.park_id) → Tasks 1, 7.
- migração legados → Task 8.
- SHA-256/sentinelas/413-415 preservados → Tasks 2, 5.
