import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pra_mlkit_text_recognition/convert_camera_image.dart';

List<CameraDescription> cameras = [];

class CameraView extends StatefulWidget {
  const CameraView({Key? key}) : super(key: key);

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late CameraController _controller;
  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.japanese);
  bool isReady = false;
  bool skipScanning = false;
  bool isScanned = false;
  RecognizedText? _recognizedText;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  _processImage(CameraImage availableImage) async {
    if (!mounted || skipScanning) return;
    setState(() {
      skipScanning = true;
    });

    final inputImage = convertCameraImage(
      camera: cameras[0],
      cameraImage: availableImage,
    );

    _recognizedText = await _textRecognizer.processImage(inputImage);
    await Future.delayed(Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      skipScanning = false;
    });
    if (_recognizedText != null && _recognizedText!.text.isNotEmpty) {
      _controller.stopImageStream();
      setState(() {
        isScanned = true;
      });
    }
  }

  Future<void> _setup() async {
    cameras = await availableCameras();

    _controller = CameraController(cameras[0], ResolutionPreset.max, imageFormatGroup: ImageFormatGroup.yuv420,);

    await _controller.initialize().catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });

    if (!mounted) {
      return;
    }

    setState(() {
      isReady = true;
    });

    _controller.startImageStream(_processImage);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = !isReady || !_controller.value.isInitialized;
    return Scaffold(
      appBar: AppBar(
        title: const Text('テキスト読み取り画面'),
      ),
      body: Column(
          children: isLoading
              ? [const Center(child: CircularProgressIndicator())]
              : [
            Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 12 / 9,
                  child: Stack(
                    children: [
                      ClipRect(
                        child: Transform.scale(
                          scale: _controller.value.aspectRatio * 12 / 9,
                          child: Center(
                            child: CameraPreview(_controller),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            isScanned
                ? ElevatedButton(
              child: const Text('再度読み取る'),
              onPressed: () {
                setState(() {
                  isScanned = false;
                  _recognizedText = null;
                });
                _controller.startImageStream(_processImage);
              },
            )
                : const Text('読み込み中'),
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Text(
                    _recognizedText != null ? _recognizedText!.text : ''),
              ),
            ),
            Text(
                // ((){return "";})()
                ((){
                  List<String> blockText = [];
                  if(_recognizedText!=null){
                    for (TextBlock block in _recognizedText!.blocks) {
                      // ブロック単位で取得したい情報がある場合はここに記載
                      blockText.add(block.text);
                      // for (TextLine line in block.lines) {
                      //   // ライン単位で取得したい情報がある場合はここに記載
                      // }
                    }
                    return blockText.toString();
                  }else{return "";}
                })()
            ),
          ]),
    );
  }
}
