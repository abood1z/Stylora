import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LiveTryOnScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LiveTryOnScreen({super.key, required this.cameras});

  @override
  State<LiveTryOnScreen> createState() => _LiveTryOnScreenState();
}

class _LiveTryOnScreenState extends State<LiveTryOnScreen> {
  CameraController? _controller;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _isProcessing = false;
  Pose? _lastPose;
  ui.Image? _clothImage;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadInitialCloth();
  }

  Future<void> _initCamera() async {
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // 480p for faster processing on mobile (30fps target)
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    _controller!.startImageStream(_processCameraImage);
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialCloth() async {
    final data = await rootBundle.load('assets/images/shirt1.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    setState(() => _clothImage = frame.image);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final inputImage = _getInputImage(image);
    if (inputImage != null) {
      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty && mounted) {
        setState(() {
          _lastPose = poses.first;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        });
      }
    }
    _isProcessing = false;
  }

  InputImage? _getInputImage(CameraImage image) {
    // Basic orientation/metadata handling simplified for brevity
    final rotation = InputImageRotationValue.fromRawValue(_controller!.description.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

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

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) return Container();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          if (_lastPose != null && _clothImage != null && _imageSize != null)
            CustomPaint(
              painter: RealTimeARPainter(
                pose: _lastPose!,
                clothImage: _clothImage!,
                imageSize: _imageSize!,
                rotation: _controller!.description.sensorOrientation,
              ),
            ),
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                // Trigger 'High-Quality Lapshot' here
              },
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ],
      ),
    );
  }
}

class RealTimeARPainter extends CustomPainter {
  final Pose pose;
  final ui.Image clothImage;
  final Size imageSize;
  final int rotation;

  RealTimeARPainter({
    required this.pose,
    required this.clothImage,
    required this.imageSize,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];

    if (ls == null || rs == null || lh == null) return;

    // 1. Better Coordinate Mapping
    Offset pLS = _mapPoint(ls.x, ls.y, size);
    Offset pRS = _mapPoint(rs.x, rs.y, size);
    Offset pLH = _mapPoint(lh.x, lh.y, size);

    // 2. Precise Euclidean Distance for Width
    final double shoulderWidth = math.sqrt(math.pow(pRS.dx - pLS.dx, 2) + math.pow(pRS.dy - pLS.dy, 2));
    
    // 3. Torso Height for vertical scaling accuracy
    final double torsoHeight = math.sqrt(math.pow(pLH.dx - pLS.dx, 2) + math.pow(pLH.dy - pLS.dy, 2));

    // 4. Center point shifted to chest (slightly below shoulders)
    final Offset center = Offset((pLS.dx + pRS.dx) / 2, (pLS.dy + pRS.dy) / 2 + (torsoHeight * 0.1));

    // 5. Angle of torso
    final double angle = math.atan2(pRS.dy - pLS.dy, pRS.dx - pLS.dx);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // 6. Dynamic Scaling (Cover torso area)
    double scale = (shoulderWidth * 1.4) / clothImage.width;
    canvas.scale(scale);

    // 7. Paint with ColorFilter to remove remaining white background if needed
    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
    
    // Position shirt starting from collar area
    canvas.drawImage(clothImage, Offset(-clothImage.width / 2, -clothImage.height * 0.15), paint);
    canvas.restore();
  }

  Offset _mapPoint(double x, double y, Size canvasSize) {
    // Invert X for Front Camera to fix mirroring
    double mirroredX = imageSize.width - x;
    double canvasX = (mirroredX / imageSize.width) * canvasSize.width;
    double canvasY = (y / imageSize.height) * canvasSize.height;
    return Offset(canvasX, canvasY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
