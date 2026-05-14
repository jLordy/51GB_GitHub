import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/calendar/presentation/screens/doctor_calendar_screen.dart';
import 'package:frontend/features/calendar/presentation/screens/patient_calendar_screen.dart';
import 'package:frontend/features/notifications/presentation/screen/notification_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/doctor_home_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/home_screen.dart';
import 'package:frontend/features/dashboard/presentation/screens/patients_screen.dart';
import 'package:frontend/features/connections/presentation/screens/connections_screen.dart';
import 'package:frontend/features/settings/presentation/screens/account_security_screen.dart';
import 'package:frontend/features/settings/presentation/screens/change_theme_screen.dart';
import 'package:frontend/features/settings/presentation/screens/delete_account_screen.dart';
import 'package:frontend/features/settings/presentation/screens/private_account_screen.dart';
import 'package:frontend/features/settings/presentation/screens/profile_settings_screen.dart';
import 'package:frontend/features/settings/presentation/screens/settings_screen.dart';
import 'package:frontend/features/journal/presentation/screens/patient_journal_folder_screen.dart';
import 'package:frontend/features/file/presentation/screens/documents_screen.dart';
import 'package:frontend/features/file/presentation/screens/folder_documents_screen.dart';
import 'package:frontend/features/file/presentation/screens/pdf_viewer_screen.dart';
import 'package:frontend/features/journal/presentation/screens/monitoring_screen.dart';
import 'package:frontend/features/report/presentation/screens/report_screen.dart';
import 'package:frontend/features/chat/presentation/screens/chat_screen.dart';
import 'package:frontend/features/reminder/presentation/screens/reminder_screen.dart';
import 'package:frontend/features/chat/presentation/screens/conversations_screen.dart';
import 'package:frontend/features/chat/model/conversation_model.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/auth/controller/auth_provider.dart';
import 'package:frontend/features/auth/model/user_model.dart';
import 'package:frontend/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:frontend/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend/features/auth/presentation/screens/register_screen.dart';
import 'package:frontend/features/auth/presentation/screens/role_selection_screen.dart';
import 'package:frontend/features/assistance/presentation/screens/assistance_screen.dart';
import 'package:frontend/features/lifestyle/presentation/screens/lifestyle_screen.dart';
import 'package:frontend/features/journal/presentation/screens/journal_screen.dart';
import 'package:frontend/features/onboarding/presentation/screens/onboarding_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.onDispose(refreshNotifier.dispose);

  void triggerRefresh() {
    refreshNotifier.value++;
  }

  ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
    final wasSignedIn = prev?.asData?.value != null;
    final isSignedIn = next.asData?.value != null;
    if (wasSignedIn != isSignedIn) triggerRefresh();
  });

  ref.listen<UserModel?>(currentUserProvider, (prev, next) {
    final prevRole = prev?.role;
    final nextRole = next?.role;
    final prevStatus = prev?.status;
    final nextStatus = next?.status;
    if (prevRole != nextRole || prevStatus != nextStatus) triggerRefresh();
  });

  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/login',
    refreshListenable: refreshNotifier,

    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final currentUser = ref.read(currentUserProvider);

      if (authState.isLoading) return null;

      final firebaseUser = authState.asData?.value;
      final isAuthenticated = firebaseUser != null && !firebaseUser.isAnonymous;
      final isPending = currentUser?.role.toLowerCase() == 'pending';

      final location = state.uri.toString();
      final isAuthPage = location == '/login' ||
          location == '/register' ||
          location == '/email-verification' ||
          location == '/forgot-password';
      final isRoleSelectionPage = location == '/role-selection';

      if (!isAuthenticated && !isAuthPage && !isRoleSelectionPage) {
        return '/login';
      }

      if (isAuthenticated && isPending && !isRoleSelectionPage) {
        return '/role-selection';
      }

      final role = currentUser?.role.toLowerCase() ?? '';
      final isDoctor = role == 'doctor' || role == 'secretary';
      final defaultHome = isDoctor ? '/doctor-dashboard' : '/home';

      if (isAuthenticated && !isPending && isRoleSelectionPage) {
        return defaultHome;
      }

      if (isAuthenticated && isAuthPage) return defaultHome;

      // Guard: doctor/secretary landed on patient home (race on role load)
      if (isAuthenticated && !isPending && isDoctor && location == '/home') {
        return '/doctor-dashboard';
      }
      // Guard: patient/caregiver landed on doctor dashboard
      if (isAuthenticated && !isPending && !isDoctor && location == '/doctor-dashboard') {
        return '/home';
      }

      return null;
    },

    routes: [
      /// 🔐 Auth
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildAuthSlidePage(
          state: state,
          child: const LoginScreen(),
          isForward: false,
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _buildAuthSlidePage(
          state: state,
          child: const RegisterScreen(),
          isForward: true,
        ),
      ),
      GoRoute(
        path: '/email-verification',
        pageBuilder: (context, state) {
          final args = state.extra as EmailVerificationArgs?;
          if (args == null) {
            return _buildAuthSlidePage(
              state: state,
              child: const RegisterScreen(),
              isForward: false,
            );
          }
          return _buildAuthSlidePage(
            state: state,
            child: EmailVerificationScreen(args: args),
            isForward: true,
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _buildAuthSlidePage(
          state: state,
          child: const ForgotPasswordScreen(),
          isForward: true,
        ),
      ),

      /// 🎭 Role selection — shown once to new users before journal access
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      /// 🧭 Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      /// 📓 Journal
      GoRoute(
        path: '/journal',
        builder: (context, state) => const JournalScreen(),
      ),

      /// 📓 Monitoring
      GoRoute(
        path: '/monitoring',
        builder: (context, state) => const MonitoringScreen(),
      ),

      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/doctor-dashboard',
        builder: (context, state) => const DoctorHomeScreen(),
      ),
      GoRoute(
        path: '/patients',
        builder: (context, state) => const PatientsScreen(),
      ),
      GoRoute(
        path: '/connections',
        builder: (context, state) => const ConnectionsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/profile',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/account-security',
        builder: (context, state) => const AccountSecurityScreen(),
      ),
      GoRoute(
        path: '/settings/theme',
        builder: (context, state) => const ChangeThemeScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivateAccountScreen(),
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/patients-journal',
        builder: (context, state) => const PatientJournalFolderScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) {
          final role = ref.read(currentUserProvider)?.role.toLowerCase() ?? '';
          final isDoctor = role == 'doctor' || role == 'secretary';
          return isDoctor ? const DoctorCalendarScreen() : const PatientCalendarScreen();
        },
      ),
      GoRoute(
        path: '/report',
        builder: (context, state) => const ReportScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: '/reminder',
        builder: (context, state) => const ReminderScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final conv = state.extra as ConversationModel;
          return ChatScreen(conversation: conv);
        },
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const DocumentsScreen(),
        routes: [
          GoRoute(
            path: ':folderId',
            builder: (context, state) {
              final folderId = state.pathParameters['folderId']!;
              final extra = (state.extra as Map?)?.cast<String, String?>() ?? {};
              return FolderDocumentsScreen(
                folderId: folderId,
                folderName: extra['name'] ?? '',
                patientUid: extra['patientUid'],
              );
            },
            routes: [
              GoRoute(
                path: 'view',
                builder: (context, state) => PdfViewerScreen(
                  fileUrl: state.uri.queryParameters['url'] ?? '',
                  fileName: state.uri.queryParameters['name'] ?? '',
                  fileType: state.uri.queryParameters['type'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/assistance',
        builder: (context, state) => const AssistanceScreen(),
      ),
      GoRoute(
        path: '/lifestyle',
        builder: (context, state) => const LifestyleScreen(),
      ),
    ],
  );
});

CustomTransitionPage<void> _buildAuthSlidePage({
  required GoRouterState state,
  required Widget child,
  required bool isForward,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final begin = Offset(isForward ? 1.0 : -1.0, 0.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end)
          .chain(CurveTween(curve: Curves.easeInOut));
      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}
