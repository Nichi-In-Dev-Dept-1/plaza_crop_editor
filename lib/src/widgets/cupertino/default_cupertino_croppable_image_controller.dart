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
        if (widget.fixedAspect != null) {
          Future.delayed(const Duration(milliseconds: 500)).then((_) {
            // applyAspectRatioCentered(snapped);
            final snapped = snapFromAllowedAspectRatios(
              widget.fixedAspect!,
              widget.allowedAspectRatios ?? [],
            );
            changeAspectRatio(ratio: snapped);
          });
        }
        setState(() {});
      });
    });
  }

  void _restoreFromUndoNode(CropUndoNode node) {
    _controller?.onBaseTransformation(
      node.data.copyWith(),
    );
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
      {CropShapeType? type,
      bool fromCrop = false,
      CroppableImageData? initialDatas,
      bool isFreeCrop = false}) async {
    late CroppableImageData initialData;
    var tempCrop =
        (type == CropShapeType.aabb || type == null) ? aabbCropShapeFn : circleCropShapeFn;
    if (initialDatas != null && !fromCrop) {
      log("aaaa using old data ${initialDatas}");
      initialData = initialDatas!;
    } else {
      log("aaaa using new  data");
      initialData = await CroppableImageData.fromImageProvider(
        widget.imageProvider,
        cropPathFn: tempCrop,
      );
      if (widget.initialData != null) {}
    }
    // 🔥 STEP 4: RECREATE CONTROLLER
    // 1️⃣ Preserve all transforms, only update shape

    final preservedData = isFreeCrop
        ? initialData
        : _controller?.data.copyWithProperCropShape(
              cropShapeFn: tempCrop,
            ) ??
            initialData;
    resetListener();
    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      data: preservedData,
      postProcessFn: widget.postProcessFn,
      cropShapeFn: tempCrop,
      // allowedAspectRatios: widget.allowedAspectRatios,
      enabledTransformations: widget.enabledTransformations ?? Transformation.values,
    );

    if (fromCrop == false) {
      _pushUndoNode(_controller, data: initialData);
    }
    initialiseListener(_controller!);

    if (mounted) {
      setState(() {});
    }
    return _controller;
  }

  changeAspectRatio({CropAspectRatio? ratio, CropShapeType? shapeType}) {
    bool isElipse = shapeType == CropShapeType.ellipse;
    if (_controller!.cropShapeFn != circleCropShapeFn && (isElipse)) {
      prepareController(type: CropShapeType.ellipse, fromCrop: true);

      Future.delayed(const Duration(milliseconds: 100)).then((_) {
        (_controller as AspectRatioMixin).currentAspectRatio = CropAspectRatio(width: 1, height: 1);
      });
    } else if (_controller!.cropShapeFn == circleCropShapeFn && (!isElipse)) {
      prepareController(type: CropShapeType.aabb, fromCrop: true, isFreeCrop: ratio == null)
          .then((localController) {
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
    // (_controller as AspectRatioMixin).currentAspectRatio = _controller?.allowedAspectRatios.first;
    Future.delayed(const Duration(milliseconds: 200)).then((_) {
      (_controller as AspectRatioMixin).currentAspectRatio = _controller?.allowedAspectRatios.first;
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
    log("uuuuuuuu  ${_undoStack.length}");
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
    prepareController(
        type: _resetData?.cropShape.type,
        initialDatas: _resetData.copyWith(),
        isFreeCrop: true,
        fromCrop: true);
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
    log("aaaaaaaaaa--${_controller?.currentAspectRatio}");
    return widget.builder(context, _controller!, this);
  }
}
