// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:croppy/src/src.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<CropImageResult?> showCupertinoImageCropper(
  BuildContext context, {
  required ImageProvider imageProvider,
  CroppableImageData? initialData,
  CroppableImagePostProcessFn? postProcessFn,
  CropShapeFn? cropPathFn,
  List<CropAspectRatio?>? allowedAspectRatios,
  List<Transformation>? enabledTransformations,
  Object? heroTag,
  double? fixedAspect,
  CroppyStyleModel? croppyStyleModel,
  bool shouldPopAfterCrop = true,
  Locale? locale,
  CupertinoThemeData? themeData,
  bool showLoadingIndicatorOnSubmit = false,
  List<CropShapeType> showGestureHandlesOn = const [CropShapeType.aabb],
}) async {
  late final CroppableImageData _initialData;

  if (initialData != null) {
    _initialData = initialData;
  } else {
    _initialData = await CroppableImageData.fromImageProvider(
      imageProvider,
      cropPathFn: cropPathFn ?? aabbCropShapeFn,
    );
  }
  var tempCrop = _initialData.cropShape.type == CropShapeType.ellipse
      ? circleCropShapeFn
      : (cropPathFn ?? aabbCropShapeFn);
  Widget builder(context) {
    return CroppyLocalizationProvider(
      locale: locale,
      child: DefaultCupertinoCroppableImageController(
        imageProvider: imageProvider,
        initialData: _initialData,
        fixedAspect: fixedAspect,
        postProcessFn: postProcessFn,
        cropShapeFn: tempCrop,
        allowedAspectRatios: allowedAspectRatios,
        enabledTransformations: enabledTransformations,
        croppyStyleModel: croppyStyleModel,
        builder: (context, controller, state) => CupertinoImageCropperPage(
          checkKey: state,
          heroTag: heroTag,

          croppyStyleModel: croppyStyleModel,
          showLoadingIndicatorOnSubmit: showLoadingIndicatorOnSubmit,
          controller: controller,
          shouldPopAfterCrop: shouldPopAfterCrop,
          themeData: themeData,
          showGestureHandlesOn: showGestureHandlesOn,
        ),
      ),
    );
  }

  if (context.mounted) {
    return Navigator.of(context).push<CropImageResult?>(
      MaterialPageRoute(builder:builder),
    );
  }

  return null;
}
