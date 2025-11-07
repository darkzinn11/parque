// lib/widgets/favorite_button.dart
import 'package:flutter/material.dart';
import '../services/favorites_service.dart'; // Importa o serviço

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    // --- CORREÇÃO: Parâmetro atualizado ---
    this.parkDocumentId, 
    this.activityId,
    this.size = 32,
  });

  final String? parkDocumentId;
  final String? activityId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: FavoritesService.instance,
      builder: (context, _) {
        
        // --- CORREÇÃO: Chama a função 'isFavoriteByDoc' ---
        final bool isFav;
        if (parkDocumentId != null) {
          isFav = FavoritesService.instance.isFavoriteByDoc(parkDocumentId!); 
        } else if (activityId != null) {
          // isFav = FavoritesService.instance.isFavoriteActivity(activityId!);
          isFav = false;
        } else {
          isFav = false;
        }

        return GestureDetector(
          onTap: () async {
            // --- CORREÇÃO: Chama a função 'toggleByDocumentId' ---
            if (parkDocumentId != null) {
              await FavoritesService.instance.toggleByDocumentId(parkDocumentId!);
            }
          },
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9), // Fundo branco
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? const Color(0xFFFF5A5F) : Colors.grey, // Coração vermelho
              size: size * 0.6,
            ),
          ),
        );
      },
    );
  }
}