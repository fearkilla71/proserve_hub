import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dispute_admin_tab.dart';
import 'job_admin_tab.dart';
import 'payment_operations_tab.dart';

class AdminOperationsScreen extends StatelessWidget {
  const AdminOperationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sign in required')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Operations')),
            body: Center(child: Text('Admin check failed: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data?.exists != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Operations')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Admin access required. This screen is only available to approved operators.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Admin Operations'),
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.payments_outlined), text: 'Payments'),
                  Tab(icon: Icon(Icons.work_outline), text: 'Jobs'),
                  Tab(
                    icon: Icon(Icons.report_problem_outlined),
                    text: 'Disputes',
                  ),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                PaymentOperationsTab(),
                JobAdminTab(),
                DisputeAdminTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}
