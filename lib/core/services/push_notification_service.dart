import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────
// Handler de background (precisa ser top-level, fora de classe)
// Chamado quando o app está em segundo plano ou encerrado
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase já está inicializado neste ponto pelo sistema
  log('[FCM] 📩 Mensagem em background recebida: ${message.messageId}');
  log('[FCM]   title: ${message.notification?.title}');
  log('[FCM]   body:  ${message.notification?.body}');
  log('[FCM]   data:  ${message.data}');
}

// ─────────────────────────────────────────────────────────────
// PushNotificationService
// ─────────────────────────────────────────────────────────────
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Referência ao router — injetada antes de chamar initialize()
  GoRouter? _router;

  /// BuildContext para mostrar banners no foreground
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ── Inicialização principal ───────────────────────────────
  Future<void> initialize({required GoRouter router}) async {
    _router = router;

    // 1. Registra o handler de background (deve ser chamado antes de tudo)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Solicita permissão (obrigatório no iOS, opcional no Android 13+)
    await _requestPermission();

    // 3. Configura apresentação de notificações em foreground no iOS
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Obtém e loga o token do dispositivo
    await _getToken();

    // 5. Inscreve no tópico padrão
    await _subscribeToTopics();

    // 6. Listeners dos 3 estados de recebimento
    _listenForeground();
    _listenBackground();
    await _handleTerminated();

    log('[FCM] ✅ PushNotificationService inicializado com sucesso.');
  }

  // ── Permissões ────────────────────────────────────────────
  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    log('[FCM] 🔐 Status de permissão: ${settings.authorizationStatus.name}');
  }

  // ── Token ────────────────────────────────────────────────
  Future<void> _getToken() async {
    try {
      final token = await _fcm.getToken();
      log('══════════════════════════════════════════════');
      log('[FCM] 📲 FCM TOKEN DO DISPOSITIVO:');
      log(token ?? 'TOKEN NULO');
      log('══════════════════════════════════════════════');
      // TODO: envie este token ao seu backend para mensagens diretas (device-to-device)
    } catch (e) {
      log('[FCM] ❌ Erro ao obter token: $e');
    }

    // Listener para quando o token é renovado
    _fcm.onTokenRefresh.listen((newToken) {
      log('[FCM] 🔄 Token renovado: $newToken');
      // TODO: atualizar token no backend
    });
  }

  // ── Inscrição em tópicos ──────────────────────────────────
  Future<void> _subscribeToTopics() async {
    await _fcm.subscribeToTopic('noticias_gerais');
    log('[FCM] 📌 Inscrito no tópico: noticias_gerais');
    // Para enviar para TODOS os usuários, use o tópico "noticias_gerais"
    // no painel do Firebase: Messaging → Nova campanha → Tópico
  }

  // ── Estado 1: App em primeiro plano ──────────────────────
  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('[FCM] 🟢 Foreground: ${message.notification?.title}');
      _showInAppBanner(message);
    });
  }

  // ── Estado 2: App em segundo plano, usuário toca ─────────
  void _listenBackground() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('[FCM] 🟡 Background tap: ${message.data}');
      _routeFromMessage(message);
    });
  }

  // ── Estado 3: App fechado, abriu pela notificação ────────
  Future<void> _handleTerminated() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      log('[FCM] 🔴 Terminated tap: ${message.data}');
      // Aguarda o router estar pronto antes de navegar
      await Future.delayed(const Duration(milliseconds: 500));
      _routeFromMessage(message);
    }
  }

  // ── Roteamento por deep link ──────────────────────────────
  //
  // Payload esperado (data message):
  //   {
  //     "title": "...",
  //     "body":  "...",
  //     "type":  "news" | "live",
  //     "link":  "<post_id>" | "live"
  //   }
  void _routeFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final link = data['link'] as String?;

    log('[FCM] 🗺️ Roteando: type=$type  link=$link');

    if (_router == null) {
      log('[FCM] ⚠️ Router não injetado, navegação ignorada.');
      return;
    }

    if (type == 'live') {
      // → Tela Ao Vivo / YouTube
      _router!.go('/live');
    } else if (type == 'news' && link != null && link.isNotEmpty) {
      // → Tela de detalhe da matéria
      _router!.go('/article/$link');
    } else {
      log('[FCM] ⚠️ Payload sem type/link reconhecido: $data');
    }
  }

  // ── Banner in-app para mensagens em foreground ────────────
  void _showInAppBanner(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'TVI News';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        '';
    final type = message.data['type'] as String?;
    final link = message.data['link'] as String?;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: type == 'live'
                    ? const Color(0xFFFF0000)
                    : const Color(0xFFFF6B00),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'live'
                    ? Icons.live_tv_rounded
                    : Icons.newspaper_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: type == 'live' ? 'VER AO VIVO' : 'LER',
          textColor: type == 'live'
              ? const Color(0xFFFF0000)
              : const Color(0xFFFF6B00),
          onPressed: () {
            if (type == 'live') {
              _router?.go('/live');
            } else if (type == 'news' && link != null) {
              _router?.go('/article/$link');
            }
          },
        ),
      ),
    );
  }
}
