# Map Screen Improvements — Design Spec
**Data:** 2026-06-05  
**Status:** Aprovado — pronto para implementação

---

## Contexto

A tela de mapa (`lib/screens/map_screen.dart`) exibe parques com pins, barra de busca e carousel de cards. A única interação disponível é tocar no card para centralizar o mapa. O objetivo é adicionar interações úteis sem mudar o visual existente.

---

## Escopo

### 1. Distância nos cards do carousel

**Onde:** badge sobre a foto do card, canto inferior esquerdo (não conflita com o botão de favorito no canto superior direito).

**Como:**
- Ao carregar os parques, tenta obter localização do usuário via `geolocator`.
- Se obtiver permissão: calcula distância em linha reta com `Geolocator.distanceBetween()` e exibe no badge.
- Se permissão negada ou localização indisponível: omite o badge silenciosamente (sem mensagem de erro).
- Formato: `"1,2 km"` para < 10 km; `"12 km"` para ≥ 10 km.

**Visual:**
- Badge branco semitransparente, `borderRadius: 8`, padding horizontal `6`, padding vertical `3`.
- Fonte Poppins 10px w700, cor `kDarkGray`.
- Posicionado via `Positioned(bottom: 6, left: 6)` dentro do Stack da imagem.

---

### 2. Bottom sheet ao tocar em pin ou card

**Trigger:** tocar em qualquer marker do mapa **ou** tocar em um card do carousel.

**Comportamento atual do carousel:** tocar no card centra o mapa. Novo comportamento: centra o mapa **e** abre o bottom sheet.

**Comportamento atual do pin:** apenas chama `_jumpToPark()`. Novo comportamento: chama `_jumpToPark()` **e** abre o bottom sheet.

**Implementação:** `showModalBottomSheet` com `backgroundColor: Colors.transparent`, `isScrollControlled: false`.

**Conteúdo do sheet:**
```
┌─────────────────────────────┐
│  [handle bar centralizado]  │
│  [hero image 140px altura]  │
│  Nome do parque  ★ 4.8      │
│  🟢 Aberto agora  · 2,3 km  │  ← distância aparece aqui também (se disponível)
│  ┌──────────┐ ┌──────────┐  │
│  │  Rotas   │ │ Detalhes │  │
│  └──────────┘ └──────────┘  │
└─────────────────────────────┘
```

- Background branco, `borderRadius` 20 no topo.
- Hero image: `CachedNetworkImage`, `borderRadius: 12`, altura fixa 140px.
- Nome: Poppins 18px w700, cor `kBrandGreen`.
- Rating: chip verde claro igual ao `_ChipRating` do `ParkDetailScreen`.
- Status: ponto verde + texto Poppins 13px (usa `park.status` se disponível).
- Distância: mesmo formato dos cards, exibida na linha do status se disponível.
- Botão **Rotas**: `OutlinedButton`, border `kBrandGreen`, texto `kBrandGreen`.
- Botão **Ver detalhes**: `FilledButton`, background `kBrandGreen`.
  - Navega via `context.go(AppRoutes.homePark(park.documentId))` ou `context.push('/parks/${park.documentId}')` dependendo de onde o mapa foi aberto.

---

### 3. Picker de apps de navegação ("Rotas")

**Trigger:** botão "Rotas" no bottom sheet.

**Implementação:** `showModalBottomSheet` simples (não transparente, fundo branco).

**Conteúdo:**
- Título "Como quer ir?" (Poppins 16px w700).
- Lista de opções, cada uma como `ListTile` com ícone e nome do app.
- Só exibe apps cujo deep link o dispositivo consegue abrir (`canLaunchUrl`).
- Ordem: Waze → Google Maps → Apple Maps.
- Fallback: se nenhum estiver instalado, abre `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}` no browser.

**Deep links:**
| App | URL |
|-----|-----|
| Waze | `waze://ul?ll={lat},{lng}&navigate=yes` |
| Google Maps | `google.navigation:q={lat},{lng}` |
| Apple Maps (iOS) | `maps://maps.apple.com/?daddr={lat},{lng}` |

---

## Dependências

- `geolocator` — já deve estar no pubspec; confirmar antes de adicionar.
- `url_launcher` — já presente (usado em outras telas).
- `cached_network_image` — já presente.

---

## O que NÃO muda

- Layout geral da tela (mapa + barra de busca + carousel).
- Visual dos cards (tamanho, sombra, imagem, botão favorito).
- `PlaceSearchDelegate` (busca por texto).
- Lógica de `_applyTargetFocus` (foco ao vir do detalhe de parque).

---

## Arquivos afetados

- `lib/screens/map_screen.dart` — único arquivo alterado.
- `pubspec.yaml` — se `geolocator` não estiver listado.
