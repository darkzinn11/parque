# Notification Inbox — Design Spec
**Data:** 2026-06-05  
**Status:** Aprovado

## Objetivo

Tornar o botão de sino na home funcional: exibir um inbox de notificações persistido localmente, alimentado pelo FCM já configurado, com badge de não-lidas e controle de deleção pelo usuário.

---

## Modelo de Dados

### `AppNotification`

```dart
class AppNotification {
  final String id;        // UUID gerado localmente
  final String type;      // 'reservation_status' | 'event' | 'general'
  final String title;
  final String body;
  final String? deeplink; // rota GoRouter para navegação ao tocar
  final bool isRead;
  final DateTime createdAt;
}
```

**Persistência:** serializada como lista JSON na chave `app_notifications` do SharedPreferences (já dependência do projeto).  
**Limite:** máximo 50 notificações — ao adicionar a 51ª, a mais antiga é removida automaticamente.

---

## NotificationProvider

`ChangeNotifier` seguindo o padrão existente do app (Provider).

| Membro | Tipo | Descrição |
|---|---|---|
| `notifications` | `List<AppNotification>` | Lista ordenada, mais recente primeiro |
| `hasUnread` | `bool` | `true` se qualquer item tiver `isRead == false` |
| `add(n)` | método | Prepend + persiste + trim a 50 |
| `markAllRead()` | método | Marca todos como lidos + persiste |
| `delete(id)` | método | Remove por id + persiste |
| `clearAll()` | método | Limpa tudo + persiste |

Registrado no `MultiProvider` em `main.dart`.

---

## Integração com NotificationService

O `NotificationService` existente recebe o `NotificationProvider` via setter após o MultiProvider estar montado (evita dependência circular).

**Fluxo ao receber `RemoteMessage`:**
1. Extrair `title`, `body`, `data['type']`, `data['deeplink']`
2. Criar `AppNotification` com UUID + `createdAt = DateTime.now()`
3. Chamar `NotificationProvider.add(notification)`
4. Se app em **foreground**: exibir `AppToast` com o título
5. Se **tap na push** (background/terminated): navegar via `deeplink`

**Mapeamento de tipos:**

| `data['type']` | Ícone | Cor | Destino padrão |
|---|---|---|---|
| `reservation_status` | `Icons.calendar_today` | verde `#669340` | `/tabs/user/minhas-reservas` |
| `event` | `Icons.event` | laranja | deeplink do payload |
| `general` | `Icons.campaign` | cinza | sem navegação |

**Usuários não logados:** notificações `event` e `general` chegam via tópico `parque-todos` e são salvas normalmente. Notificações `reservation_status` chegam apenas via token FCM individual (registrado só após login) — o filtro é natural, sem lógica extra.

---

## UI

### Badge no sino (`_NotificationBell`)

- Envolvido em `Consumer<NotificationProvider>`
- Quando `hasUnread == true`: ponto vermelho de 8px no canto superior direito
- `onTap`: navega para `/tabs/home/notificacoes` + chama `markAllRead()`

### `NotificationsScreen`

**Rota:** `/tabs/home/notificacoes` (sub-rota de `/tabs/home` no `app_router.dart`)

**AppBar:**
- Título: "Notificações"
- Ação: botão "Limpar tudo" visível apenas quando a lista não está vazia

**Lista:**
- Ordem: mais recente no topo
- Item não-lido: fundo levemente destacado (`#F5F7EB`)
- Item lido: fundo branco padrão
- Swipe para esquerda: deleta com `Dismissible`
- Tap: navega para `deeplink` (se não nulo)

**Card de notificação:**
- Ícone colorido por tipo (esquerda)
- Título em bold + corpo em cinza (centro)
- Tempo relativo no canto superior direito: `< 60min` → "há Xmin" · `< 24h` → "há Xh" · ontem → "ontem" · mais antigo → "dd/MM"

**Estado vazio:**
- Ícone `Icons.notifications_none` centralizado
- Texto: "Nenhuma notificação ainda"

**Ao montar a tela:** `provider.markAllRead()` é chamado — o ponto vermelho some.

---

## Arquivos a criar/modificar

| Ação | Arquivo |
|---|---|
| Criar | `lib/data/models/app_notification.dart` |
| Criar | `lib/providers/notification_provider.dart` |
| Criar | `lib/screens/notifications_screen.dart` |
| Modificar | `lib/services/notification_service.dart` |
| Modificar | `lib/screens/home_screen.dart` (bell badge + onTap) |
| Modificar | `lib/routes/app_router.dart` (nova rota) |
| Modificar | `lib/main.dart` (registrar NotificationProvider) |
