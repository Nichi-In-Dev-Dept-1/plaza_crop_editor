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
    this.fixedAspect, this.croppyStyleModel,
  });

  final ImageProvider imageProvider;
  final CroppableImageData? initialData;
  final double? fixedAspect;
  final CroppyStyleModel? croppyStyleModel;
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

  bool _wasTransforming = false;
  final ValueNotifier<UndoRedoState> undoRedoNotifier =
      ValueNotifier(const UndoRedoState(canUndo: false, canRedo: false));
  CroppableImageData? resetData;

  @override
  void initState() {
    super.initState();
    if(widget.croppyStyleModel!=null){
      if(widget.croppyStyleModel!.onImageFirstLoadingStarted!=null){
        widget.croppyStyleModel!.onImageFirstLoadingStarted!();
      }
    }
    prepareController(type: widget.initialData?.cropShape.type, initialDatas: widget.initialData)
        .then((val) {
      defaultSetter(val);
    });
  }

  void _restoreFromUndoNode(CropUndoNode node) {
    _controller?.onBaseTransformation(
      node.data.copyWith(),
    );
  }

  void _makeItCenter({bool isFirstTime = false}) {
    var currentRect = _controller?.getCenterRect();
    _controller?.onBaseTransformation(
      _controller!.data.copyWith(cropRect: currentRect),
    );
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
     if(isFirstTime){
       if(widget.croppyStyleModel!.onImageFirstLoadingEnded!=null){
         widget.croppyStyleModel!.onImageFirstLoadingEnded!();
       }
     }
      _undoStack.removeLast();
      _pushUndoNode(_controller);
     resetData ??= _controller?.data;
      _updateUndoRedoNotifier();
    });
  }

  CropAspectRatio aspectRatioFromDouble(
    double aspect, {
    int base = 1000,
  }) {
    // aspect = width / height
    return CropAspectRatio(
      width: (aspect * base).round(),
      height: base,
    );
  }

  Future<CupertinoCroppableImageController?> prepareController(
      {CropShapeType? type,
      bool fromCrop = false,
      bool isReset = false,
      bool isUndoReset = false,
      CroppableImageData? initialDatas,
      bool isFreeCrop = false}) async {
    late CroppableImageData initialData;
    var tempCrop =
        (type == CropShapeType.aabb || type == null) ? aabbCropShapeFn : circleCropShapeFn;
    if (initialDatas != null && !fromCrop) {
      initialData = initialDatas!.copyWith();
    } else {
      initialData = await CroppableImageData.fromImageProvider(
        widget.imageProvider,
        cropPathFn: tempCrop,
      );
    }

    final preservedData = isReset
        ? initialData
        : isFreeCrop
            ? initialData
            : _controller?.data.copyWithProperCropShape(
                  cropShapeFn: tempCrop,
                ) ??
                initialData;
    if (!isUndoReset) {
      resetListener();
    }
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
      _pushUndoNode(_controller);
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
        (_controller as AspectRatioMixin).currentAspectRatio = ratio;
      });
    } else {
      if (ratio == null) {
        applyFreeCrop(ratio);
        return;
      }
      log("Ratio called ${ratio}");
      (_controller as AspectRatioMixin).currentAspectRatio = ratio;
    }
    // centerCropCorrectly(_controller!);
  }

  applyFreeCrop(CropAspectRatio? ratio) {
    Future.delayed(const Duration(milliseconds: 200)).then((_) {
      (_controller as AspectRatioMixin).currentAspectRatio = null;
      // (_controller as AspectRatioMixin).currentAspectRatio = ;
    });
  }

  resetListener() {
    _controller?.dispose();
    _controller = null;
  }

  void applyRotationFromUI(
    CupertinoCroppableImageController controller,
    double degrees, // -90 to +90
  ) {
    controller.onRotateByAngle(
      angleRad: degrees,
    );
  }

  initialiseListener(CupertinoCroppableImageController controller) {
    // initialize guards FIRST
    _wasTransforming = controller.isTransforming;

    controller.addListener(_onControllerChanged);
    controller.baseNotifier.addListener(() {
      log("----Base Notifier");
      _pushUndoNode(
        controller,
      );
    });
    controller.aspectRatioNotifier.addListener(_onAspectRatioChanged);

    controller.dataChangedNotifier.addListener(() {
      log("----data change Notifier");
      _pushUndoNode(controller);
      // Future.delayed(Duration(milliseconds: 300)).then((_) {
      //   _makeItCenter();
      // });
    });
    controller.mirrorDataChangedNotifier.addListener(() {
      log("----mirror change Notifier");

      _pushUndoNode(controller);
    });
  }

  void _onAspectRatioChanged() {
    Future.delayed(Duration(milliseconds: 300)).then((_) {
      // _undoStack.removeLast();
      _pushUndoNode(_controller);
      // _makeItCenter();
    });
  }

  void _onControllerChanged() {
    if (_controller == null) return;

    final isTransforming = _controller!.isTransforming;

    // 🔥 Gesture JUST finished (rotate / zoom / drag / flip)
    if (_wasTransforming && !isTransforming) {
      log("----General Notifier");
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

  void _pushUndoNode(
    CupertinoCroppableImageController? controller,
  ) {
    if (_controller == null) return;

    //
    // if (_undoStack.isNotEmpty &&
    //     _undoStack.last.data == _controller!.data &&
    //     _undoStack.last.shape == _currentShape) {
    //   return;
    // }

    _undoStack.add(
      CropUndoNode(
        data: controller?.data.copyWith() ?? _controller!.data.copyWith(),
        shape: controller!.data.copyWith().cropShape.type,
      ),
    );

    // _redoStack.clear();

    _updateUndoRedoNotifier();
  }

  void undo() {
    if (_undoStack.length <= 1) return;

    final current = _undoStack.removeLast();
    _redoStack.add(current);

    final previous = _undoStack.last;

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
    // if (isLastUndo) {
    //   Future.delayed(Duration(milliseconds: 300)).then((_) {
    //     callDefault();
    //   });
    // }
    setState(() {});
  }

  resetDateWithInitializecontroller({bool isUndoReset = false}) {
    _undoStack.clear();
    _redoStack.clear();

    prepareController(
      initialDatas: resetData,
      type: widget.initialData?.cropShape.type,
      isReset: true,
    ).then((val) {
      Future.delayed(Duration(milliseconds: 300)).then((_) {
        callDefault();
      });
    });
  }

  void redo() {
    log("redo  ${_redoStack.length}");
    if (_redoStack.isEmpty) return;

    final next = _redoStack.removeLast();
    _undoStack.add(next);

    resetListener();

    _controller = CupertinoCroppableImageController(
      vsync: this,
      imageProvider: widget.imageProvider,
      postProcessFn: widget.postProcessFn,
      data: next.data.copyWith(),
      cropShapeFn:
          next.data.cropShape.type == CropShapeType.ellipse ? circleCropShapeFn : aabbCropShapeFn,
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

  void defaultSetter(CupertinoCroppableImageController? val) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      callDefault(isFirstTime: true);
    });
  }

  callDefault({bool isFirstTime = false}) {
    if (widget.fixedAspect != null) {
      Future.delayed(Duration(milliseconds: isFirstTime ? 600 : 200)).then((_) {
        // applyAspectRatioCentered(snapped);
        // applyAspectRatioCentered(snapped);
        final snapped = aspectRatioFromDouble(
          widget.fixedAspect!,
        );

        (_controller as AspectRatioMixin).currentAspectRatio = snapped;
        Future.delayed(Duration(milliseconds: isFirstTime ? 600 : 200)).then((_) {
          _undoStack.removeLast();
          _updateUndoRedoNotifier();
          _makeItCenter(isFirstTime: isFirstTime);
        });
      });
    }
    setState(() {});
  }
}
