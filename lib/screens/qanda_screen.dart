import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class QandAScreen extends StatefulWidget {
  final String contractorId;
  final bool isContractor;

  const QandAScreen({
    super.key,
    required this.contractorId,
    this.isContractor = false,
  });

  @override
  State<QandAScreen> createState() => _QandAScreenState();
}

class _QandAScreenState extends State<QandAScreen> {
  final _questionController = TextEditingController();

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to ask questions')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('qa').add({
        'contractorId': widget.contractorId,
        'question': question,
        'askedBy': user.uid,
        'askedByName': user.email?.split('@')[0] ?? 'Anonymous',
        'answer': null,
        'answeredAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _questionController.clear();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Question submitted!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting question: $e')),
        );
      }
    }
  }

  Future<void> _answerQuestion(String qaId) async {
    final answerController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Answer Question'),
        content: TextField(
          controller: answerController,
          decoration: const InputDecoration(
            labelText: 'Your Answer',
            hintText: 'Provide a helpful answer...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, answerController.text),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    answerController.dispose();

    if (result != null && result.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('qa').doc(qaId).update({
          'answer': result,
          'answeredAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Answer submitted!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting answer: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteQuestion(String qaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('qa').doc(qaId).delete();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Question deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Q&A')),
      body: Column(
        children: [
          // Ask Question Section (only for non-contractors)
          if (!widget.isContractor)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask a Question',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        hintText: 'What would you like to know?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitQuestion,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Question'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Questions List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('qa')
                  .where('contractorId', isEqualTo: widget.contractorId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final questions = snapshot.data!.docs;

                if (questions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.question_answer_outlined,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.isContractor
                                ? 'No questions yet'
                                : 'Be the first to ask!',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.isContractor
                                ? 'Customers can ask you questions about your services'
                                : 'Ask questions to learn more about this contractor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final doc = questions[index];
                    final qa = doc.data() as Map<String, dynamic>;
                    return _buildQACard(doc.id, qa);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQACard(String qaId, Map<String, dynamic> qa) {
    final question = qa['question'] as String;
    final answer = qa['answer'] as String?;
    final askedBy = qa['askedByName'] as String? ?? 'Anonymous';
    final createdAt = qa['createdAt'] as Timestamp?;
    final answeredAt = qa['answeredAt'] as Timestamp?;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMyQuestion = qa['askedBy'] == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        askedBy,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (createdAt != null)
                        Text(
                          DateFormat.yMMMd().add_jm().format(
                            createdAt.toDate(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (widget.isContractor || isMyQuestion)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteQuestion(qaId);
                      } else if (value == 'answer') {
                        _answerQuestion(qaId);
                      }
                    },
                    itemBuilder: (context) => [
                      if (widget.isContractor && answer == null)
                        const PopupMenuItem(
                          value: 'answer',
                          child: Row(
                            children: [
                              Icon(Icons.reply),
                              SizedBox(width: 8),
                              Text('Answer'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Question Text
            Text(question, style: const TextStyle(fontSize: 16)),

            // Answer Section
            if (answer != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Contractor\'s Answer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                        if (answeredAt != null) ...[
                          const Spacer(),
                          Text(
                            DateFormat.MMMd().format(answeredAt.toDate()),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      answer,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.isContractor) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _answerQuestion(qaId),
                icon: const Icon(Icons.reply),
                label: const Text('Answer This Question'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
