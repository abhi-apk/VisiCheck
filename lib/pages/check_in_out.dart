import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInOut extends StatefulWidget {
  const CheckInOut({super.key});

  @override
  _CheckInOutState createState() => _CheckInOutState();
}

class _CheckInOutState extends State<CheckInOut> {
  double? _latitude;
  double? _longitude;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  String? _attendanceMessage;
  Duration? _workingHours;
  User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _retrieveIncompleteCheckIn();
  }

  Future<void> _retrieveIncompleteCheckIn() async {
    // Query Firestore for incomplete check-ins
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
        _latitude = checkInRecord['checkInLocation'].latitude;
        _longitude = checkInRecord['checkInLocation'].longitude;
        _attendanceMessage =
            'Checked in on ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_checkInTime!)}';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
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

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location retrieved successfully!')),
    );
  }

  Future<void> _checkIn() async {
    if (_latitude != null && _longitude != null) {
      setState(() {
        _checkInTime = DateTime.now();
        _attendanceMessage =
            'Checked in at Latitude: $_latitude, Longitude: $_longitude on ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_checkInTime!)}';
      });

      String docId = DateFormat('yyyy-MM-dd_HH:mm:ss').format(_checkInTime!);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.email)
          .collection('attendance')
          .doc(docId)
          .set({
        'checkInLocation': GeoPoint(_latitude!, _longitude!),
        'checkInTime': _checkInTime,
        'checkOutTime': null, // Initially null
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please retrieve location first')),
      );
    }
  }

  Future<void> _checkOut() async {
    if (_checkInTime != null && _latitude != null && _longitude != null) {
      setState(() {
        _checkOutTime = DateTime.now();
        _attendanceMessage =
            'Checked out at Latitude: $_latitude, Longitude: $_longitude on ${DateFormat('yyyy-MM-dd HH:mm:ss').format(_checkOutTime!)}';

        _workingHours = _checkOutTime!.difference(_checkInTime!);
      });

      String docId = DateFormat('yyyy-MM-dd_HH:mm:ss').format(_checkInTime!);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.email)
          .collection('attendance')
          .doc(docId)
          .update({
        'checkOutLocation': GeoPoint(_latitude!, _longitude!),
        'checkOutTime': _checkOutTime,
        'totalWorkingHours': _formatDuration(_workingHours!),
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check in first')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Check In/Checkout"),
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
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: Text(
                  'Get Current Location',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground),
                ),
              ),
              const SizedBox(height: 16.0),
              if (_latitude != null && _longitude != null) ...[
                Text(
                  'Latitude: $_latitude',
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onBackground),
                ),
                Text(
                  'Longitude: $_longitude',
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onBackground),
                ),
              ],
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _checkIn,
                child: Text('Check In',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground)),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _checkOut,
                child: Text('Check Out',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground)),
              ),
              const SizedBox(height: 24.0),
              if (_attendanceMessage != null)
                Text(
                  _attendanceMessage!,
                  style: const TextStyle(
                    fontSize: 18.0,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24.0),
              if (_workingHours != null)
                Text(
                  'Total Working Hours: ${_formatDuration(_workingHours!)}',
                  style: const TextStyle(
                    fontSize: 18.0,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
