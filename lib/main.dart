import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Phase Assignment CS619',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'TestPhase Assignment'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FirebaseAuth auth = FirebaseAuth.instance;
  CollectionReference users = FirebaseFirestore.instance.collection('users');
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController phoneNumberController = TextEditingController();
  TextEditingController treatmentController = TextEditingController();
  String latitudeController = '';
  String longitudeController = '';
  final List<String> _userRoleDropDown = ['patient', 'caregiver'];
  String _selectedRole = "patient";
  TimeOfDay selectedTime = TimeOfDay.now();

  @override
  void initState() {
    super.initState();
    getDevicePermission();
  }

  _selectTime(BuildContext context) async {
    final TimeOfDay? timeOfDay = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (timeOfDay != null && timeOfDay != selectedTime) {
      setState(() {
        selectedTime = timeOfDay;
      });
    }
  }

  void registerUser(email, password, phoenNumber, treatement, treatementTime,
      latitude, longitude, roll) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        saveOtherUserRegisterationInformation(email, password, user.uid,
            phoenNumber, treatement, treatementTime, latitude, longitude, roll);
      } else {
        final userID = "0";
        saveOtherUserRegisterationInformation(email, password, userID,
            phoenNumber, treatement, treatementTime, latitude, longitude, roll);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> saveOtherUserRegisterationInformation(email, password, id,
      phoenNumber, treatement, treatementTime, latitude, longitude, roll) {
    CollectionReference users = FirebaseFirestore.instance.collection('users');

    if (roll == "patient") {
      List<Map<String, dynamic>> withDistanceCaregiverList = [];

      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .get()
          .then((QuerySnapshot querySnapshot) {
        for (var doc in querySnapshot.docs) {
          if (double.parse(doc['assignedPatient'].toString()) <= 5) {
            Map<String, dynamic> userMap = {
              'email': doc['email'],
              'distance': Geolocator.distanceBetween(
                  double.parse(latitude),
                  double.parse(longitude),
                  double.parse(doc['latitude']),
                  double.parse(doc['longitude']))
            };
            withDistanceCaregiverList.add(userMap);
          }
        }

        withDistanceCaregiverList.sort((m1, m2) {
          var r = m1["distance"].compareTo(m2["distance"]);
          if (r != 0) return r;
          return m1["distance"].compareTo(m2["distance"]);
        });

        print(withDistanceCaregiverList[0]);

        print("you are assigned caregiver:" +
            withDistanceCaregiverList[0]['email']);

        FirebaseFirestore.instance.collection('assignedusers').add({
          'caregiver': withDistanceCaregiverList[0]['email'],
          'patient': email,
        }).whenComplete(() {
          return FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: withDistanceCaregiverList[0]['email'])
              .get()
              .then((QuerySnapshot querySnapshot) {
            for (var doc in querySnapshot.docs) {
              final double newPatientLimit =
                  double.parse(doc['assignedPatient']) + 1;
              print("new value of patientLimit: " + newPatientLimit.toString());
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(doc.id)
                  .update({
                'assignedPatient': newPatientLimit.toString(),
              });
            }
          });
        });
      });
    }

    String roleOfPatient = '';

    if (_selectedRole == "caregiver") {
      roleOfPatient = "0";
    } else {
      roleOfPatient = "NA";
    }

    return users.add({
      'email': email,
      'password': password,
      'id': id,
      'phoneNumber': phoenNumber,
      'treatment': treatement,
      'treatementTime': treatementTime,
      'role': _selectedRole,
      'longitude': longitude,
      'latitude': latitude,
      'location': GeoPoint(double.parse(latitude), double.parse(longitude)),
      'assignedPatient': roleOfPatient,
    }).catchError((error) => print("Failed to add user: $error"));
  }

  void getDevicePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("permission not given");
      LocationPermission permissionRequest =
          await Geolocator.requestPermission();
    } else {
      Position currentDevicePosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      latitudeController = currentDevicePosition.latitude.toString();
      longitudeController = currentDevicePosition.longitude.toString();
      print("Logitude: " + currentDevicePosition.longitude.toString());
      print("Latitude: " + currentDevicePosition.latitude.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.only(left: 30, right: 30, top: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              const Text("Join", style: TextStyle(fontSize: 60)),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  hintText: 'Enter your email id',
                ),
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  hintText: 'Enter your password',
                ),
              ),
              TextFormField(
                controller: phoneNumberController,
                decoration: const InputDecoration(
                  hintText: 'Enter your phone number',
                ),
              ),
              Row(
                children: [
                  const Text("Select your role: "),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.amberAccent,
                    ),
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: DropdownButton(
                      hint: const Text('Select your role: '),
                      value: _selectedRole,
                      onChanged: (newValueofRole) {
                        setState(() {
                          _selectedRole = newValueofRole.toString();
                        });
                      },
                      items: _userRoleDropDown.map((role) {
                        return DropdownMenuItem(
                          child: Text(role),
                          value: role,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              _selectedRole == "patient"
                  ? TextFormField(
                      controller: treatmentController,
                      decoration: const InputDecoration(
                        hintText: 'What treatment your are taking?',
                      ))
                  : const SizedBox(
                      height: 2,
                    ),
              const SizedBox(
                height: 20,
              ),
              _selectedRole == "patient"
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text("Select treatment time"),
                        const SizedBox(
                          width: 10,
                        ),
                        GestureDetector(
                          onTap: () {
                            _selectTime(context);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.amberAccent,
                            ),
                            padding: const EdgeInsets.only(
                                left: 20, right: 20, top: 10, bottom: 10),
                            child: const Text("Choose Time"),
                          ),
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                        Text("${selectedTime.hour}:${selectedTime.minute}"),
                      ],
                    )
                  : const SizedBox(
                      height: 2,
                    ),
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  Text(longitudeController),
                  const SizedBox(
                    width: 15,
                  ),
                  Text(latitudeController),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        getDevicePermission();
                      });
                    },
                    icon: const Icon(Icons.location_off_rounded),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Container(
                padding: const EdgeInsets.only(
                    left: 30, right: 30, top: 2, bottom: 2),
                color: Colors.greenAccent,
                child: TextButton(
                  style: ButtonStyle(
                    foregroundColor:
                        MaterialStateProperty.all<Color>(Colors.blue),
                  ),
                  onPressed: () {
                    registerUser(
                      emailController.text.toString(),
                      passwordController.text.toString(),
                      phoneNumberController.text.toString(),
                      _selectedRole == "patient"
                          ? treatmentController.text.toString()
                          : "NA",
                      _selectedRole == "patient" ? selectedTime : "NA",
                      _selectedRole,
                      latitudeController.toString(),
                      longitudeController.toString(),
                    );
                    emailController.clear();
                    passwordController.clear();
                    phoneNumberController.clear();
                    treatmentController.clear();
                    latitudeController = "";
                    longitudeController = "";
                    selectedTime = TimeOfDay.now();
                  },
                  child: const Text('Click Here to Join'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
