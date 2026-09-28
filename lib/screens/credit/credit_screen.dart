import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_store.dart';
import '../../services/settings_store.dart';
import '../../theme/app_theme.dart';

class CreditItemModel {
  final String id;
  final String customerName;
  final double amount;
  final String date;
  final bool isPaid;
  final DateTime? createdAt;

  CreditItemModel({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.date,
    this.isPaid = false,
    this.createdAt,
  });

  factory CreditItemModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final created = data['createdAt'];
    return CreditItemModel(
      id: doc.id,
      customerName: (data['customerName'] ?? 'Customer').toString(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: (data['date'] ?? '').toString(),
      isPaid: data['isPaid'] == true,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseService _firebase = FirebaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _overdueChecked = false;

  /// Unpaid credits older than this many days trigger an overdue alert.
  static const int _overdueDays = 7;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkOverdue(List<CreditItemModel> credits) async {
    if (_overdueChecked) return;
    _overdueChecked = true;
    final now = DateTime.now();
    for (final c in credits) {
      if (c.isPaid) continue;
      final created = c.createdAt;
      if (created == null) continue;
      final days = now.difference(created).inDays;
      if (days < _overdueDays) continue;
      await NotificationStore.instance.addCreditOverdueAlert(
        creditId: c.id,
        customerName: c.customerName,
        amount: c.amount,
        daysOverdue: days,
      );
    }
  }

  Future<void> _showAddCreditDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add credit.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final amountController = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.darkGreenMid,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text(
                'Add Credit / Utang',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textWhite),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Customer name',
                      hintText: 'e.g. Juan Dela Cruz',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppColors.textWhite),
                    decoration: InputDecoration(
                      labelText:
                          'Amount (${SettingsStore.instance.currencySymbol})',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final amount =
                              double.tryParse(amountController.text.trim());
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Enter the customer name.')),
                            );
                            return;
                          }
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Enter a valid amount greater than 0.')),
                            );
                            return;
                          }
                          setDialogState(() => saving = true);
                          try {
                            final today =
                                DateFormat('yyyy-MM-dd').format(DateTime.now());
                            await _firebase.addCredit(
                              userId: user.uid,
                              customerName: name,
                              amount: amount,
                              saleId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                              date: today,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Credit / utang added successfully.')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed: $e'),
                                  backgroundColor: AppColors.accentRed,
                                ),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Mark Paid — guarded so already-paid rows cannot double-count transactions.
  Future<void> _markPaid(CreditItemModel credit) async {
    if (credit.isPaid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkGreenMid,
        title: const Text(
          'Mark as paid?',
          style: TextStyle(color: AppColors.textWhite),
        ),
        content: Text(
          'Record payment of ${SettingsStore.instance.formatMoney(credit.amount)} from ${credit.customerName}?',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _db.collection('credits').doc(credit.id).update({
        'isPaid': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('transactions').add({
        'userId': user.uid,
        'payment_method': 'Cash',
        'customer_name': credit.customerName,
        'total_amount': credit.amount,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credit marked as paid successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.accentRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: user == null
                ? const Center(
                    child: Text(
                      'Please log in to view credit / utang.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Nakatutok na ngayon sa 'credits' collection para magtugma sa web at database
                    stream: _db
                        .collection('credits')
                        .where('userId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load credits: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.mintIcon),
                        );
                      }

                      final credits = (snapshot.data?.docs ?? [])
                          .map(CreditItemModel.fromFirestore)
                          .toList()
                        ..sort((a, b) => (b.createdAt ?? DateTime(1970))
                            .compareTo(a.createdAt ?? DateTime(1970)));

                      // Filter gamit ang search query
                      final filtered = credits.where((c) {
                        return _searchQuery.isEmpty ||
                            c.customerName.toLowerCase().contains(_searchQuery.toLowerCase());
                      }).toList();

                      final totalUnpaid = credits
                          .where((c) => !c.isPaid)
                          .fold(0.0, (total, item) => total + item.amount);

                      // Fire once per screen visit for long-unpaid credits.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _checkOverdue(credits);
                      });

                        return ListenableBuilder(
                          listenable: SettingsStore.instance,
                          builder: (context, _) {
                            return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: AppColors.textWhite),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const Expanded(
                                child: Text(
                                  'Credit / Utang List',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Add Credit',
                                onPressed: _showAddCreditDialog,
                                icon: const Icon(Icons.add_circle_outline,
                                    color: AppColors.accentOrange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                            style: const TextStyle(color: AppColors.textWhite, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search customer name...',
                              hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 12),
                              prefixIcon: const Icon(Icons.search, color: AppColors.textFaint, size: 18),
                              filled: true,
                              fillColor: AppColors.fieldGreen.withValues(alpha: 0.6),
                              contentPadding: EdgeInsets.zero,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color: AppColors.mintIcon.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.fieldGreen.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.accentOrange.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL UNPAID',
                                      style: TextStyle(
                                        color: AppColors.textFaint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Uncollected Credits',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  SettingsStore.instance.formatMoney(totalUnpaid),
                                  style: const TextStyle(
                                    color: AppColors.accentOrange,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.assignment_turned_in_outlined,
                                          size: 48,
                                          color: AppColors.mintIcon.withValues(alpha: 0.4),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? 'No credits recorded yet'
                                              : 'No matching customers',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (_searchQuery.isEmpty) ...[
                                          const SizedBox(height: 12),
                                          TextButton(
                                            onPressed: _showAddCreditDialog,
                                            child: const Text(
                                              'Add your first credit',
                                              style: TextStyle(
                                                color: AppColors.accentOrange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final credit = filtered[index];
                                      return Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.fieldGreen.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: AppColors.mintIcon.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppColors.mintIcon.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.person_outline,
                                                color: AppColors.mintIcon,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    credit.customerName,
                                                    style: const TextStyle(
                                                      color: AppColors.textWhite,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    credit.date.isEmpty ? credit.id : credit.date,
                                                    style: const TextStyle(
                                                      color: AppColors.textMuted,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  SettingsStore.instance.formatMoney(credit.amount),
                                                  style: TextStyle(
                                                    color: credit.isPaid
                                                        ? AppColors.mintIcon
                                                        : AppColors.accentOrange,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: credit.isPaid
                                                      ? null
                                                      : () => _markPaid(credit),
                                                  child: Text(
                                                    credit.isPaid ? 'PAID' : 'MARK PAID',
                                                    style: TextStyle(
                                                      color: credit.isPaid
                                                          ? AppColors.mintIcon
                                                          : AppColors.accentRed,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                          },
                        );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}