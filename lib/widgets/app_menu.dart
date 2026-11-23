import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/assessment_history_screen.dart';
import '../screens/help_options_screen.dart';
import '../theme/app_theme.dart';
import 'emergency_contact_sheet.dart';

/// Put this file in lib/widgets/app_menu.dart
///
/// Contains:
///  - [AppMenuButton]: the 9-dots button for the LEFT side of any AppBar.
///    It also shows a back arrow next to it when the screen can go back.
///  - [AppMenu]: the slide-out drawer and the navigation used by its items.
///  - [UserAvatar]: the user's photo (or first letter).
///  - [ProfileSheet]: photo, name, email, change photo and log out.
///
/// Use it in any screen's AppBar like this:
///   leading: const AppMenuButton(),
///   leadingWidth: AppMenu.leadingWidthFor(context),

/// The signed-in user, or null when Supabase is not set up (for example in
/// automatic tests). Lets the drawer and profile sheet open without a backend.
User? _safeCurrentUser() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

// ============================================================
// APP BAR BUTTON  (unchanged)
// ============================================================

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({
    super.key,
    this.color = Colors.white,
    this.onBack,
    this.onBeforeNavigate,
    this.backEnabled = true,
  });

  /// Icon color. Use a dark color on light / transparent app bars.
  final Color color;

  /// Runs before going back (for example to hang up a voice call).
  final Future<void> Function()? onBack;

  /// Runs before a menu item opens another screen (for example to hang up a
  /// voice call). It does not run when the item is the screen you are on.
  final Future<void> Function()? onBeforeNavigate;

  /// Set to false to disable the back arrow (for example while loading).
  final bool backEnabled;

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canGoBack)
          IconButton(
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back, color: color),
            onPressed: backEnabled
                ? () async {
                    await onBack?.call();
                    if (context.mounted) Navigator.maybePop(context);
                  }
                : null,
          ),
        IconButton(
          tooltip: 'Menu',
          icon: Icon(Icons.apps_rounded, color: color),
          onPressed: () =>
              AppMenu.show(context, onBeforeNavigate: onBeforeNavigate),
        ),
      ],
    );
  }
}

// ============================================================
// MENU DRAWER + NAVIGATION
// ============================================================

class _MenuItem {
  const _MenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.route,
    this.useProfilePhoto = false,
  });

  /// The screen this item opens (null for items that do not navigate).
  final String? route;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool useProfilePhoto;
}

class AppMenu {
  AppMenu._();

  /// Width to give AppBar.leadingWidth so the back arrow + dots both fit.
  static double leadingWidthFor(BuildContext context) =>
      Navigator.of(context).canPop() ? 104 : 56;

  /// Opens a screen from the menu. The first screen of the app stays at the
  /// bottom of the stack, so Back always returns there and the stack never
  /// grows no matter how many times the menu is used.
  static void go(
    BuildContext context,
    String route, {
    Widget Function(BuildContext)? builder,
  }) {
    // Already on this screen.
    if (ModalRoute.of(context)?.settings.name == route) return;

    final nav = Navigator.of(context);

    String? rootName;
    nav.popUntil((r) {
      if (r.isFirst) {
        rootName = r.settings.name;
        return true;
      }
      return false;
    });

    // If the first screen already is the one we want, we are done.
    if (rootName == route) return;

    if (builder != null) {
      // Opens the screen directly, so it works even if the route name is not
      // registered in main.dart.
      nav.push(
        MaterialPageRoute(
          settings: RouteSettings(name: route),
          builder: builder,
        ),
      );
    } else {
      nav.pushNamed(route);
    }
  }

  static void show(
    BuildContext context, {
    Future<void> Function()? onBeforeNavigate,
  }) {
    // To add or remove an item, edit this list.
    final items = <_MenuItem>[
      _MenuItem(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        color: AppTheme.primaryColor,
        route: '/dashboard',
        onTap: () => go(context, '/dashboard'),
      ),
      _MenuItem(
        label: 'Voice',
        icon: Icons.mic_rounded,
        color: const Color(0xFF3498DB),
        route: '/voice_input',
        onTap: () => go(context, '/voice_input'),
      ),
      _MenuItem(
        label: 'Start Assessment',
        icon: Icons.assignment_outlined,
        color: const Color(0xFF27AE60),
        route: '/assessment',
        onTap: () => go(context, '/assessment'),
      ),
      _MenuItem(
        label: 'Past Assessments',
        icon: Icons.library_books_outlined,
        color: const Color(0xFFFDB913),
        route: '/assessment_history',
        onTap: () => go(
          context,
          '/assessment_history',
          builder: (_) => const AssessmentHistoryScreen(),
        ),
      ),
      _MenuItem(
        label: 'History',
        icon: Icons.history_rounded,
        color: const Color(0xFFE74C3C),
        route: '/history',
        onTap: () => go(context, '/history'),
      ),
      _MenuItem(
        label: 'Get Help',
        icon: Icons.support_agent,
        color: const Color(0xFF8E44AD),
        route: '/help',
        onTap: () => go(
          context,
          '/help',
          builder: (_) => const HelpOptionsScreen(),
        ),
      ),
      _MenuItem(
        label: 'Profile',
        icon: Icons.person_rounded,
        color: AppTheme.accentColor,
        onTap: () => ProfileSheet.show(context),
        useProfilePhoto: true,
      ),
    ];

    final currentRoute = ModalRoute.of(context)?.settings.name;
    final drawerWidth = (MediaQuery.of(context).size.width * 0.8).clamp(
      240.0,
      320.0,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // Slides in from the left edge.
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (dialogContext, _, __) {
        return Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            // Swipe left on the drawer to close it.
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -200) {
                Navigator.pop(dialogContext);
              }
            },
            child: Material(
              color: Colors.white,
              elevation: 16,
              shadowColor: Colors.black38,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: drawerWidth,
                height: double.infinity,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          children: [
                            for (final item in items)
                              _buildTile(
                                dialogContext,
                                context,
                                item,
                                currentRoute,
                                onBeforeNavigate,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Top of the drawer: photo, name and email.
  static Widget _buildHeader() {
    final user = _safeCurrentUser();
    final name = UserAvatar.displayName(user);
    final email = user?.email ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          UserAvatar(radius: 28, background: AppTheme.primaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.quicksand(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.quicksand(
                      fontSize: 12,
                      color: const Color(0xFF999999),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTile(
    BuildContext dialogContext,
    BuildContext hostContext,
    _MenuItem item,
    String? currentRoute,
    Future<void> Function()? onBeforeNavigate,
  ) {
    final selected = item.route != null && item.route == currentRoute;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        selected: selected,
        selectedTileColor: item.color.withOpacity(0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: item.useProfilePhoto
            ? UserAvatar(radius: 20, background: item.color)
            : CircleAvatar(
                radius: 20,
                backgroundColor: item.color.withOpacity(0.15),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
        title: Text(
          item.label,
          style: GoogleFonts.quicksand(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: AppTheme.darkColor,
          ),
        ),
        onTap: () async {
          Navigator.pop(dialogContext); // close the drawer first

          final leaving =
              item.route != null &&
              ModalRoute.of(hostContext)?.settings.name != item.route;
          if (leaving) await onBeforeNavigate?.call();

          if (!hostContext.mounted) return;
          item.onTap();
        },
      ),
    );
  }
}

// ============================================================
// USER AVATAR  (unchanged)
// ============================================================

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.radius = 18, this.background});

  final double radius;
  final Color? background;

  /// The photo to show: the one the user uploaded, otherwise the Google
  /// profile photo, otherwise null.
  static String? photoUrl(User? user) {
    final meta = user?.userMetadata;
    if (meta == null) return null;
    for (final key in ['profile_photo_url', 'avatar_url', 'picture']) {
      final value = meta[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Full name (or the start of the email), first letter capitalized.
  static String displayName(User? user) {
    final meta = user?.userMetadata;
    final name =
        (meta?['full_name'] ??
                meta?['name'] ??
                user?.email?.split('@').first ??
                'User')
            .toString();
    if (name.isEmpty) return 'User';
    return name[0].toUpperCase() + name.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final user = _safeCurrentUser();
    final name = displayName(user);
    final url = photoUrl(user);

    final fallback = Text(
      name[0].toUpperCase(),
      style: GoogleFonts.quicksand(
        fontSize: radius * 0.9,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: background ?? Colors.white24,
      child: url == null
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}

// ============================================================
// PROFILE SHEET (photo, name, email, log out)  (unchanged)
// ============================================================

class ProfileSheet {
  ProfileSheet._();

  /// Completes when the sheet is closed, so a screen can refresh itself.
  static Future<void> show(BuildContext context) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _ProfileSheetBody(navigator: navigator, messenger: messenger),
    );
  }
}

class _ProfileSheetBody extends StatefulWidget {
  const _ProfileSheetBody({required this.navigator, required this.messenger});

  final NavigatorState navigator;
  final ScaffoldMessengerState messenger;

  @override
  State<_ProfileSheetBody> createState() => _ProfileSheetBodyState();
}

class _ProfileSheetBodyState extends State<_ProfileSheetBody> {
  bool _busy = false;

  User? get _user => _safeCurrentUser();

  bool get _hasCustomPhoto {
    final value = _user?.userMetadata?['profile_photo_url'];
    return value is String && value.isNotEmpty;
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _user;
    if (user == null) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      // The user closed the gallery without choosing a picture.
      if (picked == null) return;

      if (mounted) setState(() => _busy = true);

      final bytes = await picked.readAsBytes();
      final path = '${user.id}/avatar.jpg';
      final storage = Supabase.instance.client.storage.from('avatars');

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: picked.mimeType ?? 'image/jpeg',
        ),
      );

      // The version number makes the app load the new picture instead of
      // showing the old one from its cache.
      final url =
          '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'profile_photo_url': url}),
      );

      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('PHOTO UPLOAD ERROR: $e');
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Could not upload photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = _user;
    if (user == null) return;

    try {
      setState(() => _busy = true);

      await Supabase.instance.client.storage.from('avatars').remove([
        '${user.id}/avatar.jpg',
      ]);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'profile_photo_url': null}),
      );
    } catch (e) {
      debugPrint('PHOTO REMOVE ERROR: $e');
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Could not remove photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    Navigator.pop(context); // close the sheet

    try {
      await Supabase.instance.client.auth.signOut();
      widget.navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  // ---------------- REMOVE ACCOUNT (permanent) ----------------

  Future<void> _confirmDeleteAccount() async {
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Remove account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your account and all your data: '
                'assessments, moods and history. This cannot be undone.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Type DELETE to confirm',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: controller.text.trim() == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text(
                'Delete forever',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null) return;

    setState(() => _busy = true);

    try {
      // Profile photo (not a problem if there is none).
      try {
        await Supabase.instance.client.storage.from('avatars').remove([
          '${user.id}/avatar.jpg',
        ]);
      } catch (_) {}

      // Deletes the data and the login. See delete_account.sql.
      await Supabase.instance.client.rpc('delete_user');

      // The login no longer exists; this just clears the phone's session.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      widget.navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('DELETE ACCOUNT ERROR: $e');
      widget.messenger.showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = UserAvatar.displayName(user);
    final email = user?.email ?? '';
    final hasPhoto = UserAvatar.photoUrl(user) != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _busy
                ? SizedBox(
                    width: 88,
                    height: 88,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                : UserAvatar(radius: 44, background: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(
              name,
              style: GoogleFonts.quicksand(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
              ),
            ),
            if (email.isNotEmpty)
              Text(
                email,
                style: GoogleFonts.quicksand(
                  fontSize: 13,
                  color: const Color(0xFF999999),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(hasPhoto ? 'Change photo' : 'Upload a photo'),
              ),
            ),
            if (_hasCustomPhoto)
              TextButton(
                onPressed: _busy ? null : _removePhoto,
                child: const Text(
                  'Remove photo',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => EmergencyContactSheet.show(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.contact_phone_outlined),
                label: Text(
                  'Emergency contact',
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _confirmLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Log out',
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _confirmDeleteAccount,
              icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
              label: Text(
                'Remove account',
                style: GoogleFonts.quicksand(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}