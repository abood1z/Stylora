import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LiveARTryOnScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LiveARTryOnScreen({super.key, required this.cameras});

  @override
  State<LiveARTryOnScreen> createState() => _LiveARTryOnScreenState();
}

class _LiveARTryOnScreenState extends State<LiveARTryOnScreen> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _isBusy = false;
  List<Pose> _poses = [];
  CustomPaint? _customPaint;
  ui.Image? _currentClothImage;

  // Placeholder images for the horizontal list view
  final List<String> _clothesAssets = [
    'assets/images/shirt1.png',
    'assets/images/shirt2.png',
    'assets/images/shirt3.png',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    final frontCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras[0],
    );

    // Initialize with 720p resolution
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController?.initialize();
    if (!mounted) return;

    setState(() {});

    _cameraController?.startImageStream((CameraImage image) {
      if (!_isBusy) {
        _isBusy = true;
        _processCameraImage(image);
      }
    });
  }

  Future<void> _loadClothImage(String assetFile) async {
    try {
      final ByteData data = await rootBundle.load(assetFile);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() {
        _currentClothImage = fi.image;
      });
    } catch (e) {
      debugPrint("Error loading cloth image: $e");
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (mounted) {
        setState(() {
          _poses = poses;
          _customPaint = CustomPaint(
            painter: AROverlayPainter(
              poses: _poses,
              imageSize: inputImage.metadata!.size,
              rotation: inputImage.metadata!.rotation,
              cameraLensDirection: _cameraController!.description.lensDirection,
              clothImage: _currentClothImage,
            ),
          );
        });
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
    } finally {
      if (mounted) {
        _isBusy = false;
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("AR Try-On"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            CameraPreview(_cameraController!),
          if (_customPaint != null) _customPaint!,

          // Horizontal ListView for Clothes
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _clothesAssets.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    _loadClothImage(_clothesAssets[index]);
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blueAccent, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        "Cloth ${index + 1}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // Ideally you would place Image.asset here:
                      // child: Image.asset(_clothesAssets[index], fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AROverlayPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final ui.Image? clothImage;

  AROverlayPainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    this.clothImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green.withValues(alpha: 0.5);

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        final x = _translateX(
          landmark.x,
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        final y = _translateY(
          landmark.y,
          size,
          imageSize,
          rotation,
          cameraLensDirection,
        );
        canvas.drawCircle(Offset(x, y), 5, paint);
      });

      // Connections based on body skeleton
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

      if (leftShoulder != null &&
          rightShoulder != null &&
          leftHip != null &&
          rightHip != null) {
        final ls = Offset(
          _translateX(
            leftShoulder.x,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
          _translateY(
            leftShoulder.y,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
        );
        final rs = Offset(
          _translateX(
            rightShoulder.x,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
          _translateY(
            rightShoulder.y,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
        );

        final lh = Offset(
          _translateX(
            leftHip.x,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
          _translateY(
            leftHip.y,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
        );
        final rh = Offset(
          _translateX(
            rightHip.x,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
          _translateY(
            rightHip.y,
            size,
            imageSize,
            rotation,
            cameraLensDirection,
          ),
        );

        // Draw Skeleton Lines
        canvas.drawLine(ls, rs, paint);
        canvas.drawLine(ls, lh, paint);
        canvas.drawLine(rs, rh, paint);
        canvas.drawLine(lh, rh, paint);

        // Render AR Clothes
        if (clothImage != null) {
          _drawCloth(canvas, ls, rs, lh, rh);
        }
      }
    }
  }

  void _drawCloth(Canvas canvas, Offset ls, Offset rs, Offset lh, Offset rh) {
    if (clothImage == null) return;

    // Scale: distance between shoulders defines shirt width
    final shoulderWidth = (ls.dx - rs.dx).abs();

    // A padding multiplier because clothes extend past joints
    final double scaleFactor = (shoulderWidth * 1.5) / clothImage!.width;

    // Angle: Rotation based on inclination between shoulders
    final double angle = math.atan2(
      rs.dy - ls.dy,
      rs.dy - ls.dy > 0 ? rs.dx - ls.dx : ls.dx - rs.dx,
    );

    // Center position: between shoulders
    final center = Offset((ls.dx + rs.dx) / 2, (ls.dy + rs.dy) / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scaleFactor);

    final offset = Offset(
      -clothImage!.width / 2,
      0,
    ); // Origin at top-center of cloth

    canvas.drawImage(clothImage!, offset, Paint());
    canvas.restore();
  }

  double _translateX(
    double x,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection lensDirection,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return lensDirection == CameraLensDirection.front
            ? canvasSize.width - (x * canvasSize.width / imageSize.height)
            : (x * canvasSize.width / imageSize.height);
      case InputImageRotation.rotation270deg:
        return lensDirection == CameraLensDirection.front
            ? (x * canvasSize.width / imageSize.height)
            : canvasSize.width - (x * canvasSize.width / imageSize.height);
      default:
        return x * canvasSize.width / imageSize.width;
    }
  }

  double _translateY(
    double y,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection lensDirection,
  ) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * canvasSize.height / imageSize.width;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
