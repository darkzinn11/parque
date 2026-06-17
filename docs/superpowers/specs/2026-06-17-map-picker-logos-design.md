# Map App Picker — Logos Reais

**Data:** 2026-06-17
**Status:** Aprovado

## Problema

O seletor de app de mapa atual usa ícones genéricos do Material (`Icons.navigation_rounded`, `Icons.map_rounded`) em containers coloridos. O usuário precisa ler o texto para saber qual app é qual. Apps grandes (iFood, Rappi, 99, Uber) usam os logos reais dos apps, que são reconhecidos em frações de segundo.

## Solução

Substituir os ícones genéricos por logos PNG oficiais do Waze e Google Maps, exibidos em 2 cards horizontais lado a lado no bottom sheet.

## Layout

Bottom sheet com drag handle, título "Como quer ir?" e nome do parque como subtítulo — estrutura existente mantida.

Corpo: `Row` com dois `Expanded`, cada um sendo um card:
- Fundo branco, `borderRadius: 16`, sombra suave (blur 8, opacidade 8%)
- `InkWell` com `borderRadius: 16` para tap ripple
- Logo PNG `56×56` centralizado com `Image.asset`
- Nome do app abaixo, Poppins 13 semibold, `kDarkGray`
- `padding: EdgeInsets.all(20)`

```
┌──────────────────┐  ┌──────────────────┐
│                  │  │                  │
│   [waze.png]     │  │ [google_maps.png] │
│                  │  │                  │
│      Waze        │  │   Google Maps    │
└──────────────────┘  └──────────────────┘
```

## Assets

Localização: `assets/images/maps/`

| Arquivo | App | Formato |
|---------|-----|---------|
| `waze.png` | Waze | PNG fundo transparente, mínimo 256×256 |
| `google_maps.png` | Google Maps | PNG fundo transparente, mínimo 256×256 |

Declarar no `pubspec.yaml`:
```yaml
assets:
  - assets/images/maps/
```

## Comportamento

- Waze e Google Maps exibidos em **ambas as plataformas** (iOS e Android) — sem filtro por plataforma
- Apple Maps removido completamente
- Tap: tenta URL nativa primeiro, fallback para URL web se app não instalado:
  - Waze nativa: `waze://ul?ll=$lat,$lng&navigate=yes` → web: `https://waze.com/ul?ll=$lat,$lng&navigate=yes`
  - Google Maps nativa: `comgooglemaps://?daddr=$lat,$lng&directionsmode=driving` → web: `https://maps.google.com/?daddr=$lat,$lng`
- Sheet fecha após qualquer seleção

## Mudanças em `map_screen.dart`

- `_NavApp.iosOnly` e todo o filtro de plataforma removidos
- `_NavApp.iconData` / `_NavApp.iconColor` substituídos por `_NavApp.assetPath: String`
- `_RoutePickerSheetState.build`: `Column` com `Row` de 2 cards no lugar do `...apps.map(ListTile)` atual
- `_NavApp._apps`: apenas Waze e Google Maps
