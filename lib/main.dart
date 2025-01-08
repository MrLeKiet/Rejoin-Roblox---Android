import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:process_run/shell.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Roblox Rejoin Tool",
    notificationText: "Running in background",
    notificationImportance: AndroidNotificationImportance.normal,
    notificationIcon: AndroidResource(name: 'background_icon', defType: 'drawable'),
  );
  bool hasPermissions = await FlutterBackground.initialize(androidConfig: androidConfig);
  if (hasPermissions) {
    FlutterBackground.enableBackgroundExecution();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Roblox Rejoin Tool')),
        body: GameLauncher(),
      ),
    );
  }
}

class GameLauncher extends StatefulWidget {
  @override
  _GameLauncherState createState() => _GameLauncherState();
}

class _GameLauncherState extends State<GameLauncher> {
  bool _isGameRunning = false;
  Shell _shell = Shell();
  GlobalKey _repaintBoundaryKey = GlobalKey();
  List<String> _logMessages = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  void _addLogMessage(String message) {
    setState(() {
      _logMessages.add(message);
    });
    print(message); // Ensure log messages are printed to the console
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      _addLogMessage('Storage permission granted');
    } else {
      _addLogMessage('Storage permission denied');
    }
  }

  void _startGame() async {
    setState(() {
      _isGameRunning = true;
    });

    const initialUrl = 'https://www.roblox.com/games/12886143095/Clans-Godly-Anime-Last-Stand?privateServerLinkCode=03983514044047213303545004999363';

    while (_isGameRunning) {
      try {
        await _launchURL(initialUrl);
        await Future.delayed(Duration(seconds: 10)); // Give the game 3 minutes to load

        // Periodically check for specific text in the game
        while (_isGameRunning) {
          bool textDetected = await _checkForText('Disconnected');
          if (textDetected) {
            _addLogMessage('Detected "Disconnected" text, restarting game...');
            await Future.delayed(Duration(seconds: 10)); // Wait before restarting
            await _launchURL(initialUrl);
          } else {
            // Periodically reload the browser page to ensure the game is running
            await Future.delayed(Duration(seconds: 20)); // Check every 10 seconds
            await _launchURL(initialUrl);
            _addLogMessage('Reloaded browser page to ensure game is running.');
          }
        }
      } catch (e) {
        _addLogMessage('Error detected: $e');
        await Future.delayed(Duration(seconds: 10)); // Wait before restarting
      }
    }
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false, // iOS only
        forceWebView: true, // Android only
        enableJavaScript: true,
      );
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<bool> _checkForText(String text) async {
    try {
      // Capture the screen content
      final directory = (await getExternalStorageDirectory())!.path;
      final imagePath = '$directory/screenshot.png';
      await _capturePng(imagePath);
      
      // Perform OCR on the captured image
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      _addLogMessage('OCR Result: ${recognizedText.text}'); // Log the OCR result

      for (TextBlock block in recognizedText.blocks) {
        if (block.text.contains(text)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      _addLogMessage('Error checking for text: $e');
      return false;
    }
  }

  Future<void> _capturePng(String filePath) async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();
      final file = File(filePath);
      await file.writeAsBytes(buffer);
      _addLogMessage('Screenshot saved to $filePath'); // Log the screenshot save path
    } catch (e) {
      _addLogMessage('Error capturing screenshot: $e');
    }
  }

  void _stopGame() {
    setState(() {
      _isGameRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isGameRunning ? _stopGame : _startGame,
              child: Text(_isGameRunning ? 'Stop Game' : 'Start Game'),
            ),
            SizedBox(height: 20),
            Text(_isGameRunning ? 'Game is running...' : 'Game is stopped.'),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _logMessages.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_logMessages[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}