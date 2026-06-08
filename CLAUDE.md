# Vem Pro Parque — Flutter App

## Stack
- Flutter 3 + Dart, Provider (sem Riverpod), GoRouter
- Design system: verde `#669340`, fonte Poppins, Material 3
- ApiClient centralizado: `lib/core/api/api_client.dart`
- Backend base URL: `https://apps.sitw.com.br/backend-park/api/v1`

## Projetos relacionados
- **Backend Go** — `/Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK`
- **Admin Panel React** — `/Users/sitwcomunicacaoemarketing/Desktop/PAINEL-PARK`

## Estrutura de pastas relevante
```
lib/
  core/
    api/            — ApiClient, ApiConfig
    formatters.dart — CpfFormatter, PhoneFormatter, CepFormatter (compartilhados)
  data/
    models/         — Park, Review, Space, Reservation, Participant, AppEvent, AppNotification
    repositories/   — go_park_repository, go_reviews_repository, go_reservation_repository, etc.
  providers/
    notification_provider.dart — ChangeNotifier para inbox de notificações (SharedPreferences)
  screens/
    user/           — login, cadastro, perfil, senha, preferências, user_entry_screen,
                      verificar_codigo_screen, nova_senha_screen
    reservations/   — park_selection, spaces_catalog, space_detail, booking_calendar,
                      reservation_form, my_reservations
    notifications_screen.dart — inbox de notificações FCM
    denuncie_screen.dart      — formulário de denúncia com CEP API + fotos
  services/
    auth_service.dart         — JWT em FlutterSecureStorage, loginWithToken()
    notification_service.dart — FCM + salva no NotificationProvider
    cep_service.dart          — ViaCEP sem dependência nova (timeout 8s)
    favorites, parks, run_tracker
  widgets/
    app_toast.dart                    — toast estilo Duolingo
    favorite_button.dart              — animação Lottie
    login_required.dart               — guard para telas protegidas
    password_strength_indicator.dart  — barra força + checklist de regras
  routes/
    app_router.dart — bottom bar com pill deslizante + todas as rotas
docs/
  superpowers/specs/ — specs de design aprovadas
```

## Arquitetura de autenticação
- `UserEntryScreen` é a raiz da aba "Usuário" — usa `Consumer<AuthService>` para alternar entre `LoginScreen` e `UserScreen` automaticamente
- `LoginScreen` tem dois modos: (1) dentro de `UserEntryScreen` — `onLogged` callback; (2) via rota GoRouter — após login faz `context.go('/tabs/user')`
- Guard no botão Reservas: usuário não logado é redirecionado para `/tabs/user/login`
- Recuperação de senha: `/verificar-codigo` → `/nova-senha` → login automático com JWT

## Regras de senha (obrigatórias — app de governo)
- Mínimo 8 caracteres, máximo 72 (limite bcrypt)
- Pelo menos 1 maiúscula, 1 número, 1 caractere especial
- `PasswordRules.validate()` centraliza a validação (`lib/widgets/password_strength_indicator.dart`)
- Aplicado em: RegisterScreen, ChangePasswordScreen, NovaSenhaScreen

## Sistema de notificações (inbox)
- `NotificationProvider` + SharedPreferences (máx 50, lazy até 50 itens)
- FCM recebido → salvo no inbox → ponto vermelho no sino da home
- Sino abre `NotificationsScreen` (`/tabs/home/notificacoes`)
- Funciona para não-logados (broadcasts `parque-todos`) e logados (reservas)
- `WidgetsBindingObserver` na PreferenciasScreen: atualiza status de permissão ao voltar do SO

## Estado atual do sistema de reservas (implementado)
- Fluxo: Home → seleção de parque → espaços → calendário (semana atual) → formulário → "Minhas reservas"
- Regras: 1 reserva ativa por CPF, duração fixa 2h, aprovação pelo gestor
- Rejeição: gestor informa motivo (obrigatório) → usuário tem 2h para editar e reenviar
- Cancelamento: usuário pode cancelar Pendente/Aprovada antes do dia da reserva
- Push FCM: graceful degradation (funciona sem config Firebase; ativa ao plugar credenciais)
- `Space` é a única entidade para lugares físicos (unificou map_points + spaces)
- `my_reservations_screen.dart`: tabs Atuais / Histórico + paginação "ver mais" (5 itens/página)
- Race condition eliminada no backend: `CreateIfNoConflict` com `SELECT FOR UPDATE` em transaction
- Rejeição atômica: `UpdateStatusWithMotivo` atualiza status + motivo em query única (sem janela de falha parcial)
- ListAll admin com paginação: `?page=1&page_size=100` (default 100, cap 500) + header `X-Total-Count`

## Sistema de denúncias (implementado)
- Flutter: `DenuncieScreen` com CEP auto-fill, fotos comprimidas (1280px, 75% JPEG), dados do usuário logado pré-preenchidos
- Backend: entidade `Denuncia`, status Nova/Em Análise/Resolvida/Arquivada, upload público `/denuncias/upload`
- Admin: página `DenunciasManagement` com tabela, filtros, modal + badge na sidebar
- Email: NÃO usa email, dados apenas no painel admin

## Segurança — autenticação
- JWT expira em **30 dias** (não 365)
- Rate limit: **10 tentativas/min por IP** em `/login`, `/forgot-password`, `/register`, `/denuncias/upload`
- Senha validada no backend: `min=8` (alinhado com Flutter)
- CPF validado no backend: exatamente 11 dígitos (strip de máscara antes de validar)
- Telefone validado no backend: 10–11 dígitos (strip de máscara)
- `/forgot-password` sempre retorna 200 (não revela se email existe)
- `me()` faz logout automático ao receber 401 (JWT expirado)

## API de CEP (ViaCEP)
- `lib/services/cep_service.dart` — `CepService.fetch(cep)` → `CepResult?`
- Race condition protegida por contador de sequência (`_cepSeq`) — descarta respostas obsoletas
- Usado em: RegisterScreen (preenche cidade) e DenuncieScreen (preenche rua/bairro e cidade da ocorrência)

## Recuperação de senha (implementado)
- Fluxo: "Esqueci" → POST `/forgot-password` → `VerificarCodigoScreen` (6 campos OTP, cooldown 60s) → `NovaSenhaScreen` → login automático
- Backend: `PasswordResetToken` (15min, 3 tentativas, 3 req/hora), email via Resend (fallback Brevo via `EMAIL_PROVIDER` env)
- Variáveis de ambiente necessárias: `EMAIL_PROVIDER`, `RESEND_API_KEY`, `EMAIL_FROM`

## Push Notifications FCM — configuração completa
- Firebase projeto: `vem-pro-parque-16f7e`, bundle `com.vemproparquema`
- `GoogleService-Info.plist` presente em `ios/Runner/` ✅
- APNs Auth Key (`SMHXVK22HF`, Team `XRLM248224`) cadastrada no Firebase Console (dev + prod) ✅
- `firebase-credentials.json` no VPS em `/home/wwsitw/apps/backend-park/` ✅
- Backend Go: `FIREBASE_CREDENTIALS_FILE` aponta para esse arquivo no `.env`
- App: capability **Push Notifications** deve estar no Xcode → Signing & Capabilities (confirmar entitlement `aps-environment`)
- Fluxo: login → `saveTokenAfterLogin()` → `POST /me/fcm-token` → salvo na tabela `fcm_tokens`
- Backend envia push em: aprovação, rejeição (com motivo + deeplink editar) e cancelamento pelo gestor
- Para verificar token no banco: `SELECT user_id, platform, updated_at FROM fcm_tokens ORDER BY updated_at DESC LIMIT 5;`
- Para verificar FCM no backend: `journalctl -u backend-park -n 100 | grep FCM`

## Pendências que dependem de ação humana
1. **TestFlight push notifications**: adicionar capability "Push Notifications" no Xcode → Archive → nova build TestFlight → instalar → logar → aceitar permissão
2. **Resend**: criar conta em resend.com, verificar domínio, adicionar `RESEND_API_KEY` e `EMAIL_FROM` no `.env` do backend
3. **PAINEL-PARK**: não está no git — arquivos salvos localmente mas sem versionamento
4. **Deploy**: rodar `deploy.sh` no PARQUE-BACK para subir novas features ao servidor
5. **Email Brevo**: migrado para SMTP — variáveis necessárias: `BREVO_SMTP_LOGIN`, `BREVO_SMTP_PASSWORD`, `EMAIL_FROM`

## Componentes globais importantes
- `AppToast` (`lib/widgets/app_toast.dart`) — toast estilo Duolingo, usar em vez de SnackBar
- `FavoriteButton` (`lib/widgets/favorite_button.dart`) — animação Lottie
- `LoginRequired` (`lib/widgets/login_required.dart`) — guard para telas protegidas
- `PasswordStrengthIndicator` (`lib/widgets/password_strength_indicator.dart`) — barra + checklist
- `CepService` (`lib/services/cep_service.dart`) — ViaCEP, race-condition safe
- `CpfFormatter`, `PhoneFormatter`, `CepFormatter` (`lib/core/formatters.dart`) — compartilhados
- Bottom bar com pill deslizante — implementada em `lib/routes/app_router.dart`

## Padrão AppBar (OBRIGATÓRIO em todas as telas)
```dart
AppBar(
  backgroundColor: Colors.white,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios_new, color: kGreen), // SEM size
    onPressed: () => context.pop(),
  ),
  centerTitle: true,
  title: Text('Título', style: GoogleFonts.poppins(
    color: kGreen, fontSize: 20, fontWeight: FontWeight.w700)),
)
```

## Padrão de cards (listas e formulários)
- Background: `Color(0xFFF9FAE8)` (reservas) ou `Colors.white` com sombra suave (denúncias)
- `borderRadius: BorderRadius.circular(16)`
- `padding: EdgeInsets.all(16)`
- Separador entre cards: `SizedBox(height: 12 ou 16)` — NÃO usar Divider entre cards

## Estrutura do backend Go (PARQUE-BACK) — repositórios
Todos os repositórios ficam em `internal/infrastructure/persistence/` com prefixo `mysql_`:
- `mysql_reservation_repository.go` — inclui `CreateIfNoConflict`, `UpdateStatusWithMotivo`, paginação
- `mysql_favorite_repository.go` — movido de `database/gorm/` para cá (2026-06-08)
- `mysql_fcm_token_repository.go`, `mysql_park_repository.go`, `mysql_user_repository.go`, etc.

Email Brevo: usa SMTP em vez de REST API (`smtp-relay.brevo.com:587`).

---

## Histórico de mudanças

### 2026-06-08 (fix: diagnóstico completo — BACK-01/04/07/08/11/12 + FLUTTER-01/02)

**Backend (PARQUE-BACK):**
- **BACK-01**: Race condition eliminada — `CreateIfNoConflict` com `SELECT FOR UPDATE` em transaction
- **BACK-04**: Rate limit estendido para `/register` e `/denuncias/upload` (antes só `/login`)
- **BACK-07**: `UpdateStatusWithMotivo` — status + motivo em query atômica única
- **BACK-08**: Validação de CPF (11 dígitos) e telefone (10-11 dígitos) no `Register`; erros retornam 400 com mensagem clara
- **BACK-11**: `FavoriteRepository` movido de `internal/infrastructure/database/gorm/` → `persistence/mysql_favorite_repository.go`
- **BACK-12**: `ListAll` com paginação — `?page=&page_size=` (default 100, cap 500), header `X-Total-Count`
- Email Brevo: migrado de REST API para SMTP (`smtp-relay.brevo.com:587`); erro de envio de senha agora logado

**Flutter:**
- **FLUTTER-01**: `reservations_service.dart` (Strapi) deletado; todo o fluxo usa `GoReservationRepository`
- **FLUTTER-02**: `StrapiParkRepository` removido; `park_repository.dart` agora é interface pura
- `spaces_service.dart`: migrado de Strapi `/items/map_points` → Go `/map-points`
- `favorites_service.dart`: migrado de `http` raw para `ApiClient`; proteção contra double-tap (`_pending` set)
- `parks_service.dart`: removido (código morto)
- `map_screen.dart`: redesenhado com dados reais do Go backend via `GoParkRepository`; busca + geolocalização + ordenação por distância
- `my_reservations_screen.dart`: tabs Atuais/Histórico + paginação "ver mais"
- `back/go-api/`: removido do repo Flutter (backend vive em `/Users/sitwcomunicacaoemarketing/Desktop/PARQUE-BACK`)

**Security:**
- `.gitignore` reforçado: `KEYS/`, `*.p8`, `*.pem`, `.env` agora ignorados
- Chave `AuthKey_SMHXVK22HF.p8` removida do histórico git (estava commitada acidentalmente)

### 2026-06-05 (feat: recuperação de senha via OTP)
- **Fluxo completo implementado nos 3 projetos**
  - Backend: `PasswordResetToken` + `EmailSender` (Resend/Brevo) + 3 endpoints
  - Flutter: `VerificarCodigoScreen` (6 campos OTP) + `NovaSenhaScreen` + login automático
  - Regras: 15min expiração, 3 tentativas, 3 req/hora, rate limit no endpoint

### 2026-06-05 (feat: sistema de denúncias completo)
- **DenuncieScreen** reescrita do zero (era stub fake)
  - Submit real para `POST /denuncias`, fotos via `POST /denuncias/upload`
  - CEP auto-fill (endereço denunciante + local ocorrência), dados do usuário pré-preenchidos
  - Fotos: `image_picker` real, compressão 1280px 75% JPEG
- **Backend**: entidade `Denuncia`, status lifecycle, upload público
- **Admin React**: `DenunciasManagement` com badge na sidebar

### 2026-06-05 (feat: cadastro profissional)
- Máscaras: CPF (`XXX.XXX.XXX-XX`), celular (`(XX) XXXXX-XXXX`), CEP (`XXXXX-XXX`)
- Endereço completo: Rua (auto-fill CEP), Número, Complemento, Bairro, Cidade
- Formatadores compartilhados em `lib/core/formatters.dart`
- Regras de senha obrigatórias: 8+ chars, maiúscula, número, especial
- `PasswordStrengthIndicator` com barra 4 segmentos + checklist visual

### 2026-06-05 (fix: segurança autenticação)
- JWT: 365 dias → **30 dias**
- Rate limit: 10 tentativas/min por IP em `/login`
- Senha backend: `min=6` → `min=8` em todos os endpoints
- `me()` faz logout automático no 401
- `_forgot()` valida formato de email antes de enviar

### 2026-06-05 (feat: inbox de notificações — sino da home)
- `NotificationProvider` + `AppNotification` + `NotificationsScreen`
- FCM salvo localmente, badge vermelho no sino, swipe-to-delete
- Funciona com/sem login

### 2026-06-05 (feat: preferências reais)
- Toggles de notificação e localização conectados ao SO
- `WidgetsBindingObserver`: status atualiza ao voltar das configurações do SO

### 2026-06-05 (feat: API de CEP ViaCEP)
- `CepService` com race-condition protection (contador de sequência)
- Usado em RegisterScreen e DenuncieScreen

### 2026-06-05 (fix: padronização AppBar)
- 9 telas corrigidas: ícone sem `size`, título `fontSize: 20` w700 verde

### 2026-06-02 (fix: pontos de interesse + deploy script)
- Bug: migration map_points → spaces usava coluna errada (`categoria_mapa` vs `categoria_map_a`)
- Deploy script criado: `PARQUE-BACK/deploy.sh` (SCP + porta 8081 + VPS 162.240.151.36)
- Fluxo completo de agendamento validado em produção ✅

### 2026-06-02 (feat: sistema de reservas completo)
- Backend: Reservation expandida, ReservationUseCase, FCM graceful degradation
- Flutter: fluxo completo Home → reserva → aprovação → Minhas reservas
- Admin React: ReservationsManagement com Aprovar/Rejeitar/Cancelar

### 2026-06-01
- Spec: Review Draft Mode (`docs/superpowers/specs/2026-06-01-review-draft-mode-design.md`)
  - Status: **spec aprovada — implementação pendente**
