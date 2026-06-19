# Spec: 8 Correções — Android + Bugs de Produto

**Data:** 2026-06-18  
**Escopo:** Flutter (app) + Backend Go (PARQUE-BACK)  
**Status:** Aprovada — pronta para implementação

---

## Visão geral

Correções identificadas por revisão de engenheiro sênior testando no Android real. 8 itens divididos em backend Go (2) e Flutter (6).

---

## Item 1 — Notificação push para participantes quando reserva aprovada

### Problema
Quando o gestor aprova uma reserva, apenas o responsável (líder) recebe push. Os participantes listados na reserva não recebem nenhuma notificação, mesmo que tenham conta no app.

### Solução

**Backend — nova interface de repositório**

Adicionar à interface `UserRepository` (`internal/domain/repositories/user_repository.go`):

```go
GetByListOfCPF(ctx context.Context, cpfs []string) ([]entities.User, error)
```

**Backend — implementação MySQL** (`mysql_user_repository.go`)

Query: `SELECT * FROM users WHERE cpf IN (?,?,...)` usando `sqlx.In` ou expansão manual do placeholder. Retorna apenas os usuários encontrados (os CPFs sem conta são simplesmente ignorados).

**Backend — use case** (`reservation_usecase.go` → `notifyStatusChange`)

Quando `status == StatusAprovada`:
1. Extrair slice de CPFs dos `res.Participants`
2. Chamar `userRepo.GetByListOfCPF(ctx, cpfs)`
3. Para cada `user` retornado, disparar `notifier.SendToUser` best-effort
4. Falha de push individual não bloqueia os demais nem o fluxo de aprovação

**Conteúdo da notificação para participante:**
- Título: `"Você tem uma reserva confirmada! ✓"`
- Corpo: `"[NomeResponsável] confirmou sua participação em [Espaço] no dia [DD/MM]."`
- Deeplink: `/tabs/user/minhas-reservas` (para o participante ver próprias reservas, não a reserva alheia)
- `data["type"]`: `"participant_reservation_confirmed"`

**Comportamento:** best-effort silencioso. Participante sem conta → CPF não aparece no retorno do `GetByListOfCPF` → sem notificação, sem erro.

---

## Item 2 — CPF único no cadastro

### Problema
Múltiplos usuários podem se cadastrar com o mesmo CPF porque não há constraint de unicidade nem checagem na aplicação.

### Solução em três camadas

**Camada 1 — Banco de dados (backstop)**

Adicionar na migration/init SQL que roda no boot:
```sql
ALTER TABLE users ADD UNIQUE INDEX idx_users_cpf (cpf);
```
Executado via `CREATE UNIQUE INDEX IF NOT EXISTS` para ser idempotente. Esta camada previne race conditions de cadastros simultâneos.

**Camada 2 — Repositório (tradução do erro DB)**

Em `mysql_user_repository.go` → `Create()`: capturar o erro MySQL 1062 (duplicate entry) especificamente para a chave `idx_users_cpf` e retornar `ErrCPFAlreadyExists`. Isso evita vazar erros de banco brutos.

**Camada 3 — Use case (UX amigável)**

Adicionar à interface `UserRepository`:
```go
GetByCPF(ctx context.Context, cpf string) (*entities.User, error)
```

Em `user_auth_usecase.go` → `Register()`, após normalizar o CPF, antes de `Create()`:
```go
existing, _ := uc.repo.GetByCPF(ctx, cpf)
if existing != nil {
    return nil, ErrCPFAlreadyExists
}
```

A camada 3 resolve 99,9% dos casos com uma mensagem clara. A camada 1+2 protege o 0,1% de race condition.

**Erro retornado ao Flutter:** HTTP 409 com `{"error": "CPF já cadastrado"}` — já tratado no handler.

---

## Item 3 — Botão Caminhada com texto extravasando em telas pequenas

### Problema
O segmented control na `AtividadeScreen` usa `Expanded` para cada tab, mas o texto `"Caminhada"` (o mais longo) não tem tratamento de overflow. Em telas pequenas (~360px de largura), o conteúdo do chip selecionado — que tem shadow e background branco — extravasa visualmente.

### Solução

No widget `_HeroSection`, no `Text` dentro do `AnimatedContainer` de cada tab:

```dart
Text(
  typeLabels[i],
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(
    fontSize: 12, // reduzido de 13
    fontWeight: ...,
    color: ...,
  ),
),
```

Reduzir `fontSize` de 13 → 12 dá margem suficiente para "Caminhada" sem truncar em nenhum dispositivo com largura ≥ 320px.

---

## Item 4 — Bottom bar sem respiro em telas pequenas

### Problema
A bottom bar tem altura fixa `64px`. Em telas compactas (width < 380px), o conjunto ícone + label de cada aba fica sem padding lateral adequado, e a pill deslizante ocupa 70% da largura do tab, deixando muito pouco espaço visual.

### Solução

Em `app_router.dart` → `_TabScaffoldState`:

```dart
// Responsivo: 56px em telas compactas, 60px em telas normais
final barHeight = MediaQuery.of(context).size.width < 380 ? 56.0 : 60.0;
```

```dart
SizedBox(
  height: barHeight,
  child: _SlidingTabBar(barHeight: barHeight, ...),
)
```

No `_SlidingTabBar`, usar `barHeight` para calcular a pill e passar para os itens:

- Pill: `height: barHeight - 12` (era 52, passa a ser dinâmico)
- Label `fontSize`: `10` em telas compactas, `11` em telas normais
- Ícone `size`: `22` em telas compactas, `24` em telas normais

---

## Item 5 — Expandir foto dos espaços ao tocar

### Problema
As fotos dos espaços na seção "Descubra mais sobre o parque" (`_SpaceCard`) não respondem ao toque. O usuário não tem como ver a foto em detalhe.

### Solução

Envolver o `ClipRRect` da imagem em `_SpaceCard` com `GestureDetector`:

```dart
GestureDetector(
  onTap: () => _showFullImage(context, imgUrl, space.name),
  child: ClipRRect(...),
)
```

Função `_showFullImage` abre `showDialog` com:
```dart
Dialog(
  backgroundColor: Colors.transparent,
  child: Stack(children: [
    InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 4.0,
      child: CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.contain),
    ),
    Positioned(
      top: 8, right: 8,
      child: CircleButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
    ),
  ]),
)
```

Fundo do diálogo: `Colors.black.withOpacity(0.85)`. Usuário fecha tocando no X ou fora do diálogo (`barrierDismissible: true`).

---

## Item 6 — Redesign do card de foto na avaliação

### Problema
O campo de foto em `_AddReviewBottomSheet` é um `OutlinedButton.icon` simples e pequeno que fica fora do padrão visual do app e não comunica bem que é uma área de upload.

### Solução

Substituir o `OutlinedButton.icon` por um container de upload estilo DenuncieScreen:

**Estado vazio (sem foto selecionada):**
```
┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
│                                         │
│         [ícone câmera 32px]             │
│      Toque para adicionar foto          │  ← fontSize 13, cor cinza
│           (opcional)                    │
│                                         │
└─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
```
Container com `border: Border.all(color: Color(0xFFD0D5DD), width: 1.5)`, `borderRadius: 12`, `strokeDashArray` simulado via padding e cor tracejada (usando `CustomPainter` com `dashPattern` ou simplesmente border sólida fina na cor `0xFFD0D5DD` — preferir sólida para simplicidade).

**Estado com foto selecionada:**
```
┌──────────────────────────────────────┐
│  [thumbnail 80x80]  Foto pronta ✓   │
│       [X]           ou "Enviando..." │
└──────────────────────────────────────┘
```
Row com thumbnail + indicador de status + botão de remover. Igual ao padrão existente mas dentro de um container com background `Color(0xFFF9FAE8)` e border verde `kBrandGreen`.

**Estado carregando:** overlay escuro 35% sobre o thumbnail + `CircularProgressIndicator` branco.

---

## Item 7 — Botão "Enviar avaliação" coberto pela nav bar Android

### Problema
O `_AddReviewBottomSheet` usa `padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + viewInsets.bottom)`. O `viewInsets.bottom` é o teclado. A safe area do Android (barra de navegação gestual ou botões) fica em `MediaQuery.padding.bottom` e não está sendo somada. Resultado: botão fica atrás da nav bar nativa.

### Solução

```dart
final bottomInset = MediaQuery.of(context).viewInsets.bottom;
final bottomSafe = MediaQuery.of(context).padding.bottom;

Container(
  padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset + bottomSafe),
  ...
)
```

Adicionar também `useSafeArea: true` na chamada `showModalBottomSheet` em `_showAddReviewBottomSheet()`. Isso garante que o sheet em si não fique sob a barra gestural antes mesmo de renderizar.

---

## Item 8 — Toast com sublinhado amarelo

### Problema
O `AppToast` renderiza via `OverlayEntry`. Fora da árvore Material normal, o Flutter aplica o `DefaultTextStyle` raiz que tem `decoration: TextDecoration.underline` com cor amarela (herança do estilo de texto HTML padrão). Resultado: toda mensagem de toast aparece sublinhada em amarelo.

### Solução

No `_ToastCard`, no `GoogleFonts.poppins()` do `Text`:

```dart
style: GoogleFonts.poppins(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: cfg.textColor,
  height: 1.35,
  decoration: TextDecoration.none, // ← adicionar
),
```

Uma linha. Resolve completamente.

---

---

## Item 9 — Race condition em solicitações de evento (mesmo espaço/data/horário)

### Problema
Múltiplos usuários podem solicitar eventos no mesmo espaço, data e horário simultaneamente. Sem verificação na aprovação, o admin poderia aprovar dois eventos conflitantes para o mesmo slot.

**Reservas já estão protegidas** (`CreateIfNoConflict` com `SELECT FOR UPDATE`). Esse item cobre apenas eventos.

### Comportamento definido

**Na criação:** sem bloqueio — múltiplas solicitações pendentes para o mesmo slot podem coexistir na fila do admin. O admin vê todas e decide.

**Na aprovação (atômica):**
1. Verificar se já existe evento com status `Aprovado` para o mesmo `space_id` + `data_evento` com horário sobreposto → retornar `ErrSlotAlreadyBooked` se houver
2. Se livre: aprovar a solicitação
3. Buscar todas as demais solicitações com status `Pendente` para o mesmo `space_id` + `data_evento` com horário sobreposto → rejeitar automaticamente com `motivo_rejeicao = "Horário ocupado por outra solicitação aprovada"`
4. Tudo em uma única transação MySQL — elimina race condition entre dois admins aprovando simultaneamente

### Definição de sobreposição de horários
Dois intervalos `[A_inicio, A_fim)` e `[B_inicio, B_fim)` se sobrepõem quando: `A_inicio < B_fim AND A_fim > B_inicio`

### Mudanças no backend

**Repositório de eventos** — novo método na interface `EventRequestRepository`:
```go
GetConflicting(ctx context.Context, spaceID uint, date, horaInicio, horaFim string, excludeID uint) ([]entities.EventRequest, error)
```
Query: `WHERE space_id = ? AND data_evento = ? AND hora_inicio < ? AND hora_fim > ? AND id != ? AND status IN ('Pendente', 'Aprovado')`

**Use case** — novo método `ApproveEventRequest(ctx, id, adminID)`:
- Abre transação
- Busca a solicitação e valida ownership/permissão
- Chama `GetConflicting` filtrando só `Aprovado` — se retornar resultados: rollback + `ErrSlotAlreadyBooked`
- Atualiza status para `Aprovado`
- Chama `GetConflicting` filtrando só `Pendente` — para cada um, `UpdateStatus(id, Rejeitado, motivo)`
- Commit

**Handler admin** — `ApproveEventRequest` no handler HTTP, retorna HTTP 409 para `ErrSlotAlreadyBooked` com mensagem `"Este horário já foi ocupado por outra solicitação aprovada"`.

### Mudanças no Flutter / Admin Panel
- **Admin Panel React:** ao receber HTTP 409 na aprovação, mostrar toast de erro com a mensagem do backend — nenhuma outra mudança necessária
- **Flutter:** nenhuma mudança — o usuário recebe notificação de rejeição automática pelo fluxo FCM existente

---

## Impacto e dependências

| Item | Arquivo(s) | Escopo | Dependência |
|------|-----------|--------|-------------|
| 1 | `reservation_usecase.go`, `user_repository.go`, `mysql_user_repository.go` | Backend | Adiciona `GetByListOfCPF` ao mesmo arquivo de interface/impl do item 2 |
| 2 | `user_auth_usecase.go`, `user_repository.go`, `mysql_user_repository.go`, migration SQL | Backend | Adiciona `GetByCPF`; ambos itens mexem nos mesmos arquivos de repositório |
| 3 | `atividade_screen.dart` | Flutter | — |
| 4 | `app_router.dart` | Flutter | — |
| 5 | `park_detail_screen.dart` | Flutter | — |
| 6 | `park_detail_screen.dart` | Flutter | — |
| 7 | `park_detail_screen.dart` | Flutter | — |
| 8 | `app_toast.dart` | Flutter | — |
| 9 | `event_request_repository.go` (interface + mysql), use case eventos, handler admin | Backend | — |

**Ordem de implementação recomendada:**
1. Backend: items 2 → 1 → 9 (CPF único → notif participantes → race condition eventos) — deploy único
2. Flutter: item 8 (toast, 1 linha) → item 7 (safe area) → item 3 e 4 (UI responsivo) → items 5 e 6 (features visuais) → item 1 Flutter side (validação participantes)

**Sem novos pacotes:** todos os itens Flutter usam o que já está no `pubspec.yaml`.
