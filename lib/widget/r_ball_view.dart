import 'dart:convert';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

typedef OnTapRBallTagCallback = void Function(RBallTagData);

//The point hit when the finger is pressed
PointAnimationSequence? pointAnimationSequence;

//sphere radius
int radius = 150;

///text color
Color textColor = const Color(0xFF333333);

///text highlight color
Color highLightTextColor = const Color(0xFF000000);

class RBallView extends StatefulWidget {
  final MediaQueryData mediaQueryData;

  ///Keywords to display
  final List<RBallTagData> keywords;

  ///Keywords that need to be highlighted
  final List<RBallTagData> highlight;

  /// Display up to multiple characters
  final int maxChar;

  /// click callback
  final OnTapRBallTagCallback? onTapRBallTagCallback;

  /// Whether to run animation
  final bool isAnimate;

  /// Sphere Container Decoration
  final Decoration? decoration;

  /// Whether to show the sphere container decoration
  final bool isShowDecoration;

  ///elevation reference value
  ///Uniform distribution of elevation angles
  final List<double>? centers;

  ///sphere radius
  final int? radius;

  ///text color
  final Color? textColor;

  ///text highlight color
  final Color? highLightTextColor;

  const RBallView({
    Key? key,
    required this.mediaQueryData,
    required this.keywords,
    required this.highlight,
    this.maxChar = 5,
    this.onTapRBallTagCallback,
    this.isAnimate = true,
    this.decoration,
    this.isShowDecoration = false,
    this.centers,
    this.radius,
    this.textColor,
    this.highLightTextColor,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _RBallViewState();
  }
}

class _RBallViewState extends State<RBallView>
    with SingleTickerProviderStateMixin {
  //Ball image width with halo
  late double sizeOfBallWithFlare;

  List<Point> points = [];

  late Animation<double> animation;
  late AnimationController controller;
  double currentRadian = 0;

  //The previous position of the finger movement
  late Offset lastPosition;

  //where the finger is pressed
  late Offset downPosition;

  //The time when the keyword was last clicked and hit
  int lastHitTime = 0;

  //current axis of rotation
  Point axisVector = getAxisVector(Offset(2, -1));

  @override
  void initState() {
    super.initState();

    /// Initialize tool class
    if (widget.keywords.length < 10) {
      RBallViewUtil.nameHalfSize = 12;
      RBallViewUtil.pointHalfTop = 6;
      RBallViewUtil.pointHalfWidth = 16;
    } else if (widget.keywords.length < 20) {
      RBallViewUtil.nameHalfSize = 10;
      RBallViewUtil.pointHalfTop = 6;
      RBallViewUtil.pointHalfWidth = 14;
    } else if (widget.keywords.length < 30) {
      RBallViewUtil.nameHalfSize = 8;
      RBallViewUtil.pointHalfTop = 5;
      RBallViewUtil.pointHalfWidth = 12;
    } else {
      RBallViewUtil.nameHalfSize = 6;
      RBallViewUtil.pointHalfTop = 3;
      RBallViewUtil.pointHalfWidth = 9;
    }

    // Initialize constant value
    textColor = widget.textColor ?? const Color(0xFF333333);
    highLightTextColor = widget.highLightTextColor ?? const Color(0xFF000000);

    //Calculate ball size, radius, etc.
    sizeOfBallWithFlare = widget.mediaQueryData.size.width - 2 * 10;
    radius = widget.radius ?? ((sizeOfBallWithFlare * 32 / 35) / 2).round();

    //initialization point
    generatePoints(widget.keywords, widget.maxChar);

    //animation
    controller = AnimationController(
        duration: Duration(milliseconds: 40000), vsync: this);
    animation = Tween(begin: 0.0, end: pi * 2).animate(controller);
    animation.addListener(() {
      setState(() {
        for (int i = 0; i < points.length; i++) {
          rotatePoint(axisVector, points[i], animation.value - currentRadian);
        }
        currentRadian = animation.value;
      });
    });
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        currentRadian = 0;
        controller.forward(from: 0.0);
      }
    });
    controller.forward();
  }

  @override
  void didUpdateWidget(RBallView oldWidget) {
    super.didUpdateWidget(oldWidget);

    //Data has changed, reinitialize the point
    if (oldWidget.keywords != widget.keywords) {
      generatePoints(widget.keywords, widget.maxChar);
    }

    // animation state change
    if (oldWidget.isAnimate != widget.isAnimate) {
      if (controller.isAnimating && !widget.isAnimate) {
        controller.stop();
      } else if (!controller.isAnimating && widget.isAnimate) {
        double from = currentRadian / (pi * 2);
        controller.forward(from: from);
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void generatePoints(List<RBallTagData> keywords, int maxChar) {
    points.clear();
    Random random = Random();
    //elevation reference value
    //Uniform distribution of elevation angles
    List<double> centers = widget.centers ??
        [
          0.5,
          0.35,
          0.65,
          0.35,
          0.2,
          0.5,
          0.65,
          0.35,
          0.65,
          0.8,
        ];

    //Divide 2pi into equal parts of keywords.length
    double dAngleStep = 2 * pi / keywords.length;
    for (int i = 0; i < keywords.length; i++) {
      //polar azimuth
      double dAngle = dAngleStep * i;
      //elevation angle
      double eAngle = (centers[i % 10] + (random.nextDouble() - 0.5) / 10) * pi;

      //Spherical Coordinates to Cartesian Coordinates
      double x = radius * sin(eAngle) * sin(dAngle);
      double y = radius * cos(eAngle);
      double z = radius * sin(eAngle) * cos(dAngle);

      Point point = Point(x, y, z);
      point.data = keywords[i];
      String showName = point.data.tag;
      bool needHight = _needHight(point.data);
      if (point.data.tag.characters.length > maxChar) {
        showName =
            keywords[i].tag.characters.getRange(0, maxChar).toString() + '...';
      }
      //Calculate the paragraph of the point at each z coordinate
      point.paragraphs = [];
      //Generate a paragraph every 3 z, saving memory
      for (int z = -radius; z <= radius; z += 3) {
        point.paragraphs.add(
          buildText(
            showName,
            2.0 * radius,
            RBallViewUtil.getNameFontsize(z.toDouble()),
            RBallViewUtil.getPointOpacity(z.toDouble()),
            needHight,
          ),
        );
      }
      points.add(point);
    }
  }

  ///Check if this keyword needs to be highlighted
  bool _needHight(RBallTagData tag) {
    bool ret = false;
    if (widget.highlight.length > 0) {
      for (int i = 0; i < widget.highlight.length; i++) {
        if (tag == widget.highlight[i]) {
          ret = true;
          break;
        }
      }
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isShowDecoration) {
      return Container(
        decoration: widget.decoration ??
            BoxDecoration(
              color: Color(0xffffffff),
              borderRadius: BorderRadius.circular(radius.toDouble()),
              boxShadow: [
                BoxShadow(
                  color: Color(0xffeeeeee),
                  blurRadius: 5.0,
                )
              ],
            ),
        child: _buildBall(),
      );
    }
    return _buildBall();
  }

  Widget _buildBall() {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        int now = DateTime.now().millisecondsSinceEpoch;
        downPosition = convertCoordinate(event.localPosition);
        lastPosition = convertCoordinate(event.localPosition);

        //speed tracking queue
        clearQueue();
        addToQueue(PositionWithTime(downPosition, now));

        //Stop animation on finger touch
        controller.stop();
      },
      onPointerMove: (PointerMoveEvent event) {
        int now = DateTime.now().millisecondsSinceEpoch;
        Offset currentPostion = convertCoordinate(event.localPosition);

        addToQueue(PositionWithTime(currentPostion, now));

        Offset delta = Offset(currentPostion.dx - lastPosition.dx,
            currentPostion.dy - lastPosition.dy);
        double distance = sqrt(delta.dx * delta.dx + delta.dy * delta.dy);
        //If the calculation level is too small,
        // an error of precision overflow will be reported inside the framework
        if (distance > 2) {
          //rotation point
          setState(() {
            lastPosition = currentPostion;

            //The angle in radians the sphere should rotate = distance/radius
            double radian = distance / radius;
            //旋转轴
            axisVector = getAxisVector(delta);
            //The location of the update point
            for (int i = 0; i < points.length; i++) {
              rotatePoint(axisVector, points[i], radian);
            }
          });
        }
      },
      onPointerUp: (PointerUpEvent event) {
        int now = DateTime.now().millisecondsSinceEpoch;
        Offset upPosition = convertCoordinate(event.localPosition);

        addToQueue(PositionWithTime(upPosition, now));

        //Detect whether it is a fling gesture
        Offset velocity = getVelocity();
        if (widget.isAnimate) {
          //Velocity modulus >=1 is considered fling gesture
          if (sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy) >=
              1) {
            //Start fling animation
            currentRadian = 0;
            controller.fling();
          } else {
            //Start animation at constant speed
            currentRadian = 0;
            controller.forward(from: 0.0);
          }
        }

        //Detect click events
        double distanceSinceDown = sqrt(
            pow(upPosition.dx - downPosition.dx, 2) +
                pow(upPosition.dy - downPosition.dy, 2));
        //If the distance between the pressed and lifted points is less than 4,
        // it is considered a click event
        if (distanceSinceDown < 4) {
          //Find the hit point
          int searchRadiusW = RBallViewUtil.nameHalfSize.toInt() * 3;
          int searchRadiusH = (RBallViewUtil.nameHalfSize +
                      RBallViewUtil.pointHalfTop +
                      RBallViewUtil.pointHalfWidth)
                  .toInt() *
              2;
          for (int i = 0; i < points.length; i++) {
            //points[i].z >= 0：Find only points on the front of the ball
            if (points[i].z >= 0 &&
                (upPosition.dx - points[i].x).abs() < searchRadiusW &&
                (upPosition.dy - points[i].y).abs() < searchRadiusH) {
              int now = DateTime.now().millisecondsSinceEpoch;
              //prevent double click
              if (now - lastHitTime > 2000) {
                lastHitTime = now;
                //Create a point-and-click animation sequence
                pointAnimationSequence = PointAnimationSequence(
                    points[i], _needHight(points[i].data));

                // call back
                widget.onTapRBallTagCallback?.call(points[i].data);
              }
              break;
            }
          }
        }
      },
      onPointerCancel: (_) {
        //开始匀速动画
        currentRadian = 0;
        controller.forward(from: 0.0);
      },
      child: ClipOval(
        child: CustomPaint(
          size: Size(2.0 * radius, 2.0 * radius),
          painter: MyPainter(points),
        ),
      ),
    );
  }

  ///speed tracking queue
  Queue<PositionWithTime> queue = Queue();

  ///add tracepoint
  void addToQueue(PositionWithTime p) {
    int lengthOfQueue = 5;
    if (queue.length >= lengthOfQueue) {
      queue.removeFirst();
    }

    queue.add(p);
  }

  ///clear queue
  void clearQueue() {
    queue.clear();
  }

  ///calculation speed
  ///Speed unit: pixel/millisecond
  Offset getVelocity() {
    Offset ret = Offset.zero;

    if (queue.length >= 2) {
      PositionWithTime first = queue.first;
      PositionWithTime last = queue.last;
      ret = Offset(
        (last.position.dx - first.position.dx) / (last.time - first.time),
        (last.position.dy - first.position.dy) / (last.time - first.time),
      );
    }

    return ret;
  }
}

class MyPainter extends CustomPainter {
  List<Point> points;
  late Paint ballPaint, pointPaint;

  MyPainter(this.points) {
    pointPaint = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    //draw text
    for (int i = 0; i < points.length; i++) {
      Point point = points[i];
      List<double> xy = transformCoordinate(point);
      ui.Paragraph p;
      //It is the selected point, which needs to show the effect of zooming in and out
      if (pointAnimationSequence != null &&
          pointAnimationSequence?.point == point) {
        //Animation didn't complete
        if (pointAnimationSequence!.paragraphs.isNotEmpty) {
          p = pointAnimationSequence!.paragraphs.removeFirst();
          //animation finished
        } else {
          p = point.getParagraph(radius);
          pointAnimationSequence = null;
        }
      } else {
        p = point.getParagraph(radius);
      }

      //Get the width and height of the text
      double halfWidth = p.minIntrinsicWidth / 2;
      double halfHeight = p.height / 2;
      //Draw text (point is the coordinate in the 3D model coordinate system,
      // which needs to be converted to the coordinate in the drawing coordinate system)
      canvas.drawParagraph(
        p,
        Offset(xy[0] - halfWidth, xy[1] - halfHeight),
      );
      //draw dots
      pointPaint
        ..color = Colors.primaries[i % 17]
            .withOpacity(RBallViewUtil.getPointOpacity(point.z))
        ..strokeWidth = RBallViewUtil.getPointStrokeWidth(point.z);

      canvas.drawPoints(
          ui.PointMode.points,
          [
            Offset(xy[0],
                xy[1] + p.height + RBallViewUtil.getPointTopMargin(point.z))
          ],
          pointPaint);
    }
  }

  ///Convert coordinates in the 3d model coordinate system to coordinates in the drawing coordinate system
  ///x2 = r+x1;y2 = r-y1;
  List<double> transformCoordinate(Point point) {
    return [radius + point.x, radius - point.y, point.z];
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

///Calculate the point coordinates of the point point after rotating radian radians around the axis axis
///Calculation basis: Rodrigue's rotation vector formula
void rotatePoint(
  Point axis,
  Point point,
  double radian,
) {
  double x = cos(radian) * point.x +
      (1 - cos(radian)) *
          (axis.x * point.x + axis.y * point.y + axis.z * point.z) *
          axis.x +
      sin(radian) * (axis.y * point.z - axis.z * point.y);

  double y = cos(radian) * point.y +
      (1 - cos(radian)) *
          (axis.x * point.x + axis.y * point.y + axis.z * point.z) *
          axis.y +
      sin(radian) * (axis.z * point.x - axis.x * point.z);

  double z = cos(radian) * point.z +
      (1 - cos(radian)) *
          (axis.x * point.x + axis.y * point.y + axis.z * point.z) *
          axis.z +
      sin(radian) * (axis.x * point.y - axis.y * point.x);

  point.x = x;
  point.y = y;
  point.z = z;
}

///Calculate the approximate angle by which the sphere should turn based on the straight-line distance the finger touch moves
///Arc length corresponding to unit angle：2*pi*r/2*pi = 1/r
double getRadian(double distance) {
  return distance / radius;
}

//Convert coordinates in the drawing coordinate system to coordinates in the 3d model coordinate system
Offset convertCoordinate(Offset offset) {
  return Offset(offset.dx - radius, radius - offset.dy);
}

///Get the unit vector in the direction of the rotation axis from the rotation vector
///Rotate the rotation vector (x, y) 90 degrees counterclockwise
///x2 = xcos(pi/2)-ysin(pi/2)
///y2 = xsin(pi/2)+ycos(pi/2)
Point getAxisVector(Offset scrollVector) {
  double x = -scrollVector.dy;
  double y = scrollVector.dx;
  double module = sqrt(x * x + y * y);
  return Point(x / module, y / module, 0);
}

ui.Paragraph buildText(
  String content,
  double maxWidth,
  double fontSize,
  double opacity,
  bool highLight,
) {
  String text = content;

  ui.ParagraphBuilder paragraphBuilder =
      ui.ParagraphBuilder(ui.ParagraphStyle());
  paragraphBuilder.pushStyle(
    ui.TextStyle(
        fontSize: fontSize,
        color: highLight
            ? highLightTextColor.withOpacity(opacity)
            : textColor.withOpacity(opacity),
        height: 1.0,
        shadows: highLight
            ? [
                Shadow(
                  color: Colors.white.withOpacity(opacity),
                  offset: Offset(0, 0),
                  blurRadius: 10,
                )
              ]
            : []),
  );
  paragraphBuilder.addText(text);

  ui.Paragraph paragraph = paragraphBuilder.build();
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));
  return paragraph;
}

class Point {
  double x, y, z;
  late RBallTagData data;
  late List<ui.Paragraph> paragraphs;

  Point(this.x, this.y, this.z);

  //The paragraph when z takes the value [-radius, radius] is stored in the paragraphs in turn
  //Generate a paragraph every 3 z
  getParagraph(int radius) {
    int index = (z + radius).round() ~/ 3;
    return paragraphs[index];
  }
}

class PositionWithTime {
  Offset position;
  int time;

  PositionWithTime(this.position, this.time);
}

class PointAnimationSequence {
  late Point point;
  late bool needHighLight;
  late Queue<ui.Paragraph> paragraphs;

  PointAnimationSequence(this.point, this.needHighLight) {
    paragraphs = Queue();

    double fontSize = RBallViewUtil.getNameFontsize(point.z);
    double opacity = RBallViewUtil.getPointOpacity(point.z);
    //Font size changed from fontSize to 16
    for (double fs = fontSize;
        fs <= RBallViewUtil.nameHalfSize * 2 + 5;
        fs += 1) {
      paragraphs.addLast(
          buildText(point.data.tag, 2.0 * radius, fs, opacity, needHighLight));
    }
    //Font size changed from 16 to fontSize
    for (double fs = RBallViewUtil.nameHalfSize * 2 + 5;
        fs >= fontSize;
        fs -= 1) {
      paragraphs.addLast(
          buildText(point.data.tag, 2.0 * radius, fs, opacity, needHighLight));
    }
  }
}

RBallTagData tagModelFromJson(String str) =>
    RBallTagData.fromJson(json.decode(str));

String tagModelToJson(RBallTagData data) => json.encode(data.toJson());

class RBallTagData {
  RBallTagData({
    required this.tag,
    required this.id,
  });

  String tag;
  String id;

  factory RBallTagData.fromJson(Map<String, dynamic> json) => RBallTagData(
        tag: json["tag"],
        id: json["id"],
      );

  Map<String, dynamic> toJson() => {
        "tag": tag,
        "id": id,
      };
}

/// Utility
class RBallViewUtil {
  static int itemCount = 30;

  static double nameHalfSize = 6;
  static double pointHalfTop = 3;
  static double pointHalfWidth = 9;

  ///
  /// Get the size of the name, the size of the corresponding text is [6,12]
  static double getNameFontsize(double z, {double? halfSize}) {
    halfSize ??= nameHalfSize;
    return _getDisplaySize(z, halfSize);
  }

  /// Get the transparency, the transparency of the corresponding point is [0.5,1]
  static double getPointOpacity(double z, [double halfOpacity = 0.5]) {
    return _getDisplaySize(z, halfOpacity);
  }

  /// Get point and text spacing
  static double getPointTopMargin(double z, {double? halfTop}) {
    halfTop ??= pointHalfTop;
    return _getDisplaySize(z, halfTop);
  }

  /// get point size
  static double getPointStrokeWidth(double z, {double? halfWidth}) {
    halfWidth ??= pointHalfWidth;
    return _getDisplaySize(z, halfWidth);
  }

  /// Get the size according to the ratio
  static double _getDisplaySize(double z, double halfValue) {
    return halfValue + halfValue * (z + radius) / (2 * radius);
  }
}
