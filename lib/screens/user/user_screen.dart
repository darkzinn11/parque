import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_toast.dart';
import 'profile_edit_screen.dart';
import 'preferencias_screen.dart';
import '../../core/api/api_config.dart';

const _green = Color(0xFF669340);
const _dark  = Color(0xFF32384A);

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
    _loadData();
  }

  void _loadData() {
    final cached = AuthService.instance.currentUser;
    _meFuture = cached != null
        ? Future.value(cached)
        : AuthService.instance.me();
  }

  void _refreshUserData() {
    setState(() {
      _loadData();
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
        final nome = me['nome'] ?? me['name'] ?? '';
        final email = (me['email'] ?? '').toString();
        final displayName = nome.toString().isEmpty ? email : nome.toString();
        
        final String? avatarUrl = me['avatar_url'];

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
                    color: _dark.withValues(alpha: 0.7),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              const SizedBox(height: 16),
              _Item(
                icon: Icons.person_outline, 
                title: 'Dados pessoais',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileEditScreen(),
                    ),
                  ).then((_) => _refreshUserData());
                },
              ),
              _Item(
                icon: Icons.calendar_month_outlined,
                title: 'Minhas reservas',
                onTap: () => context.push('/tabs/user/minhas-reservas'),
              ),
              _Item(
                icon: Icons.settings_outlined, 
                title: 'Preferências',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PreferenciasScreen(),
                    ),
                  );
                },
              ),
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
                    AppToast.show(context, 'Você saiu da conta.', type: ToastType.warning);
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

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap; 
  
  const _Item({required this.icon, required this.title, this.onTap}); 
  
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
      onTap: onTap,
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
    if (url == null || url.isEmpty) return null;
    
    if (url.startsWith('http')) {
      if (url.contains('apps.sitw.com.br') && !url.contains('/backend-park/')) {
        return url.replaceFirst('apps.sitw.com.br/', 'apps.sitw.com.br/backend-park/');
      }
      return url;
    }
    
    final baseUrl = ApiConfig.baseUrl.replaceAll('/api/v1', '');
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanPath';
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return; 

    setState(() => _isUploading = true);

    try {
      final token = await AuthService.instance.token();
      final uri = Uri.parse('${ApiConfig.baseUrl}/me/avatar');

      final request = http.MultipartRequest('POST', uri);
      
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final bytes = await image.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'avatar',
        bytes,
        filename: image.name,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await AuthService.instance.me();
        widget.onUploadComplete();
        if (mounted) {
          AppToast.show(context, 'Foto de perfil atualizada com sucesso!', type: ToastType.success);
        }
      } else {
        if (mounted) {
          AppToast.show(context, 'Erro no upload: ${response.statusCode}', type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Erro ao enviar imagem: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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
                color: Colors.black.withValues(alpha: 0.5),
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