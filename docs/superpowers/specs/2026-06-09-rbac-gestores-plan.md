# Plano de Implementação — RBAC Gestores por Parque

**Spec:** `2026-06-09-rbac-gestores-design.md`  
**Ordem:** implementar ANTES do sistema de eventos  
**Projetos:** Backend Go → Admin React → Flutter app

---

## Fase 1 — Backend Go (PARQUE-BACK)

### 1.1 Entidade `AdminUser` — novos campos
**Arquivo:** `internal/domain/entities/admin_user.go`
- Adicionar `Role string` com gorm tag `size:20;default:'super_admin'`
- Adicionar `ParkID *uint` com gorm tag `index`
- Adicionar `Park *Park` com gorm tag `foreignKey:ParkID`
- Adicionar `Cargo string` com gorm tag `size:120`

### 1.2 Entidade `Denuncia` — campo park_id
**Arquivo:** `internal/domain/entities/denuncia.go`
- Adicionar `ParkID *uint` com gorm tag `index`
- Adicionar `Park *Park` com gorm tag `foreignKey:ParkID`

### 1.3 AutoMigrate
**Arquivo:** `cmd/api/main.go`
- Sem mudanças no AutoMigrate — GORM adiciona as novas colunas automaticamente nas tabelas existentes

### 1.4 Middleware de permissão por role
**Arquivo:** `internal/infrastructure/http/middleware/admin_auth.go` (ou onde estiver o RequireAdminAuth)
- Após validar o JWT do admin, injetar no contexto Gin:
  - `admin_role` (string: "super_admin" ou "gestor")
  - `admin_park_id` (*uint: nil para super_admin)
- Criar helper `RequireSuperAdmin()` — middleware que retorna 403 se role != "super_admin"

### 1.5 Filtro automático por park_id nos handlers admin

**Arquivo:** `internal/infrastructure/http/handlers/park_handler.go`
- `ListParks`: se `admin_role == "gestor"`, filtrar WHERE id = admin_park_id
- `GetPark`, `UpdatePark`, `DeletePark`: se gestor, verificar park.ID == admin_park_id → 403 se diferente

**Arquivo:** `internal/infrastructure/http/handlers/space_handler.go`
- Todos os endpoints admin: se gestor, filtrar por park_id

**Arquivo:** `internal/infrastructure/http/handlers/reservation_handler.go`
- `AdminList`: se gestor, adicionar filtro por park_id do espaço

**Arquivo:** `internal/infrastructure/http/handlers/review_handler.go`
- `List` (admin): se gestor, filtrar por park_id

**Arquivo:** `internal/infrastructure/http/handlers/denuncia_handler.go`
- `AdminList`: se gestor, filtrar por park_id
- `AdminGetByID`: se gestor, verificar park_id

**Arquivo:** `internal/infrastructure/http/handlers/map_point_handler.go`
- Endpoints admin: se gestor, filtrar por park_id

### 1.6 Nova entidade e handler — Gestão de Equipe
**Novo arquivo:** `internal/infrastructure/http/handlers/team_handler.go`

Endpoints:
- `GET /admin/team` — listar todos os membros (AdminUser) com park preloadado
- `POST /admin/team` — criar gestor ou super_admin (hash de senha via bcrypt)
- `PUT /admin/team/:id` — editar (nome, email, cargo, role, park_id, senha se enviada)
- `DELETE /admin/team/:id` — remover (não pode remover a si mesmo)

Regras no handler:
- Apenas `super_admin` acessa (usar `RequireSuperAdmin()`)
- Gestor sem park_id → 400
- Não pode alterar o próprio role para "gestor"
- Não pode deletar a própria conta

### 1.7 Rotas novas no main.go
```go
adminTeam := admin.Group("/team")
adminTeam.Use(middleware.RequireSuperAdmin(authUseCase))
{
    adminTeam.GET("/", teamHandler.List)
    adminTeam.POST("/", teamHandler.Create)
    adminTeam.PUT("/:id", teamHandler.Update)
    adminTeam.DELETE("/:id", teamHandler.Delete)
}
```

Rotas exclusivas de super_admin (adicionar `RequireSuperAdmin` middleware):
- `/admin/users` — gestão de usuários do app
- `/admin/notifications/broadcast`

### 1.8 Endpoint de denúncia — aceitar park_id
**Arquivo:** `internal/infrastructure/http/handlers/denuncia_handler.go`
- `Create`: aceitar `park_id` opcional no body do POST /denuncias

---

## Fase 2 — Admin React (PAINEL-PARK)

### 2.1 Auth context — armazenar role e park do admin logado
**Arquivo:** onde o login é gerenciado (provavelmente `src/contexts/AuthContext.tsx` ou similar)
- Após login, salvar `role` e `park_id` do admin logado
- Expor `isSuperAdmin()` e `gestorParkId` para uso nos componentes

### 2.2 Nova página: Equipe (`/equipe`)
**Novo arquivo:** `src/pages/TeamManagement/TeamManagement.tsx`

Tabela com colunas: Nome, E-mail, Papel, Parque (se gestor), Cargo, Último acesso, Ações.

Formulário (modal) de criação/edição:
- Nome, E-mail, Senha + confirmação (senha opcional na edição)
- Cargo (texto livre, opcional)
- Papel: select "Super Admin" / "Gestor"
- Parque: select com todos os parques — visível e obrigatório só quando Papel = Gestor

### 2.3 Sidebar — ocultar itens para gestor
**Arquivo:** componente da sidebar (ex: `src/components/Sidebar.tsx`)
- Ocultar para gestores: "Usuários", "Notificações", "Equipe"
- Mostrar para gestores: "Parque", "Espaços", "Reservas", "Eventos", "Avaliações", "Denúncias"

### 2.4 Header — badge de contexto para gestor
- Se gestor logado: mostrar "Gestor — [Nome do Parque]"

### 2.5 Filtros automáticos de park_id nas páginas
As páginas a seguir devem passar `park_id` automaticamente nas queries quando o admin for gestor:
- Reservas, Espaços/Pontos, Avaliações, Denúncias
- Parques: se gestor, mostrar só o parque dele (sem tabela — direto na tela de edição)

### 2.6 Formulário de Denúncia — campo Parque (admin)
**Arquivo:** `src/pages/DenunciasManagement/DenunciasManagement.tsx`
- No modal de detalhes, exibir o parque vinculado (se houver)

---

## Fase 3 — Flutter App

### 3.1 DenuncieScreen — campo Parque
**Arquivo:** `lib/screens/denuncie_screen.dart`
- Adicionar campo "Parque relacionado" (select opcional) na seção "Local da Denúncia"
- Carregar lista de parques via `GoParkRepository`
- Incluir `park_id` no payload do `POST /denuncias`

### 3.2 GoReservationRepository / modelos
- Sem mudança no Flutter para RBAC — o filtro é transparente, feito pelo backend

---

## Ordem de execução sugerida

1. Backend: 1.1 → 1.2 → 1.4 → 1.5 → 1.6 → 1.7 → 1.8
2. Compilar e testar: `go build ./...`
3. Admin: 2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6
4. Flutter: 3.1
5. Deploy e validar login de gestor no painel
