# Reestruturação de uploads — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unificar os 4 fluxos de upload do backend num único `MediaService`, com storage organizado por parque/categoria, tabela `media` de rastreio, migração dos legados e limpeza de órfãos.

**Architecture:** Um serviço único (`MediaService`) valida, resolve o caminho parque-first, grava o arquivo e registra na tabela `media` (entity_id NULL no upload). Os usecases preenchem `entity_id` no save via `Link`. Dois comandos CLI standalone fazem migração one-shot e limpeza de órfãos (dry-run por padrão).

**Tech Stack:** Go, Gin, GORM (MySQL 8), arquitetura em camadas (entities → repositories → usecases → handlers).

## Global Constraints

- Repositório: `/Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK` (todo código Go). Module: `github.com/darkzinn11/parque/back/go-api`.
- **Branch:** o PARQUE-BACK está em `main`. Antes de qualquer commit, criar uma branch de feature (ex.: `feat/media-uploads-restructure`).
- Sem framework de teste no projeto: testes só para lógica pura (resolução de caminho, validação de bytes); restante verificado com `go build ./...` + execução local + dry-run.
- Colunas de URL permanecem `varchar(512)`; alinhar `users.avatar_url` 255 → 512.
- URLs gravadas no banco são **relativas** (`/uploads/...`).
- Nome de arquivo: `{tipo}_{hash6}.{ext}` (hash hex de 6 chars; sem entity_id).
- Migração e limpeza: `--dry-run` por padrão; `--apply` exige backup antes; nunca rodar a migração de produção sem confirmação humana explícita.
- Validação de upload: máx 5 MB; extensões `.jpg/.jpeg/.png/.webp/.gif`; MIME sniffing dos primeiros 512 bytes.
- Convenção DDL #8: alterar coluna existente exige ALTER explícito em `main.go`, não só a struct.

---

### Task 1: Entidade `Media` + registro no AutoMigrate

**Files:**
- Create: `internal/domain/entities/media.go`
- Modify: `cmd/api/main.go` (lista do `AutoMigrate`, ~linha 136-157)

**Interfaces:**
- Produces: `entities.Media` struct com campos `ID, EntityType, EntityID *uint, ParkID *uint, FilePath, Mime, SizeBytes, CreatedAt, DeletedAt gorm.DeletedAt`.

- [ ] **Step 1: Criar a entidade**

`internal/domain/entities/media.go`:
```go
package entities

import (
	"time"

	"gorm.io/gorm"
)

// Media é o ledger de rastreio de arquivos de upload.
// NÃO é a fonte de verdade da exibição: as colunas de URL das entidades
// (reviews.midia_url, spaces.imagem_url, etc.) continuam mandando.
type Media struct {
	ID         uint           `json:"id" gorm:"primaryKey"`
	EntityType string         `json:"entity_type" gorm:"size:20;index:idx_media_entity,priority:1"`
	EntityID   *uint          `json:"entity_id" gorm:"index:idx_media_entity,priority:2"`
	ParkID     *uint          `json:"park_id" gorm:"index"`
	FilePath   string         `json:"file_path" gorm:"size:512"`
	Mime       string         `json:"mime" gorm:"size:30"`
	SizeBytes  int64          `json:"size_bytes"`
	CreatedAt  time.Time      `json:"created_at"`
	DeletedAt  gorm.DeletedAt `json:"deleted_at,omitempty" gorm:"index"`
}
```

- [ ] **Step 2: Registrar no AutoMigrate**

Em `cmd/api/main.go`, adicionar `&entities.Media{},` à lista do `db.AutoMigrate(...)` (junto das outras entidades, após `&entities.Denuncia{}` ou no fim da lista).

- [ ] **Step 3: Build**

Run: `cd /Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK && go build ./...`
Expected: sem erros.

- [ ] **Step 4: Commit**

```bash
git add internal/domain/entities/media.go cmd/api/main.go
git commit -m "feat(media): adiciona entidade Media (ledger de rastreio) + AutoMigrate"
```

---

### Task 2: Resolução de caminho (lógica pura, TDD)

**Files:**
- Create: `internal/application/services/media_path.go`
- Test: `internal/application/services/media_path_test.go`

**Interfaces:**
- Produces:
  - `const (EntityPark="park"; EntitySpace="space"; EntityReview="review"; EntityEvento="evento"; EntityDenuncia="denuncia"; EntityAvatar="avatar")`
  - `func ResolveDir(entityType string, parkID *uint, ownerID *uint) (relDir string, err error)` — retorna o diretório relativo (sem `uploads/` na frente), ex. `parques/52/reviews`.
  - `func BuildFilename(entityType, hash, ext string) string` — ex. `review_a3f9c1.webp`.
  - `func RelURL(relDir, filename string) string` — ex. `/uploads/parques/52/reviews/review_a3f9c1.webp`.

- [ ] **Step 1: Escrever o teste que falha**

`internal/application/services/media_path_test.go`:
```go
package services

import "testing"

func u(v uint) *uint { return &v }

func TestResolveDir(t *testing.T) {
	cases := []struct {
		name       string
		entityType string
		parkID     *uint
		ownerID    *uint
		want       string
		wantErr    bool
	}{
		{"review com parque", EntityReview, u(52), nil, "parques/52/reviews", false},
		{"espaço com parque", EntitySpace, u(7), nil, "parques/7/espacos", false},
		{"capa de parque existente", EntityPark, u(3), nil, "parques/3/capa", false},
		{"capa de parque novo (sem parkID)", EntityPark, nil, nil, "parques/_sem-vinculo", false},
		{"evento com parque", EntityEvento, u(9), nil, "parques/9/eventos", false},
		{"evento editorial sem parque", EntityEvento, nil, nil, "eventos-gerais", false},
		{"denúncia com parque", EntityDenuncia, u(4), nil, "parques/4/denuncias", false},
		{"denúncia sem parque", EntityDenuncia, nil, nil, "denuncias-sem-parque", false},
		{"avatar usa ownerID", EntityAvatar, nil, u(8), "usuarios/8", false},
		{"avatar sem ownerID é erro", EntityAvatar, nil, nil, "", true},
		{"tipo desconhecido é erro", "qualquer", u(1), nil, "", true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := ResolveDir(c.entityType, c.parkID, c.ownerID)
			if c.wantErr {
				if err == nil {
					t.Fatalf("esperava erro, got dir=%q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("erro inesperado: %v", err)
			}
			if got != c.want {
				t.Errorf("ResolveDir = %q, want %q", got, c.want)
			}
		})
	}
}

func TestBuildFilename(t *testing.T) {
	got := BuildFilename(EntityReview, "a3f9c1", ".webp")
	if got != "review_a3f9c1.webp" {
		t.Errorf("BuildFilename = %q", got)
	}
}

func TestRelURL(t *testing.T) {
	got := RelURL("parques/52/reviews", "review_a3f9c1.webp")
	if got != "/uploads/parques/52/reviews/review_a3f9c1.webp" {
		t.Errorf("RelURL = %q", got)
	}
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd /Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK && go test ./internal/application/services/ -run 'ResolveDir|BuildFilename|RelURL' -v`
Expected: FAIL (undefined: ResolveDir, etc.)

- [ ] **Step 3: Implementar**

`internal/application/services/media_path.go`:
```go
package services

import (
	"fmt"
	"path"
)

const (
	EntityPark     = "park"
	EntitySpace    = "space"
	EntityReview   = "review"
	EntityEvento   = "evento"
	EntityDenuncia = "denuncia"
	EntityAvatar   = "avatar"
)

// categorySubdir mapeia o tipo de entidade para a subpasta dentro de parques/{id}/.
var categorySubdir = map[string]string{
	EntityPark:     "capa",
	EntitySpace:    "espacos",
	EntityReview:   "reviews",
	EntityEvento:   "eventos",
	EntityDenuncia: "denuncias",
}

// ResolveDir retorna o diretório relativo (sem o prefixo "uploads/").
// parkID: parque dono quando conhecido. ownerID: id do usuário (só para avatar).
func ResolveDir(entityType string, parkID *uint, ownerID *uint) (string, error) {
	switch entityType {
	case EntityAvatar:
		if ownerID == nil {
			return "", fmt.Errorf("avatar exige ownerID")
		}
		return fmt.Sprintf("usuarios/%d", *ownerID), nil
	case EntityEvento:
		if parkID == nil {
			return "eventos-gerais", nil
		}
		return fmt.Sprintf("parques/%d/%s", *parkID, categorySubdir[EntityEvento]), nil
	case EntityDenuncia:
		if parkID == nil {
			return "denuncias-sem-parque", nil
		}
		return fmt.Sprintf("parques/%d/%s", *parkID, categorySubdir[EntityDenuncia]), nil
	case EntityPark:
		if parkID == nil {
			return "parques/_sem-vinculo", nil
		}
		return fmt.Sprintf("parques/%d/%s", *parkID, categorySubdir[EntityPark]), nil
	case EntitySpace, EntityReview:
		if parkID == nil {
			return "", fmt.Errorf("%s exige parkID", entityType)
		}
		return fmt.Sprintf("parques/%d/%s", *parkID, categorySubdir[entityType]), nil
	default:
		return "", fmt.Errorf("entityType desconhecido: %q", entityType)
	}
}

func BuildFilename(entityType, hash, ext string) string {
	return fmt.Sprintf("%s_%s%s", entityType, hash, ext)
}

func RelURL(relDir, filename string) string {
	return "/uploads/" + path.Join(relDir, filename)
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `go test ./internal/application/services/ -run 'ResolveDir|BuildFilename|RelURL' -v`
Expected: PASS (todos os subtests).

- [ ] **Step 5: Commit**

```bash
git add internal/application/services/media_path.go internal/application/services/media_path_test.go
git commit -m "feat(media): resolução de caminho parque-first (lógica pura + testes)"
```

---

### Task 3: Validação de upload (lógica pura, TDD)

**Files:**
- Create: `internal/application/services/media_validate.go`
- Test: `internal/application/services/media_validate_test.go`

**Interfaces:**
- Produces:
  - `const MaxUploadBytes = 5 << 20`
  - `func ValidateUpload(filename string, size int64, head []byte) (ext, mime string, err error)` — valida tamanho, extensão (allowlist) e MIME sniffing.

- [ ] **Step 1: Escrever o teste que falha**

`internal/application/services/media_validate_test.go`:
```go
package services

import "testing"

// cabeçalhos mínimos para o http.DetectContentType
var pngHead = []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}
var jpegHead = []byte{0xFF, 0xD8, 0xFF, 0xE0}

func TestValidateUpload(t *testing.T) {
	if _, _, err := ValidateUpload("foto.png", 1000, pngHead); err != nil {
		t.Errorf("png válido recusado: %v", err)
	}
	if _, mime, err := ValidateUpload("foto.jpg", 1000, jpegHead); err != nil || mime != "image/jpeg" {
		t.Errorf("jpg válido recusado: mime=%q err=%v", mime, err)
	}
	if _, _, err := ValidateUpload("grande.png", MaxUploadBytes+1, pngHead); err == nil {
		t.Error("arquivo acima do limite deveria falhar")
	}
	if _, _, err := ValidateUpload("doc.pdf", 1000, pngHead); err == nil {
		t.Error("extensão não permitida deveria falhar")
	}
	if _, _, err := ValidateUpload("falso.png", 1000, jpegHead); err == nil {
		t.Error("conteúdo divergente da extensão deveria falhar")
	}
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `go test ./internal/application/services/ -run ValidateUpload -v`
Expected: FAIL (undefined: ValidateUpload)

- [ ] **Step 3: Implementar**

`internal/application/services/media_validate.go`:
```go
package services

import (
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
)

const MaxUploadBytes = 5 << 20 // 5 MB

var allowedExt = map[string]string{
	".jpg":  "image/jpeg",
	".jpeg": "image/jpeg",
	".png":  "image/png",
	".webp": "image/webp",
	".gif":  "image/gif",
}

// ValidateUpload checa tamanho, extensão (allowlist) e MIME real (sniffing).
// head deve conter os primeiros bytes do arquivo (até 512).
func ValidateUpload(filename string, size int64, head []byte) (ext, mime string, err error) {
	if size > MaxUploadBytes {
		return "", "", fmt.Errorf("arquivo excede o tamanho máximo de 5MB")
	}
	ext = strings.ToLower(filepath.Ext(filename))
	expected, ok := allowedExt[ext]
	if !ok {
		return "", "", fmt.Errorf("tipo de arquivo não permitido")
	}
	detected := http.DetectContentType(head)
	// webp/gif: DetectContentType retorna image/webp e image/gif; jpeg/png idem.
	if detected != expected {
		// http.DetectContentType nem sempre reconhece webp em libs antigas; aceita se bater no grupo image/*
		if !(strings.HasPrefix(detected, "image/") && (ext == ".webp")) {
			return "", "", fmt.Errorf("conteúdo do arquivo não corresponde à extensão")
		}
	}
	return ext, expected, nil
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `go test ./internal/application/services/ -run ValidateUpload -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add internal/application/services/media_validate.go internal/application/services/media_validate_test.go
git commit -m "feat(media): validação de upload (tamanho/ext/MIME) com testes"
```

---

### Task 4: Repositório `media` + interface

**Files:**
- Create: `internal/domain/repositories/media_repository.go`
- Create: `internal/infrastructure/persistence/mysql_media_repository.go`

**Interfaces:**
- Produces: `repositories.MediaRepository` com:
  - `Create(ctx, *entities.Media) error`
  - `LinkByURL(ctx, url, entityType string, entityID uint) error` (seta entity_id na linha cujo file_path = url)
  - `ListAll(ctx) ([]entities.Media, error)`
  - `SoftDeleteByID(ctx, id uint) error`

- [ ] **Step 1: Interface**

`internal/domain/repositories/media_repository.go`:
```go
package repositories

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
)

type MediaRepository interface {
	Create(ctx context.Context, m *entities.Media) error
	LinkByURL(ctx context.Context, url, entityType string, entityID uint) error
	ListAll(ctx context.Context) ([]entities.Media, error)
	SoftDeleteByID(ctx context.Context, id uint) error
}
```
> Module Go: `github.com/darkzinn11/parque/back/go-api` (confirmado no `go.mod`).

- [ ] **Step 2: Implementação MySQL**

`internal/infrastructure/persistence/mysql_media_repository.go`:
```go
package persistence

import (
	"context"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
	"gorm.io/gorm"
)

type mysqlMediaRepository struct {
	db *gorm.DB
}

func NewMySQLMediaRepository(db *gorm.DB) repositories.MediaRepository {
	return &mysqlMediaRepository{db: db}
}

func (r *mysqlMediaRepository) Create(ctx context.Context, m *entities.Media) error {
	return r.db.WithContext(ctx).Create(m).Error
}

func (r *mysqlMediaRepository) LinkByURL(ctx context.Context, url, entityType string, entityID uint) error {
	return r.db.WithContext(ctx).
		Model(&entities.Media{}).
		Where("file_path = ? AND entity_type = ? AND entity_id IS NULL", url, entityType).
		Update("entity_id", entityID).Error
}

func (r *mysqlMediaRepository) ListAll(ctx context.Context) ([]entities.Media, error) {
	var ms []entities.Media
	if err := r.db.WithContext(ctx).Find(&ms).Error; err != nil {
		return nil, err
	}
	return ms, nil
}

func (r *mysqlMediaRepository) SoftDeleteByID(ctx context.Context, id uint) error {
	return r.db.WithContext(ctx).Delete(&entities.Media{}, id).Error
}
```

- [ ] **Step 3: Build**

Run: `go build ./...`
Expected: sem erros (confirme o import path do module).

- [ ] **Step 4: Commit**

```bash
git add internal/domain/repositories/media_repository.go internal/infrastructure/persistence/mysql_media_repository.go
git commit -m "feat(media): repositório media (Create/LinkByURL/ListAll/SoftDelete)"
```

---

### Task 5: `MediaService.Save` + `Link` + wiring no main.go

**Files:**
- Create: `internal/application/services/media_service.go`
- Modify: `cmd/api/main.go` (instanciar repo + service)

**Interfaces:**
- Consumes: `repositories.MediaRepository`, `services.ResolveDir/BuildFilename/RelURL/ValidateUpload`.
- Produces: `services.MediaService` com `Save(ctx, SaveInput) (string, error)` e `Link(ctx, url, entityType string, entityID uint) error`. `SaveInput{EntityType string; ParkID *uint; OwnerID *uint; File *multipart.FileHeader}`.

- [ ] **Step 1: Implementar o service**

`internal/application/services/media_service.go`:
```go
package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"mime/multipart"
	"os"
	"path/filepath"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/domain/repositories"
)

type MediaService struct {
	repo    repositories.MediaRepository
	baseDir string // ex.: "uploads"
}

func NewMediaService(repo repositories.MediaRepository, baseDir string) *MediaService {
	return &MediaService{repo: repo, baseDir: baseDir}
}

type SaveInput struct {
	EntityType string
	ParkID     *uint // nil quando desconhecido (capa de parque novo) ou sem parque (avatar)
	OwnerID    *uint // só para avatar
	File       *multipart.FileHeader
}

func randHash() (string, error) {
	b := make([]byte, 3) // 6 chars hex
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// Save valida, resolve o caminho, grava o arquivo e cria a linha media (entity_id NULL).
func (s *MediaService) Save(ctx context.Context, in SaveInput) (string, error) {
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

	relDir, err := ResolveDir(in.EntityType, in.ParkID, in.OwnerID)
	if err != nil {
		return "", err
	}
	hash, err := randHash()
	if err != nil {
		return "", err
	}
	filename := BuildFilename(in.EntityType, hash, ext)

	absDir := filepath.Join(s.baseDir, relDir)
	if err := os.MkdirAll(absDir, 0755); err != nil {
		return "", fmt.Errorf("falha ao criar diretório: %w", err)
	}
	absPath := filepath.Join(absDir, filename)
	if err := saveMultipart(in.File, absPath); err != nil {
		return "", fmt.Errorf("falha ao salvar arquivo: %w", err)
	}

	url := RelURL(relDir, filename)
	m := &entities.Media{
		EntityType: in.EntityType,
		EntityID:   nil,
		ParkID:     in.ParkID,
		FilePath:   url,
		Mime:       mime,
		SizeBytes:  in.File.Size,
	}
	if err := s.repo.Create(ctx, m); err != nil {
		// arquivo já gravado; loga mas não falha o upload por causa do ledger
		return url, nil
	}
	return url, nil
}

// Link preenche entity_id na linha media correspondente à url.
func (s *MediaService) Link(ctx context.Context, url, entityType string, entityID uint) error {
	if url == "" {
		return nil
	}
	return s.repo.LinkByURL(ctx, url, entityType, entityID)
}

func saveMultipart(fh *multipart.FileHeader, dst string) error {
	src, err := fh.Open()
	if err != nil {
		return err
	}
	defer src.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()
	buf := make([]byte, 32*1024)
	for {
		n, rerr := src.Read(buf)
		if n > 0 {
			if _, werr := out.Write(buf[:n]); werr != nil {
				return werr
			}
		}
		if rerr != nil {
			if rerr.Error() == "EOF" {
				break
			}
			break
		}
	}
	return nil
}
```
> Nota de implementação: se preferir, troque `saveMultipart` por `c.SaveUploadedFile` no handler e passe o caminho ao service; aqui o service salva direto para manter a lógica num lugar só.

- [ ] **Step 2: Instanciar no main.go**

Em `cmd/api/main.go`, junto dos outros repos (~linha 245-257):
```go
mediaRepo := persistence.NewMySQLMediaRepository(db)
```
Junto dos services/usecases (~linha 268+):
```go
mediaService := services.NewMediaService(mediaRepo, "uploads")
```
(import do pacote `services` se ainda não houver.)

- [ ] **Step 3: Build**

Run: `go build ./...`
Expected: sem erros (o `mediaService` pode ficar não-usado até a Task 6; se o compilador reclamar de variável não usada, prossiga direto para a Task 6 antes de commitar, ou injete já no primeiro handler).

- [ ] **Step 4: Commit**

```bash
git add internal/application/services/media_service.go cmd/api/main.go
git commit -m "feat(media): MediaService.Save/Link + wiring no main"
```

---

### Task 6: Refatorar os 4 handlers para delegar ao MediaService

**Files:**
- Modify: `internal/infrastructure/http/handlers/upload_handler.go` (genérico: denúncia/parque/espaço)
- Modify: `internal/infrastructure/http/handlers/review_handler.go` (`UploadReviewMedia`)
- Modify: `internal/infrastructure/http/handlers/user_auth_handler.go` (`UploadAvatar`)
- Modify: `internal/infrastructure/http/handlers/evento_handler.go` (`AdminUpload`)
- Modify: `cmd/api/main.go` (injetar `mediaService` nos construtores dos handlers)

**Interfaces:**
- Consumes: `services.MediaService.Save`.
- Os handlers passam a ler campos opcionais do form: `entity_type` e `park_id` (e usam `user_id` do contexto para avatar como OwnerID).

- [ ] **Step 1: Handler genérico**

Substituir o corpo de `UploadHandler.Upload` para extrair `entity_type` e `park_id` do form e delegar:
```go
func (h *UploadHandler) Upload(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Arquivo não encontrado na requisição"})
		return
	}
	entityType := c.PostForm("entity_type")
	if entityType == "" {
		entityType = services.EntityDenuncia // default histórico do endpoint genérico
	}
	var parkID *uint
	if v := c.PostForm("park_id"); v != "" {
		if id, perr := strconv.ParseUint(v, 10, 64); perr == nil {
			pid := uint(id)
			parkID = &pid
		}
	}
	url, err := h.media.Save(c.Request.Context(), services.SaveInput{
		EntityType: entityType,
		ParkID:     parkID,
		File:       file,
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"url": url, "name": filepath.Base(url)})
}
```
Atualizar a struct `UploadHandler` e `NewUploadHandler` para receber `*services.MediaService` (campo `media`). Remover a lógica antiga de validação/escrita (agora no service) e o `BaseURL/BasePath` se não forem mais usados.

- [ ] **Step 2: Review handler**

Trocar o corpo de `UploadReviewMedia` para delegar (mantém auth e o campo `media`, mas exige `park_id`):
```go
func (h *ReviewHandler) UploadReviewMedia(c *gin.Context) {
	if _, ok := c.Get("user_id"); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "não autenticado"})
		return
	}
	file, err := c.FormFile("media")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "arquivo 'media' é obrigatório"})
		return
	}
	var parkID *uint
	if v := c.PostForm("park_id"); v != "" {
		if id, perr := strconv.ParseUint(v, 10, 64); perr == nil {
			pid := uint(id)
			parkID = &pid
		}
	}
	if parkID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "park_id é obrigatório"})
		return
	}
	url, err := h.media.Save(c.Request.Context(), services.SaveInput{
		EntityType: services.EntityReview, ParkID: parkID, File: file,
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"url": url})
}
```
Adicionar campo `media *services.MediaService` ao `ReviewHandler` + parâmetro no `NewReviewHandler`.
> Compatibilidade Flutter: a tela de review hoje pode não enviar `park_id`. Como a review é sempre de um parque conhecido na tela, adicionar `park_id` no multipart é uma mudança pequena no app (ver Task 10). Até lá, o endpoint retorna 400 sem `park_id`.

- [ ] **Step 3: Avatar handler**

Trocar `UploadAvatar` para delegar usando `OwnerID = user_id`:
```go
func (h *UserAuthHandler) UploadAvatar(c *gin.Context) {
	v, ok := c.Get("user_id")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "usuário não autenticado"})
		return
	}
	userID, ok := v.(uint)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "sessão inválida"})
		return
	}
	file, err := c.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "arquivo avatar é obrigatório"})
		return
	}
	url, err := h.media.Save(c.Request.Context(), services.SaveInput{
		EntityType: services.EntityAvatar, OwnerID: &userID, File: file,
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	user, err := h.useCase.UpdateAvatar(c.Request.Context(), userID, url)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	_ = h.media.Link(c.Request.Context(), url, services.EntityAvatar, userID)
	c.JSON(http.StatusOK, user)
}
```
Adicionar campo `media` ao `UserAuthHandler` + parâmetro no construtor.
> O avatar é o único caso em que entity_id (=user_id) já é conhecido no upload, então o `Link` é chamado aqui mesmo.

- [ ] **Step 4: Evento handler**

Trocar `AdminUpload` para delegar. Evento editorial não tem parque no upload, então `ParkID: nil` (cai em `eventos-gerais/`):
```go
func (h *EventoHandler) AdminUpload(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "arquivo não encontrado na requisição"})
		return
	}
	url, err := h.media.Save(c.Request.Context(), services.SaveInput{
		EntityType: services.EntityEvento, ParkID: nil, File: file,
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"url": url, "name": filepath.Base(url)})
}
```
Adicionar campo `media` ao `EventoHandler` + parâmetro no construtor.

- [ ] **Step 5: Atualizar construtores no main.go**

Passar `mediaService` em `NewUploadHandler`, `NewReviewHandler`, `NewUserAuthHandler`, `NewEventoHandler`. Garantir `import "strconv"` e `"path/filepath"` onde usados, e o import do pacote `services`.

- [ ] **Step 6: Build + smoke local**

Run: `go build ./...`
Expected: sem erros.
Smoke (opcional, local): `go run ./cmd/api` e subir um arquivo via curl:
```bash
curl -F "file=@/caminho/foto.png" -F "entity_type=denuncia" -F "park_id=1" http://localhost:8081/api/v1/denuncias/upload
```
Expected: JSON com `url` apontando para `/uploads/parques/1/denuncias/denuncia_xxxxxx.png`; arquivo presente no disco; linha em `media`.

- [ ] **Step 7: Commit**

```bash
git add internal/infrastructure/http/handlers/ cmd/api/main.go
git commit -m "refactor(media): 4 handlers delegam ao MediaService (caminho parque-first unificado)"
```

---

### Task 7: Ligar `Link` nos usecases de create/update + mover capa de parque novo

**Files:**
- Modify: `internal/application/usecases/review_usecase.go` (após criar review → Link)
- Modify: `internal/application/usecases/park_usecase.go` (criar/atualizar parque → mover capa de `_sem-vinculo` + Link)
- Modify: usecases de espaço, denúncia, evento (Link no save)

**Interfaces:**
- Consumes: `services.MediaService.Link`. Os usecases que ainda não recebem o service ganham um parâmetro no construtor; atualizar `main.go`.

- [ ] **Step 1: Review usecase**

No método que cria a review, após `repo.Create(ctx, review)` (quando `review.ID` já está populado e `review.MidiaURL != ""`):
```go
if review.MidiaURL != "" {
	_ = uc.media.Link(ctx, review.MidiaURL, services.EntityReview, review.ID)
}
```
Adicionar `media *services.MediaService` ao struct do usecase + parâmetro no `NewReviewUseCase` + atualizar `main.go`.

- [ ] **Step 2: Park usecase — mover capa + Link**

No create de parque, quando `park.ImagemURL` aponta para `parques/_sem-vinculo/`:
```go
if strings.Contains(park.ImagemURL, "/parques/_sem-vinculo/") {
	newURL, err := uc.media.MoveToPark(ctx, park.ImagemURL, park.ID, services.EntityPark)
	if err == nil && newURL != "" {
		park.ImagemURL = newURL
		_ = uc.repo.Update(ctx, park) // persiste a URL já movida
	}
}
_ = uc.media.Link(ctx, park.ImagemURL, services.EntityPark, park.ID)
```
Isso exige um método novo no service (Step 3).

- [ ] **Step 3: Adicionar `MoveToPark` ao MediaService**

Em `internal/application/services/media_service.go`:
```go
// MoveToPark move um arquivo de parques/_sem-vinculo/ para parques/{id}/{categoria}/
// e atualiza file_path na linha media. Retorna a nova URL relativa.
func (s *MediaService) MoveToPark(ctx context.Context, oldURL string, parkID uint, entityType string) (string, error) {
	if !strings.Contains(oldURL, "/parques/_sem-vinculo/") {
		return oldURL, nil
	}
	filename := filepath.Base(oldURL)
	relDir, err := ResolveDir(entityType, &parkID, nil)
	if err != nil {
		return "", err
	}
	newURL := RelURL(relDir, filename)
	oldAbs := filepath.Join(s.baseDir, strings.TrimPrefix(oldURL, "/uploads/"))
	newAbs := filepath.Join(s.baseDir, relDir, filename)
	if err := os.MkdirAll(filepath.Dir(newAbs), 0755); err != nil {
		return "", err
	}
	if err := os.Rename(oldAbs, newAbs); err != nil {
		return "", err
	}
	_ = s.repo.UpdatePath(ctx, oldURL, newURL, &parkID) // ver Step 4
	return newURL, nil
}
```
Adicionar `import "strings"`.

- [ ] **Step 4: Adicionar `UpdatePath` ao repositório media**

Interface + impl:
```go
// interface
UpdatePath(ctx context.Context, oldURL, newURL string, parkID *uint) error
// impl
func (r *mysqlMediaRepository) UpdatePath(ctx context.Context, oldURL, newURL string, parkID *uint) error {
	return r.db.WithContext(ctx).
		Model(&entities.Media{}).
		Where("file_path = ?", oldURL).
		Updates(map[string]interface{}{"file_path": newURL, "park_id": parkID}).Error
}
```

- [ ] **Step 5: Espaço, denúncia, evento usecases**

Em cada create/update que grava URL de imagem, após persistir e ter o id, chamar `Link` com o tipo correto (`EntitySpace`, `EntityDenuncia`, `EntityEvento`). Para denúncia, percorrer `fotos[]` e ligar cada uma. Adicionar o service ao construtor de cada usecase + `main.go`.

- [ ] **Step 6: Build**

Run: `go build ./...`
Expected: sem erros.

- [ ] **Step 7: Commit**

```bash
git add internal/application/usecases/ internal/application/services/ internal/domain/repositories/media_repository.go internal/infrastructure/persistence/mysql_media_repository.go cmd/api/main.go
git commit -m "feat(media): usecases vinculam entity_id no save + move capa de parque novo"
```

---

### Task 8: ALTER `users.avatar_url` 255 → 512

**Files:**
- Modify: `cmd/api/main.go` (bloco de schema hardening, antes do AutoMigrate, ~linha 98-115)

- [ ] **Step 1: Adicionar o ALTER**

Junto dos outros `MODIFY` de longtext:
```go
db.Exec("ALTER TABLE users MODIFY avatar_url VARCHAR(512)")
```

- [ ] **Step 2: Build**

Run: `go build ./...`
Expected: sem erros.

- [ ] **Step 3: Commit**

```bash
git add cmd/api/main.go
git commit -m "fix(ddl): users.avatar_url 255 -> 512 (alinha com demais colunas de URL)"
```

---

### Task 9: Comando de migração one-shot `cmd/migrate-media`

**Files:**
- Create: `cmd/migrate-media/main.go`

**Interfaces:**
- Reaproveita `entities`, `persistence`, `services`. Conecta no banco com as mesmas envs do `cmd/api` (`DB_HOST/PORT/USER/PASS/NAME`).

- [ ] **Step 1: Implementar o comando**

`cmd/migrate-media/main.go` — flags `--dry-run` (default true) e `--apply`. Lógica:
1. Conecta no banco (copiar o trecho de conexão GORM do `cmd/api/main.go`).
2. Para cada entidade com URL (parks.imagem_url; spaces.imagem_url+2/3/4; reviews.midia_url; eventos.banner_url+capa_url; users.avatar_url; denuncia.fotos[]):
   - derivar `park_id` (regras da spec), montar `relDir` via `services.ResolveDir`, manter o nome do arquivo existente (ou renomear no padrão novo).
   - se `--apply`: `os.Rename` do arquivo físico de `uploads/<antigo>` para `uploads/<novo>`; `UPDATE` da coluna com a URL nova relativa; `INSERT` na `media` (entity_type, entity_id, park_id, file_path, mime inferido pela extensão, size via `os.Stat`).
   - se dry-run: só logar "moveria X → Y".
3. `denuncia.fotos`: converter URL absoluta (`https://.../api/v1/uploads/...`) para relativa.
4. Ao final, listar arquivos em `uploads/` (e raiz) sem dono identificado → se `--apply`, mover para `uploads/_quarantine/`.
5. Imprimir resumo: N movidos, N linhas media criadas, N em quarentena.

Estrutura mínima (cabeçalho real; preencher o corpo conforme acima):
```go
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/darkzinn11/parque/back/go-api/internal/domain/entities"
	"github.com/darkzinn11/parque/back/go-api/internal/application/services"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	apply := flag.Bool("apply", false, "executa de fato (default: dry-run)")
	flag.Parse()
	dryRun := !*apply

	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=true&loc=Local",
		os.Getenv("DB_USER"), os.Getenv("DB_PASS"), os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"), os.Getenv("DB_NAME"))
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("conexão: %v", err)
	}
	ctx := context.Background()
	base := "uploads"

	moved, linked, quarantined := 0, 0, 0

	// Exemplo para reviews; replicar o padrão para as demais entidades.
	var reviews []entities.Review
	db.Find(&reviews)
	for _, rv := range reviews {
		if rv.MidiaURL == "" {
			continue
		}
		pid := rv.ParkID
		relDir, derr := services.ResolveDir(services.EntityReview, &pid, nil)
		if derr != nil {
			log.Printf("review %d: %v", rv.ID, derr)
			continue
		}
		oldRel := strings.TrimPrefix(rv.MidiaURL, "/uploads/")
		oldRel = strings.TrimPrefix(oldRel, "/api/v1/uploads/")
		filename := filepath.Base(oldRel)
		newURL := services.RelURL(relDir, filename)
		oldAbs := filepath.Join(base, oldRel)
		newAbs := filepath.Join(base, relDir, filename)
		log.Printf("review %d: %s -> %s", rv.ID, rv.MidiaURL, newURL)
		if dryRun {
			continue
		}
		os.MkdirAll(filepath.Dir(newAbs), 0755)
		if err := os.Rename(oldAbs, newAbs); err != nil {
			log.Printf("  rename falhou: %v", err)
			continue
		}
		db.Model(&entities.Review{}).Where("id = ?", rv.ID).Update("midia_url", newURL)
		fi, _ := os.Stat(newAbs)
		var size int64
		if fi != nil {
			size = fi.Size()
		}
		eid := rv.ID
		db.Create(&entities.Media{
			EntityType: services.EntityReview, EntityID: &eid, ParkID: &pid,
			FilePath: newURL, Mime: mimeFromExt(filename), SizeBytes: size,
		})
		moved++
		linked++
	}

	// TODO operacional (não placeholder de código): replicar o bloco acima para
	// parks, spaces (4 urls), eventos (2 urls), users (avatar), denuncia (fotos json).
	// Em seguida varrer uploads/ por arquivos órfãos -> _quarantine.

	log.Printf("RESUMO: movidos=%d linhas_media=%d quarentena=%d (dryRun=%v)", moved, linked, quarantined, dryRun)
}

func mimeFromExt(name string) string {
	switch strings.ToLower(filepath.Ext(name)) {
	case ".png":
		return "image/png"
	case ".webp":
		return "image/webp"
	case ".gif":
		return "image/gif"
	default:
		return "image/jpeg"
	}
}
```
> Este comando lê dados de produção. Rodar **sempre** `--dry-run` primeiro e revisar o log. A execução real (`--apply`) em produção exige backup e confirmação humana (ver Task 11).

- [ ] **Step 2: Build**

Run: `go build ./cmd/migrate-media`
Expected: sem erros.

- [ ] **Step 3: Commit**

```bash
git add cmd/migrate-media/main.go
git commit -m "feat(media): comando migrate-media (dry-run por padrão)"
```

---

### Task 10: Comando de limpeza `cmd/cleanup-media`

**Files:**
- Create: `cmd/cleanup-media/main.go`

- [ ] **Step 1: Implementar**

`cmd/cleanup-media/main.go` — flag `--apply` (default dry-run). Lógica:
1. Conecta no banco (mesmo trecho).
2. Carrega todas as linhas `media` e todos os arquivos sob `uploads/` (exceto `_quarantine`).
3. **Linha-sem-dono**: para cada `media` com `entity_id` setado, verificar se a entidade ainda existe (por tipo). Se não: `--apply` → `os.Remove` do arquivo + soft-delete da linha.
4. **Arquivo-sem-linha**: arquivo no disco sem `media` com aquele `file_path`. `--apply` → mover para `uploads/_quarantine/`.
5. Resumo no log.

Cabeçalho idêntico ao `migrate-media` (flag, conexão, `dryRun := !*apply`). Corpo conforme acima.

- [ ] **Step 2: Build**

Run: `go build ./cmd/cleanup-media`
Expected: sem erros.

- [ ] **Step 3: Commit**

```bash
git add cmd/cleanup-media/main.go
git commit -m "feat(media): comando cleanup-media (órfãos, dry-run por padrão)"
```

---

### Task 11: Ajustes Flutter + Admin (URLs relativas e park_id)

**Files:**
- Modify: `/Users/sitwcomunicacaoemarketing/Documents/PARQUE/lib/screens/denuncie_screen.dart` (guardar URL relativa)
- Modify: tela de avaliação no Flutter que sobe mídia (enviar `park_id` no multipart de `/reviews/media`)
- Modify: PAINEL-PARK — exibição de fotos de denúncia (prefixar base à URL relativa); uploads do admin passam `entity_type`/`park_id` quando aplicável

- [ ] **Step 1: Flutter denúncia guarda relativo**

Em `denuncie_screen.dart`, trocar o retorno do upload para guardar o caminho **relativo** (`data['url']`) em vez de montar a URL absoluta. As telas que exibem (admin) passam a prefixar a base.

- [ ] **Step 2: Flutter review envia park_id**

Na tela de avaliação, adicionar o campo `park_id` ao `MultipartRequest` de upload de mídia (o parque já é conhecido no contexto da tela).

- [ ] **Step 3: Admin prefixa base na denúncia**

No PAINEL-PARK, onde a foto de denúncia é exibida, prefixar `API_BASE` à URL relativa (antes vinha absoluta pronta). (PAINEL-PARK não está no git; salvar localmente.)

- [ ] **Step 4: Build Flutter**

Run: `cd /Users/sitwcomunicacaoemarketing/Documents/PARQUE && flutter analyze`
Expected: 0 erros novos.

- [ ] **Step 5: Commit (Flutter)**

```bash
cd /Users/sitwcomunicacaoemarketing/Documents/PARQUE
git add lib/screens/denuncie_screen.dart lib/screens/park_detail_screen.dart
git commit -m "feat(media): denúncia guarda URL relativa + review envia park_id no upload"
```

---

## Checkpoint de produção (NÃO automatizar)

Depois de todo o código pronto e buildando:
1. Backup obrigatório: dump do banco + `tar` da pasta `uploads/` no VPS → `backups/`.
2. Deploy do backend (`deploy.sh`) — isso cria a tabela `media` e aplica o ALTER do avatar.
3. `migrate-media --dry-run` em produção, revisar o log inteiro.
4. **Confirmação humana explícita** antes de `migrate-media --apply`.
5. Verificar: app exibe imagens, raiz de `uploads/` limpa, linhas `media` populadas.
6. `cleanup-media --dry-run` para conferir o que sobrou em `_quarantine`.

## Self-review (cobertura da spec)

- Estrutura parque-first → Task 2 (ResolveDir).
- media ledger → Tasks 1, 4, 5, 7.
- 4 handlers unificados → Task 6.
- Vínculo no save + capa de parque novo → Task 7.
- avatar_url 512 → Task 8.
- Migração legados + denúncia absoluta→relativa + quarentena → Task 9.
- Limpeza de órfãos dry-run → Task 10.
- Impacto Flutter/Admin → Task 11.
- Backup + checkpoint humano → seção final.
