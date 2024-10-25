import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';

class AutoCheckInOut extends StatefulWidget {
  const AutoCheckInOut({super.key});

  @override
  _AutoCheckInOutState createState() => _AutoCheckInOutState();
}

class _AutoCheckInOutState extends State<AutoCheckInOut> {
  User? user;
  final double _officeLatitude = 26.3070193;
  final double _officeLongitude = 73.0030597;

  double? _currentLatitude;
  double? _currentLongitude;
  String? _attendanceMessage;
  bool _isCheckedIn = false;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  Stream<Position>? _positionStream;

  final double _radius = 4.0; // radius

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _retrieveIncompleteCheckIn(); // Check for existing check-in records
    _monitorLocation(); // Monitoring location in real-time
    _scheduleBackgroundCheck(); // Schedule background check
  }

  void _scheduleBackgroundCheck() {
    Workmanager().registerPeriodicTask(
      "1",
      "backgroundLocationCheck",
      frequency: const Duration(seconds: 1),
    );
  }

  Future<void> _retrieveIncompleteCheckIn() async {
    var attendanceRecords = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.email)
        .collection('attendance')
        .where('checkOutTime', isNull: true) // Incomplete check-ins
        .orderBy('checkInTime', descending: true) // Get latest check-in
        .limit(1)
        .get();

    if (attendanceRecords.docs.isNotEmpty) {
      var checkInRecord = attendanceRecords.docs.first;
      setState(() {
        _checkInTime = checkInRecord['checkInTime'].toDate();
        _currentLatitude = checkInRecord['checkInLocation'].latitude;
        _currentLongitude = checkInRecord['checkInLocation'].longitude;
        _isCheckedIn = true;
        _attendanceMessage =
            'Currently checked in at Latitude: $_currentLatitude, Longitude: $_currentLongitude\nChecked in on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_checkInTime!)}';
      });
    }
  }

  Future<void> _monitorLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.')),
      );
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );

    _positionStream!.listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
      });
      _handleAttendance(position);
    });
  }

  Future<void> _handleAttendance(Position position) async {
    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _officeLatitude,
      _officeLongitude,
    );

    if (distance <= _radius && !_isCheckedIn) {
      // Check-in
      _checkInTime = DateTime.now();
      setState(() {
        _isCheckedIn = true;
        _attendanceMessage =
            'Checked in at Latitude: $_currentLatitude, Longitude: $_currentLongitude\n Time: ${DateFormat('hh:mm:ss').format(_checkInTime!)}';
      });

      String docId = DateFormat('yyyy-MM-dd_HH:mm:ss').format(_checkInTime!);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.email)
          .collection('attendance')
          .doc(docId)
          .set({
        'checkInLocation': GeoPoint(_currentLatitude!, _currentLongitude!),
        'checkInTime': _checkInTime,
      });
    } else if (distance > _radius && _isCheckedIn) {
      // Check-out
      _checkOutTime = DateTime.now();
      Duration workingDuration = _checkOutTime!.difference(_checkInTime!);
      String formattedDuration = _formatDuration(workingDuration);

      setState(() {
        _attendanceMessage =
            'Checked out at Latitude: $_currentLatitude, Longitude: $_currentLongitude\nTime: ${DateFormat('hh:mm:ss').format(_checkOutTime!)}\nTotal Working Hours: $formattedDuration';
        _isCheckedIn = false;
      });

      var checkInRecord = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.email)
          .collection('attendance')
          .where('checkInTime', isEqualTo: _checkInTime)
          .get();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.email)
          .collection('attendance')
          .doc(checkInRecord.docs.first.id)
          .update({
        'checkOutLocation': GeoPoint(_currentLatitude!, _currentLongitude!),
        'checkOutTime': _checkOutTime,
        'totalWorkingHours': formattedDuration,
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    return "$hours:$minutes";
  }

  @override
  void dispose() {
    _positionStream?.listen(null); // Cancel the position stream
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Check-In/Check-Out'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16.0),
              if (_currentLatitude != null && _currentLongitude != null) ...[
                Text(
                  'Current Latitude: $_currentLatitude',
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onBackground),
                ),
                Text(
                  'Current Longitude: $_currentLongitude',
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onBackground),
                ),
              ],
              const SizedBox(height: 20.0),
              if (_attendanceMessage != null)
                Text(
                  _attendanceMessage!,
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.primary),
                )
              else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
