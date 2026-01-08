import 'dart:developer';
import 'dart:math' as math;

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
    // _controller?.onBaseTransformation(
    //   node.data.copyWith(
    //     currentImageTransform: Matrix4.identity(),
    //   ),
    // );
  }

  CropAspectRatio? snapFromAllowedAspectRatios(
    double fixedAspect,
    List<CropAspectRatio?> allowedAspectRatios,
  ) {
    CropAspectRatio? closest;
    double minDiff = double.infinity;

    for (final ratio in allowedAspectRatios) {
      if (ratio == null) continue; // skip free crop

      final value = ratio.width / ratio.height;
      final diff = (fixedAspect - value).abs();

      if (diff < minDiff) {
        minDiff = diff;
        closest = ratio;
      }
    }

    return closest;
  }

  Offset quad2Center(Quad2 quad) {
    final cx = (quad.point0.x + quad.point1.x + quad.point2.x + quad.point3.x) / 4;

    final cy = (quad.point0.y + quad.point1.y + quad.point2.y + quad.point3.y) / 4;

    return Offset(cx, cy);
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
      // allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );
    if (widget.fixedAspect != null && !fromCrop) {
      final snapped = snapFromAllowedAspectRatios(
        widget.fixedAspect!,
        widget.allowedAspectRatios ?? [],
      );
      log("--------${snapped}");
      Future.delayed(const Duration(milliseconds: 100)).then((_) {
        // applyAspectRatioCentered(snapped);
        _controller!.currentAspectRatio = snapped;
      });
    }

    _pushUndoNode(_controller, data: initialData);
    initialiseListener(_controller!);

    if (mounted) {
      setState(() {});
    }
    return _controller;
  }

  changeAspectRatio({CropAspectRatio? ratio, CropShapeType? shapeType}) {
    bool isElipse = shapeType == CropShapeType.ellipse;
    if (_controller!.cropShapeFn != circleCropShapeFn && (isElipse)) {
      print("----  Current shape changed to Square to Circle ");
      prepareController(type: CropShapeType.ellipse, fromCrop: true);
    } else if (_controller!.cropShapeFn == circleCropShapeFn && (!isElipse)) {
      print("----  Current shape changed to circle to square ");
      prepareController(type: CropShapeType.aabb, fromCrop: true).then((localController) {
        if (ratio == null) {
          applyFreeCrop(ratio);
          return;
        }
        (_controller as AspectRatioMixin).currentAspectRatio =
            ratio ?? _controller?.allowedAspectRatios.first;
      });
    } else {
      if (ratio == null) {
        applyFreeCrop(ratio);
        return;
      }
      (_controller as AspectRatioMixin).currentAspectRatio = ratio;
    }
  }

  applyFreeCrop(CropAspectRatio? ratio) {
    (_controller as AspectRatioMixin).currentAspectRatio = _controller?.allowedAspectRatios.first;
    Future.delayed(const Duration(milliseconds: 200)).then((_) {
      (_controller as AspectRatioMixin).currentAspectRatio = ratio;
    });
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
      postProcessFn: widget.postProcessFn,
      // allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );
    _restoreFromUndoNode(previous);
    initialiseListener(_controller!);
    _updateUndoRedoNotifier();
    setState(() {});
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
      postProcessFn: widget.postProcessFn,
      data: next.data.copyWith(),
      cropShapeFn:
          next.data.cropShape.type == CropShapeType.ellipse ? circleCropShapeFn : aabbCropShapeFn,
      // allowedAspectRatios: widget.allowedAspectRatios,
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
