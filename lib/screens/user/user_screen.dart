import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:http/http.dart' as http; 
import '../../services/auth_service.dart';

const _green = Color(0xFF669340);
const _dark  = Color(0xFF32384A);

// ADICIONE A URL DO SEU STRAPI AQUI
const String kStrapiBaseUrl = 'http://192.168.15.12:1337';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key, this.onChanged});
  final VoidCallback? onChanged;

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late Future<Map<String, dynamic>?> _meFuture;

  @override
  void initState() {
    super.initState();
    _meFuture = AuthService.instance.me();
  }

  void _refreshUserData() {
    setState(() {
      _meFuture = AuthService.instance.me(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _meFuture, 
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: _green)),
          );
        }

        if (!snap.hasData || snap.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.goNamed('user_login'); 
            }
          });
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: _green)),
          );
        }

        final me = snap.data!;
        final nome = me['name'] ?? '${me['first_name'] ?? ''} ${me['last_name'] ?? ''}'.trim();
        final email = (me['email'] ?? '').toString();
        final displayName = nome.isEmpty ? email : nome;
        
        final avatarData = me['avatar'];
        final String? avatarUrl = (avatarData is Map && avatarData['url'] != null) 
                                    ? avatarData['url'] 
                                    : null;

        return Scaffold(
          backgroundColor: Colors.white, 
          body: ListView(
            padding: const EdgeInsets.all(16), 
            children: [
              const SizedBox(height: 84), 
              
              Center(
                child: _AvatarEdit(
                  userId: me['id'].toString(), 
                  avatarUrl: avatarUrl,
                  onUploadComplete: _refreshUserData, 
                ),
              ),
              
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  email,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _dark.withOpacity(0.7),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              const SizedBox(height: 16),
              const _Item(icon: Icons.person_outline, title: 'Dados pessoais'),
              const _Item(icon: Icons.calendar_month_outlined, title: 'Minhas reservas'),
              const _Item(icon: Icons.settings_outlined, title: 'Preferências'),
              const SizedBox(height: 24),

              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), 
                  ),
                ),
                onPressed: () async {
                  await AuthService.instance.logout();
                  widget.onChanged?.call(); 
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Você saiu da conta.')),
                    );
                    context.go('/tabs/user'); 
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sair',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.logout, size: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Widget _Item (Menu)
class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Item({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _dark),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: _dark,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: _dark, size: 20),
      onTap: () {
        // TODO: navegações específicas
      },
    );
  }
}

class _AvatarEdit extends StatefulWidget {
  const _AvatarEdit({
    required this.userId,
    this.avatarUrl,
    required this.onUploadComplete,
  });

  final String userId;
  final String? avatarUrl;
  final VoidCallback onUploadComplete;

  @override
  State<_AvatarEdit> createState() => _AvatarEditState();
}

class _AvatarEditState extends State<_AvatarEdit> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  String? _getFullAvatarUrl(String? url) {
    if (url == null) return null;
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$kStrapiBaseUrl$url';
    return '$kStrapiBaseUrl/$url';
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return; 

    setState(() => _isUploading = true);

    try {
      final token = await AuthService.instance.token();
      if (token == null) throw Exception('Usuário não autenticado');

      final uri = Uri.parse('$kStrapiBaseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('files', image.path));
      
      request.fields['ref'] = 'plugin::users-permissions.user'; 
      request.fields['refId'] = widget.userId; 
      request.fields['field'] = 'avatar'; 

      final response = await request.send();

      // --- CORREÇÃO AQUI ---
      // Agora aceita 200 (OK) ou 201 (Created) como sucesso!
      if (response.statusCode == 200 || response.statusCode == 201) {
        // --- FIM DA CORREÇÃO ---

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada!')),
        );
        widget.onUploadComplete(); 
      } else {
        final respStr = await response.stream.bytesToString();
        throw Exception('Falha no upload: ${response.statusCode} $respStr');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar imagem: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullAvatarUrl = _getFullAvatarUrl(widget.avatarUrl);

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none, 
        children: [
          CircleAvatar(
            radius: 48, 
            backgroundColor: const Color(0xFFE1E1E5), 
            backgroundImage: fullAvatarUrl != null 
                              ? NetworkImage(fullAvatarUrl) 
                              : null,
            child: (fullAvatarUrl == null && !_isUploading)
                ? const Icon(Icons.person, size: 48, color: Colors.white70)
                : null,
          ),
          
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector( 
              onTap: _isUploading ? null : _pickAndUploadImage, 
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _green, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2), 
                ),
                child: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

          if (_isUploading)
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}