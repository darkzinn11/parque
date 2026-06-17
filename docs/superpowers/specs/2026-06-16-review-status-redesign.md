# Spec — Redesign do Sistema de Status de Avaliações

**Data:** 2026-06-16  
**Escopo:** Backend Go + Admin React + Flutter

---

## Problema

O sistema atual tem 6 status (`Pendente`, `Aprovada`, `Rejeitada`, `Publicada`, `Denunciada`, `Ocultada`) com semântica sobreposta:
- `Aprovada` e `Publicada` fazem a mesma coisa
- `Ocultada` é redundante com `Rejeitada`
- `Denunciada` não tem papel aqui — denúncias têm sistema próprio no app

---

## Solução: 3 status

| Status | Significado |
|---|---|
| `Pendente` | Enviada pelo usuário, aguardando moderação |
| `Publicada` | Aprovada pelo gestor, visível a todos |
| `Rejeitada` | Recusada pelo gestor, não visível ao público |

### Transições permitidas
```
Pendente → Publicada   (gestor aprova)
Pendente → Rejeitada   (gestor rejeita)
Rejeitada → Publicada  (gestor reverte decisão)
Publicada → Rejeitada  (gestor remove publicação)
```

---

## Comportamento por perfil

### Usuário comum (público)
- Vê apenas avaliações com status `Publicada` no detalhe do parque

### Autor da avaliação
- Sempre vê a própria avaliação, independente do status
- **Nenhum badge ou indicador de status é exibido** — ele acredita que a avaliação já está visível para todos (shadow moderation)
- Se rejeitada, continua aparecendo para ele normalmente

### Admin / Gestor
- Vê todas as avaliações com status real
- Ações disponíveis: "Publicar" e "Rejeitar" (sem dropdown de status livre)

---

## Backend Go

### Endpoints afetados

**`GET /parks/:id/reviews`** (público)  
Filtrar: `WHERE status = 'Publicada'`  
Atualmente retorna tudo — corrigir.

**`GET /parks/:id/reviews/mine`** (autenticado)  
Retorna a avaliação do próprio usuário independente do status.  
Comportamento atual está correto — manter.

**`PUT /admin/reviews/:id`** (admin)  
Aceitar apenas `{ "status": "Publicada" }` ou `{ "status": "Rejeitada" }`.  
Rejeitar qualquer outro valor com 400.

### Migration de dados
Executar ao subir o novo deploy:
```sql
UPDATE reviews SET status = 'Publicada' WHERE status = 'Aprovada';
UPDATE reviews SET status = 'Rejeitada' WHERE status = 'Ocultada';
UPDATE reviews SET status = 'Publicada' WHERE status = 'Denunciada';
```

---

## Admin React (ReviewsManagement)

### Filtro de status
Remover: `Aprovada`, `Denunciada`, `Ocultada`  
Manter: `Todos os Status`, `Pendente`, `Publicada`, `Rejeitada`

### Ações por card
Substituir o dropdown de status livre por dois botões explícitos:
- **"Publicar"** — verde, só aparece se status ≠ `Publicada`
- **"Rejeitar"** — vermelho/outline, só aparece se status ≠ `Rejeitada`

### Métricas
- Remover card "Avaliações ocultadas"
- "Pendentes de moderação" = `Pendente`
- "Denunciadas" = remover
- Manter: Total, Média geral, Pendentes, Parques avaliados

### Interface de edição
Remover o `<select>` de status do modal de edição.  
Ações de mudança de status acontecem apenas pelos botões Publicar/Rejeitar.

---

## Flutter

### park_detail_screen.dart

A tela carrega dois endpoints em paralelo:
1. `GET /parks/:id/reviews` → reviews públicas (`Publicada`)
2. `GET /parks/:id/reviews/mine` → avaliação do próprio usuário (qualquer status)

Mescla as duas listas deduplicando por `review.id`. Se o usuário tem avaliação própria e ela já é `Publicada`, ela aparece uma única vez (via lista pública).

**Nenhum indicador de status** é exibido na review do usuário. Campo `isRejected` no modelo pode ser removido ou mantido como dead code — não impacta a UI.

### Review model
- Remover ou ignorar o campo `isRejected` na exibição
- `displayName` e demais campos: sem alteração

---

## Spec self-review

- Sem TBDs ou seções incompletas
- Migration cobre todos os status legados
- Comportamento do autor está consistente em backend e Flutter
- Escopo limitado: não toca no fluxo de denúncias, reservas ou eventos
