# Recuperação de Senha via Código — Design Spec
**Data:** 2026-06-05
**Status:** Aprovado

## Objetivo

Implementar fluxo completo de recuperação de senha com verificação de identidade por código de 6 dígitos enviado ao email do usuário. Sem custo: email via Resend (3.000/mês grátis), Brevo como fallback via variável de ambiente.

---

## Fluxo completo

```
LoginScreen → digita email → POST /forgot-password
  ↓
VerificarCodigoScreen (email mascarado, 6 campos OTP)
  → POST /verify-reset-code → código válido
  ↓
NovaSenhaScreen (nova senha + confirmação + PasswordStrengthIndicator)
  → POST /reset-password
  → login automático → /tabs/user
```

---

## Regras de negócio

| Regra | Valor |
|---|---|
| Expiração do código | 15 minutos |
| Tentativas erradas antes de invalidar | 3 |
| Cooldown para reenvio (Flutter) | 60 segundos |
| Máximo de solicitações por email/hora | 3 |
| Resposta do `/forgot-password` quando email não existe | 200 OK (não revela cadastro) |

---

## Backend Go

### Nova tabela: `password_reset_tokens`

```go
type PasswordResetToken struct {
    ID        uint       `gorm:"primaryKey"`
    UserID    uint       `gorm:"not null;index"`
    Code      string     `gorm:"size:6;not null"`
    ExpiresAt time.Time  `gorm:"not null"`
    UsedAt    *time.Time
    Attempts  int        `gorm:"default:0"`
    CreatedAt time.Time
}
```

### Interface de email

```go
type EmailSender interface {
    SendPasswordReset(to, nome, code string) error
}
```

Selecionada via `EMAIL_PROVIDER` env var:
- `resend` → `ResendSender` (padrão, HTTP puro, sem lib)
- `brevo`  → `BrevoSender` (fallback, HTTP puro)

### Novos arquivos

| Arquivo | Responsabilidade |
|---|---|
| `entities/password_reset_token.go` | Struct GORM |
| `repositories/password_reset_repository.go` | Interface: Create, FindValid, IncrAttempts, Consume, CountRecent |
| `persistence/mysql_password_reset_repository.go` | Implementação MySQL |
| `infrastructure/email/email_service.go` | Interface `EmailSender` + factory |
| `infrastructure/email/resend_sender.go` | Resend REST API |
| `infrastructure/email/brevo_sender.go` | Brevo REST API |
| `usecases/password_reset_usecase.go` | RequestReset, VerifyCode, ResetPassword |
| `handlers/password_reset_handler.go` | 3 handlers HTTP |

### Endpoints (todos públicos, sem auth)

```
POST /forgot-password
  body: { email }
  response: 200 sempre (não revela se email existe)

POST /verify-reset-code
  body: { email, code }
  response: 200 { valid: true } | 400 { error } | 429 (tentativas esgotadas)

POST /reset-password
  body: { email, code, senha }
  response: 200 { token, usuario } | 400 { error }
  — retorna token JWT para login automático
```

### Variáveis de ambiente

```
EMAIL_PROVIDER=resend
RESEND_API_KEY=re_xxxxxxxxxxxx
EMAIL_FROM=noreply@vemproparque.com.br
# Fallback:
# EMAIL_PROVIDER=brevo
# BREVO_API_KEY=xkeysib-xxxxxxxxxxxx
```

---

## Flutter

### Telas novas

**`VerificarCodigoScreen`** — rota `/verificar-codigo`
- Recebe `extra: { 'email': String }` via GoRouter
- Email mascarado exibido: `jo**@gmail.com`
- 6 `TextFormField` individuais (1 dígito cada, teclado numérico)
  - Foco avança automaticamente ao digitar
  - Backspace volta ao campo anterior
- Botão "Verificar" desabilitado até 6 dígitos preenchidos
- Link "Reenviar código" com countdown de 60s (desabilitado durante contagem)
- Erro inline vermelho se código inválido/expirado
- Design: branco, título verde Poppins w700 20px, campos com borda verde

**`NovaSenhaScreen`** — rota `/nova-senha`
- Recebe `extra: { 'email': String, 'code': String }` via GoRouter
- Campo "Nova senha" + "Confirmar nova senha" (toggle show/hide)
- `PasswordStrengthIndicator` reutilizado (já existe em `lib/widgets/`)
- Botão "Salvar nova senha" desabilitado durante loading
- Após sucesso: `AuthService.login(email, senha)` → `context.go('/tabs/user')`
- Design: segue padrão do `ChangePasswordScreen`

### Navegação

```dart
// LoginScreen._forgot() após sucesso do POST:
context.push('/verificar-codigo', extra: {'email': email});

// VerificarCodigoScreen após POST /verify-reset-code com sucesso:
context.push('/nova-senha', extra: {'email': email, 'code': code});

// NovaSenhaScreen após POST /reset-password com sucesso:
await AuthService.instance.login(email, novaSenha);
context.go('/tabs/user');
```

### Rotas adicionadas em `app_router.dart`

```dart
GoRoute(path: '/verificar-codigo', builder: (_, s) =>
    VerificarCodigoScreen(email: s.extra as Map ...))
GoRoute(path: '/nova-senha', builder: (_, s) =>
    NovaSenhaScreen(email: ..., code: ...))
```

### Arquivo modificado

- `lib/services/auth_service.dart` — atualizar `requestPasswordReset` e `resetPassword` para o novo contrato

---

## Email (template)

Assunto: **Seu código de recuperação — Vem Pro Parque**

Corpo (HTML simples):
- Saudação com nome do usuário
- Código em destaque: fonte grande, fundo verde claro
- "Este código expira em 15 minutos"
- "Se você não solicitou, ignore este email"

---

## AutoMigrate

Adicionar `&entities.PasswordResetToken{}` em `main.go`.
