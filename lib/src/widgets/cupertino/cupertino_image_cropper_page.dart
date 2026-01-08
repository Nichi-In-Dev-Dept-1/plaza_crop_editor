import 'dart:math';

import 'package:croppy/src/model/croppy_style_model.dart';
import 'package:croppy/src/src.dart';
import 'package:croppy/src/widgets/cupertino/cupertino_image_cropper_app_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CupertinoImageCropperPage extends StatelessWidget {
  CupertinoImageCropperPage({
    super.key,
    required this.controller,
    required this.shouldPopAfterCrop,
    required this.showGestureHandlesOn,
    this.gesturePadding = 16.0,
    this.heroTag,
    this.themeData,
    this.showLoadingIndicatorOnSubmit = false,
    this.croppyStyleModel,
    required this.checkKey,
  }) {
    _croppyStyleModel = croppyStyleModel ?? CroppyStyleModel();
  }

  final CroppableImageController controller;
  final double gesturePadding;
  final Object? heroTag;
  final DefaultCupertinoCroppableImageControllerState checkKey;
  final CroppyStyleModel? croppyStyleModel;
  final bool shouldPopAfterCrop;
  final bool showLoadingIndicatorOnSubmit;
  final List<CropShapeType> showGestureHandlesOn;
  final CupertinoThemeData? themeData;
  late CroppyStyleModel _croppyStyleModel;

  @override
  Widget build(BuildContext context) {


    return Theme(
      data: Theme.of(context)
          .copyWith(scaffoldBackgroundColor: _croppyStyleModel.backGroundColor),
      child: Scaffold(
        backgroundColor: _croppyStyleModel.backGroundColor,
        appBar: _croppyStyleModel.appbar == null
            ? null
            : _croppyStyleModel.appbar!(controller, checkKey),
        bottomNavigationBar: _croppyStyleModel.bottomNavigationBar == null
            ? null
            : _croppyStyleModel.bottomNavigationBar!(controller, checkKey),
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: _croppyStyleModel.backGroundColor ,
            statusBarBrightness: Brightness.dark,
            statusBarColor: _croppyStyleModel.backGroundColor,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: CroppableImagePageAnimator(
            controller: controller,
            heroTag: heroTag,
            builder: (context, overlayOpacityAnimation) {
              return CupertinoPageScaffold(
                backgroundColor: _croppyStyleModel.backGroundColor,
                navigationBar: _croppyStyleModel.appbar == null
                    ? CupertinoImageCropperAppBar(
                        controller: controller,
                      )
                    : null,
                child: SafeArea(
                  top: false,
                  bottom: true,
                  minimum: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: RepaintBoundary(
                          child: AnimatedCroppableImageViewport(
                            controller: controller,
                            overlayOpacityAnimation: overlayOpacityAnimation,
                            gesturePadding: gesturePadding,
                            heroTag: heroTag,
                            cropHandlesBuilder: (context) => CupertinoImageCropHandles(
                              controller: controller,
                              gesturePadding: gesturePadding,
                              showGestureHandlesOn: showGestureHandlesOn,
                            ),
                          ),
                        ),
                      ),
                      if (_croppyStyleModel.bottomNavigationBar == null)
                        RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: overlayOpacityAnimation,
                            builder: (context, _) => Opacity(
                              opacity: overlayOpacityAnimation.value,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 96.0,
                                    child: CupertinoToolbar(
                                      controller: controller,
                                    ),
                                  ),
                                  CupertinoImageCropperBottomAppBar(
                                    controller: controller,
                                    shouldPopAfterCrop: shouldPopAfterCrop,
                                    showLoadingIndicatorOnSubmit: showLoadingIndicatorOnSubmit,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

// Widget _bottomNavigationBar(BuildContext context) {
//   return Container(
//     color: _croppyStyleModel.backGroundColor,
//     child: Row(
//       spacing: 12,
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         IconWithName(
//           onPressed: () async {
//             // final CroppableImageData initialData = await CroppableImageData.fromImageProvider(
//             //   controller.res,
//             //   cropPathFn: ellipseCropShapeFn,
//             // );
//             // controller.CahnageShaoe(initialData);
//
//             // checkKey.currentState!.changeShape();
//             // controller.cropShapeFn=CropShape();
//             // controller.onBaseTransformation(
//             //     initialData.copyWithProperCropShape(cropShapeFn: ellipseCropShapeFn));
//             showCropOptions(context);
//           },
//           title: "Cropper",
//           child: const Icon(
//             Icons.crop,
//             color: Colors.black,
//           ),
//         ),
//         IconWithName(
//             onPressed: controller.onRotateCCW,
//             title: "Rotate",
//             child: const Icon(Icons.rotate_90_degrees_ccw, color: Colors.black)),
//         IconWithName(
//             onPressed: controller.onMirrorHorizontal,
//             title: "Flip",
//             child: const Icon(Icons.flip, color: Colors.black)),
//         IconWithName(
//             onPressed: controller.onMirrorVertical,
//             title: "Flip",
//             child: Transform.rotate(
//               angle: pi / 2,
//               child: const Icon(Icons.flip, color: Colors.black),
//             )),
//       ],
//     ),
//   );
// }

// Future<void> showCropOptions(BuildContext context) async {
//   await showModalBottomSheet<Object?>(
//     context: context,
//     clipBehavior: Clip.antiAlias,
//     backgroundColor: _croppyStyleModel.backGroundColor,
//     builder: (_) {
//       return AspectRatioSelectionBottomSheet(
//         controller: controller as AspectRatioMixin,
//         onCircleTap: (val, isElipse) {
//           checkKey.changeAspectRatio(ratio: val, shapeType: isElipse);
//         },
//       );
//     },
//   );
// }
}

class IconWithName extends StatelessWidget {
  const IconWithName({super.key, required this.child, required this.title, this.onPressed});

  final Widget child;
  final String title;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: onPressed,
        icon: Column(
          spacing: 6,
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            Text(
              title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
            )
          ],
        ));
  }
}

// class AspectRatioSelectionBottomSheet extends StatelessWidget {
//   const AspectRatioSelectionBottomSheet(
//       {super.key, required this.controller, required this.onCircleTap});
//
//   final AspectRatioMixin controller;
//   final Function(CropAspectRatio?, CropShapeType isEllipse) onCircleTap;
//
//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: <Widget>[
//             // Aspect ratios
//             _buildAspectRatioChip(
//                 label: 'Free-Crop', ratio: null, context: context, iconData: Icons.crop_free),
//             _buildAspectRatioChip(
//                 label: 'Square',
//                 ratio: const CropAspectRatio(width: 1, height: 1),
//                 context: context,
//                 iconData: Icons.crop_square),
//             _buildAspectRatioChip(
//                 label: 'Circle',
//                 ratio: null,
//                 context: context,
//                 iconData: Icons.circle_outlined,
//                 isEllipse: CropShapeType.ellipse),
//             _buildAspectRatioChip(
//                 label: '3:4', ratio: const CropAspectRatio(width: 3, height: 4), context: context),
//             _buildAspectRatioChip(
//                 label: '4:3', ratio: const CropAspectRatio(width: 4, height: 3), context: context),
//             _buildAspectRatioChip(
//                 label: '16:9',
//                 ratio: const CropAspectRatio(width: 16, height: 9),
//                 context: context),
//             _buildAspectRatioChip(
//                 label: '9:16',
//                 ratio: const CropAspectRatio(width: 9, height: 16),
//                 context: context),
//
//             // Special crops
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildAspectRatioChip(
//       {required String label,
//       IconData? iconData,
//       CropShapeType isEllipse = CropShapeType.aabb,
//       CropAspectRatio? ratio,
//       required BuildContext context}) {
//     return ActionChip(
//       backgroundColor: Colors.white,
//       side: const BorderSide(color: Colors.grey),
//       label: Text(label),
//       // avatar: iconData == null
//       //     ? null
//       //     : Icon(
//       //         iconData,
//       //         size: 20,
//       //         color: croppyStyleModel.bottomIconColor,
//       //       ),
//       onPressed: () {
//         Navigator.pop(context);
//         onCircleTap(ratio, isEllipse);
//       },
//     );
//   }
// }
