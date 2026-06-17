import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_overview_tab.dart';
import 'dispute_admin_tab.dart';
import 'job_admin_tab.dart';
import 'moderation_admin_tab.dart';
import 'payment_operations_tab.dart';
import '../../l10n/app_localizations.dart';

class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.signInRequired)));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.adminOperationsTitle)),
            body: Center(
              child: Text(l10n.adminCheckFailed(snapshot.error.toString())),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data?.exists != true) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.adminOperationsTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.adminAccessRequired,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.adminOperationsTitle),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.dashboard_outlined),
                    text: l10n.adminOverviewTab,
                  ),
                  Tab(
                    icon: const Icon(Icons.payments_outlined),
                    text: l10n.adminPaymentsTab,
                  ),
                  Tab(icon: const Icon(Icons.work_outline), text: l10n.jobs),
                  Tab(
                    icon: const Icon(Icons.report_problem_outlined),
                    text: l10n.adminDisputesTab,
                  ),
                  Tab(
                    icon: const Icon(Icons.flag_outlined),
                    text: l10n.adminModerationTab,
                  ),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                AdminOverviewTab(),
                PaymentOperationsTab(),
                JobAdminTab(),
                DisputeAdminTab(),
                ModerationAdminTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}
