# RBAC — Sistema de Gestores por Parque

**Data:** 2026-06-09  
**Status:** Aprovado — aguardando implementação  
**Projetos afetados:** Backend Go (PARQUE-BACK), Admin React (PAINEL-PARK), Flutter app

---

## Problema

O painel admin hoje tem um único nível de acesso: qualquer admin vê e edita tudo. Com múltiplos parques e gestores diferentes para cada um, é necessário um sistema onde cada gestor só enxerga e opera os dados do seu próprio parque.

---

## Modelo de Permissões

Dois papéis no painel admin:

| Papel | Descrição | Acesso |
|-------|-----------|--------|
| `super_admin` | Administrador geral (dono do sistema, secretários) | Tudo, todos os parques |
| `gestor` | Responsável por um parque específico | Apenas o parque vinculado |

Regra de cardinalidade: **1 gestor = 1 parque** (exatamente). Um gestor não pode ser vinculado a mais de um parque.

### O que o gestor acessa

| Módulo | Gestor | Super Admin |
|--------|--------|-------------|
| Dashboard (filtrado ao seu parque) | ✅ | ✅ (global) |
| Parque — editar info básica, fotos, status | ✅ (só o seu) | ✅ |
| Espaços/Pontos de interesse | ✅ (só do seu parque) | ✅ |
| Reservas | ✅ (só do seu parque) | ✅ |
| Eventos | ✅ (só do seu parque) | ✅ |
| Avaliações | ✅ (só do seu parque) | ✅ |
| Denúncias | ✅ (só vinculadas ao seu parque) | ✅ |
| Usuários do app | ❌ | ✅ |
| Notificações broadcast | ❌ | ✅ |
| Equipe (gestores/admins) | ❌ | ✅ |

---

## Arquitetura Backend (PARQUE-BACK)

### 1. Entidade `AdminUser` — novos campos

```go
Role   string `json:"role" gorm:"size:20;default:'super_admin'"` // "super_admin" | "gestor"
ParkID *uint  `json:"park_id" gorm:"index"`                      // nil para super_admin
Park   *Park  `json:"park,omitempty" gorm:"foreignKey:ParkID"`
Cargo  string `json:"cargo" gorm:"size:120"`                     // texto livre, ex: "Gestor APA"
```

Migração segura: admins existentes ficam com `role = "super_admin"` e `park_id = NULL` — sem quebra.

### 2. Middleware de permissão

Após validar o JWT do admin, o middleware injeta no contexto Gin:
- `admin_id` (já existe)
- `admin_role` — `"super_admin"` ou `"gestor"`
- `admin_park_id` — `*uint`, nil para super_admin

### 3. Filtro automático nos handlers

Cada handler admin lê `admin_role` e `admin_park_id` do contexto:

```
se admin_role == "gestor":
    query += WHERE park_id = admin_park_id
    tentativa de acessar outro parque → 403 Forbidden

se admin_role == "super_admin":
    sem filtro adicional
```

### 4. Rotas exclusivas de `super_admin`

O middleware bloqueia gestores com 403 nas seguintes rotas:
- `GET/POST/PUT/DELETE /admin/team` — gestão de gestores e admins
- `GET/PUT/DELETE /admin/users` — usuários do app
- `POST /admin/notifications/broadcast` — notificações push

### 5. Denúncias — campo `park_id`

Adicionar `park_id` (nullable, FK para Park) na entidade `Denuncia`:

```go
ParkID *uint `json:"park_id" gorm:"index"`
Park   *Park `json:"park,omitempty" gorm:"foreignKey:ParkID"`
```

- No app Flutter: campo "Parque" (select, opcional) no formulário de denúncia
- Gestor vê só denúncias com `park_id = seu parque`
- Denúncias antigas (park_id NULL) visíveis apenas para super_admin
- Super_admin vê todas independente de park_id

---

## Admin Panel React (PAINEL-PARK)

### Nova página: Equipe (`/equipe`)

Visível **apenas para super_admin** na sidebar (ícone de pessoas).

**Tabela:**

| Nome | E-mail | Papel | Parque | Cargo | Último acesso | Ações |
|------|--------|-------|--------|-------|---------------|-------|
| João Silva | dev@sitw | Super Admin | — | Administrador | hoje | Editar |
| Karina Gonçalves | karina@... | Gestor | Rangedor | Gestor APA | 2d | Editar / Remover |

**Formulário de criação/edição:**
- Nome completo (obrigatório)
- E-mail (obrigatório, único)
- Senha + confirmação (obrigatório na criação; vazio na edição = mantém a atual)
- Cargo (opcional — texto livre para exibição)
- Papel: select `Super Admin` / `Gestor`
- Parque vinculado: select com todos os parques — visível e obrigatório **só quando Papel = Gestor**

**Validações:**
- Não pode remover a própria conta
- Não pode alterar o próprio papel de super_admin para gestor
- Gestor deve ter parque vinculado (validação no front e no back)

### Adaptação da UI para gestor logado

**Sidebar:** exibe apenas os módulos que o gestor pode acessar (Parque, Espaços, Reservas, Eventos, Avaliações, Denúncias). Oculta: Usuários, Notificações, Equipe.

**Header:** badge "Gestor — [Nome do Parque]" para identificação visual do contexto.

**Dados:** todas as tabelas chegam pré-filtradas pelo backend — o gestor nunca recebe dados de outros parques.

**Formulários:** campos de seleção de parque ficam pré-preenchidos e desabilitados (o gestor não pode mudar o parque de uma reserva para outro parque).

---

## Flutter App

### Denúncia — campo Parque

No `DenuncieScreen`, adicionar campo "Parque relacionado" (opcional):
- Select com a lista de parques (`GET /parks`)
- Posicionado na seção "Local da Denúncia"
- Enviado como `park_id` no payload do `POST /denuncias`

---

## Fluxo de Criação de Gestor

```
Super Admin → Tela Equipe → Novo Membro
→ Preenche: nome, email, senha, cargo, papel=Gestor, parque=Rangedor
→ Backend cria AdminUser com role="gestor", park_id=ID_RANGEDOR
→ Gestor recebe e-mail com credenciais (ou super admin repassa)
→ Gestor faz login → painel adaptado automaticamente ao Rangedor
```

---

## Pontos de Atenção

- **Senha do gestor**: o backend deve ter endpoint para super_admin resetar senha de qualquer membro da equipe (`PUT /admin/team/:id/reset-password`)
- **Primeiro login**: considerar forçar troca de senha no primeiro acesso (flag `must_change_password` na entidade)
- **Auditoria**: ações do gestor já ficam rastreáveis pelo `admin_id` que existe nos registros de denúncias e reservas
