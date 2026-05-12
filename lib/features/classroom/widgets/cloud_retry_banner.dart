import 'package:flutter/material.dart';

import '../../../core/services/firebase_service.dart';

/// Red banner shown at the top of management screens when Firebase
/// failed to initialise. Replaces the older `_CloudOffBanner` that
/// required an app restart to recover.
///
/// Tapping **Retry now** calls [FirebaseService.retryInit] which re-runs
/// `Firebase.initializeApp` with the last-used options and re-attempts
/// anonymous sign-in. On success, [onRetrySucceeded] fires so the parent
/// screen can refresh whatever provider was empty before.
///
/// Mounted in:
///   - [ClassroomManagementScreen] (teacher-side)
///   - [HomeGroupManagementScreen] (parent-side)
///
/// The widget is a `StatefulWidget` so it can show a tiny inline
/// progress indicator while the retry is in flight without forcing the
/// parent screen to manage the loading state.
class CloudRetryBanner extends StatefulWidget {
  /// Called after a successful retry so the parent screen can refresh
  /// any provider that gates on [FirebaseService.isConfigured].
  final VoidCallback? onRetrySucceeded;

  const CloudRetryBanner({super.key, this.onRetrySucceeded});

  @override
  State<CloudRetryBanner> createState() => _CloudRetryBannerState();
}

class _CloudRetryBannerState extends State<CloudRetryBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final ok = await FirebaseService.retryInit();
    if (!mounted) return;
    setState(() => _retrying = false);
    if (ok) {
      widget.onRetrySucceeded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud sync reconnected.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Still offline — ${FirebaseService.lastInitError ?? "unknown error"}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.red.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_off_rounded,
                  color: Colors.red.shade900, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cloud sync OFF — local-only mode.',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: _retrying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_retrying ? 'Retrying…' : 'Retry now'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Codes you create here can\'t be joined from other devices. '
            '${FirebaseService.lastInitError ?? ""}',
            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
