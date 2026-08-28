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
    models/         — Park, Review, Space, Reservation, Participant, AppEvent, AppNotification,
                      ParkActivityType, ParkEventRule, EventRequest
    repositories/   — go_park_repository, go_reviews_repository, go_reservation_repository,
                      go_event_repository
  providers/
    notification_provider.dart — ChangeNotifier para inbox de notificações (SharedPreferences)
  screens/
    user/           — login, cadastro, perfil, senha, preferências, user_entry_screen,
                      verificar_codigo_screen, nova_senha_screen
    reservations/   — park_selection, spaces_catalog, space_detail, booking_calendar,
                      reservation_form, my_reservations
    events/         — event_park_selection, event_request_screen, event_details_screen,
                      event_request_success_screen, my_event_requests_screen
    notifications_screen.dart — inbox de notificações FCM (redesenhado 2026-06-12)
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
- Regras: 1 reserva ativa por CPF, duração **1h ou 2h** (usuário escolhe slots consecutivos), aprovação pelo gestor
- Duração: `booking_calendar_screen.dart` usa `_anchorHour`+`_selCount`; slots em incrementos de 1h; máx 2 consecutivos
- Backend valida `duracao_horas` (1 ou 2) — `ErrInvalidDuration` retorna 400 se fora desse range; `addHours(start, n)` calcula fim
- Rejeição: gestor informa motivo (obrigatório) → usuário tem deeplink para editar e reenviar; guard impede reenvio se status ≠ `Rejeitada`
- Cancelamento: usuário pode cancelar Pendente/Aprovada antes do dia da reserva
- Push FCM: graceful degradation (funciona sem config Firebase; ativa ao plugar credenciais)
- `Space` é a única entidade para lugares físicos (unificou map_points + spaces)
- `my_reservations_screen.dart`: tabs Atuais / Histórico + paginação "ver mais" (5 itens/página)
- Race condition eliminada no backend: `CreateIfNoConflict` com `SELECT FOR UPDATE` em transaction
- Rejeição atômica: `UpdateStatusWithMotivo` atualiza status + motivo em query única (sem janela de falha parcial)
- ListAll admin com paginação: `?page=1&page_size=100` (default 100, cap 500) + header `X-Total-Count`
- **Notificação participantes (2026-06-18)**: quando reserva aprovada, backend notifica via FCM os participantes que têm conta (lookup por CPF via `GetByListOfCPF`); mensagem: "Você tem uma reserva confirmada! ✓"; best-effort silencioso para CPFs sem conta
- **Validação Flutter (2026-06-18)**: `_collectParticipants()` bloqueia CPF duplicado entre participantes e CPF igual ao do líder

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
- CPF é **UNIQUE** no banco (`UNIQUE INDEX idx_users_cpf`) — `Register()` checa via `GetByCPF` antes de `Create()`; DB constraint como backstop de race condition; HTTP 409 + `"CPF já cadastrado"` se duplicado
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

## Race condition em solicitações de evento (implementado 2026-06-18)
- Múltiplas solicitações pendentes para o mesmo espaço/data/horário podem coexistir na fila do admin
- Ao **aprovar**: verifica se já há evento `Aprovado` no mesmo slot → bloqueia (HTTP 409) se houver; auto-rejeita todos os `Pendentes` conflitantes com motivo "Horário ocupado por outra solicitação aprovada"; tudo em transação única
- Método `GetConflicting(ctx, spaceID, date, horaInicio, horaFim, excludeID)` no `EventRequestRepository`
- Reservas e eventos NÃO compartilham os mesmos espaços — sem cross-check entre os dois sistemas

## Sistema de eventos (implementado 2026-06-12)
- Fluxo Flutter: Home → EventParkSelectionScreen → EventRequestScreen (espaço + data + hora) → EventDetailsScreen (formulário) → EventRequestSuccessScreen
- `EventDetailsScreen`: tipo atividade (chips ou free-text), qtd pessoas, objetivo, nome/telefone/CPF/email do responsável (pré-preenchidos do cadastro), switch BPA
- Regras dinâmicas: `ParkEventRule` filtra por `tipoAtividade` e `thresholdMin` em tempo real; BPA forçado se `bpaObrigatorio=true`
- `EventRequestSuccessScreen`: tela de sucesso com `assets/images/calendario.png` (mesmo padrão da reserva)
- `my_event_requests_screen.dart`: lista solicitações do usuário
- Rota de sucesso: `/tabs/home/eventos/sucesso`

## Sistema de regras de evento por parque (implementado 2026-06-12)
- Entidade `ParkEventRule`: `titulo`, `texto`, `tipo_atividade`, `threshold_min`, `threshold_max`, `bpa_obrigatorio`, `min_participantes`, `obrigatoria`, `ativo`, `ordem`
- Backend seed: 7 regras padrão por parque na inicialização (antecedência 15 dias, limpeza, ambulância 200+, segurança 500+, corridas, trilhas, horário)
- Admin: `EventRulesManagement` em `/parques/:parkId/regras-eventos` — toggle ativo/inativo, criar/editar/deletar
- Endpoint público: `GET /event-requests/rules?park_id=X` → só retorna `ativo=true`
- Endpoint admin: `GET /admin/parks/:id/event-rules` → retorna todas

## Sistema de tipos de atividade por parque (implementado 2026-06-12)
- Entidade `ParkActivityType`: `nome`, `descricao`, `ativo`, `park_id`
- Backend seed: 7 tipos padrão por parque na inicialização
- Flutter: carregados em `EventDetailsScreen`; fallback para campo de texto livre se nenhum disponível

## Campo `permite_evento` nos espaços (implementado 2026-06-12)
- `Space.PermiteEvento bool` — controla se o espaço aceita solicitações de evento
- `MapPointInput` e `MapPointResponse` incluem `permite_evento`
- Admin: toggle "Permite solicitar eventos" no formulário de Pontos de Interesse
- Sem este toggle ativo no espaço, o backend retorna erro "este espaço não permite eventos"

## Sistema de avaliações — status e moderação (implementado 2026-06-17)
- **3 status apenas**: `Pendente`, `Publicada`, `Rejeitada` (eliminados: Aprovada, Ocultada, Denunciada)
- **Shadow moderation**: usuário sempre vê a própria avaliação sem nenhum badge de status; acredita que está pública
- Backend: `ListByParkID` filtra `WHERE status = 'Publicada'`; `Update` handler aceita SOMENTE `Publicada` ou `Rejeitada` (400 para qualquer outro)
- Flutter: `Review.status` default `'Pendente'`; `_hasActiveReview` verifica `status == 'Publicada'`; badge "Não publicada" removido; avaliação rejeitada ainda aparece para o autor (shadow)
- Admin React: 4 cards de métrica (Total, Média, Pendentes, Parques); botões diretos "Publicar"/"Rejeitar" sem dropdown
- Migration SQL no boot: `Aprovada→Publicada`, `Ocultada→Rejeitada`, `Denunciada→Publicada`, vazio→`Pendente`
- Spec: `docs/superpowers/specs/2026-06-16-review-status-redesign.md`

## Painel Admin — mudanças (2026-06-12)
- `MapPointFormPage.tsx`: removidos campos Latitude, Longitude, "Seção no app", toggle "Exibir no mapa"
- Toggles desativados: cor alterada de `bg-border-strong` (invisível) → `bg-gray-300`
- `EventRequestsManagement.tsx`: bug `formatarData` corrigido (RangeError: Invalid time value) — `data_evento` vinha como ISO completo do Go backend

## Pendências que dependem de ação humana
1. **TestFlight push notifications**: adicionar capability "Push Notifications" no Xcode → Archive → nova build TestFlight → instalar → logar → aceitar permissão
2. **Resend**: criar conta em resend.com, verificar domínio, adicionar `RESEND_API_KEY` e `EMAIL_FROM` no `.env` do backend
3. **PAINEL-PARK**: não está no git — arquivos salvos localmente mas sem versionamento
4. **Email Brevo**: migrado para SMTP — variáveis necessárias: `BREVO_SMTP_LOGIN`, `BREVO_SMTP_PASSWORD`, `EMAIL_FROM`
5. **Admin PAINEL-PARK — PDF na solicitação de evento**: `EventRequestsManagement.tsx` deve exibir link/badge do PDF quando `pdf_url` estiver preenchido na solicitação (não implementado ainda)
6. **DDL para engenheiro (2026-06-23)**: nova coluna `pdf_url VARCHAR(512)` adicionada à tabela `event_requests` via `AutoMigrate` (sem migration manual necessária). Demais pendências DDL de baixa prioridade listadas abaixo.

## Android — padrões de segurança obrigatórios (2026-06-18)
- **Safe area em bottom sheets**: sempre somar `MediaQuery.of(context).padding.bottom` ao padding do container + `useSafeArea: true` no `showModalBottomSheet`; `viewInsets.bottom` é só o teclado, não cobre a nav bar gestural
- **Bottom bar responsiva**: `_SlidingTabBar` em `app_router.dart` usa altura dinâmica (56px em telas < 380px, 60px em telas maiores)
- **Segmented control**: labels com `maxLines: 1, overflow: TextOverflow.ellipsis` para evitar overflow em telas compactas

## Componentes globais importantes
- `AppToast` (`lib/widgets/app_toast.dart`) — toast estilo Duolingo, usar em vez de SnackBar; SEMPRE incluir `decoration: TextDecoration.none` no `GoogleFonts.poppins()` dentro de `OverlayEntry` (sem isso herda sublinhado amarelo do DefaultTextStyle raiz)
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

## Banco de dados — convenções DDL (OBRIGATÓRIO — auditoria 2026-06-20)
Aprendizados que evitam regressão de schema. **Toda nova entidade/coluna deve seguir:**
1. **NUNCA deixar `string` sem tag** — GORM mapeia `string` cru para `LONGTEXT` (4 GB, não indexável, risco de storage). Sempre dimensionar: URL `gorm:"size:512"`, nome `size:150`, hora `size:5`, status/enum `size:20`, texto livre `gorm:"type:text"`.
2. **Nome de coluna = field Go em snake_case, NÃO o json tag.** `ImagemUrl2` → coluna `imagem_url2` (sem `_` antes do dígito); `CategoriaMapA` → `categoria_map_a`. Migrations raw devem usar o nome REAL (conferir com `mysqldump --no-data`).
3. **Charset = utf8mb4** em todas as tabelas (utf8mb4_unicode_ci). utf8mb3 não guarda emoji → `Incorrect string value` em avaliações/denúncias.
4. **`AutoMigrate` só adiciona/altera, nunca dropa.** Limpeza = `Migrator().DropColumn`/`DROP TABLE` explícito. ALTERs de tipo e índices devem rodar **antes** do AutoMigrate (em `main.go`); coluna nova com FK exige backfill **antes** do AutoMigrate (senão valor 0 viola FK → boot fatal); dropar coluna/tabela com FK exige `DROP FOREIGN KEY` antes.
8. **`NOT NULL`/`UNIQUE`/`FK` em coluna que JÁ existe NUNCA é aplicado pelo `AutoMigrate`** (confirmado em prod 2026-06-22). Marcar `gorm:"not null"` na struct de uma coluna existente compila e dá falsa sensação de integridade, mas o MySQL continua `DEFAULT NULL`. Exige `ALTER TABLE ... MODIFY ... NOT NULL` explícito em `main.go` (depois de garantir 0 nulls). Vale para constraint nova em coluna preexistente — não para coluna criada do zero.
5. **Backup obrigatório antes de migration destrutiva**: `mysqldump` via ssh no VPS → `/home/wwsitw/apps/backend-park/backups/`.
6. **`reservations` agora tem `park_id`** (FK + index, setado no `CreateReservation` a partir do espaço). As métricas de reserva por parque (dashboard gestor/admin) dependem dele.
7. **`deploy.sh` dá falso "ERRO"** quando a migration é pesada (ex: CONVERT utf8mb4) e passa do `sleep 2` do health-check — confirmar no log (`parque.log` → "Listening and serving") e via `curl localhost:8081/api/v1/parks`.

## Pendências DDL — baixa prioridade (auditoria 2026-06-22, NÃO resolvidas)
Achados de uma 2ª auditoria do schema real de prod (`mysqldump --no-data`). **Todas baixo risco e baixo impacto — adiadas de propósito.** Dados verificados limpos no dia (0 nulls/órfãos), então aplicáveis com segurança quando formos resolver. Caminho correto: alterar struct + `ALTER` explícito em `main.go` + `deploy.sh` (não mexer no banco na mão, senão código e DB divergem).

1. **`NOT NULL` que nunca aplicou** (P1) — `reservations.{user_id,space_id,data_reserva,park_id}` e `run_activities.client_id` seguem `DEFAULT NULL` em prod apesar das structs marcarem `not null`. Causa: `AutoMigrate` não altera nulabilidade de coluna existente (ver convenção DDL #8). Fix: `ALTER TABLE ... MODIFY col tipo NOT NULL` após confirmar 0 nulls. Considerar também `favorites.{user_id,park_id}` (hoje nullable, favorito sem user/park é sem sentido).
2. **FKs ausentes** (P2) — só têm índice, sem `FOREIGN KEY`: `event_interests.{user_id,evento_id}`, `fcm_tokens.user_id`, `park_activity_types.park_id`, `park_event_rules.park_id`. 0 órfãos hoje → adicionar FK como backstop de integridade.
3. **`spaces.latitude`/`longitude` são `varchar(30)`** (P3) — inconsistente com `parks` (`double`). String = sem validação nem cálculo geográfico. Conversão exige backfill parse string→double (só ~7 linhas).
4. **Colunas mortas em `spaces`** (P3) — `categoria_map_a` tem **0 linhas preenchidas** → dropável. `exibir_no_mapa` (7/7 forçado `true` pelo `toSpace()`) só servia ao endpoint `/map-points` das listas "Vem caminhar/divertir" já removidas — **confirmar que `/map-points` não é mais servido pelo backend ANTES de dropar.** O catálogo vivo (`/spaces`) filtra por `categoria`/`park_id`/`permite_reserva`, nunca por `exibir_no_mapa`.
5. **`reviews` sem `UNIQUE(user_id,park_id)`** (opcional) — "1 avaliação por parque" é garantido só no app (`_hasActiveReview`). Backstop no DB seria bom, **mas ressalva**: shadow moderation mantém avaliação rejeitada visível ao autor; constraint rígida pode travar re-avaliação futura. Avaliar antes.

---

## Histórico de mudanças

### 2026-06-23 (run_tracker cross-device + UX fixes + PDF em eventos — deployado)

**Flutter:**
- **Cross-device restore** (`run_tracker_service.dart` + `main.dart`): `pullFromCloud()` exposto como método público; auth listener em `main.dart` agora chama tanto `syncPending()` (local→nuvem) quanto `pullFromCloud()` (nuvem→local) ao logar — restaura histórico de atividades em troca de dispositivo
- **`atividade_screen.dart`** — 3 correções:
  - "Ver tudo da semana" redesenhado: `DraggableScrollableSheet` com stats agregados + lista scrollável de atividades individuais (antes mostrava só totais); cada card abre `ActivityDetailModal`
  - Bug pós-corrida: modal puxava atividade anterior quando percurso curto não era salvo — corrigido com guard `prevCount` (`run.activities.length > prevCount` antes de mostrar)
  - "Histórico Recente" → "Histórico"; cap de 20 itens removido
- **`home_screen.dart`**: saudação "Oi, **Nilo!**" — pega `me['nome']` (chave em PT-BR), normaliza com `toLowerCase()` + capitaliza primeira letra; sem trailing "Boa noite" (gramaticalmente incorreto)
- **`user_screen.dart`**: exibe apenas primeiro + último nome, cada um capitalizado (ex: "NILO DI ARMANNI SILVA DE SOUSA" → "Nilo Sousa")
- **`park_detail_screen.dart`**: singular/plural correto — `'$n ${n == 1 ? 'avaliação' : 'avaliações'}'`
- **`event_details_screen.dart`** — PDF opcional em solicitações de evento:
  - Card "Documento PDF" com `file_picker ^8.1.2`; `withData: true` para compatibilidade iOS; `behavior: HitTestBehavior.opaque` + `try/catch` para garantir abertura do picker
  - `_uploadPdf()`: usa `bytes` da memória (withData) com fallback para `path`; POST em `/upload` com `entity_type=event_request`
  - `pdfUrl` incluído no body do `_submit()` quando preenchido
  - Ordem dos campos: PDF antes do switch BPA
- **`data/models/event_request.dart`**: campo `pdfUrl` adicionado com default `''`

**Backend (PARQUE-BACK) — deployado:**
- **`event_request.go`**: `PdfUrl string json:"pdf_url" gorm:"size:512"` — AutoMigrate adiciona coluna `pdf_url VARCHAR(512)` automaticamente
- **`event_request_usecase.go`**: `PdfUrl` em `CreateEventInput` e `UpdateAndResubmitInput`
- **`event_request_handler.go`**: `pdf_url` em `createEventRequestInput` e `updateAndResubmitInput`
- **`media_validate.go`**: PDF adicionado ao allowlist (`.pdf → application/pdf`); `MaxPdfUploadBytes = 5 << 20` (5 MB)

**DDL novo em produção:**
- `event_requests.pdf_url VARCHAR(512) NULL` — adicionado via AutoMigrate no deploy deste dia

### 2026-06-20 (auditoria DDL completa + limpeza de schema morto — deployado)

**Backend (PARQUE-BACK) — migration em `main.go`, deployada em produção:**
- **Charset**: todas as 18 tabelas `utf8mb3 → utf8mb4` (emoji em avaliações/denúncias agora funciona; fim do deprecated)
- **longtext → varchar/text dimensionado**: `parks`, `spaces`, `reviews`, `reservations`, `space_rules`, `eventos`; `reviews.status varchar(20)` **+ índice**; `run_activities.route → mediumtext`
- **`reservations.park_id`** adicionado + backfill via `spaces.park_id` + FK + index — **corrigiu dashboards do gestor/admin que estavam zerados** (queries filtravam `park_id` numa coluna inexistente, erro engolido)
- **`aceitou_termos`** agora é persistido em cadastro e denúncia (era gap de LGPD — app enviava, backend descartava): ligado em `User`, `Denuncia`, handlers e usecases
- **Integridade**: `UNIQUE(user_id,park_id)` em `favorites`; `parks.deleted_at → gorm.DeletedAt` (soft-delete real). ⚠️ **CORREÇÃO (auditoria 2026-06-22):** o `NOT NULL` que se pretendia aplicar em `reservations.{user_id,space_id,data_reserva,park_id}` e `run_activities.client_id` **NÃO foi aplicado** — o `AutoMigrate` ignora `NOT NULL` em coluna existente (ver pendência DDL abaixo). As structs marcam, mas em prod seguem `DEFAULT NULL`.
- **Schema morto removido**: tabelas `map_points`/`activities`/`vem_caminhars`; colunas `parks.imagem_url2/3`, `favorites.activity_id`, `denuncia.{cep,rua,numero,complemento,bairro}`; entidades Go `Activity`/`MapPoint`/`VemCaminhar` + repos órfãos
- Decisão: `eventos.data_inicio/fim` mantido como `varchar(30)` (não migrado p/ `DATE` — exigiria mexer no fluxo editorial)

**Flutter:**
- `Park` passou a ler/exibir `endereco`/`cidade` (home + detalhe); removido hack `description.contains('Rua')`
- Removido subsistema morto "Vem se divertir/Vem caminhar": listas da home + `map_point_repository.dart` + `map_point.dart` + `spaces_service.dart`
- `home_screen`: 5 atalhos reordenados → Colabore · Reservas · Eventos · Favoritos · Info

**Admin (PAINEL-PARK):**
- `ParkFormPage`: 3 fotos → 1 (só capa); `AdminDashboard` usa dados reais por período (não mock); mock removido de `api.ts`/`AdminLayout`/`ReviewsManagement`

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

### 2026-06-12 (feat: sistema de eventos completo — Flutter + Backend + Admin)

**Flutter:**
- Fluxo redesenhado: 5 telas → 2 telas (`EventRequestScreen` + `EventDetailsScreen`)
- `EventRequestScreen`: seleção de espaço (chips filtrados por `permiteEvento`) + calendário inline + chips de horário
- `EventDetailsScreen`: formulário completo com pré-preenchimento de nome/telefone/CPF/email do usuário logado
- `EventRequestSuccessScreen`: tela de sucesso pós-envio (mesmo padrão da reserva com `calendario.png`)
- `NotificationsScreen` redesenhada: ícones melhores por tipo (`event_available_rounded`, `celebration_rounded`, `local_activity_rounded`, etc.) com container centralizado
- Rota `/tabs/home/eventos/sucesso` adicionada ao `app_router.dart`

**Backend (PARQUE-BACK) — deploy feito:**
- `EventRequest`: colunas `cpf_responsavel` e `email_responsavel` adicionadas (GORM AutoMigrate)
- `Space.PermiteEvento`: mapeado em `MapPointInput`, `MapPointResponse`, `toSpace()`, `toResponse()`
- `ParkEventRule`: campos `titulo`, `bpa_obrigatorio`, `min_participantes`, `ativo` adicionados
- Seed 7 tipos de atividade padrão + 7 regras padrão por parque no boot
- Endpoint público `ListActive` retorna só regras `ativo=true`

**Admin Panel (PAINEL-PARK):**
- `MapPointFormPage`: removidos Latitude, Longitude, "Seção no app", toggle "Exibir no mapa"
- Toggle "Permite solicitar eventos" adicionado (roxo, `permite_evento`)
- Toggles off agora visíveis: `bg-gray-300` em vez de `bg-border-strong`
- `EventRequestsManagement`: bug `formatarData` corrigido (ISO datetime completo do Go)
- `EventRulesManagement`: nova página `/parques/:parkId/regras-eventos`

### 2026-06-17 (feat: reserva 1h/2h + redesign avaliações + 10 correções code-review)

**Reserva 1h ou 2h (Flutter + Backend):**
- `booking_calendar_screen.dart`: substituído `_selectedSlotValue` por `_anchorHour`+`_selCount`; slots em incrementos de 1h; seleção consecutiva (adjacente estende, não-adjacente recomeça, tocar 2º retorna a 1h); resumo "13:00 – 15:00 · 2h"
- Backend (`reservation_usecase.go`): `addHours(start, n)` substitui `addTwoHours`; valida `DuracaoHoras` (1 ou 2) → `ErrInvalidDuration` → HTTP 400; `disponibilidade` gera slots de 1h (`hour++`)
- `go_reservation_repository.dart`: parâmetro `int duracaoHoras = 1`, body inclui `'duracao_horas'`
- `reservation_form_screen.dart`: campo `_duracaoHoras`, resumo com duração, guard deeplink (só reenvio se `status == 'Rejeitada'`)

**Redesign de status de avaliações (3 projetos):**
- 6 status → 3: `Pendente`, `Publicada`, `Rejeitada` — shadow moderation (usuário nunca vê badge, sempre acredita que está publicada)
- Backend: `ListByParkID` filtra só `Publicada`; `Update` vinculado a `Publicada`/`Rejeitada`; migration SQL no boot
- Flutter: default `'Pendente'`, badge "Não publicada" removido, avaliação rejeitada ainda aparece para autor
- Admin React: 3 status, 4 métricas, botões "Publicar"/"Rejeitar" diretos

**10 correções do code-review:**
1. `evento_detail_screen.dart`: flag `_interesseInitialized` — toggle não reverte mais em rebuild do FutureBuilder
2. `event_details_screen.dart`: modo edição chama `_prefillUser()` antes de `_prefillEditing()` — CPF/email vêm de `AuthService.currentUser`
3. `run_tracker_service.dart`: filtro GPS 30m + sync cold start com `unawaited(syncPending())` + guard `_syncing` sem reentrada
4. `run_tracker_service.dart`: `synced` removido como campo; virou getter derivado `bool get synced => serverId != null`
5. `go_run_activity_repository.dart`: removido `synced: true` do construtor (campo não existe mais)
6. `atividade_screen.dart`: `_handleSave` null-safe + try/catch; não crasha em resultado inesperado
7. `park_detail_screen.dart`: `_resolveImg` duplicado removido (parâmetro `toImageUrl` único); `_SmartImage` deletado (eliminado download duplo); `_SpaceCard` usa `CachedNetworkImage` diretamente
8–10. Telas mortas de eventos deletadas: `event_datetime_screen.dart`, `event_form_screen.dart`, `event_space_selection_screen.dart`

**Estado pós-sessão:** tudo implementado, `flutter analyze` 0 erros, `go build` ✅ — **nada commitado nem deployado ainda**

### 2026-06-17 (fix: share button iOS + map picker redesign)

**Botão Compartilhar (`atividade_screen.dart`):**
- `sharePositionOrigin` é obrigatório no iOS — `UIActivityViewController` lança `PlatformException("sharePositionOrigin: argument must be set")` se o rect for zero (default quando omitido)
- Fix: `GlobalKey _shareButtonKey` no `OutlinedButton.icon` de compartilhar + `box.localToGlobal(Offset.zero) & box.size` passado como `sharePositionOrigin`; fallback seguro `Rect.fromLTWH(0, 0, 1, 1)`
- Removido parâmetro `text` de `Share.shareXFiles` — iOS rejeita `UIActivityViewController` com `String + XFile` simultâneos (WhatsApp/Instagram recusam o item combinado)
- `_handleShare` com try/catch completo + `bytes.isEmpty` check + `debugPrint` do erro real no catch

**Map Picker redesenhado (`map_screen.dart`):**
- Logos reais: `assets/images/maps/waze.png` (PNG 1600×1600) + `assets/images/maps/google_maps.svg` (SVG oficial via `flutter_svg`)
- 2 cards horizontais lado a lado; `InkWell` com ripple; logo 56px centralizado + nome abaixo
- Zero loading state — `_checkApps()`/`_checking`/`_available` removidos
- Apple Maps removido de todas as plataformas; Google Maps URL corrigida para iOS: `comgooglemaps://`
- `_NavApp` usa `assetPath + isSvg` em vez de `iconData + iconColor + iosOnly`
- `LSApplicationQueriesSchemes` adicionado ao `ios/Runner/Info.plist` (`comgooglemaps`, `waze`)

### 2026-06-01
- Spec: Review Draft Mode (`docs/superpowers/specs/2026-06-01-review-draft-mode-design.md`)
  - Status: **spec aprovada — implementação pendente**
