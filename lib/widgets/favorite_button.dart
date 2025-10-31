// lib/widgets/favorite_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/favorites_service.dart';

class FavoriteButton extends StatelessWidget {
  final String parkId;
  final double size;

  const FavoriteButton({
    super.key,
    required this.parkId,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final favs = context.watch<FavoritesService>(); // reage ao estado
    final isFav = favs.isFavorite(parkId);

    return SizedBox(
      width: size + 16, // área de toque maior
      height: size + 16,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: size,
        icon: Icon(
          isFav ? Icons.favorite : Icons.favorite_border,
          color: isFav ? Colors.red : Colors.grey,
        ),
        onPressed: () async {
          // usa read aqui pra não re-buildar duas vezes
          final service = context.read<FavoritesService>();
          service.toggleFavorite(parkId);

          // feedback visual (opcional)
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFav
                  ? 'Removido dos favoritos'
                  : 'Adicionado aos favoritos'),
              duration: const Duration(milliseconds: 900),
            ),
          );
        },
        tooltip: isFav ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
      ),
    );
  }
}
