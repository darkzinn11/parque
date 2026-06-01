# Review Draft Mode — Design Spec
**Data:** 2026-06-01  
**Status:** Aprovado

---

## Contexto

Os gestores do app Vem Pro Parque precisam moderar avaliações antes de publicá-las. O objetivo é evitar avaliações maliciosas ou inadequadas, mantendo o controle editorial. O usuário deve ver sua própria avaliação imediatamente após enviar, mas outros usuários só a veem após aprovação no painel admin.

---

## Abordagem escolhida — B (dois endpoints separados)

- `GET /parks/:id/reviews` → público, retorna só `Aprovada`
- `GET /parks/:id/reviews/mine` → autenticado, retorna reviews do usuário (todos os status)
- Flutter busca os dois quando logado e mescla no cliente

---

## Seção 1 — Backend (Go / PARQUE-BACK)

### 1.1 Entidade Review

Adicionar campo `Status` à struct `Review` em `internal/domain/entities/collections.go`:

```go
Status string `json:"status" gorm:"default:'Pendente'"`
```

Estados válidos: `Pendente` | `Aprovada` | `Rejeitada` | `Ocultada` | `Denunciada`

### 1.2 Migration de dados existentes

Rodar UPDATE via GORM após AutoMigrate para que dados antigos não quebrem:

```go
db.Exec("UPDATE reviews SET status = 'Aprovada' WHERE status = '' OR status IS NULL")
```

### 1.3 Endpoints

| Método | Rota | Auth | Comportamento |
|--------|------|------|---------------|
| `POST` | `/reviews` | User | Força `Status = "Pendente"` — ignora status enviado no body |
| `GET` | `/parks/:id/reviews` | Público | `WHERE status = 'Aprovada'` |
| `GET` | `/parks/:id/reviews/mine` | User | Reviews do `user_id` extraído do token, todos os status |
| `PUT` | `/admin/reviews/:id` | Admin | Aceita campo `status` no body — persiste normalmente |

### 1.4 Validação de unicidade

Antes de criar, verificar se o usuário já tem review para o parque:

```go
existing, _ := repo.GetByUserAndPark(ctx, userID, parkID)
if existing != nil {
    return errors.New("você já enviou uma avaliação para este parque")
}
```

Retorno HTTP: `409 Conflict` com `{ "error": "você já enviou uma avaliação para este parque" }`.

### 1.5 Repositório — novos métodos necessários

- `GetByUserAndPark(ctx, userID, parkID uint) (*Review, error)`
- `ListByParkIDAndUserID(ctx, parkID, userID uint) ([]Review, error)`

---

## Seção 2 — Painel Admin (React / PAINEL-PARK)

### 2.1 Botões de ação rápida na tabela

Substituir "Responder" + "More" por botões contextuais:

| Ação | Condição de exibição | Payload |
|------|---------------------|---------|
| Aprovar (verde) | `status === 'Pendente'` | `{ status: 'Aprovada' }` |
| Rejeitar (vermelho) | `status === 'Pendente'` | `{ status: 'Rejeitada' }` |
| Ocultar (cinza) | `status === 'Aprovada'` | `{ status: 'Ocultada' }` |
| Editar (outline) | sempre | abre modal |

Chamam `PUT /admin/reviews/:id` via mutation do react-query com invalidação automática da query `['reviews']`.

### 2.2 Modal de edição

Adicionar campo `status` ao `ReviewPayload` e ao formulário:

```tsx
interface ReviewPayload {
  titulo: string;
  rating: number;
  texto: string;
  midia_url: string;
  park_id: number;
  status: string; // novo
}
```

Dropdown com as 5 opções no modal existente.

### 2.3 Ordenação padrão

Reviews com `status === 'Pendente'` aparecem primeiro na tabela por padrão, sem necessidade de filtrar manualmente.

### 2.4 Sem notificação ao usuário

Gestores aprovam/rejeitam silenciosamente. Não há e-mail, push ou outra notificação ao autor.

---

## Seção 3 — Flutter App

### 3.1 Model `Review`

```dart
class Review {
  // campos existentes...
  final String status;
}

// fromMap:
status: map['status'] ?? 'Aprovada',
```

### 3.2 `ReviewsRepository` — novos métodos

```dart
abstract class ReviewsRepository {
  Future<List<Review>> fetchForPark(int parkId);    // existente — só Aprovadas
  Future<List<Review>> fetchMineForPark(int parkId); // novo — GET /parks/:id/reviews/mine
  Future<Review?> createReview({...});               // existente
}
```

### 3.3 Lógica de exibição em `ParkDetailScreen`

Quando usuário está logado:
1. Busca `fetchForPark` (aprovadas)
2. Busca `fetchMineForPark` (próprias)
3. Mescla: remove duplicatas por ID, insere próprias pendentes/rejeitadas no topo

Quando não logado:
- Busca só `fetchForPark`

### 3.4 Badge por status na UI

| Status | Badge | Cor |
|--------|-------|-----|
| `Pendente` | ⏳ Em análise | Âmbar |
| `Rejeitada` | ✕ Não publicada | Cinza |
| `Aprovada` | — (sem badge) | — |

Badge exibido só para o próprio autor (reviews retornadas por `fetchMineForPark`).

### 3.5 Botão "Avaliar este parque"

- Oculto se usuário já tem review com `status = 'Pendente'` ou `'Aprovada'` para o parque
- Visível se `status = 'Rejeitada'` (pode reenviar) ou se não tem review

### 3.6 Toast após envio

Texto atual: `"Avaliação enviada com sucesso!"`  
Texto novo: `"Avaliação enviada! Ela será publicada após análise."`  
Tipo: `ToastType.success`

### 3.7 Fluxo completo do usuário

```
Usuário envia review
  → Backend salva com Status = "Pendente"
  → Flutter exibe no topo da lista com badge "Em análise"
  → Botão "Avaliar" some

Gestor abre painel admin
  → Vê review na fila com badge "Pendente"
  → Clica "Aprovar"
  → Backend atualiza Status = "Aprovada"

Outros usuários
  → Veem a review normalmente (sem badge)
  
Usuário autor
  → Badge desaparece, review fica visível como normal
```

---

## Arquivos a modificar

### Backend (via Antigravity)
- `internal/domain/entities/collections.go` — campo Status
- `internal/domain/repositories/review_repository.go` — 2 novos métodos
- `internal/application/usecases/review_usecase.go` — validação unicidade + ListByParkIDAndUserID
- `internal/infrastructure/persistence/mysql_review_repository.go` — implementação
- `internal/infrastructure/http/handlers/review_handler.go` — novo handler `/mine`, forçar Pendente no Create
- `cmd/api/main.go` — registrar rota `/parks/:id/reviews/mine`

### Painel Admin (PAINEL-PARK)
- `src/pages/ReviewsManagement/ReviewsManagement.tsx` — botões, modal, ordenação

### Flutter App (PARQUE)
- `lib/data/models/review.dart` — campo status
- `lib/data/reviews_repository.dart` — método fetchMineForPark
- `lib/data/repositories/go_reviews_repository.dart` — implementação
- `lib/screens/park_detail_screen.dart` — lógica de merge, badge, botão condicional
