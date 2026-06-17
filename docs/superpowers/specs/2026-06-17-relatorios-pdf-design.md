# Spec — Sistema de Relatórios PDF

**Data:** 2026-06-17
**Status:** aprovado

## Objetivo

Permitir que gestores e o secretário/admin exportem relatórios de monitoramento em PDF, com logo do Vem Pro Parque, highlights numéricos e tabela de dados completa — para uso em reuniões e prestação de contas.

## Escopo

Relatórios disponíveis em 5 seções do painel admin:
- Reservas
- Solicitações de Evento
- Avaliações
- Denúncias
- Usuários

## Arquitetura

### Endpoint

```
GET /admin/reports/pdf
  ?tipo=reservas|eventos|avaliacoes|denuncias|usuarios
  &inicio=2026-06-01        (ISO date, obrigatório)
  &fim=2026-06-30           (ISO date, obrigatório)
  &park_id=2                (opcional; omitir = todos os parques)
```

**Auth:** JWT admin (middleware `AdminAuthMiddleware` já existente)

**Resposta:**
```
Content-Type: application/pdf
Content-Disposition: attachment; filename="relatorio-reservas-junho-2026.pdf"
```

**RBAC:**
- Role `gestor`: `park_id` extraído do próprio JWT — não pode escolher outro parque
- Role `admin`/`secretario`: pode passar qualquer `park_id` ou omitir para relatório consolidado

### Biblioteca Go

`github.com/johnfercher/maroto/v2` — layout grid + logo + tabela nativa

### Arquivo de logo

`assets/logo-vem-pro-parque.png` no diretório do backend — carregado via path relativo na inicialização

---

## Estrutura do PDF (comum a todos os tipos)

### Cabeçalho
```
[Logo Vem Pro Parque]    [Título do Relatório]    [Período]
──────────────────────────────────────────────── (linha verde #669340)
```

### Bloco de highlights
3–4 métricas em destaque: número grande + label abaixo. Layout horizontal em grid.

### Tabela de dados
- Header: fundo `#669340`, texto branco
- Linhas alternadas: branco / `#F9FAE8`
- Query direta no banco, sem paginação — retorna todos os registros do período

### Rodapé
```
Gerado em 17/06/2026 às 14:32 · Vem Pro Parque · Página 1 de 3
```

---

## Conteúdo por tipo de relatório

### Reservas
**Highlights:** Total · % Aprovadas · % Rejeitadas · % Canceladas

**Tabela:**
| Usuário | Espaço | Data/Hora | Duração | Status | Data Solicitação |

---

### Solicitações de Evento
**Highlights:** Total · % Aprovadas · Pendentes · Tipo mais solicitado

**Tabela:**
| Responsável | Espaço | Data Evento | Tipo Atividade | Qtd Pessoas | Status |

---

### Avaliações
**Highlights:** Total · Nota Média · % Publicadas · % Rejeitadas

**Tabela:**
| Usuário | Parque | Nota | Comentário (máx 120 chars) | Status | Data |

---

### Denúncias
**Highlights:** Total · Novas · Em Análise · % Resolvidas

**Tabela:**
| ID | Endereço | Status | Data Abertura |

*Nota: dados do denunciante não são expostos no relatório (privacidade)*

---

### Usuários
**Highlights:** Total Cadastrados · Novos no Período · Com Reserva Realizada · Cidades

**Tabela:**
| Nome | Email | CPF (XXX.XXX.***-**) | Cidade | Data Cadastro | Reservas Realizadas |

*CPF mascarado: exibir apenas os 3 primeiros grupos, ocultar os últimos 2 dígitos + verificadores*

---

## Frontend (React — PAINEL-PARK)

### Componente reutilizável: `ReportExportButton`

Botão "Exportar PDF" adicionado à barra de ações de cada uma das 5 páginas de gerenciamento.

### Modal de período

```
┌─────────────────────────────────────────┐
│  Exportar Relatório — Reservas          │
│                                         │
│  [Esta semana] [Este mês] [Mês anterior]│
│                                         │
│  ▼ Período personalizado                │
│  De: [__/__/____]  Até: [__/__/____]    │
│                                         │
│  [Cancelar]           [Gerar relatório] │
└─────────────────────────────────────────┘
```

- Botões rápidos calculam `inicio`/`fim` automaticamente
- "Período personalizado" expande dois inputs `type="date"`
- "Gerar relatório" faz GET no endpoint, recebe blob, dispara download via `URL.createObjectURL`
- Durante geração: botão desabilitado + spinner

### Páginas que recebem o botão

| Página | `tipo` | Observação |
|--------|--------|-----------|
| `ReservationsManagement` | `reservas` | |
| `EventRequestsManagement` | `eventos` | |
| `ReviewsManagement` | `avaliacoes` | |
| `DenunciasManagement` | `denuncias` | |
| `UsersManagement` | `usuarios` | |

---

## Backend Go — estrutura de arquivos

```
internal/
  application/usecases/
    report_usecase.go          — orquestra query + geração do PDF
  domain/repositories/
    report_repository.go       — interface com os 5 métodos de query
  infrastructure/
    persistence/
      mysql_report_repository.go — queries SQL por tipo + período + park_id
    pdf/
      report_pdf_generator.go  — renderização via maroto (logo, highlights, tabela)
  http/handlers/
    report_handler.go          — valida params, chama usecase, serve bytes
```

---

## Validações e erros

| Condição | HTTP | Mensagem |
|----------|------|----------|
| `tipo` inválido | 400 | `"tipo inválido: use reservas, eventos, avaliacoes, denuncias ou usuarios"` |
| `inicio` ou `fim` ausente | 400 | `"parametros inicio e fim sao obrigatorios"` |
| `fim` anterior a `inicio` | 400 | `"fim deve ser posterior a inicio"` |
| Período > 366 dias | 400 | `"periodo maximo de 366 dias"` |
| Gestor tentando outro `park_id` | 403 | `"acesso negado"` |
| Nenhum dado no período | 200 | PDF gerado com mensagem "Nenhum registro encontrado no período" na tabela |

---

## Pendências de assets

- Logo `assets/logo-vem-pro-parque.png` precisa ser disponibilizada no backend (PNG, fundo transparente ou branco, mínimo 200×60px)
