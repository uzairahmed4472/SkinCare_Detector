import 'dart:io';
import 'package:flutter_application_1/advanced_test/1-affected_area.dart';
import 'package:flutter_application_1/diseases/scc.dart';
import 'package:flutter_application_1/home.dart';
import 'package:flutter_application_1/skin_test/1-test_home_page.dart';
import 'package:flutter_application_1/skin_test/3-display_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite/tflite.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_application_1/services/firestore_service.dart';

enum imgSrc { camera, gallery }

class Load_image extends StatefulWidget {
  const Load_image({Key? key}) : super(key: key);

  @override
  State<Load_image> createState() => _Load_imageState();
}

class _Load_imageState extends State<Load_image> {
  late File _image;
  bool _loading = true;
  final picker = ImagePicker();
  late bool _modelLoading;
  late bool _modelPredicting;
  late List _output;
  // int not_image_ok = 0;

  String base64string = 'Not Selected';
  String augustus_output = '';
  String augustus_confidence = '';
  String augustus_error = '';
  var loaded_image = 0;
  int temp = 0;
  late String _infotxt;
  var quick_advanced;

  var name;
  var email;
  var phone;
  var password;

  List dangerous_lessions = [
    'Melanoma',
    'Basal Cell Carcinoma',
    'Squamous Cell Carcinoma'
  ];

  final FirestoreService _firestoreService = FirestoreService();

  Future<void> getText(String path) async {
    final _loadedData = await rootBundle.loadString(path);
    setState(() {
      _infotxt = _loadedData;
    });
  }

  deletePref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Save the current user's email before clearing
    String? currentEmail = prefs.getString('email');

    // Clear only the current test data, not the history
    await prefs.remove('base64string');
    await prefs.remove('label_output');
    await prefs.remove('confidence_output');
    await prefs.remove('infotxt');
    await prefs.remove('affected_area');
    await prefs.remove('affected_area_size');
    await prefs.remove('duration_injury');
    await prefs.remove('itch');
    await prefs.remove('fever');
    await prefs.remove('affected_area_shape');
    await prefs.remove('affected_area_color');
    await prefs.remove('tissue_damage');

    // Keep the user's email for history tracking
    if (currentEmail != null) {
      await prefs.setString('user_test_email', currentEmail);
    }

    print('Current test data cleared, history preserved');
  }

  getPref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      quick_advanced = prefs.getString('diseases_or_test');
      name = prefs.getString('name');
      email = prefs.getString('email');
      phone = prefs.getString('phone');
      password = prefs.getString('password');
      quick_advanced = prefs.getString('quick_advanced');

      print(password);
    });
    print('get Pref of quick_advanced has been done');
    print('---------------------------------------------------');
    print(quick_advanced);
  }

  savePref() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Uint8List imagebytes = await _image.readAsBytes();
    base64string = base64.encode(imagebytes);
    print('DEBUG: base64string saved: ' +
        (base64string.length > 30
            ? base64string.substring(0, 30) + '...'
            : base64string));

    // Get the current user's email
    String? userEmail = prefs.getString('email');
    if (userEmail == null || userEmail.isEmpty) {
      print('Error: No user email found when saving test result');
      return;
    }

    print('Saving test result for user: $userEmail');

    // Create new test result
    Map<String, dynamic> newResult = {
      'label': augustus_output,
      'confidence': augustus_confidence,
      'imageBase64': base64string,
      'infoText': _infotxt,
      'name': name ?? '',
      'email': userEmail,
      'phone': phone ?? '',
      'affectedArea': prefs.getString('affected_area') ?? '',
      'affectedAreaSize': prefs.getString('affected_area_size') ?? '',
      'durationInjury': prefs.getString('duration_injury') ?? '',
      'itch': prefs.getString('itch') ?? '',
      'fever': prefs.getString('fever') ?? '',
      'affectedAreaShape': prefs.getString('affected_area_shape') ?? '',
      'affectedAreaColor': prefs.getString('affected_area_color') ?? '',
      'tissueDamage': prefs.getString('tissue_damage') ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'testType': quick_advanced ?? 'quick',
    };

    try {
      // Save to Firestore
      await _firestoreService.saveTestResult(newResult);
      print('Test result saved successfully to Firestore');

      // Save current test data for immediate use
      await prefs.setString('base64string', base64string);
      await prefs.setString('label_output', augustus_output);
      await prefs.setString('confidence_output', augustus_confidence);
      await prefs.setString('infotxt', _infotxt);
      await prefs.setString('name', name ?? '');
      await prefs.setString('email', userEmail);
      await prefs.setString('phone', phone ?? '');
      await prefs.setString('password', password ?? '');
      await prefs.setString('quick_advanced', quick_advanced ?? '');

      print('Test result saved successfully for user: $userEmail');
      print('Test type: ${quick_advanced ?? "quick"}');
      print('Test label: $augustus_output');
    } catch (e) {
      print('Error saving test result: $e');
    }
  }

  Future loadModel() async {
    await Tflite.loadModel(
        model: "assets/model_unquant.tflite", labels: "assets/labels.txt");
  }

  ///Tries to load image from either gallery or camera depening on [scr]. If successfull, calls classify function on image.
  Future getImagePrediction(imgSrc src) async {
    // get image file via picker
    final pickedFile = (src == imgSrc.gallery)
        ? await picker.getImage(source: ImageSource.gallery)
        : await picker.getImage(source: ImageSource.camera);

    // Check if user cancelled or no file selected
    if (pickedFile == null) {
      return;
    }

    // change state and call classify if successfull
    setState(() {
      _image = File(pickedFile.path);
      _modelPredicting = true;
      _loading = true;
      temp = 0; // Reset to show loading
    });

    try {
      await classifyImg(_image);
    } catch (e) {
      setState(() {
        _modelPredicting = false;
        _loading = false;
        augustus_error = 'Error !please sir try another picture ';
        temp = 1;
        loaded_image = 1;
      });
      print('Error in getImagePrediction: $e');
    }
  }

  /// classifies image on tensor flow lite model and loads infotext file based on prediction
  Future classifyImg(File image) async {
    // predict with tflite model
    var output = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 9,
      imageMean: 127.5,
      imageStd: 127.5,
      threshold: 0.0, // Lowered threshold to capture more results
    );

    // Debug: Print output details
    print('DEBUG: Model output type: ${output.runtimeType}');
    print('DEBUG: Model output is null: ${output == null}');
    if (output != null) {
      print('DEBUG: Model output length: ${output.length}');
      if (output.isNotEmpty) {
        print('DEBUG: First result: ${output[0]}');
      }
    }

    // Check if output is null or empty
    if (output == null || output.isEmpty) {
      setState(() {
        _modelPredicting = false;
        _loading = false;
        augustus_output = '';
        augustus_confidence = '';
        augustus_error = 'Error !please sir try another picture ';
        temp = 1;
        loaded_image = 1;
      });
      print('Error: Model output is null or empty');
      return;
    }

    // Process the output and update UI
    try {
      String label = '${output[0]['label']}';
      double confidence = output[0]['confidence'] as double;
      int index = output[0]["index"] as int;

      print(
          'DEBUG: Processing result - Label: $label, Confidence: $confidence, Index: $index');

      // Load info text file for the predicted class (async, but don't wait)
      getText('assets/$index.txt').catchError((error) {
        print(
            'Warning: Could not load info text file for index $index: $error');
        // Continue even if info text fails to load
      });

      // Update UI with results
      setState(() {
        _output = output;
        _loading = false;
        _modelPredicting = false;

        if (label != 'Melanoma' &&
            label != 'Basal Cell Carcinoma' &&
            label != 'Squamous Cell Carcinoma') {
          augustus_output = 'Unknown';
          augustus_confidence = '';
          augustus_error = 'Not Supported.';
        } else {
          augustus_output = label;
          augustus_confidence = '${(confidence * 100).round()}';
          augustus_error = '';
        }
        loaded_image = 0;
        temp = 1;
      });

      print(
          'DEBUG: UI updated - Output: $augustus_output, Confidence: $augustus_confidence');
    } catch (e) {
      print('Error processing output: $e');
      setState(() {
        _modelPredicting = false;
        _loading = false;
        _output = output;
        augustus_output = '';
        augustus_confidence = '';
        augustus_error = 'Error !please sir try another picture ';
        temp = 1;
        loaded_image = 1;
      });
    }
  }

  //init state
  @override
  void initState() {
    super.initState();
    _modelLoading = true;
    _modelPredicting = false;
    //load tflite model
    loadModel().then((value) {
      setState(() {
        _modelLoading = false;
      });
    });
    getPref();
  }

  @override
  void dispose() {
    super.dispose();
    Tflite.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Color.fromARGB(255, 16, 170, 226),
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color.fromARGB(255, 16, 170, 226),
                  Color.fromARGB(255, 87, 179, 212),
                ],
              ),
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_outlined, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Test_Home_page()),
              );
            },
          ),
          title: Text(
            'Image selection',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.home_sharp, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              },
            ),
          ],
        ),
        body: _modelPredicting
            ? Container(
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
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 16, 170, 226),
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Processing image...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 16, 170, 226),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Please wait while we analyze your skin condition',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : temp == 0
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        //  colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 174, 217, 255)],
                        //  colors: [Color.fromARGB(255, 96, 165, 239), Color.fromARGB(255, 153, 204, 250)], // mahmoud
                        colors: [
                          Color.fromARGB(146, 147, 226, 255),
                          Color.fromARGB(255, 227, 245, 255)
                        ],

                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            margin: EdgeInsets.only(
                                top: 18, left: 18, right: 18, bottom: 5),
                            width: double.infinity,
                            height: double.infinity,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                  side: BorderSide(
                                      width: 3, color: Colors.black)),
                              child: InkWell(
                                  onTap: () {
                                    try {
                                      setState(() {
                                        getImagePrediction(imgSrc.gallery);
                                      });
                                    } catch (e) {
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                Display_image()),
                                      );
                                    }
                                  },
                                  // Handle your callback.
                                  splashColor: Colors.blue,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Ink(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          image: DecorationImage(
                                            image:
                                                AssetImage("assets/upload.png"),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Text('Import Image',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Text('select a mole or skin lesion',
                                          style: TextStyle(
                                            fontSize: 15,
                                          )),
                                      Text('photograph from your gallary',
                                          style: TextStyle(
                                            fontSize: 15,
                                          ))
                                    ],
                                  )),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            margin: EdgeInsets.only(
                                top: 5, left: 18, right: 18, bottom: 18),
                            width: double.infinity,
                            height: double.infinity,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                  side: BorderSide(
                                      width: 3, color: Colors.black)),
                              child: InkWell(
                                  onTap: () {
                                    try {
                                      setState(() {
                                        getImagePrediction(imgSrc.camera);
                                      });
                                    } catch (e) {
                                      Navigator.of(context).pop();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                Display_image()),
                                      );
                                    }
                                  },
                                  // Handle your callback.
                                  splashColor: Colors.blue,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Ink(
                                        height: 100,
                                        width: 100,
                                        decoration: BoxDecoration(
                                          // border: Border.all(width:3,color:Color.fromARGB(255, 2, 2, 2)),
                                          image: DecorationImage(
                                            image:
                                                AssetImage("assets/camera.png"),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Text('Take a photo',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(
                                        height: 5,
                                      ),
                                      Text('Rapidly take a photo of the skin',
                                          style: TextStyle(
                                            fontSize: 15,
                                          )),
                                      Text('region for analysis',
                                          style: TextStyle(
                                            fontSize: 15,
                                          ))
                                    ],
                                  )),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )

                /// form of diplaying images and results
                : Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        //  colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 174, 217, 255)],
                        //  colors: [Color.fromARGB(255, 96, 165, 239), Color.fromARGB(255, 153, 204, 250)], // mahmoud
                        colors: [
                          Color.fromARGB(146, 147, 226, 255),
                          Color.fromARGB(255, 227, 245, 255)
                        ],

                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Column(children: [
                      SizedBox(
                        height: 20,
                      ),
                      loaded_image == 0
                          ? Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    width: 1,
                                    color: Color.fromRGBO(1, 5, 53, 1)),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              margin: EdgeInsets.all(20),
                              height: 270,
                              width: 270,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(50),
                                child: Image.file(
                                  _image,
                                  fit: BoxFit.fill,
                                ),
                              ))
                          : Container(),
                      Container(
                        child: Column(
                          children: [
                            // Display error if any
                            if (augustus_error.isNotEmpty)
                              Container(
                                padding: EdgeInsets.all(10),
                                margin: EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  augustus_error,
                                  style: TextStyle(
                                    color: Colors.red[900],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            // Display results if available
                            if (augustus_output.isNotEmpty &&
                                augustus_error.isEmpty)
                              Container(
                                margin: EdgeInsets.all(20),
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.3),
                                      spreadRadius: 2,
                                      blurRadius: 5,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Prediction Result',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Color.fromARGB(255, 16, 170, 226),
                                      ),
                                    ),
                                    SizedBox(height: 15),
                                    Text(
                                      augustus_output,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (augustus_confidence.isNotEmpty) ...[
                                      SizedBox(height: 10),
                                      Text(
                                        'Confidence: ${augustus_confidence}%',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            SizedBox(height: 10.0),
                            Container(
                              alignment: Alignment.center,
                              height: 50.0,
                              width: 300,
                              margin: EdgeInsets.all(10),
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (augustus_output == 'Unknown') {
                                    AwesomeDialog(
                                      context: context,
                                      dialogType: DialogType.INFO,
                                      animType: AnimType.BOTTOMSLIDE,
                                      title: 'Image validation Error',
                                      desc:
                                          'Please select an image of a skin condition',
                                      btnCancelOnPress: () {
                                        setState(() {
                                          temp = 0;
                                          augustus_error =
                                              'Please select a valid skin condition image';
                                        });
                                      },
                                      btnOkOnPress: () {
                                        setState(() {
                                          temp = 0;
                                        });
                                      },
                                    )..show();
                                    return;
                                  }

                                  await getPref();
                                  deletePref();
                                  await savePref();

                                  print('---------------------------------');
                                  print(quick_advanced);

                                  if (quick_advanced == 'advanced') {
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              Affected_area()),
                                    );
                                  } else {
                                    // Add check for base64string before navigating
                                    SharedPreferences prefs =
                                        await SharedPreferences.getInstance();
                                    String? b64 =
                                        prefs.getString('base64string');
                                    print(
                                        'DEBUG: base64string before navigation: ' +
                                            (b64 != null && b64.length > 30
                                                ? b64.substring(0, 30) + '...'
                                                : (b64 ?? 'null')));
                                    if (b64 == null ||
                                        b64.isEmpty ||
                                        b64 == 'Not Selected') {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'No image data found. Please select an image first!')),
                                      );
                                      return;
                                    }
                                    Navigator.of(context).pop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              Display_image()),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  primary: Color.fromARGB(255, 243, 33, 33),
                                  fixedSize: Size(350, 100),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(80.0)),
                                  padding: EdgeInsets.all(0.0),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(255, 66, 120, 212),
                                          Color.fromARGB(255, 79, 151, 213)
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(30.0)),
                                  child: Container(
                                      constraints: BoxConstraints(
                                          maxWidth: 350.0, minHeight: 50.0),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Processed",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                          ),
                                        ],
                                      )),
                                ),
                              ),
                            ),

                            Container(
                              alignment: Alignment.center,
                              height: 50.0,
                              width: 300,
                              margin: EdgeInsets.all(10),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    temp = 0;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  primary: Color.fromARGB(255, 243, 33, 33),
                                  fixedSize: Size(350, 100),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(80.0)),
                                  padding: EdgeInsets.all(0.0),
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color.fromARGB(255, 66, 120, 212),
                                          Color.fromARGB(255, 79, 151, 213)
                                        ],

                                        //  colors: [Colors.green, Color.fromARGB(255, 36, 129, 8),],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(30.0)),
                                  child: Container(
                                      constraints: BoxConstraints(
                                          maxWidth: 350.0, minHeight: 50.0),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "Back to take another photo",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20),
                                          ),
                                        ],
                                      )),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: 5,
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ));
  }
}
