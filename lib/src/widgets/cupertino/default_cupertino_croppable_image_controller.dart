import 'dart:developer';

import 'package:croppy/src/src.dart';
import 'package:flutter/material.dart';

class DefaultCupertinoCroppableImageController extends StatefulWidget {
  const DefaultCupertinoCroppableImageController({
    super.key,
    required this.builder,
    required this.imageProvider,
    required this.initialData,
    this.allowedAspectRatios,
    this.postProcessFn,
    this.cropShapeFn,
    this.enabledTransformations,
    this.fixedAspect,
  });

  final ImageProvider imageProvider;
  final CroppableImageData? initialData;
  final double? fixedAspect;
  final CroppableImagePostProcessFn? postProcessFn;
  final CropShapeFn? cropShapeFn;
  final List<CropAspectRatio?>? allowedAspectRatios;
  final List<Transformation>? enabledTransformations;

  final Widget Function(BuildContext context, CupertinoCroppableImageController controller,
      DefaultCupertinoCroppableImageControllerState state) builder;

  @override
  State<DefaultCupertinoCroppableImageController> createState() =>
      DefaultCupertinoCroppableImageControllerState();
}

class DefaultCupertinoCroppableImageControllerState
    extends State<DefaultCupertinoCroppableImageController> with TickerProviderStateMixin {
  CupertinoCroppableImageController? _controller;
  final List<CropUndoNode> _undoStack = [];
  final List<CropUndoNode> _redoStack = [];
  late final CroppableImageData _resetData;
  bool _wasTransforming = false;
  final ValueNotifier<UndoRedoState> undoRedoNotifier =
      ValueNotifier(const UndoRedoState(canUndo: false, canRedo: false));
  CropShapeType _currentShape = CropShapeType.aabb;

  @override
  void initState() {
    super.initState();
    prepareController(type: widget.initialData?.cropShape.type, initialDatas: widget.initialData)
        .then((val) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetData = val!.data.copyWith();
        setState(() {});
      });
    });
  }

  void _restoreFromUndoNode(CropUndoNode node) {
    _controller?.onBaseTransformation(
      node.data.copyWith(
        currentImageTransform: Matrix4.identity(),
      ),
    );
  }

  CropAspectRatio aspectFromDouble(double fixedAspect) {
    const int base = 1000; // keeps precision
    return CropAspectRatio(
      width: (fixedAspect * base).round(),
      height: base,
    );
  }

  Future<CupertinoCroppableImageController?> prepareController(
      {CropShapeType? type, bool fromCrop = false, CroppableImageData? initialDatas}) async {
    late final CroppableImageData initialData;
    var tempCrop =
        (type == CropShapeType.aabb || type == null) ? aabbCropShapeFn : circleCropShapeFn;
    if (initialDatas != null && !fromCrop) {
      initialData = initialDatas!;
    } else {
      initialData = await CroppableImageData.fromImageProvider(
        widget.imageProvider,
        cropPathFn: tempCrop,
      );
    }
    // 🔥 STEP 4: RECREATE CONTROLLER

    resetListener();
    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      data: initialData,
      postProcessFn: widget.postProcessFn,
      cropShapeFn: tempCrop,
      allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );
    // if (widget.fixedAspect != null && !fromCrop) {
    //   var temp = aspectFromDouble(widget.fixedAspect!);
    //   log("aaaaaaaaaaa ${temp}");
    //   _controller!.currentAspectRatio = aspectFromDouble(widget.fixedAspect!);
    //   applyInitialCrop(fixedAspect: widget.fixedAspect!, widthFactor: 1);
    // }

    _pushUndoNode(_controller, data: initialData);
    initialiseListener(_controller!);

    if (mounted) {
      setState(() {});
    }
    return _controller;
  }

  void applyInitialCrop({
    required double fixedAspect,
    required double widthFactor,
  }) {
    final imageSize = _controller!.data.imageSize;

    final cropWidth = imageSize.width * widthFactor;
    final cropHeight = cropWidth / fixedAspect;

    final rect = Rect.fromCenter(
      center: imageSize.center(Offset.zero),
      width: cropWidth,
      height: cropHeight,
    );

    _controller?.onBaseTransformation(
      _controller!.data.copyWith(cropRect: rect),
    );
  }

  changeAspectRatio({CropAspectRatio? ratio, CropShapeType? shapeType}) {
    bool isElipse = shapeType == CropShapeType.ellipse;
    if (_controller!.cropShapeFn != circleCropShapeFn && (isElipse)) {
      print("----  Current shape changed to Square to Circle ");
      prepareController(type: CropShapeType.ellipse, fromCrop: true);
    } else if (_controller!.cropShapeFn == circleCropShapeFn && (!isElipse)) {
      print("----  Current shape changed to circle to square ");
      prepareController(type: CropShapeType.aabb, fromCrop: true).then((localController) {
        (localController as AspectRatioMixin).currentAspectRatio = ratio;
      });
    } else {
      (_controller as AspectRatioMixin).currentAspectRatio = ratio;
    }
  }

  resetListener() {
    _controller?.dispose();
    _controller = null;
    _controller?.removeListener(_onControllerChanged);
    _controller?.aspectRatioNotifier.removeListener(_onAspectRatioChanged);
  }

  initialiseListener(CupertinoCroppableImageController controller) {
    // initialize guards FIRST
    _wasTransforming = controller.isTransforming;

    controller.addListener(_onControllerChanged);
    controller.baseNotifier.addListener(() {
      _pushUndoNode(_controller, data: controller.baseNotifier.value);
    });
    controller.aspectRatioNotifier.addListener(_onAspectRatioChanged);
  }

  void _onAspectRatioChanged() {
    _pushUndoNode(
      _controller,
    );
  }

  void _onControllerChanged() {
    if (_controller == null) return;

    final isTransforming = _controller!.isTransforming;

    // 🔥 Gesture JUST finished (rotate / zoom / drag / flip)
    if (_wasTransforming && !isTransforming) {
      _pushUndoNode(_controller);
    }

    _wasTransforming = isTransforming;
  }

  bool get canUndo => _undoStack.length > 1;

  bool get canRedo => _redoStack.isNotEmpty;

  void _updateUndoRedoNotifier() {
    undoRedoNotifier.value = UndoRedoState(
      canUndo: _undoStack.length > 1,
      canRedo: _redoStack.isNotEmpty,
    );
  }

  void _pushUndoNode(CupertinoCroppableImageController? controller, {CroppableImageData? data}) {
    if (_controller == null) return;
    //
    // if (_undoStack.isNotEmpty &&
    //     _undoStack.last.data == _controller!.data &&
    //     _undoStack.last.shape == _currentShape) {
    //   return;
    // }

    _undoStack.add(
      CropUndoNode(
        data: data?.copyWith() ?? _controller!.data.copyWith(),
        shape: _currentShape,
      ),
    );

    _redoStack.clear();
    _updateUndoRedoNotifier();
  }

  void undo() {
    if (_undoStack.length <= 1) return;

    final current = _undoStack.removeLast();
    _redoStack.add(current);

    final previous = _undoStack.last;

    _currentShape = previous.shape;

    _controller?.dispose();

    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      data: previous.data.copyWith(),
      cropShapeFn: previous.data.cropShape.type == CropShapeType.ellipse
          ? circleCropShapeFn
          : aabbCropShapeFn,
      allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );
    _restoreFromUndoNode(previous);
    initialiseListener(_controller!);
    _updateUndoRedoNotifier();
    setState(() {});
  }

  void hardReset() {
    _undoStack.clear();
    _redoStack.clear();

    _controller?.onBaseTransformation(
      _resetData.copyWith(),
    );

    _updateUndoRedoNotifier();
  }

  resetData() {
    _controller?.onBaseTransformation(_resetData.copyWith());

    // _controller!.resetProcess(_resetData);
    // _redoStack.clear();
    // var temp = _undoStack.removeAt(0);
    // _undoStack.clear();
    // _undoStack.add(temp);
    // _updateUndoRedoNotifier();
  }

  resetDateWithInitializecontroller() {
    prepareController(type: _resetData?.cropShape.type, initialDatas: _resetData.copyWith());
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    final next = _redoStack.removeLast();
    _undoStack.add(next);

    _currentShape = next.shape;

    resetListener();

    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      data: next.data.copyWith(),
      cropShapeFn:
          next.data.cropShape.type == CropShapeType.ellipse ? circleCropShapeFn : aabbCropShapeFn,
      allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );
    _restoreFromUndoNode(next);
    initialiseListener(_controller!);
    _updateUndoRedoNotifier();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return widget.builder(context, _controller!, this);
  }
}
