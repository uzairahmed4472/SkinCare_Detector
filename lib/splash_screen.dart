import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/modules/login_screen/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Splash2 extends StatefulWidget {
  @override
  _Splash2State createState() => _Splash2State();
}

class _Splash2State extends State<Splash2> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SecondScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(146, 147, 226, 255),
              Color.fromARGB(255, 227, 245, 255)
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo2.png',
                width: 200.0,
                height: 200.0,
                fit: BoxFit.fill,
              ),
              SizedBox(height: 20),
              Text(
                "We care about your health",
                style: TextStyle(color: Colors.blueAccent),
              ),
              SizedBox(height: 20),
              CircularProgressIndicator(
                color: Color.fromARGB(255, 227, 245, 255),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SecondScreen extends StatefulWidget {
  const SecondScreen({Key? key}) : super(key: key);

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  var user;
  getPref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      user = prefs.getString('email');
    });

    print('--------------------');
    print(user);
  }

  Future<void> parameter_() async {
    try {
      {
        await Future.delayed(const Duration(milliseconds: 50), () {
          getPref();
        });
      }
    } catch (e) {
      print('parameter_ has failed' + e.toString());
    }
  }

  @override
  void initState() {
    parameter_();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return user == null ? LoginScreen() : Home();
    return LoginScreen();
  }
}
