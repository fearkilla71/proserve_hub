import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';

class ProjectTimelineScreen extends StatelessWidget {
  final String jobId;

  const ProjectTimelineScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Timeline')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('job_requests')
            .doc(jobId)
            .get(),
        builder: (context, jobSnapshot) {
          if (!jobSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final jobData = jobSnapshot.data!.data() as Map<String, dynamic>?;
          if (jobData == null) {
            return const Center(child: Text('Job not found'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('job_requests')
                .doc(jobId)
                .collection('milestones')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (context, milestonesSnapshot) {
              if (!milestonesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final milestones = milestonesSnapshot.data!.docs;

              // Build timeline events
              final events = <TimelineEvent>[];

              // Job created
              final createdAt = jobData['createdAt'] as Timestamp?;
              if (createdAt != null) {
                events.add(
                  TimelineEvent(
                    title: 'Job Created',
                    description: jobData['serviceName']?.toString() ?? '',
                    timestamp: createdAt,
                    status: 'completed',
                    icon: Icons.description,
                  ),
                );
              }

              // Job assigned
              final assignedAt = jobData['assignedAt'] as Timestamp?;
              if (assignedAt != null) {
                events.add(
                  TimelineEvent(
                    title: 'Contractor Assigned',
                    description: 'Work can now begin',
                    timestamp: assignedAt,
                    status: 'completed',
                    icon: Icons.person_add,
                  ),
                );
              }

              // Add milestones
              for (var doc in milestones) {
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title']?.toString() ?? 'Milestone';
                final description = data['description']?.toString() ?? '';
                final status = data['status']?.toString() ?? 'pending';
                final timestamp =
                    data['completedAt'] as Timestamp? ??
                    data['createdAt'] as Timestamp?;

                if (timestamp != null) {
                  events.add(
                    TimelineEvent(
                      title: title,
                      description: description,
                      timestamp: timestamp,
                      status: status,
                      icon: Icons.flag,
                    ),
                  );
                }
              }

              // Job completion
              final completedAt = jobData['completedAt'] as Timestamp?;
              if (completedAt != null) {
                events.add(
                  TimelineEvent(
                    title: 'Job Completed',
                    description: 'Work finished successfully',
                    timestamp: completedAt,
                    status: 'completed',
                    icon: Icons.check_circle,
                  ),
                );
              } else {
                // Add expected completion if available
                final expectedCompletion =
                    jobData['expectedCompletion'] as Timestamp?;
                if (expectedCompletion != null) {
                  events.add(
                    TimelineEvent(
                      title: 'Expected Completion',
                      description: 'Target completion date',
                      timestamp: expectedCompletion,
                      status: 'pending',
                      icon: Icons.schedule,
                    ),
                  );
                }
              }

              // Sort events by timestamp
              events.sort((a, b) => a.timestamp.compareTo(b.timestamp));

              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timeline,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No timeline events yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final isFirst = index == 0;
                  final isLast = index == events.length - 1;

                  return TimelineTile(
                    isFirst: isFirst,
                    isLast: isLast,
                    alignment: TimelineAlign.start,
                    indicatorStyle: IndicatorStyle(
                      width: 40,
                      color: _getStatusColor(event.status),
                      iconStyle: IconStyle(
                        iconData: event.icon,
                        color: Colors.white,
                      ),
                    ),
                    beforeLineStyle: LineStyle(
                      color: _getStatusColor(
                        event.status,
                      ).withValues(alpha: 0.3),
                      thickness: 2,
                    ),
                    endChild: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'MMM d, y • h:mm a',
                            ).format(event.timestamp.toDate()),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              event.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class TimelineEvent {
  final String title;
  final String description;
  final Timestamp timestamp;
  final String status;
  final IconData icon;

  TimelineEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.icon,
  });
}
