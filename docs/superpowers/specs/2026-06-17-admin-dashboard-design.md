# Spec — Dashboard Admin/Secretário

**Data:** 2026-06-17
**Status:** aprovado

## Objetivo

Substituir o dashboard atual do painel admin por dois dashboards distintos com dados reais e úteis:
- **Gestor:** visão do seu parque — pendências + métricas
- **Admin/Secretário:** visão de todos os parques — panorama geral do sistema

## Escopo

- PAINEL-PARK (React): página `Dashboard/index.tsx` — detecta role do JWT e renderiza o dashboard correto
- PARQUE-BACK (Go): endpoint `GET /admin/dashboard` já existente — adicionar campos novos ou criar sub-endpoints

---

## Dashboard do Gestor

**Quem vê:** usuário com `role = "gestor"` (tem `park_id` no JWT)

### Seção 1 — Fila de pendências *(topo, sempre visível)*

4 cards com número em destaque + label + botão de ação direta:

| Card | Dado | Link |
|------|------|------|
| Reservas pendentes | `COUNT reservations WHERE status='Pendente' AND park_id=X` | `/reservas?status=pendente` |
| Eventos para revisar | `COUNT event_requests WHERE status='Pendente' AND park_id=X` | `/eventos?status=pendente` |
| Denúncias novas | `COUNT denuncias WHERE status='Nova' AND park_id=X` | `/denuncias?status=nova` |
| Avaliações para moderar | `COUNT reviews WHERE status='Pendente' AND park_id=X` | `/avaliacoes?status=pendente` |

### Seção 2 — Métricas do mês

3 números sem botão de ação — informativos:
- Reservas este mês (total)
- Taxa de aprovação (% aprovadas / (aprovadas + rejeitadas))
- Satisfação média (AVG nota das avaliações `Publicada` do parque)

### Seção 3 — Gráfico

Reservas por dia nos últimos 30 dias — bar chart simples (biblioteca já usada no projeto, ex: Recharts).

### Seção 4 — Próximas reservas

Lista das próximas 5 reservas com status `Aprovada`, ordenadas por `data_hora ASC`:
- Nome do usuário · Espaço · Data/Hora · Status

---

## Dashboard do Admin/Secretário

**Quem vê:** usuário com `role = "admin"` ou `role = "super_admin"` (sem `park_id` no JWT)

### Seção 1 — Resumo geral do sistema

4 KPI cards:
- Total de parques cadastrados
- Total de usuários cadastrados
- Total de reservas este mês (todos os parques)
- Total de denúncias abertas (status `Nova` + `Em Análise`)

### Seção 2 — Tabela por parque

Uma linha por parque, colunas:
| Parque | Reservas Pendentes | Satisfação Média | Denúncias Abertas |

Clicável: clicar na linha filtra as outras páginas pelo parque (via URL param ou state global).

### Seção 3 — Gráfico

Reservas por parque este mês — bar chart horizontal para comparação entre parques.

### Seção 4 — Atividade recente

Últimas 10 ações no sistema (feed cronológico):
- `[Reserva]` João Silva criou reserva no Parque X — há 2h
- `[Evento]` Corrida beneficente aprovada no Parque Y — há 4h
- `[Denúncia]` Nova denúncia registrada em São Luís — há 6h

Tipos de evento no feed: reserva criada, reserva aprovada/rejeitada/cancelada, evento criado/aprovado/rejeitado, denúncia criada/resolvida.

---

## Backend Go — endpoints necessários

### Gestor

```
GET /admin/dashboard/gestor
  Authorization: Bearer <admin JWT>
  (park_id extraído do JWT)
```

Resposta:
```json
{
  "pendencias": {
    "reservas_pendentes": 5,
    "eventos_pendentes": 2,
    "denuncias_novas": 1,
    "avaliacoes_pendentes": 3
  },
  "metricas_mes": {
    "reservas_total": 28,
    "taxa_aprovacao": 0.85,
    "satisfacao_media": 4.2
  },
  "reservas_por_dia": [
    { "dia": "2026-06-01", "total": 3 },
    ...
  ],
  "proximas_reservas": [
    { "usuario": "Ana Costa", "espaco": "Quadra A", "data_hora": "2026-06-17T14:00:00Z", "status": "Aprovada" },
    ...
  ]
}
```

### Admin/Secretário

```
GET /admin/dashboard/admin
  Authorization: Bearer <admin JWT>
```

Resposta:
```json
{
  "resumo": {
    "total_parques": 4,
    "total_usuarios": 1243,
    "reservas_mes": 112,
    "denuncias_abertas": 7
  },
  "por_parque": [
    {
      "park_id": 1,
      "nome": "Parque do Rangedor",
      "reservas_pendentes": 5,
      "satisfacao_media": 4.2,
      "denuncias_abertas": 1
    },
    ...
  ],
  "reservas_por_parque_mes": [
    { "park_id": 1, "nome": "Rangedor", "total": 28 },
    ...
  ],
  "atividade_recente": [
    { "tipo": "reserva_criada", "descricao": "João Silva criou reserva no Parque do Rangedor", "created_at": "2026-06-17T12:00:00Z" },
    ...
  ]
}
```

---

## Frontend (React)

### Detecção de role

```tsx
// Dashboard/index.tsx
const { role } = useAdminAuth();
return role === 'gestor' ? <GestorDashboard /> : <AdminDashboard />;
```

### Componentes

```
src/pages/Dashboard/
  index.tsx                  — roteador de role
  GestorDashboard.tsx        — seções 1-4 do gestor
  AdminDashboard.tsx         — seções 1-4 do admin
  components/
    PendenciaCard.tsx        — card de contagem com link
    KpiCard.tsx              — card de métrica (sem link)
    ReservasPorDiaChart.tsx  — bar chart 30 dias
    ReservasPorParqueChart.tsx — bar chart horizontal
    ProximasReservasList.tsx — lista de próximas reservas
    ParqueTable.tsx          — tabela comparativa por parque
    AtividadeRecenteFeed.tsx — feed de atividade
```

---

## Observações

- O campo `role` já existe em `AdminUser` (`Role string`, default `"super_admin"`); o JWT já inclui o role no payload
- `park_id` no JWT: só presente para gestores; admins não têm `park_id`
- Atividade recente: pode ser implementada como view/query dos últimas registros nas tabelas principais, sem uma tabela de audit log separada na primeira versão
