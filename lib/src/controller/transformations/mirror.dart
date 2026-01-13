import 'package:croppy/src/src.dart';
import 'package:flutter/material.dart';

/// Provides methods for mirroring the image.
mixin MirrorTransformation on BaseCroppableImageController {
  /// Mirrors the image horizontally.
  void onMirrorHorizontal() {
    final newBaseTransformations = data.baseTransformations.copyWith(
      scaleX: data.baseTransformations.scaleX * -1,
    );

    final transformation = getMatrixForBaseTransformations(
      newBaseTransformations,
    );

    final cropRect = data.cropRect.transform(transformation);

    var newData = data.copyWith(
      cropRect: cropRect,
      baseTransformations: newBaseTransformations,
    );
    onBaseTransformation(newData);
    _updateRotationNotifier();
  }

  void onMirrorVertical() {
    final newBaseTransformations = data.baseTransformations.copyWith(
      scaleY: data.baseTransformations.scaleY * -1,
    );

    final transformation = getMatrixForBaseTransformations(
      newBaseTransformations,
    );

    final cropRect = data.cropRect.transform(transformation);
    var newData = data.copyWith(
      cropRect: cropRect,
      baseTransformations: newBaseTransformations,
    );
    onBaseTransformation(newData);
    _updateRotationNotifier();
  }

  final horizontalFlipNotifier = ValueNotifier<bool>(false);
  final verticalFlipNotifier = ValueNotifier<bool>(false);
  ValueNotifier<CroppableImageData?> mirrorDataChangedNotifier = ValueNotifier(null);

  _updateRotationNotifier() {
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      mirrorDataChangedNotifier.value = data;
    });
  }

  @override
  void recomputeValueNotifiers() {
    super.recomputeValueNotifiers();

    horizontalFlipNotifier.value = data.baseTransformations.scaleX < 0;

    verticalFlipNotifier.value = data.baseTransformations.scaleY < 0;
  }
}
