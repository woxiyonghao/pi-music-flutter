import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'iphone_landscape_view.dart';
import 'iphone_portrait_view.dart';
import 'widgets/iphone_orientation_dialog.dart';

/// iPhone 移动端发烧纯音主视窗
/// 具备：
/// 1. 每次冷启动弹出横竖屏操作模式选择对话框 (不持久化记住，每次自由选择)
/// 2. 竖屏模式：1:1 严格对齐四大层级设计手稿 (顶部Sidebar、内容视窗、歌曲信息卡片、iPad/Mac播放底栏)
/// 3. 横屏模式：1:1 严格对齐 Mac 经典固定 4 块架构 (左上功能歌单、左下DAC卡片、右上主舞台、右下播放胶囊栏)
/// 4. 无息屏屏保，无全屏打扰，所有板块常驻单手触控
class IphoneMainView extends StatefulWidget {
  const IphoneMainView({super.key});

  @override
  State<IphoneMainView> createState() => _IphoneMainViewState();
}

class _IphoneMainViewState extends State<IphoneMainView> {
  // 启动模式选择状态 (内存变量：每次 App 启动均访问用户，不记住偏好)
  bool _hasSelectedOrientation = false;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    // 默认允许自由旋转以配合启动检测
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _onOrientationConfirmed(bool isLandscape) {
    setState(() {
      _isLandscape = isLandscape;
      _hasSelectedOrientation = true;
    });

    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _switchToLandscape() {
    setState(() {
      _isLandscape = true;
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _switchToPortrait() {
    setState(() {
      _isLandscape = false;
    });
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 主工作台界面 (横屏或竖屏)
        Positioned.fill(
          child: _isLandscape
              ? IphoneLandscapeView(onSwitchToPortrait: _switchToPortrait)
              : IphonePortraitView(onSwitchToLandscape: _switchToLandscape),
        ),

        // 每次启动冷启动弹窗：横竖屏选择模态框 (覆盖在主视窗上)
        if (!_hasSelectedOrientation)
          Positioned.fill(
            child: IphoneOrientationDialog(
              initialIsLandscape: _isLandscape,
              onConfirmed: _onOrientationConfirmed,
            ),
          ),
      ],
    );
  }
}
