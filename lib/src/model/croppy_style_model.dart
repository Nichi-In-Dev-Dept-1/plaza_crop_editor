import 'package:flutter/material.dart';

import '../../croppy.dart';

class CroppyStyleModel {
  final Widget? backIcon;
  final Color? backGroundColor;
  final Color? bottomIconColor;
  final Widget? doneIcon;
  final Widget? resetIcon;
  final TextStyle? titleTextStyle;
  final String? titleText;
  final VoidCallback? onImageFirstLoadingStarted;
  final VoidCallback? onImageFirstLoadingEnded;
  final Widget? Function(CroppableImageController, DefaultCupertinoCroppableImageControllerState)?
      bottomNavigationBar;
  final PreferredSizeWidget? Function(
      CroppableImageController, DefaultCupertinoCroppableImageControllerState)? appbar;

  CroppyStyleModel({
    this.backIcon,
    this.backGroundColor,
    this.doneIcon,
    this.resetIcon,
    this.titleTextStyle,
    this.titleText,
    this.bottomNavigationBar,
    this.appbar,
    this.bottomIconColor,
    this.onImageFirstLoadingStarted,
    this.onImageFirstLoadingEnded,
  });
}

class CropUndoNode {
  final CroppableImageData data;
  final CropShapeType shape;

  CropUndoNode({
    required this.data,
    required this.shape,
  });
}

class UndoRedoState {
  final bool canUndo;
  final bool canRedo;

  const UndoRedoState({
    required this.canUndo,
    required this.canRedo,
  });
}
