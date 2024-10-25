import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Activity extends StatefulWidget {
  const Activity({super.key});

  @override
  _ActivityState createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  DateTimeRange? dateRange;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: dateRange,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != dateRange) {
      setState(() {
        dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Activity',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onBackground,
            )),
        backgroundColor: Theme.of(context).colorScheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.email)
            .collection('attendance')
            .orderBy('checkInTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final attendanceRecords = snapshot.data?.docs;

          if (attendanceRecords == null || attendanceRecords.isEmpty) {
            return const Center(child: Text('No attendance records found.'));
          }

          Map<String, List<Map<String, dynamic>>> groupedRecords = {};
          for (var record in attendanceRecords) {
            final data = record.data() as Map<String, dynamic>?;

            if (data == null) continue;

            final checkInTime = data['checkInTime'] as Timestamp;

            // Group by date
            final dateKey =
                DateFormat('yyyy-MM-dd').format(checkInTime.toDate());
            if (dateRange == null ||
                (checkInTime.toDate().isAfter(dateRange!.start) &&
                    checkInTime.toDate().isBefore(
                        dateRange!.end.add(const Duration(days: 1))))) {
              groupedRecords.putIfAbsent(dateKey, () => []);
              groupedRecords[dateKey]!.add(data);
            }
          }

          return ListView(
            children: groupedRecords.entries.map((entry) {
              final date = entry.key;
              final records = entry.value;
              Duration totalDuration = Duration.zero;

              for (var record in records) {
                final checkInTime = record['checkInTime'] as Timestamp;
                final checkOutTime = record.containsKey('checkOutTime')
                    ? (record['checkOutTime'] as Timestamp)
                    : null;

                if (checkOutTime != null) {
                  totalDuration +=
                      checkOutTime.toDate().difference(checkInTime.toDate());
                }
              }

              return Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                color:
                    Color.fromRGBO(22, 22, 22, 1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white),
                      ),
                      Text(
                        'Total Working Hours: ${_formatDuration(totalDuration)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      ExpansionTile(
                        title: const Text('View Details',
                            style: TextStyle(color: Colors.white)),
                        iconColor: Colors.white,
                        backgroundColor: Color.fromRGBO(22, 22, 22,
                            1),
                        children: records.map((data) {
                          final checkInTime = data['checkInTime'] as Timestamp;
                          final checkOutTime = data.containsKey('checkOutTime')
                              ? (data['checkOutTime'] as Timestamp)
                              : null;

                          return Container(
                            color: Color.fromRGBO(22, 22, 22,
                                1),
                            child: ListTile(
                              title: Text(
                                'Check-in: ${checkInTime.toDate()}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location: ${data['checkInLocation'].latitude}, ${data['checkInLocation'].longitude}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (checkOutTime != null) ...[
                                    Text(
                                      'Check-out: ${checkOutTime.toDate()}',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      'Location: ${data['checkOutLocation'].latitude}, ${data['checkOutLocation'].longitude}',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ] else ...[
                                    const Text(
                                      'Checked in but not yet checked out.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}
